
;=============================================================================
; cdebug.inc: custom debug include by Thomas Bleeker
; All credits go to vkim and Ernie, I just made some
; modifications.
;=============================================================================







;This file was written by vkim
;vkim@aport2000.ru
;-----------------------------------------------------------------------------

DebugPrint proto :dword

FillString macro Arr, Text
    local i
IFDEF _DEBUG
    i = 0
    forc var, <&Text>
        mov Arr[i], '&var'
        i = i + 1
    endm
    mov Arr[i], 0
ENDIF
endm

FillMem macro pString, Text
    local i
IFDEF _DEBUG
    i = 0
    ifdifi <&pString>, <eax>
        push eax
        mov eax, pString
    endif
    forc var, <&Text>
        mov byte ptr [eax+i], '&var'
        i = i + 1
    endm
    mov byte ptr [eax+i], 0
    ifdifi <&pString>, <eax>
        pop eax
    endif
ENDIF
endm

;-----------------------------------------------------------------------------

PrintString macro Var: REQ
IFDEF _DEBUG
    pushad
    invoke lstrlen, addr Var
    add eax, @SizeStr(&Var)+4
    invoke GlobalAlloc, GMEM_FIXED+GMEM_ZEROINIT, eax
    mov ebx, eax
    FillMem ebx, &Var
    mov dword ptr [eax+@SizeStr(&Var)], 203D20h
    invoke lstrcat, ebx, addr Var
    invoke DebugPrint, ebx
    invoke GlobalFree, ebx
    popad
ENDIF
endm

;----------------------------------------------------------------------------

PrintStringByAddr macro Var: REQ
IFDEF _DEBUG
    pushad
    push Var
    invoke lstrlen, Var
    add eax, @SizeStr(&Var)+4
    invoke GlobalAlloc, GMEM_FIXED+GMEM_ZEROINIT, eax
    mov ebx, eax
    FillMem ebx, &Var
    mov dword ptr [eax+@SizeStr(&Var)], 203D20h
    pop eax
    invoke lstrcat, ebx, eax
    invoke DebugPrint, ebx
    invoke GlobalFree, ebx
    popad
ENDIF
endm

;---------------------------------------------------------------------------

PrintText macro Var: REQ
    local szText
IFDEF _DEBUG
    .data
    szText byte Var, 0
    .code
    pushad
    invoke DebugPrint, addr szText
    popad
ENDIF
endm

;--------------------------------------------------------------------------

PrintDec macro Var: REQ
    local szDebugNum
IFDEF _DEBUG
    .data
    szDebugNum byte 12 dup(0)
    .code
    pushad
    invoke dwtoa, Var, addr szDebugNum
    invoke lstrlen, addr szDebugNum 
    add eax, @SizeStr(&Var)+4
    invoke GlobalAlloc, GMEM_FIXED+GMEM_ZEROINIT, eax
    mov ebx, eax
    FillMem eax, &Var
    mov dword ptr [eax+@SizeStr(&Var)], 203D20h
    invoke lstrcat, eax, addr szDebugNum
    invoke DebugPrint, ebx
    invoke GlobalFree, ebx
    popad
ENDIF
endm

PrintDword macro Var: REQ
IFDEF _DEBUG
    PrintDec &Var
ENDIF
endm
;---------------------------------------------------------------------------

PrintLine macro
IFDEF _DEBUG
    PrintText "------------------------------------"
ENDIF
endm

;---------------------------------------------------------------------------

PrintHex macro Var: REQ
    local szDebugNum
IFDEF _DEBUG
    .data
    szDebugNum byte 9 dup(0) 
    .code
    pushad
    invoke dw2hex, Var, addr szDebugNum
    invoke lstrlen, addr szDebugNum
    add eax, @SizeStr(&Var)+4
    invoke GlobalAlloc, GMEM_FIXED+GMEM_ZEROINIT, eax
    mov ebx, eax
    FillMem ebx, &Var
    mov dword ptr [eax+@SizeStr(&Var)], 203D20h
    invoke lstrcat, ebx, addr szDebugNum
    invoke DebugPrint, ebx
    invoke GlobalFree, ebx
    popad
ENDIF
endm

;---------------------------------------------------------------------------

PrintError macro
    local pDesc
