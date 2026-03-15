;===================================================================
;==================== Load requested level =========================
;===================================================================
LoadLevel PROC nLev:DWORD
    LOCAL Num:  DWORD
    LOCAL ddX:  DWORD        ;Õ coord
    LOCAL ddY:  DWORD        ;Y coord
        
	mov UndoEnable,FALSE
	invoke ClearUndo
   	invoke EnableMenuItem,hMenu,IDM_UNDO,MF_GRAYED 
   	
    ;===================================
    ; Calc an entry for requested level
    ;===================================
    mov eax, 320
    imul nLev
    mov ecx, offset Level
    lea esi,[eax+ecx]

    ;================================
    ; Work on temp map
    ; Here we trace all moves
    ;================================
    mov edi,offset LevelMap
    push edi
    push edi
    
    sub edi, esi
    pop edi
    
    cld
    mov ecx,80
    rep movsd
    
    ;================================
    ; Initialize variables
    ;================================
    mov Num, 20
    mov Boxes, 0
    mov Step, 0
    mov Direction, 0
    pop ebx				;Level start
    mov Pushing, 0
    mov Moves, 0
    mov LevStart, ebx
    
    mov ecx, 320
@@: xor edx, edx
    mov eax, ebx
    sub eax, LevStart
    idiv Num
    shl eax, 5
    shl edx, 5
    mov ddY,eax
    mov ddX,edx
    mov al, [ebx]
    
    .IF al=='@'
        invoke DrawTile, hTileDC, 0, ddX, ddY
    .ELSEIF al=='x'
        invoke DrawTile, hTileDC, 2, ddX, ddY
    .ELSEIF al=='#'
        invoke DrawTile, hBoxDC, 1, ddX, ddY
    .ELSEIF al=='o'
        inc Boxes
        invoke DrawTile, hBoxDC, 0, ddX, ddY
    .ELSEIF al=='$'
        invoke DrawTile, hTileDC, 1, ddX, ddY
        invoke DrawMan, 6, ddX, ddY
        mov ManPos, ebx
        mov BYTE PTR [ebx],' '
	.ELSEIF al=='+'
		invoke DrawTile, hTileDC, 2, ddX, ddY
		
		;invoke DrawTile, hTileDC, 1, ddX, ddY
        invoke DrawMan, 6, ddX, ddY
        mov ManPos, ebx
        mov BYTE PTR [ebx],'x'       
    .ELSE
        invoke DrawTile, hTileDC, 1, ddX, ddY
    .ENDIF
	inc ebx 
    dec ecx
    or ecx, ecx
    jnz @B

    
    call ProcessStatusBar
    call WriteMoves
    
    ret
LoadLevel ENDP
;==============================================================

