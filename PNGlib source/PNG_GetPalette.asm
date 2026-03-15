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

include <pnglib_internal.inc>


.code
PNG_GetPalette proc uses esi edi lpPNGInfo:DWORD, lpOutput:DWORD, dwFormat:DWORD
	mov		esi, lpPNGInfo
	assume	esi:PTR PNGINFO

	.IF		[esi].curState<PNGI_STATE_DATALOADED || [esi].dwLoadType==PNGI_LT_NOTHING
		mov		[esi].dwLastError, PNGLIB_ERR_ALREADY_LOADED
		xor		esi, esi
		jmp		@return
	.ENDIF

	mov		ecx, dwFormat
	.IF ecx!=PNG_PF_RGB && ecx!=PNG_PF_BGRX
		mov		[esi].dwLastError, PNGLIB_ERR_INVALIDPARAMETER
		xor		esi, esi
		jmp		@return
	.ENDIF
	
	
	.IF		[esi].pPNGPalette==0 || [esi].nColors==0
		mov		[esi].dwLastError, PNGLIB_ERR_NOPALETTE
		xor		esi, esi
		jmp		@return
	.ENDIF

	.IF		ecx==PNG_PF_RGB
    	mov		ecx, [esi].nColors
    	lea		ecx, [ecx+2*ecx]
    	mov		esi, [esi].pPNGPalette
    	mov		edi, lpOutput
    	cld
    	mov	edx, ecx
		shr ecx, 2
    	rep movsd
    	mov ecx, edx
    	and ecx, 3
    	rep movsb
	.ELSEIF eax==PNG_PF_BGRX
		mov		ecx, [esi].nColors
		mov		edi, lpOutput
		mov		edx, [esi].pPNGPalette
		sub		edi, 4
		@@:
		mov		eax, [edx]	; ?? BB GG RR
		add		edi, 4
		shl		eax, 8		; BB GG RR 00
		shr		ax, 8		; BB GG 00 RR
		rol		eax, 16		; 00 RR BB GG
		add		edx, 3
		ror		ax, 8		; 00 RR GG BB
		mov		[edi], eax
		dec		ecx
		jnz		@B
	.ENDIF	
	mov		esi, 1
@return:
	mov		eax, esi
ret
assume	esi:nothing
PNG_GetPalette	endp

end