.DATA
ofn  OPENFILENAME <>

buffer          db MAXSIZE dup(0)
FilterString    db "Soko Files",0,"*.sok",0,0
DefExt          db "sok",0
LoadFromCmdLine	dd	0

.CODE
LevelSaveFile PROC
    LOCAL hFile:HFILE
    LOCAL SizeReadWrite: DWORD
    LOCAL mpos: DWORD
    
    mov ofn.Flags,OFN_LONGNAMES or\
                  OFN_EXPLORER or OFN_HIDEREADONLY
    invoke GetSaveFileName, ADDR ofn
	.if eax==TRUE
	
	   invoke CreateFile,ADDR buffer,\
                GENERIC_WRITE ,\
                NULL, NULL,CREATE_ALWAYS ,FILE_ATTRIBUTE_NORMAL,\
                NULL
    	   mov hFile,eax
	   invoke WriteFile,hFile,ADDR LevelMap, 320,ADDR SizeReadWrite,NULL
	   invoke WriteFile,hFile,OFFSET CurLevel, 4,ADDR SizeReadWrite,NULL
         mov eax, ManPos
         sub eax, OFFSET LevelMap
         mov mpos, eax

	   invoke WriteFile,hFile,ADDR mpos, 4,ADDR SizeReadWrite,NULL
         invoke WriteFile,hFile,ADDR Boxes, 4,ADDR SizeReadWrite,NULL
         invoke WriteFile,hFile,ADDR Moves, 4,ADDR SizeReadWrite,NULL
         
	   invoke CloseHandle,hFile
	.endif

    ret
LevelSaveFile ENDP




;==============================================================================
; Load Saved Level
;==============================================================================
LevelLoadFile PROC
    LOCAL hFile:HFILE
    LOCAL SizeReadWrite: DWORD
    LOCAL ddX: DWORD        ;Х координата
    LOCAL ddY: DWORD        ;Y координата
    LOCAL Num: DWORD

	
	cmp LoadFromCmdLine,1
	jz @F

    mov  ofn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_LONGNAMES or\
                    OFN_EXPLORER or OFN_HIDEREADONLY
	                    
    invoke GetOpenFileName, ADDR ofn
        .IF eax==TRUE
@@:  	
	       invoke CreateFile,ADDR buffer,\
                                GENERIC_READ or GENERIC_WRITE ,\
                                FILE_SHARE_READ or FILE_SHARE_WRITE,\
                                NULL,OPEN_EXISTING,FILE_ATTRIBUTE_ARCHIVE,\
                                NULL
		 mov hFile,eax
		 invoke ReadFile,hFile,ADDR LevelMap,320,ADDR SizeReadWrite,NULL
     		 invoke ReadFile,hFile,ADDR CurLevel,4,ADDR SizeReadWrite,NULL

     		 invoke ReadFile,hFile,ADDR ManPos,4,ADDR SizeReadWrite,NULL ;ManPosition
             mov eax, ManPos
             add eax, OFFSET LevelMap
             mov ManPos, eax
     		 invoke ReadFile,hFile,ADDR Boxes,4,ADDR SizeReadWrite,NULL
     		 invoke ReadFile,hFile,ADDR Moves,4,ADDR SizeReadWrite,NULL
	       invoke CloseHandle,hFile


             mov Num ,20
             mov ecx, 320
             mov ebx, OFFSET LevelMap
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
            
            invoke GetCoord, ManPos
            invoke DrawMan, 0, edx, eax
            invoke InvalidateRect, hWindow, NULL, FALSE
	 .ENDIF

       call ProcessStatusBar 
       call WriteMoves
    ret
LevelLoadFile ENDP

