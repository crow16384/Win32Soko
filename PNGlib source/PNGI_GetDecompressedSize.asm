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
; Calculates size of buffer to hold decompressed, yet unfiltered data.
;
extern	PNG_LUsamplesPerPixel:BYTE

PNGI_GetDecompressedSize proc uses esi ebx edi lpPNGInfo:DWORD
IFNDEF _NOINTERLACE
LOCAL totalSize:DWORD
LOCAL passMask:DWORD
ENDIF
	mov		esi, lpPNGInfo
	assume	esi:PTR PNGINFO


	xor		eax, eax
	xor		ecx, ecx
	mov		al, [esi].PNGColorType
	mov		cl, [esi].PNGBitDepth
	mov		al, [PNG_LUsamplesPerPixel][eax]
	mul		ecx
	IFNDEF	_NOINTERLACE
		cmp		[esi].PNGInterlaced, PNG_IM_ADAM7
		je		@adam7
	ENDIF
	mul		[esi].iWidth
	test	eax, 111b
	jz		@F
	add		eax, 8
	@@:
	shr		eax, 3
	inc		eax
	;eax is now linesize for one decode PNG line, including the filter byte
	mul		[esi].iHeight ;*nr of lines
ret
IFNDEF	_NOINTERLACE
extern PNG_PassScaling:BYTE
extern PNGI_StartOffsetsLog2:BYTE
extern PNG_PassLinesScaling:BYTE
extern PNG_ILMasks_Hor:BYTE
extern PNG_ILMasks_Ver:BYTE
	@adam7:
	mov		totalSize, 0
	; eax = bits per pixel
	mov		edi, eax
	xor		ebx, ebx
	
	xor		edx, edx
	mov		dl, 1111111b	; by default, all 7 passes are used
	mov		eax, [esi].iHeight
	mov		ecx, [esi].iWidth
	cmp		eax, 5
	jb		@height_or_width_lt_5
	cmp		ecx, 5
	jb		@height_or_width_lt_5
	jmp		@setPassMask_done
	@height_or_width_lt_5:
	; lookup limited masks
	and		dl, [PNG_ILMasks_Hor][ecx-1]
	and		dl, [PNG_ILMasks_Ver][eax-1]
	@setPassMask_done:
	mov		passMask, edx

	@a7loop:
	test	passMask, 1
	jz		@empty_pass
	mov		cl, [PNGI_StartOffsetsLog2][ebx]
	xor		eax, eax
	cmp		cl, -1
	je		@F
	inc		eax
	shl		eax, cl
	neg		eax
	@@:
	add		eax, [esi].iWidth
	
	mov		cl, [PNG_PassScaling][ebx]
	dec		eax
	shr		eax, cl
	inc		eax
	mul		edi
	test	eax, 111b
	jz		@F
	add		eax, 8
	@@:
	shr		eax, 3
	inc		eax		;add filter byte
	DPrintValD eax, "linesize:"
	push	eax
	
	cmp		ebx, 3-1
	je		@adam7_ver_offset4
	cmp		ebx, 5-1
	je		@adam7_ver_offset3
	cmp		ebx, 7-1
	je		@adam7_ver_offset2
	xor		eax, eax
	jmp		@adam7_no_ver_offset
	@adam7_ver_offset3:
	mov		eax, -2
	jmp		@F
	@adam7_ver_offset4:
	mov		eax, -4
	jmp		@F
	@adam7_ver_offset2:
	mov		eax, -1
	@@:
	@adam7_no_ver_offset:
		
	add		eax, [esi].iHeight
	dec		eax
	mov		cl, [PNG_PassLinesScaling][ebx]
	shr		eax, cl
	inc		eax
	DPrintValD eax, "lines:"
	pop		ecx
	mul		ecx
	
	add		totalSize, eax
	
	
	
	@empty_pass:
	shr		passMask, 1
	inc		ebx
	cmp		ebx, 7
	jb		@a7loop
	mov		eax, totalSize
	
	ret
	
ENDIF
	assume  esi:nothing
PNGI_GetDecompressedSize endp

end