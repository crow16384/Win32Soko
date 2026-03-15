;===========================================================
;=========  Create the Status bar ==========================
;===========================================================

.DATA
hStatus     		dd 0

StLevelText         db "Уровень:    ",0
StBoxesText         db "Ящиков:     ",0
StMovesText         db "Шагов:         ",0
StLevelComments_1	db "Стандартные уровни",0
StLevelComments_2	db "Дополнительные уровни",0
StLevelComments_3	db "Уровни от Yoshio Murase",0 
fmt                 db "%d",0


.CODE
Do_Status PROC hParent:DWORD
    LOCAL sbParts[4] :DWORD

    invoke CreateStatusWindow,WS_CHILD or WS_VISIBLE or \
                              SBS_SIZEGRIP,NULL, hParent, 200
    mov hStatus, eax
      
  ; -------------------------------------
  ; sbParts is a DWORD array of 4 members
  ; -------------------------------------
    mov [sbParts +  0], 120
    mov [sbParts +  4], 240
    mov [sbParts +  8], 430
    mov [sbParts + 12], -1

    invoke SendMessage,hStatus,SB_SETPARTS, 4,ADDR sbParts

    ret
Do_Status endp

;========================================================================
ProcessStatusBar:
    push eax 
    mov eax, CurLevel
    inc eax
    invoke wsprintf, ADDR StLevelText+10,ADDR fmt, eax
    invoke wsprintf, ADDR StBoxesText+10,ADDR fmt, Boxes
    invoke SendMessage, hStatus, SB_SETTEXT, 0 or SBT_RTLREADING, ADDR StLevelText
    invoke SendMessage, hStatus, SB_SETTEXT, 1 or SBT_RTLREADING, ADDR StBoxesText
    .IF CurLevel <= 49
    	invoke SendMessage, hStatus, SB_SETTEXT, 3 or SBT_RTLREADING, ADDR StLevelComments_1
	.ELSEIF CurLevel > 49 && CurLevel <= 91
		invoke SendMessage, hStatus, SB_SETTEXT, 3 or SBT_RTLREADING, ADDR StLevelComments_2
	.ELSE
		invoke SendMessage, hStatus, SB_SETTEXT, 3 or SBT_RTLREADING, ADDR StLevelComments_3
    .ENDIF
    pop eax
    ret
;========================================================================

WriteMoves:
    invoke wsprintf, ADDR StMovesText+10,ADDR fmt, Moves
    invoke SendMessage, hStatus, SB_SETTEXT, 2 or SBT_RTLREADING, ADDR StMovesText
    ret