IFDEF _DEBUG
    pushad
    .data
    pDesc dword 0
    .code
    invoke GetLastError
    invoke FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM, 0, eax, 0, addr pDesc, 0, 0
    invoke DebugPrint, pDesc
    invoke LocalFree, pDesc
    popad
ENDIF
endm

;------------------------------------------------------------------------------
;pExcept must be a pointer to EXCEPTION_RECORD structure

PrintException macro pExcept: REQ
    local Info
IFDEF _DEBUG
    .data
    Info byte 35 dup(0)
    .code
    pushad
    mov eax, pExcept
    mov eax, (EXCEPTION_RECORD ptr [eax]).ExceptionCode
    .if ax == EXCEPTION_ACCESS_VIOLATION
        FillString Info, <EXCEPTION_ACCESS_VIOLATION>
    .elseif ax == EXCEPTION_ARRAY_BOUNDS_EXCEEDED
        FillString Info, <EXCEPTION_ARRAY_BOUNDS_EXCEEDED>
    .elseif ax == EXCEPTION_BREAKPOINT
        FillString Info, <EXCEPTION_BREAKPOINT> 
    .elseif ax == EXCEPTION_DATATYPE_MISALIGNMENT
        FillString Info, <EXCEPTION_DATATYPE_MISALIGNMENT>
    .elseif ax == EXCEPTION_FLT_DENORMAL_OPERAND
        FillString Info, <EXCEPTION_FLT_DENORMAL_OPERAND>
    .elseif ax == EXCEPTION_FLT_DIVIDE_BY_ZERO
        FillString Info, <EXCEPTION_FLT_DIVIDE_BY_ZERO>     
    .elseif ax == EXCEPTION_FLT_INEXACT_RESULT
        FillString Info, <EXCEPTION_FLT_INEXACT_RESULT>
    .elseif ax == EXCEPTION_FLT_INVALID_OPERATION
        FillString Info, <EXCEPTION_FLT_INVALID_OPERATION>  
    .elseif ax == EXCEPTION_FLT_OVERFLOW
        FillString Info, <EXCEPTION_FLT_OVERFLOW>
    .elseif ax == EXCEPTION_FLT_STACK_CHECK
        FillString Info, <EXCEPTION_FLT_STACK_CHECK>
    .elseif ax == EXCEPTION_FLT_UNDERFLOW
        FillString Info, <EXCEPTION_FLT_UNDERFLOW>      
    .elseif ax == EXCEPTION_ILLEGAL_INSTRUCTION
        FillString Info, <EXCEPTION_ILLEGAL_INSTRUCTION>
    .elseif ax == EXCEPTION_IN_PAGE_ERROR
        FillString Info, <EXCEPTION_IN_PAGE_ERROR>
    .elseif ax == EXCEPTION_INT_DIVIDE_BY_ZERO
        FillString Info, <EXCEPTION_INT_DIVIDE_BY_ZERO>
    .elseif ax == EXCEPTION_INT_OVERFLOW
        FillString Info, <EXCEPTION_INVALID_DISPOSITION>
    ;.elseif ax == EXCEPTION_NONCONTINUABLE_EXCEPTION
    ;   FillString Info, <EXCEPTION_PRIV_INSTRUCTION>
    .elseif ax == EXCEPTION_SINGLE_STEP
        FillString Info, <EXCEPTION_SINGLE_STEP>
    ;.elseif ax == EXCEPTION_STACK_OVERFLOW
    ;   FillString Info, <EXCEPTION_STACK_OVERFLOW>
    .endif
    invoke DebugPrint, addr Info
    popad
ENDIF
endm

;=============================================================================

Spy macro Var: REQ
IFDEF _DEBUG
    ifndef __dwVar
        .data
        __dwVar dword 0
        __iTrap dword 0
        .code
    endif
    .if __iTrap == 0 
        PrintText "************************************"
        push eax
        ;install new SEH
        assume fs: nothing
        mov __dwVar, offset Var
        push offset _except_handler
        push fs:[0]
        mov fs:[0], esp
        inc __iTrap
        ;set TF
        pushf
        pop ax
        or ax, 100h
        push ax
        popf
        nop 
    .endif
ENDIF  
endm

