;==============================================================================;
;                      +--\ |\  | +----   |    | +---\                         ;
;                      |  | | \ | | __    |    | |___/                         ;
;                      +--/ |  \| |   \   |    | |   \                         ;
;                      |    |   | +---/   +--- ' +---/                         ;
;==============================================================================;
; PNGLIB v1.0                                                                  ;    
;                                                                              ;
; Written by Thomas Bleeker. (C) 2002.                                         ;
; Thomas@MadWizard.org                                                         ;
; www.MadWizard.org                                                            ;
;------------------------------------------------------------------------------;


.486
.model	flat,stdcall

option 	casemap:none

include	<windows.inc>
include	<kernel32.inc>
include <user32.inc>
include <pnglib_internal.inc>

dwtoa PROTO STDCALL :DWORD, :DWORD
dw2hex PROTO STDCALL :DWORD, :DWORD

include <cdebug.inc>

extern	PNGI_ValidColorTypes:BYTE

.code

PNGI_LoadHeader proc uses esi edi ebx lpPNGInfo:DWORD
LOCAL chunkInfo:PNG_CHUNKINFO

	mov		esi, lpPNGInfo
	assume	esi: PTR PNGINFO
	
	xor		eax, eax
	mov		[esi].lpCurrent, eax
	mov		[esi].pHeader, eax
	mov		[esi].pIDAT,eax
	mov		[esi].pPNGPalette,eax
	mov		[esi].dwLastError, eax
	
	cmp 	[esi].lnPNGData, 16
	jb		@failed
	
	mov		edi, [esi].lpPNGData
	cmp		dword ptr [edi], 474E5089h
	jne		@failed
	cmp		dword ptr [edi+4],0A1A0A0Dh
	jne		@failed
	
	add		edi, 8
	mov		[esi].lpCurrent, edi
	
	invoke	PNGI_GetNextChunk, esi, addr chunkInfo
	cmp		chunkInfo.dwType, PNG_CHUNK_IHDR
	jne		@failed
	
	IFDEF	_SAFE
		cmp		chunkInfo.dwLength, PNGI_CHUNKLENGTH_IHDR
		jne		@failed
	ENDIF
	
	mov		eax, edi
	add		eax, 8
	mov		[esi].pHeader, eax
	mov		ecx, dword ptr [eax] ;width in IHDR data
	bswap	ecx
	or		ecx, ecx
	jz		@failed
	IFDEF	_SAFE
		cmp		ecx, PNG_MAX_SUPPORTED_WIDTH
		ja		@failed
	ENDIF
	mov		[esi].iWidth, ecx
	mov		ecx, dword ptr [eax+4] ;height in IHDR data
	bswap	ecx
	or		ecx, ecx
	jz		@failed
	IFDEF	_SAFE
		cmp		ecx, PNG_MAX_SUPPORTED_HEIGHT
		ja		@failed
	ENDIF
	mov		[esi].iHeight, ecx
	
	DTrace "Chunk type: %d, length: %d, CRC: %08X", \
			chunkInfo.dwType,chunkInfo.dwLength,chunkInfo.dwCRC

	IFDEF _SAFE
		mov		ecx,  [esi].lpCurrent
		mov		eax, chunkInfo.dwLength
		add		eax, 4 ;chunk code is CRC-ed as well
		add		ecx, 4
		invoke	PNGI_CRC32, ecx, eax
		DPrintValH eax, "Calculated CRC 1"
		.IF		eax!=chunkInfo.dwCRC
			DPrint "CRC not correct!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 2  "
			jmp		@failed
		.ENDIF
	ENDIF
		
		
	.WHILE	1
		mov		eax, chunkInfo.dwLength
		add		eax, 12
		add		[esi].lpCurrent, eax
		
		invoke	PNGI_GetNextChunk, esi, addr chunkInfo
		.BREAK .IF !eax
		
		DTrace "Chunk type: %d, length: %d, CRC: %08X", \
				chunkInfo.dwType,chunkInfo.dwLength,chunkInfo.dwCRC
		
		IFDEF _SAFE
			mov		ecx,  [esi].lpCurrent
			mov		eax, chunkInfo.dwLength
			add		eax, 4 ;chunk code is CRC-ed as well
			add		ecx, 4
			invoke	PNGI_CRC32, ecx, eax
			DPrintValH eax, "Calculated CRC"
			.IF		eax!=chunkInfo.dwCRC
				DPrint "CRC not correct!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
				jmp		@failed
			.ENDIF
		ENDIF
		
		.IF	chunkInfo.dwType==PNG_CHUNK_UNKOWN_CRITICAL
			jmp	@format_not_ok
		.ENDIF
		
		.IF chunkInfo.dwType==PNG_CHUNK_PLTE && ![esi].pPNGPalette
			mov		eax, [esi].lpCurrent
			add		eax, 8	;move to real data
			mov		[esi].pPNGPalette, eax
			mov		eax, chunkInfo.dwLength
			xor		edx, edx
			mov		ecx, 3
			div		ecx
			IFDEF	_SAFE
				or		eax, eax	;no colors?
				jz		@failed
				or		edx, edx
				jnz		@failed		;nr of bytes not dividable by 3
				cmp		eax, 256
				ja		@failed		;max 256 colors
			ENDIF
			mov		[esi].nColors, eax
		.ENDIF
		.IF chunkInfo.dwType==PNG_CHUNK_IDAT && ![esi].pIDAT
			mov		eax, [esi].lpCurrent
			mov		[esi].pIDAT, eax
		.ENDIF
	.ENDW
	
	IFDEF	_SAFE
		cmp		[esi].pIDAT,0
		je		@failed		;no IDAT
	ENDIF
	
	mov		edx, [esi].pHeader
	assume	edx:PTR PNGI_IHDRFORMAT

	mov		ebx, offset PNGI_ValidColorTypes
	mov		al, [edx].interlaceMethod
	mov		[esi].PNGInterlaced, al
	
	mov		al, [edx].colorType
	mov		ah, [edx].bitDepth
	mov		[esi].PNGColorType, al
	mov		[esi].PNGBitDepth, ah

	@@:
	mov		cx, [ebx]
	cmp		cx, -1
	je		@format_not_ok
	add		ebx, 2
	cmp		ax, cx
	je		@format_ok
	jmp		@B
	
	@format_ok:
	cmp		[edx].filterMethod, 0
	jne		@format_not_ok
	
	cmp		[edx].compressionMethod, 0
	jne		@format_not_ok
	
	mov		al, [edx].interlaceMethod
	IFDEF	_NOINTERLACE
		or		al, al
		jnz		@format_not_ok
	ELSE
		cmp		al, 1	;only format 0 (not interlaced) and 1 (adam7) allowed
		ja		@format_not_ok
	ENDIF
	
	IFDEF	_SAFE
		cmp		[edx].colorType, 3
		jne		@F
		cmp		[esi].pPNGPalette, 0
		jz		@failed				;palette required but not present
		@@:
	ENDIF
	
	assume		edx:nothing

	jmp		@success
	
@format_not_ok:
	mov		[esi].dwLastError, PNGLIB_ERR_UNSUPPORTED
	xor		eax, eax
	ret                            
                                

@success:
xor		eax, eax
inc		eax
ret
@failed:
mov		[esi].dwLastError, PNGLIB_ERR_INVALIDPNG
xor		eax, eax
ret

	assume	esi:nothing
PNGI_LoadHeader endp

end