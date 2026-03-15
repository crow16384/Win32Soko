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

PNG_LoadFile proc uses esi lpPNGInfo:DWORD, lpFileName:DWORD
LOCAL	hFile:DWORD
LOCAL	pMem:DWORD
LOCAL	bRead:DWORD
	mov		esi, lpPNGInfo
	assume	esi:PTR PNGINFO
	
	.IF		[esi].curState!=PNGI_STATE_INITIALIZED || [esi].dwLoadType!=PNGI_LT_NOTHING
		mov		[esi].dwLastError, PNGLIB_ERR_ALREADY_LOADED
		xor		esi, esi
		jmp		@return
	.ENDIF
	
	mov		[esi].dwLastError, 0
	invoke	CreateFile, lpFileName, GENERIC_READ, FILE_SHARE_READ, NULL,\
				OPEN_EXISTING, NULL, NULL
	.IF		eax==INVALID_HANDLE_VALUE
		IFDEF _DEBUG
			invoke	GetLastError
			DPrintValD eax, "!!!!!!!!! CreateFile failed, last error (dec)"
		ENDIF
		mov		[esi].dwLastError, PNGLIB_ERR_OPENFILE
		xor		esi, esi
		jmp		@return
	.ENDIF
	mov		hFile, eax
	invoke	GetFileSize, eax, NULL
	.IF		eax==-1
		mov		[esi].dwLastError, PNGLIB_ERR_OPENFILE
		xor		esi, esi
		jmp		@exit1
	.ENDIF
	mov		[esi].lnPNGData, eax
	invoke	PNGHelp_alloc, eax
	.IF		eax==0
		mov		[esi].dwLastError, PNGLIB_ERR_MEMALLOC
		xor		esi, esi
		jmp		@exit1
	.ENDIF
	mov		pMem, eax
	invoke	ReadFile, hFile, pMem, [esi].lnPNGData, ADDR bRead, NULL
	.IF		eax==NULL
		mov		[esi].dwLastError, PNGLIB_ERR_OPENFILE
		xor		esi, esi
		jmp		@exit_d1
	.ENDIF
	mov		eax, pMem
	mov		[esi].lpPNGData, eax
	mov		[esi].lpCurrent, eax
	mov		[esi].dwLoadType, PNGI_LT_FILE
	
	invoke	PNGI_LoadHeader, esi
	.IF		eax==0
		xor		esi, esi
		jmp		@exit_d1
	.ENDIF
	mov		[esi].curState, PNGI_STATE_DATALOADED
	mov		esi, 1
@exit1:
	invoke	CloseHandle, hFile
@return:
	mov		eax, esi
ret
@exit_d1:
	mov		eax, lpPNGInfo
	mov		(PNGINFO ptr [eax]).dwLoadType, PNGI_LT_NOTHING
	invoke	PNGHelp_free, pMem
	jmp		@exit1
assume	esi:nothing
PNG_LoadFile		endp

end