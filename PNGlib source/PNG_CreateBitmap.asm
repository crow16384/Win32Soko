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
include <gdi32.inc>
include <pnglib_internal.inc>

dwtoa PROTO STDCALL :DWORD, :DWORD
dw2hex PROTO STDCALL :DWORD, :DWORD

include <cdebug.inc>
CUSTOMBITMAPINFO STRUCT
	header	BITMAPINFOHEADER <?>
	palette	dword 256 dup (?)
CUSTOMBITMAPINFO ENDS

.code
PNG_CreateBitmap proc uses esi edi ebx lpPNGInfo:DWORD, hWnd:DWORD, dwFormat:DWORD, bDDB:DWORD
LOCAL chunkInfo:PNG_CHUNKINFO
LOCAL customBitmapInfo:CUSTOMBITMAPINFO
LOCAL IBmpInfo:PNG_IBMPINFO
LOCAL hBitmap:DWORD
LOCAL bitptr:DWORD
	mov		esi, lpPNGInfo
	assume	esi: PTR PNGINFO

	mov		bitptr, 0
	
	.IF		[esi].curState!=PNGI_STATE_DECODED
		mov		[esi].dwLastError, PNGLIB_ERR_WRONGSTATE
		xor		eax, eax
		ret
	.ENDIF
	
	mov		eax, dwFormat
	.IF		eax!=PNG_OUTF_AUTO
		cmp		ah, 1
		je		@F
		@invalidformat:
		mov		[esi].dwLastError, PNGLIB_ERR_INVALIDFORMAT
		xor		eax, eax
		ret
		@@:
		shr		eax, 16
		cmp		[esi].PNGColorType, ah	;color type match?
		jne		@invalidformat
		cmp		[esi].PNGBitDepth, ah	;bit depth match?
		jne		@invalidformat
	.ENDIF
	
	; Get suggested bitmap info
	invoke	PNGI_BitmapInfo, esi, addr customBitmapInfo, addr IBmpInfo
	
	; if custom format, some of the bitmapinfo members may have 
	; to be changed
	mov		eax, dwFormat
	.IF		eax!=PNG_OUTF_AUTO
		; overrule output format:
		mov		IBmpInfo.dwOutputFormat, eax
	.ENDIF  
	assume	eax:nothing
	
	cmp eax, PNG_OUTF_TA8_T8_BGR
	je	@changebitdepth
	cmp	eax, PNG_OUTF_TA16_T8_BGR
	jne	@F
	@changebitdepth:
		mov		customBitmapInfo.header.biBitCount, 24
	@@:

	invoke	GetDC, hWnd
	mov		ebx, eax

	.IF 	bDDB
		mov		eax, customBitmapInfo.header.biWidth
		movzx	ecx, customBitmapInfo.header.biBitCount
		mul		ecx
		test	eax, 111b
		jz		@F
		add		eax, 8
		@@:
		shr		eax, 3	;bytes/pixel
		test	eax, 11b
		jz		@F
		add		eax, 4
		@@:
		and		eax, NOT 11b ;rounded up to the next 4 byte boundary
		mov		ecx, customBitmapInfo.header.biHeight
		neg		ecx
		mul		ecx
		
		invoke	PNGHelp_alloc, eax
		or		eax, eax
		jnz		@F
		mov		[esi].dwLastError, PNGLIB_ERR_MEMALLOC
		jmp		@failed
		@@:
		mov		bitptr, eax
	.ELSE
		invoke	CreateDIBSection, ebx, ADDR customBitmapInfo, DIB_RGB_COLORS,\
				 ADDR bitptr, NULL, NULL
		or		eax, eax
		jnz		@F
		mov		[esi].dwLastError, PNGLIB_ERR_CREATEBITMAP
		jmp		@failed
		@@:
		mov		hBitmap, eax
	.ENDIF

	invoke	PNG_OutputRaw, esi, bitptr, IBmpInfo.dwOutputFormat
	or		eax, eax
	jz		@failed
	
	.IF		bDDB
		invoke	CreateDIBitmap,ebx, ADDR customBitmapInfo,CBM_INIT,bitptr,ADDR customBitmapInfo,DIB_RGB_COLORS
		or		eax, eax
		jnz		@F
		mov		[esi].dwLastError, PNGLIB_ERR_CREATEBITMAP
		jmp		@failed
		@@:
		mov		hBitmap, eax
	.ENDIF
	invoke	ReleaseDC,hWnd, ebx
	
@end:
	.IF		bDDB && bitptr
		invoke	PNGHelp_free, bitptr
	.ENDIF
	mov		eax, hBitmap
	ret
@failed:
	mov		hBitmap, 0
	jmp		@end
	assume	esi:nothing
PNG_CreateBitmap endp

end