StopSpy macro
IFDEF _DEBUG
    mov __iTrap, 0 
    mov eax, [esp] ;restore previous SEH
    mov fs:[0], eax
    add esp, 8
    pop eax ;restore eax
    PrintText "************************************"
ENDIF
endm

;==============================================================================






















dw2ah textequ <dw2hex>

;---------------------------------------------------------------------
;  Routines for debugging under assmembly language
;
; Written by E Murphy
;
;  Copyright © March 24, 2000 by the author
;  Complete re-write August 9, 2000
;  Added DLog series September 7, 2000
;
;  Contact author at ernie@surfree.com
;                 or 10206.2341@compuserve.com
;
;---------------------------------------------------------------------
;  USEAGE:
;             The DPrint macros will direct debug information to either
;             a message box (only good for a few messages) or to a console
;             output (even better: show you the program's dynamic action 
;             as it happens.
;             
;             Define one of the following BEFORE the include files area:
;
;               DEBUGC  EQU 1       ; console debug print
;
;               DEBUGW  EQU 1       ; windows debug print
;
;
;             DPrint Debug statements may be added as follows:
;
;
;               DPrint "Message here"       ; print a comment
;
;               DPrintValD eax, "EAX"       ; print a comment followed by 
;                                           ;  a register value (in decimal)
;
;               DPrintValH eax, "EAX"       ; print a comment followed by 
;                                           ;  a register value (in hex)
;
;               DPrintSZ OFFSET szString , "The string is"
;                                           ; print a zero terminated string
;                                           ;  note uses a pointer
;                                           ;  also note also prints a comment string
;
;             To use console output, use the Console build options of Quick Editor
;           This is completely compatable with a windows app, as you will get both
;           the application window, and a console.
;
;             If the console app is started from a dos box, the console output 
;           goes there. This output may then be piped to a file.
;
;           IE,
;               c:\somepath>MyApp.exe  >MyApp.txt
;
;             This command dumps the console output to the file MyApp.txt
;
;             When using the windows app option, message boxes will appear. This
;           is only desirable for a very few messages. NOT SUITABLE for  
;           monitoring the message loop for sure.
;         
;             Also note, these functions will work quite happily on displaying 
;           value in memory, so that this is quite legal:
;           
;               DPrintValH SomeVar, "SomeVar is" ; print a comment followed by 
;                                                ;  a memory variable value (in hex)
;           
;
;
; LOGGING TO FILES:
;           
;           The Dlog series of macros perform the same actions as the DPrint series,
;           but send their output to a text file.  
;           
;           Dlog differs in that the file must be opened and closed, and appropiate
;           macros for this are included
;           
;           
;           DLog Debug statements may be added as follows:
;
;
;             Define the following BEFORE the include files area:
;
;               DEBUGL  EQU 1       ; console debug print
;
;
;               DLogStart "MyApp.txt"     ; opens the file for information
;                                         ;  this exampl names the file 
;                                         ;  "MyApp.txt"
;                                         ;  MUST be performed before any 
;                                         ;  other DLog statement
;
;               DLogEnd                   ; Closes the file, place just before your 
;                                         ;  your app terminates. The file will
;                                         ;  be closed by the OS if your program
;                                         ;  crashes before normal termination.
;
;               DLog "Message here"       ; print a comment
;
;               DLogValD eax, "EAX"       ; print a comment followed by 
;                                         ;  a register value (in decimal)
;
;               DLogValH eax, "EAX"       ; print a comment followed by 
;                                         ;  a register value (in hex)
;
;               DLogSZ OFFSET szString , "The string is"
;                                         ; print a zero terminated string
;                                         ;  note uses a pointer
;                                         ;  also note also prints a comment string
;
;
;
;---------------------------------------------------------------------



DPrint MACRO string:req
    LOCAL szMessage
    IFDEF _DEBUG
        ; do a console version Print Message
        .data
        szMessage   BYTE    string,0
        .code
        pushad 
        invoke DebugPrint, ADDR szMessage
        popad
    ENDIF
ENDM

DPrintValD MACRO value:req, string:req
    LOCAL szMessage, szNumBuffer
    IFDEF _DEBUG
        ; do a console version Print Message
        .data
        szMessage		db	string, ": "
        szNumBuffer     BYTE 15 DUP(?)
        .code
        pushad
        invoke dwtoa, value, ADDR szNumBuffer  
        invoke DebugPrint, addr szMessage
        popad
    ENDIF
ENDM


DPrintValH MACRO value:req, string:req
    LOCAL szMessage, szNumBuffer
    IFDEF _DEBUG
        ; do a console version Print Message
        .data
        szMessage		db	string, ": "
        szNumBuffer     BYTE 15 DUP(?)
        .code
        pushad
        invoke dw2ah, value, ADDR szNumBuffer  
        invoke DebugPrint, addr szMessage
        popad
    ENDIF
ENDM


DPrintSZ  MACRO  pstring:req, string
    LOCAL szMessage
    IFDEF _DEBUG
        ; do a console version Print Message
        .data
        IFNB <string>
            szMessage   BYTE  string, ":",0
        ENDIF
        .code
        pushad 
        pushad
        IFNB <string>
            invoke DebugPrint, ADDR szMessage
        ENDIF
        popad
        invoke DebugPrint, pstring
        popad
    ENDIF
ENDM


DTrace  MACRO  szString:REQ, vars:VARARG
    LOCAL @szString, @memptr
    IFDEF _DEBUG
        ; do a console version Print Message
        .data
        @szString  db szString, 0
        .data?
        @memptr dd ?
        .code
        pushad 
        pushad
        invoke 	GlobalAlloc, GMEM_FIXED, 512
        mov		@memptr, eax
        popad
        invoke	wsprintf, @memptr, addr @szString, vars
        invoke 	DebugPrint, @memptr
        invoke	GlobalFree, @memptr
        popad
    ENDIF
ENDM

DbgDump	MACRO	lpStart:REQ, lnData:req

; DbgDump debug macro. Dumps memory. Usage:
; 		DbgDump [startaddress], [length]
; Any mem locations, registers or 
; immediate values may be used as parameters.
;
; Written by Thomas Bleeker [exagone].
; http://exagone.cjb.net
;
LOCAL @pmem
    IFDEF _DEBUG
	.data?
	@pmem	dd	?
	.code

	pushad
	push	lpStart
	push	lnData
	invoke	GlobalAlloc, GMEM_FIXED, 80
	mov		@pmem, eax

	pop		ebx ;lnData
	pop		esi ;lpStart
	
	.WHILE	ebx
		mov		edi, @pmem
		invoke 	dw2hex, esi, edi
		mov		word ptr [edi+8],  " :"
		mov		byte ptr [edi+10], " "
		add	  	edi, 11
		
		push	esi
		push	ebx
		; dump hex values:
		xor		ecx, ecx
		.WHILE	ecx<16
			.IF		!ebx
				mov	 dword ptr [edi], "    "
				add	 edi, 3				
			.ELSE
				dec	 ebx
				xor	 eax, eax
				
				mov	 al, [esi]
				inc	 esi
				ror	 ax, 4
				shr	 ah, 4
				add	 ax, 3030h
				cmp	 ah, 39h
				jbe	 @F
				add	 ah, "A"-3Ah
				@@:
				cmp	 al, 39h
				jbe	 @F
				add	 al, "A"-3Ah
				@@:
				mov	 word ptr [edi], ax
				mov	 byte ptr [edi+2], " "
				add	 edi, 3
			.ENDIF
			inc	ecx
		.ENDW
		pop		ebx
		pop		esi
		mov		word ptr [edi], "  "
		add		edi, 2
		
		; dump text output:
		xor		ecx, ecx
		.WHILE	ecx<16
			mov		al, [esi]
			.IF		!ebx
				mov	 al, "."
			.ELSE
				dec	 ebx
				inc	 esi
				cmp	 al, 20h
				jae	 @F
				mov	 al, "."
				@@:
			.ENDIF
			mov	 [edi], al
			inc	 edi
			inc	 ecx
		.ENDW
		mov		byte ptr [edi],0
		mov		edi, @pmem
		
		; write dashes:
		mov		byte ptr [edi+22], "-"
		mov		byte ptr [edi+34], "-"
		mov		byte ptr [edi+46], "-"
		
		invoke	DebugPrint, edi
		
	.ENDW	
	invoke	GlobalFree, @pmem
	
	popad
	ENDIF
ENDM

