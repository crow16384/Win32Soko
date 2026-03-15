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

PNG_LoadCustom proc uses esi lpPNGInfo:DWORD, lpData:DWORD, lnData:DWORD
	mov		esi, lpPNGInfo
	assume	esi:PTR PNGINFO
	
	.IF		[esi].curState!=PNGI_STATE_INITIALIZED || [esi].dwLoadType!=PNGI_LT_NOTHING
		mov		[esi].dwLastError, PNGLIB_ERR_ALREADY_LOADED
		xor		esi, esi
		jmp		@return
	.ENDIF
	
	mov		[esi].dwLastError, 0
	mov		eax, lpData
	mov		ecx, lnData
	mov		[esi].lpPNGData, eax
	mov		[esi].lpCurrent, eax
	mov		[esi].lnPNGData, ecx
	
	mov		[esi].dwLoadType, PNGI_LT_CUSTOM
	
	invoke	PNGI_LoadHeader, esi
	.IF		eax==0
		mov		[esi].dwLoadType, PNGI_LT_NOTHING
		xor		esi, esi
		jmp		@return
	.ENDIF
	mov		[esi].curState, PNGI_STATE_DATALOADED
	mov		esi, 1
@return:
	mov		eax, esi
ret
assume	esi:nothing
PNG_LoadCustom	endp

end