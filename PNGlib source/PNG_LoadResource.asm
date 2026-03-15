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

PNG_LoadResource proc uses esi lpPNGInfo:DWORD, hInstance:DWORD, lpResName:DWORD
	mov		esi, lpPNGInfo
	assume	esi:PTR PNGINFO
	
	.IF		[esi].curState!=PNGI_STATE_INITIALIZED || [esi].dwLoadType!=PNGI_LT_NOTHING
		mov		[esi].dwLastError, PNGLIB_ERR_ALREADY_LOADED
		xor		esi, esi
		jmp		@return
	.ENDIF
	
	mov		[esi].dwLastError, 0

	invoke	FindResource, hInstance, lpResName, RT_RCDATA
	or		eax, eax
	jnz		@F
	mov		[esi].dwLastError, PNGLIB_ERR_FINDRESOURCE
	xor		esi, esi
	jmp		@return
	@@:
	
	push	eax
	invoke	LoadResource, hInstance, eax
	pop		ecx
	or		eax, eax
	jnz		@F
	mov		[esi].dwLastError, PNGLIB_ERR_LOADRESOURCE
	xor		esi, esi
	jmp		@return
	@@:
	mov		[esi].lpPNGData, eax
	mov		[esi].lpCurrent, eax
	
	invoke	SizeofResource, hInstance, ecx
	or		eax, eax
	jnz		@F
	mov		[esi].dwLastError, PNGLIB_ERR_LOADRESOURCE
	xor		esi, esi
	jmp		@return
	@@:
	mov		[esi].lnPNGData, eax
	
	mov		[esi].dwLoadType, PNGI_LT_RESOURCE
	
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
PNG_LoadResource	endp

end