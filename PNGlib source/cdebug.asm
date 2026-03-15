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

USE_FILE = 1
.code
IFDEF _DEBUG
	
	_except_handler proc C uses edx pExcept: dword, pFrame: dword, pContext: dword, pDispatch: dword
	    local SpyVar: dword
	IFDEF _DEBUG
	    ifndef __iTrap
	        .data
	        __iTrap dword 0
	        __dwVar dword 0
	        .code
	    endif
	    mov edx, pContext
	    assume edx: ptr CONTEXT
	    .if __iTrap > 1
	        pushfd
	        pop eax
	        or ax, 100h
	        push eax
	        pop [edx].regFlag ;set TF
	        mov eax, __dwVar
	        push dword ptr [eax]
	        pop SpyVar
	        PrintDec SpyVar
	        inc __iTrap
	    .elseif __iTrap == 1
	        pushfd
	        pop eax
	        or ax, 100h
	        push eax
	        pop [edx].regFlag ;set TF
	        inc __iTrap
	    .endif
	    assume edx: nothing
	    mov eax, ExceptionContinueExecution
	    ret
	ENDIF
	_except_handler endp


.data
szWinCaption byte "Debug Window for MASM32", 0
szCommandLine byte "\masm32\bin\dbgwin.exe", 0
szCRLF byte 13, 10, 0 
szEdit byte "Edit", 0
DbgfileName	db	"debug logfile$$.txt",0
.data?
hDbgLogFile		dd		?
.code
IF USE_FILE EQ 1
	DebugPrint proc DebugData: dword
	    LOCAL bytesWritten:DWORD
	    .IF		hDbgLogFile==0
	    	invoke	CreateFile, addr DbgfileName, GENERIC_WRITE, FILE_SHARE_READ,\
	    				0, CREATE_ALWAYS,0,0
	    	mov		hDbgLogFile, eax
	    .ENDIF
	    .IF	hDbgLogFile!=0
	    	invoke	WriteFile, hDbgLogFile, addr szCRLF, 2, addr bytesWritten, 0
	    	invoke	lstrlen, DebugData
	    	lea		ecx, bytesWritten
	    	invoke	WriteFile, hDbgLogFile, DebugData,eax,ecx,0
		.ENDIF
	    ret
	DebugPrint endp
ELSE

	DebugPrint proc DebugData: dword
	    local hwnd: dword
	    invoke FindWindow, NULL, addr szWinCaption 
	    .if !eax
	        invoke WinExec, addr szCommandLine, SW_SHOWNORMAL
	        invoke FindWindow, NULL, addr szWinCaption 
	    .endif
	    .if eax
	        mov hwnd, eax
	        invoke FindWindowEx, hwnd, NULL, addr szEdit, NULL
	        mov hwnd, eax
	        invoke SendMessage, hwnd, WM_GETTEXTLENGTH, 0, 0
	        push eax
	        invoke SendMessage,hwnd,EM_SETSEL, -1, -1
	        pop eax
	        .if eax
	            invoke SendMessage,hwnd,EM_REPLACESEL, FALSE, addr szCRLF
	        .endif
	        invoke SendMessage,hwnd,EM_REPLACESEL, FALSE, DebugData
	        invoke SendMessage,hwnd,EM_SCROLLCARET, 0, 0
	    .endif
	    ret
	DebugPrint endp
ENDIF


ENDIF

end