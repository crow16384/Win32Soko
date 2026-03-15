.DATA
errLoadRes  db 'Error Loading PNG',0

.CODE
;===================================================================================
; Загружаем PNG картинки из ресурсов
;===================================================================================
Load_PNG PROC res:DWORD
    LOCAL pngInfo :PNGINFO

    invoke PNG_Init, ADDR pngInfo
    invoke PNG_LoadResource, ADDR pngInfo, hInstance, res
    .IF !eax
		invoke MessageBox, hWindow, ADDR errLoadRes, ADDR errLoadRes, MB_ICONERROR
		invoke ExitProcess,1
    .ENDIF

    invoke PNG_Decode, ADDR pngInfo
    .IF !eax
		invoke MessageBox, hWindow, ADDR errLoadRes, ADDR errLoadRes, MB_ICONERROR
		invoke ExitProcess,1
    .ENDIF

    invoke PNG_CreateBitmap, ADDR pngInfo, hWindow, PNG_OUTF_AUTO, FALSE
    .IF !eax
		invoke MessageBox, hWindow, ADDR errLoadRes, ADDR errLoadRes, MB_ICONERROR
		invoke ExitProcess,1
    .ENDIF

    push eax
    invoke PNG_Cleanup, ADDR pngInfo
    
    pop eax
    ret
Load_PNG ENDP

;================================================================================
; Процедура инициализации всех hBMP и контекстов устройств
;================================================================================
Prepare PROC hWnd: DWORD
    LOCAL hDC:HDC     ;контекст устройства главного окна
    
    ;===================================================
    ; Получим главный контекст
    ;===================================================
    invoke GetDC, hWnd
    mov hDC, eax
    ;===================================================
    ; Создадим BackDC
    ;===================================================
    invoke CreateCompatibleDC, hDC
    mov hBackDC, eax
    ;===================================================
    ; И BackBmp для флиппинга
    ;===================================================
    invoke	CreateCompatibleBitmap, hDC, wWidth, wHeight
    mov hBackBmp, eax
    invoke	SelectObject, hBackDC, hBackBmp
    ;===================================================
    ; Ячейка (стена, пол)
    ;===================================================
    invoke Load_PNG, IDB_TILE
    mov hTileBmp, eax   
    
    invoke CreateCompatibleDC, hDC
    mov hTileDC, eax
    invoke SelectObject, hTileDC, hTileBmp
    ;===================================================
    ; Ящик
    ;=================================================== 
    invoke Load_PNG, IDB_BOX
    mov hBoxBmp, eax
    invoke CreateCompatibleDC, hDC
    mov hBoxDC, eax
    invoke SelectObject, hBoxDC, hBoxBmp
    ;===================================================
    ; Человечик
    ;===================================================
    invoke Load_PNG, IDB_MAN
    mov hManBmp, eax
    invoke CreateCompatibleDC, hDC
    mov hManDC, eax

    invoke CreateCompatibleDC, hDC
    mov htmpManDC, eax
    invoke CreateCompatibleBitmap, hDC, 32, 32
    mov htmpManBmp, eax
    invoke SelectObject, htmpManDC, htmpManBmp
       
    invoke CreateCompatibleDC, hDC
    mov htmpBoxDC, eax
    invoke CreateCompatibleBitmap, hDC, 32, 32
    mov htmpBoxBmp, eax
    invoke SelectObject, htmpBoxDC, htmpBoxBmp


    invoke SelectObject, hManDC, hManBmp
    invoke SetBkColor, hManDC, 0FF00FFh

    invoke CreateCompatibleDC, hBackDC
    mov hTransDC, eax
    invoke CreateBitmap, 32, 32, 1, 1, NULL
    mov hTransBmp, eax
    invoke SelectObject, hTransDC, hTransBmp
    
    invoke	ReleaseDC, hWnd, hDC
	
	;invoke LoadData
	
    ret
Prepare ENDP
;=================================================================


;=================================================================
; Удалим Все контексты устройств и картинки перед выходом
; Так же очистим память Undo
;=================================================================
Delete PROC
    invoke DeleteDC, hBackDC
    invoke DeleteObject, hBackBmp
    invoke DeleteDC, hTileDC
    invoke DeleteObject, hTileBmp

    invoke DeleteDC, hBoxDC
    invoke DeleteObject, hBoxBmp
    invoke DeleteDC, hManDC
    invoke DeleteObject, hManBmp
    invoke DeleteDC, htmpManDC
    invoke DeleteObject, htmpManBmp
    invoke DeleteDC, htmpBoxDC
    invoke DeleteObject, htmpBoxBmp

    invoke DeleteDC, hTransDC
    invoke DeleteObject, hTransBmp
	
	invoke ClearUndo

    ret
Delete ENDP
;==================================================================

