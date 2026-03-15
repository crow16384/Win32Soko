.CODE
;===================================================================
; Drawing the Man
;===================================================================
; Num    -  Offset of picture
; X      -  X coord on BackDC
; Y      -  Y coord on BackDC            
;===================================================================
DrawMan PROC Num:DWORD, X:DWORD, Y:DWORD
    LOCAL sX:DWORD
    LOCAL sY:DWORD
    
    pushad
    mov eax, Num
    mov ebx, Pushing
    shl eax, 5      ;Num = Num * 32
    
    ;======================================
    ; Pushing?32:0 optimized!!
    ; No AGI
    ;======================================
    neg ebx
    sbb ebx, ebx
    and ebx, 020h
    mov sX, eax
    mov sY, ebx
    ;======================================

    invoke BitBlt, hTransDC, 0, 0, 32, 32, hManDC,  sX, sY, SRCCOPY
    invoke BitBlt, hBackDC,  X, Y, 32, 32, hManDC,  sX, sY, SRCINVERT
    invoke BitBlt, hBackDC,  X, Y, 32, 32, hTransDC, 0,  0, SRCAND
    invoke BitBlt, hBackDC,  X, Y, 32, 32, hManDC,  sX, sY, SRCINVERT
    popad
    
    ret
DrawMan ENDP    
;===========================================================================

;===================================================================
; Прорисовка базовой единицы
;===================================================================
; hSrcDC -  Контекст устройства откуда рисовать   
; Num    -  Номер смещения от начала фрейма 
;           (Num*TILE_WIDTH - реальное смещение)
; X      -  X координата на BackDC
; Y      -  Y координата на BackDC            
;===================================================================
DrawTile PROC hSrcDC:DWORD, Num:DWORD, X:DWORD, Y:DWORD
    pushad
    mov eax, Num
    shl eax, 5      ;Num = Num * TILE_WIDTH
    
    invoke BitBlt, hBackDC, X, Y, 32, 32, hSrcDC, eax, 0, SRCCOPY
    popad
    
    ret
DrawTile ENDP    
;==============================================

;============ Direction Equates ===============

LEFT    equ 0
RIGHT   equ 3
UP      equ 6
DOWN    equ 9
;==============================================


;==============================================
; Ask for the move in required direction       
; Direction is in global variable "Direction"  
;==============================================
ChgDir:
    .IF Direction==LEFT
        dec ebx
    .ELSEIF Direction==RIGHT
        inc ebx
    .ELSEIF Direction==UP
        sub ebx, 20
    .ELSE
        add ebx, 20
    .ENDIF
    
;	add ebx,Direction
   ret    
;==============================================

AskForMove PROC uses ebx
    
    mov ebx, ManPos

    call ChgDir

    mov al,[ebx]
    .IF al==' ' || al=='x'
        mov Pushing, FALSE
        mov eax, TRUE
        ret
   
    .ELSEIF al=='#'
        mov BoxPos, ebx
        
        call ChgDir
        
        mov al,[ebx]
        .IF al==' ' || al=='x'
            mov Pushing, TRUE
            mov eax, TRUE
            ret
        .ELSE
            mov Pushing, FALSE
            xor eax,eax
            ret            
        .ENDIF
        
        .ELSEIF al=='o'
        mov BoxPos, ebx
        call ChgDir
        
        mov al,[ebx]
        .IF al==' ' || al=='x'
            mov Pushing, TRUE
            mov eax, TRUE
            ret
        .ELSE
            jmp @F
        .ENDIF
        
    .ELSE
@@: 
		mov Pushing, FALSE
		mov eax, FALSE                
    .ENDIF
                                                
    ret
AskForMove ENDP

;===========================================================================
GetCoord PROC pos: DWORD
    LOCAL Nums: DWORD

    mov eax, pos
    sub eax, LevStart
    mov Nums, 20
    xor edx, edx
    div Nums
    shl eax, 5 ;Y
    shl edx, 5 ;X
ret
GetCoord ENDP
;============================================================================


