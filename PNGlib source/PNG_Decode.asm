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

PNG_Decode proc uses esi lpPNGInfo:DWORD
	mov		esi, lpPNGInfo
	assume	esi:PTR PNGINFO
	.IF		[esi].curState!=PNGI_STATE_DATALOADED
		mov	[esi].dwLastError, PNGLIB_ERR_WRONGSTATE
		xor	 eax, eax
		ret
	.ENDIF

	invoke	PNGI_GetDecompressedSize, esi
	mov		[esi].lnOutput, eax
	invoke	PNGHelp_alloc, eax
	mov		[esi].lpOutput, eax
	invoke	PNGI_Decompress, esi
	.IF		eax
		mov		[esi].curState, PNGI_STATE_DECODED
	.ELSE
		push	eax
		invoke	PNGHelp_free, [esi].lpOutput
		mov		[esi].lpOutput, 0
		pop		eax
	.ENDIF
	
	assume	esi:nothing
ret
PNG_Decode		endp

end