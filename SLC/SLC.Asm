.586
.model flat,stdcall
option casemap: none

include WINDOWS.INC
include kernel32.inc
include MASM32.INC

includelib kernel32.lib
includelib masm32.lib

;**********************************
;	MACRO
;**********************************
print MACRO Quoted_Text:VARARG

        LOCAL Txt

          .data

            Txt db Quoted_Text,0

          .code

        invoke StdOut,ADDR Txt

ENDM
;**********************************

.CONST
MyChars	db "@#ox$  ",0

.CODE
;=====================================
; lpData - 	pointer to the source data
; hFile	 -	output file handle
; return - 	pointer to compressed data
;			NULL if fail	
;===================================== 
Compress proc lpData: DWORD, hFile: DWORD
	LOCAL wr: DWORD
	LOCAL buf: WORD
	LOCAL flag: BYTE
	
	cld
	xor eax,eax
	xor edx,edx
	mov flag,al
	mov esi,lpData
	mov ebx,offset MyChars
	
	mov ah,[esi]
	inc esi

@Skip:	
	mov edi,ebx
	mov ecx,7
	mov al,[esi]
	or al,al
	setz flag
	jz @F
	inc esi
	repne scasb
	or ecx,ecx
	jz @Skip
	
	inc edx
	cmp ah,al
	jz @Skip
@@:	
	xchg ah,al

	.IF flag
		inc edx
	.endif
		
	xchg dh,dl			
	mov dl,al
	mov buf,dx
	pushad
	invoke WriteFile,hFile,addr buf,2,addr wr,NULL
	popad
	xor edx,edx
	.IF flag
		ret
	.endif
	jmp @Skip 
				
@Exit:		
	ret
Compress endp

;=====================================
start proc
	LOCAL Arg1: DWORD
	LOCAL Arg2: DWORD
	LOCAL iFile: DWORD
	LOCAL oFile: DWORD
	LOCAL iFileMap: DWORD
	LOCAL iFileMapAddr: DWORD
	
	invoke LocalAlloc,LMEM_FIXED,MAX_PATH
	mov Arg1, eax
	invoke LocalAlloc,LMEM_FIXED,MAX_PATH
	mov Arg2, eax
	
	invoke GetCL,1,Arg1			;Get arg1
	.IF eax != 1
		print "Please use SLC.exe <input file> <output file>"
		jmp Exit
	.ENDIF
		
	invoke GetCL,2,Arg2			;Get arg2
	.IF eax != 1
		print "Please use SLC.exe <input file> <output file>"
		jmp Exit
	.ENDIF
	
	invoke CreateFile,Arg1,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
	.IF eax == INVALID_HANDLE_VALUE
		print "Error open input file"
		jmp Exit
	.ENDIF
	mov iFile,eax
	
	invoke CreateFile,Arg2,GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
	.IF eax == INVALID_HANDLE_VALUE
		print "Error open input file"
		invoke CloseHandle,iFile
		jmp Exit
	.ENDIF
	mov oFile,eax
	
	invoke CreateFileMapping,iFile,NULL,PAGE_READONLY,NULL,NULL,Arg1
	.IF eax == NULL
		print "Can't create view of input file"
		invoke CloseHandle,iFile
		invoke CloseHandle,oFile
		jmp Exit
	.ENDIF
	mov iFileMap,eax
	
	invoke MapViewOfFile,iFileMap,FILE_MAP_READ,NULL,NULL,NULL
	.IF eax == NULL
		print "Can't map input file"
		invoke CloseHandle,iFileMap
		invoke CloseHandle,iFile
		invoke CloseHandle,oFile
		jmp Exit
	.ENDIF
	mov iFileMapAddr,eax
	
	invoke Compress,eax,oFile
	

	invoke UnmapViewOfFile,iFileMapAddr
	invoke CloseHandle,iFileMap
	invoke CloseHandle,iFile
	invoke CloseHandle,oFile
	
Exit:	
	invoke LocalFree,Arg1
	invoke LocalFree,Arg2
	invoke ExitProcess,NULL
start endp	

end start