;============================================================================
MoveMan PROC
	
	.IF !ManMoving
		invoke GetCoord, ManPos
		mov ManRec.left, edx
		mov ManRec.top, eax
		add edx, 32
		add eax, 32
		mov ManRec.right, edx
		mov ManRec.bottom, eax

		mov esi, ManPos
		mov al,[esi]
		.IF al==' '
			invoke DrawTile, hTileDC, 1, ManRec.left, ManRec.top
		.ELSEIF al=='x'
			invoke DrawTile, hTileDC, 2, ManRec.left, ManRec.top
		.ENDIF
		   
		invoke BitBlt, htmpManDC, 0, 0, 32, 32, hBackDC, ManRec.left, ManRec.top, SRCCOPY
		invoke DrawMan, Direction, ManRec.left, ManRec.top
		inc Step
		mov ManMoving, TRUE
		invoke InvalidateRect, hWindow, offset ManRec, FALSE
		inc Moves
		call WriteMoves 
	.ELSE
		invoke BitBlt, hBackDC, ManRec.left, ManRec.top, ManRec.right, \
						ManRec.bottom, htmpManDC, 0, 0, SRCCOPY
		invoke InvalidateRect, hWindow, offset ManRec, FALSE
		
		.IF Direction==LEFT
			invoke OffsetRect, OFFSET ManRec, -8, 0
		.ELSEIF Direction==RIGHT
			invoke OffsetRect, OFFSET ManRec, 8, 0
		.ELSEIF Direction==UP
			invoke OffsetRect, OFFSET ManRec, 0, -8
		.ELSEIF Direction==DOWN
			invoke OffsetRect, OFFSET ManRec, 0, 8
		.ENDIF
		 
		invoke BitBlt, htmpManDC, 0, 0, 32, 32, hBackDC, ManRec.left, ManRec.top, SRCCOPY
		mov eax, Direction
		mov ebx, Step
		.IF Step > 2
			sub ebx, 4
			neg ebx 
			add eax, ebx
		.ELSE
			add eax, ebx        
		.ENDIF
		        
		invoke DrawMan, eax, ManRec.left, ManRec.top
		inc Step
		.IF Step > 4
			mov ManMoving, FALSE
			mov Step, 0
			.IF Direction == LEFT
				dec ManPos
			.ELSEIF Direction == RIGHT
				inc ManPos
			.ELSEIF Direction == UP
				sub ManPos, 20
			.ELSEIF Direction == DOWN
				add ManPos, 20
			.ENDIF
		.ENDIF
		
			invoke InvalidateRect, hWindow, offset ManRec, FALSE
    .ENDIF
       
	ret
MoveMan ENDP

;============================================================================
MoveBox PROC
	LOCAL box : DWORD
    
	.IF Pushing
		.IF !BoxMoving
			invoke GetCoord, BoxPos
			mov BoxRec.left, edx
			mov BoxRec.top, eax
			add edx, 32
			add eax, 32
			mov BoxRec.right, edx
			mov BoxRec.bottom, eax
			mov ebx, BoxPos
			mov al, [ebx]
			.IF al=='#'
				invoke DrawTile, hTileDC, 2, BoxRec.left, BoxRec.top
				mov box, 1
			.ELSE
				invoke DrawTile, hTileDC, 1, BoxRec.left, BoxRec.top
				mov box, 0
			.ENDIF
			invoke BitBlt, htmpBoxDC, 0, 0, 32, 32, hBackDC, BoxRec.left, BoxRec.top, SRCCOPY
			invoke DrawTile, hBoxDC, box, BoxRec.left, BoxRec.top
			mov BoxMoving, TRUE
			invoke InvalidateRect, hWindow, OFFSET BoxRec, FALSE
		.ELSE
			invoke BitBlt, hBackDC, BoxRec.left, BoxRec.top, BoxRec.right, \
							BoxRec.bottom, htmpBoxDC, 0, 0, SRCCOPY
			invoke InvalidateRect, hWindow, OFFSET BoxRec, FALSE
			.IF Direction == LEFT
				invoke OffsetRect, OFFSET BoxRec, -8, 0
			.ELSEIF Direction == RIGHT
				invoke OffsetRect, OFFSET BoxRec, 8, 0
			.ELSEIF Direction == UP
				invoke OffsetRect, OFFSET BoxRec, 0, -8
			.ELSEIF Direction == DOWN
				invoke OffsetRect, OFFSET BoxRec, 0, 8
			.ENDIF 
			invoke BitBlt, htmpBoxDC, 0, 0, 32, 32, hBackDC, BoxRec.left, BoxRec.top, SRCCOPY
			invoke DrawTile, hBoxDC, 0, BoxRec.left, BoxRec.top
			.IF Step == 4
				mov BoxMoving, FALSE
				mov ebx, BoxPos
				mov al,[ebx]
				.IF al=='#'
					mov al,'x'
					inc Boxes
					call ProcessStatusBar
				.ELSE
					mov al,' '
				.ENDIF
				mov [ebx],al
			                        
				.IF Direction == LEFT
					dec ebx
				.ELSEIF Direction == RIGHT
					inc ebx
				.ELSEIF Direction == UP
					sub ebx, 20
				.ELSEIF Direction == DOWN
					add ebx, 20
				.ENDIF
			
				mov al,[ebx]
				.IF al=='x'
					mov box, 1
					mov al, '#'
					dec Boxes
					call ProcessStatusBar
					.IF Boxes==0
						invoke PostMessage, hWindow, WM_USER+100, NULL, NULL
					.ENDIF                
				.ELSE
					mov box, 0
					mov al,'o'
				.ENDIF  
				mov [ebx], al
				invoke DrawTile, hBoxDC, box, BoxRec.left, BoxRec.top
			.ENDIF
			
			invoke InvalidateRect, hWindow, OFFSET BoxRec, FALSE
		.ENDIF   
	.ENDIF

	ret
MoveBox ENDP