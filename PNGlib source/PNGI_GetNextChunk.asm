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

.code

PNGI_GetNextChunk proc uses esi edi ebx lpPNGInfo:DWORD, lpChunkInfo:DWORD

	mov		ebx, lpPNGInfo
	assume	ebx:PTR PNGINFO
	
	mov		edi, [ebx].lpPNGData
	mov		esi, [ebx].lpCurrent
	add		edi, [ebx].lnPNGData
	mov		ecx, lpChunkInfo
	assume	ecx:PTR PNG_CHUNKINFO

	cmp		esi, edi
	jae		@failed

	mov		eax, edi
	sub		eax, esi
	cmp		eax, 12		;at least one 0-data chunk available?
	jb		@failed

	
	; get chunktype
	mov		eax, [esi+4]
	mov		edx, eax
	and		eax, NOT (1 SHL 5) ;unset bit 5 in first byte->always uppercased
	cmp		eax, 'RDHI'
	je		@ihdr
	cmp		eax, 'TADI'
	je		@idat
	cmp		eax, 'ETLP'
	je		@plte
	cmp		eax, 'DNEI'
	je		@iend
	;unknown:
	test	edx, (1 SHL 5) ; critical?
	mov		eax, PNG_CHUNK_UNKOWN
	jnz		@F
	mov		eax, PNG_CHUNK_UNKOWN_CRITICAL
	@@:
	jmp		@ok		
	
	@ihdr:
	mov		eax, PNG_CHUNK_IHDR
	jmp		@ok
	@idat:
	mov		eax, PNG_CHUNK_IDAT
	jmp		@ok
	@plte:
	mov		eax, PNG_CHUNK_PLTE
	jmp		@ok
	@iend:
	mov		eax, PNG_CHUNK_IEND
	;jmp		@ok
	
	@ok:
	mov		[ecx].dwType, eax
	mov		eax, [esi]
	bswap	eax
	mov		[ecx].dwLength, eax
	add		eax, esi
	add		eax, 8
	sub		edi, 4
	cmp		eax, edi
	ja		@failed
	mov		eax, [eax]
	bswap	eax
	mov		[ecx].dwCRC, eax

	assume ecx:nothing
	assume ebx:nothing
@success:
mov eax, 1
ret
@failed:
xor		eax,eax ;end of file
ret
PNGI_GetNextChunk endp

end