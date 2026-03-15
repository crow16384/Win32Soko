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

PNG_Cleanup proc uses esi lpPNGInfo:DWORD
	mov		esi, lpPNGInfo
	assume	esi:PTR PNGINFO
	.IF		[esi].dwLoadType==PNGI_LT_FILE && [esi].lpPNGData!=0
		invoke	PNGHelp_free, [esi].lpPNGData	
	.ENDIF
	.IF		[esi].curState==PNGI_STATE_DECODED
		mov		eax, [esi].lpOutput
		.IF		eax
			invoke	PNGHelp_free, eax
		.ENDIF
	.ENDIF
	
	assume  esi:nothing
	invoke	PNGHelp_zeroMem, lpPNGInfo, sizeof PNGINFO
	xor	eax, eax
	inc	eax
ret
PNG_Cleanup endp

end