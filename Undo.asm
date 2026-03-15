;======================================================================
; Оргинизация Undo буфера на основе стека FILO
; ---------------------------------------------------------------------
;
; ---------------------------------------------------------------------
; Ларченко В.А. 
; Изменено 13.08.2004 
;======================================================================
.DATA
UndoEnable	dd 0

.CODE

UNDO_BUFFER_SIZE	equ 332

;=========================================
;=        Сохранить последний ход        =
;=========================================
UndoPush proc uses ebx edx
	
	invoke LocalAlloc,LMEM_FIXED,UNDO_BUFFER_SIZE
	push eax				; указатель на буфер Undo
	invoke PushStack,eax	; сохраним указатель на буфер Undo в стеке FILO
	cld
	pop edi
	mov esi, offset LevelMap
	mov ecx, 80
	rep movsd
	 
	mov eax, CurLevel
	mov [edi], eax
     
	mov eax, ManPos
	mov [edi+4], eax
   
	mov eax, Boxes
	mov [edi+8], eax
 	
	ret
UndoPush endp   
;=========================================
;=      Вернуть все на один ход назад    =
;=========================================
UndoPop PROC
    LOCAL Num:DWORD
    LOCAL ddY:DWORD
    LOCAL ddX:DWORD

	invoke PopStack
	.IF eax == NULL
		;mov UndoEnable,eax
		;invoke EnableMenuItem,hMenu,IDM_UNDO,MF_GRAYED
		ret
	.endif
	push eax
	cld
	mov esi,eax
	
    mov edi, OFFSET LevelMap
    mov ecx, 80
    rep movsd
	
    lodsd
    mov CurLevel, eax
    lodsd
    mov ManPos, eax
    lodsd
    mov Boxes, eax
    pop eax
    .IF eax != NULL
    	invoke LocalFree, eax
    .ENDIF
    
	mov Num ,20
	mov ecx, 320
	mov ebx, offset LevelMap
	xor esi, esi
@@:               
	xor edx, edx
	mov eax, esi
	div Num
	shl eax, 5
	shl edx, 5
	mov ddY,eax
	mov ddX,edx
	xor eax, eax
	mov al, [ebx]
             
	.IF al=='@'
		invoke DrawTile, hTileDC, 0, ddX, ddY
	.ELSEIF al=='x'
		invoke DrawTile, hTileDC, 2, ddX, ddY
	.ELSEIF al=='#'
		invoke DrawTile, hBoxDC, 1, ddX, ddY
	.ELSEIF al=='o'
		invoke DrawTile, hBoxDC, 0, ddX, ddY
	.ELSE
		invoke DrawTile, hTileDC, 1, ddX, ddY
	.ENDIF 
	inc ebx 
	inc esi
	dec ecx
	or ecx, ecx
	jnz @B
	
	mov Pushing, FALSE            
	invoke GetCoord, ManPos
	invoke DrawMan, 0, edx, eax
	invoke InvalidateRect, hWindow, NULL, FALSE
    
	call ProcessStatusBar
	dec Moves
	call WriteMoves
	ret
UndoPop ENDP

;=========================================
;=			Очистить буфер Undo    		 =
;=========================================
ClearUndo proc
	invoke PopStack
	.WHILE eax != NULL
		invoke LocalFree,eax
		invoke PopStack
	.ENDW	
	
	ret
ClearUndo endp