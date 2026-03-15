.586
.model flat,stdcall
option casemap: none

include Win32Soko.inc

.DATA
ScreenRes			db "Require at least 800x600 screen resolution",0
ScreenResCaption	db "Can't continue!",0

Finish				db "Отлично! Вы трудолюбивы и достаточно умны...",13,10
					db "Спасибо, что оценили моё творение",0
FinishCapt			db "Игра закончена!",0


;===============================================================================
;=                                  ВХОД                                       =  
;===============================================================================
.CODE
start:
	invoke GetModuleHandle, NULL
	mov hInstance, eax
	;===================================  
	;=  Нужен режим 800x600. Проверим  =
	;===================================
	invoke GetSystemMetrics, SM_CXSCREEN
	mov ebx, eax
	invoke GetSystemMetrics, SM_CYSCREEN
	;cmp ebx, 800
	;cmp eax, 600
	.IF ebx < 800 || eax < 600
		invoke MessageBox, NULL, OFFSET ScreenRes, OFFSET ScreenResCaption, MB_OK or MB_ICONERROR
		invoke 	ExitProcess,1
	.ENDIF   
	
	invoke GetCL,1,offset buffer							;Если имеется переданный параметр, то передать имя файла в WinMain
	.IF eax == 1
		mov LoadFromCmdLine,TRUE
	.endif
	invoke 	WinMain, hInstance, NULL, NULL, SW_SHOWNORMAL
	invoke UnregisterClass,offset ClassName,hInstance
	invoke 	ExitProcess,NULL
;===============================================================================



;===============================================================================
;= WinMain
;===============================================================================
WinMain PROC hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    
	;================================================
	; Заполняем WNDCLASSEX структуру
	;================================================
	mov   	wc.cbSize,SIZEOF WNDCLASSEX
	mov   	wc.style, CS_HREDRAW or CS_VREDRAW
	mov   	wc.lpfnWndProc, OFFSET WndProc
	mov   	wc.cbClsExtra,NULL
	mov   	wc.cbWndExtra,NULL
	m2m  	      wc.hInstance, hInstance
	mov   	wc.hbrBackground,COLOR_WINDOW
	mov   	wc.lpszMenuName, MainMenu
	mov   	wc.lpszClassName,OFFSET ClassName
	invoke 	LoadIcon, hInstance, IDI_ICONBIG
	mov   	wc.hIcon, eax
	invoke 	LoadIcon, hInstance, IDI_ICONSMALL
	mov   	wc.hIconSm, eax
	invoke 	LoadCursor,NULL,IDC_ARROW
	mov   	wc.hCursor,eax
	invoke 	RegisterClassEx, addr wc
	invoke 	CreateWindowEx,NULL,ADDR ClassName,ADDR AppName,\
							WS_OVERLAPPEDWINDOW-WS_MAXIMIZEBOX-WS_SIZEBOX,\
							CW_USEDEFAULT, CW_USEDEFAULT,wWidth,wHeight,NULL,NULL,hInst,NULL
	mov         hWindow, eax
	invoke GetMenu,eax
	mov hMenu,eax

	invoke LoadAccelerators, hInstance, addr MyAccel
	mov hAccel, eax
      
	invoke 	ShowWindow, hWindow, CmdShow
	invoke 	UpdateWindow, hWindow
	;================================================
	; Подкачиваем сообщение и доставляем его
	;================================================
	.WHILE 	TRUE
		invoke GetMessage, ADDR msg,NULL,0,0
		.BREAK .IF (!eax)
		invoke TranslateMessage, ADDR msg
		invoke TranslateAccelerator, hWindow, hAccel, ADDR msg
		invoke DispatchMessage, ADDR msg
	.ENDW
	mov     eax,msg.wParam
	ret
WinMain endp
;===============================================================================


;===============================================================================
;= Обработка события нажатия клавиши
;===============================================================================
ProcessKey PROC Dir: DWORD
	.IF !ManMoving
		    
		m2m Direction, Dir
		invoke AskForMove
		.IF eax
			invoke UndoPush
			mov KeyPressed, eax
			mov ManMoving, FALSE
			mov BoxMoving, FALSE
			invoke MoveBox
			invoke MoveMan
			invoke UpdateWindow,hWindow
			.IF !UndoEnable
				mov UndoEnable,TRUE
				invoke EnableMenuItem,hMenu,IDM_UNDO,MF_ENABLED
			.ENDIF
		.ENDIF
	.ENDIF                    

	ret
ProcessKey ENDP
;================================================================================
; Процедура About диалога
;================================================================================
DlgProc PROC hWnd:HWND, iMsg:DWORD, wParam:WPARAM, lParam:LPARAM
	.IF iMsg == WM_CLOSE
		invoke EndDialog,hWnd,NULL
	.ELSEIF iMsg == WM_COMMAND
		mov eax,wParam
		mov edx,eax
		shr edx,16
		.IF dx == BN_CLICKED
			.IF eax == IDCD_OK
				invoke SendMessage,hWnd,WM_CLOSE,NULL,NULL
			.ENDIF
		.ENDIF
	.ELSE
		mov eax,FALSE
		ret
	.ENDIF
	mov  eax,TRUE
	ret
DlgProc endp
;===============================================================================

;================================================================================
; Процедура диалога загрузки ЛЮБОГО уровня
;================================================================================
DlgWLevProc PROC hWnd:HWND, iMsg:DWORD, wParam:WPARAM, lParam:LPARAM
	.IF iMsg == WM_CLOSE
		invoke EndDialog,hWnd,NULL
	.ELSEIF iMsg == WM_COMMAND
		mov eax,wParam
		mov edx,eax
		shr edx,16
		.IF dx == BN_CLICKED
			.IF eax == IDB_LOAD_LEVEL
				invoke GetDlgItemInt,hWnd,IDC_LEVEL,NULL,FALSE
				dec eax
				.IF eax <= MAX_LEVELS
					mov CurLevel, eax
					invoke LoadLevel,CurLevel
					invoke InvalidateRect, hWindow, NULL, FALSE
					invoke SendMessage,hWnd,WM_CLOSE,NULL,NULL
				.ELSE
					invoke MessageBox,hWnd,offset BadLevel,offset BadLevel,MB_OK
					xor eax,eax
					ret	
				.ENDIF				
			.ENDIF
		.ENDIF
	.ELSE
		xor eax,eax
		ret
	.ENDIF
	xor eax,eax
	inc eax
	ret
DlgWLevProc endp
;===============================================================================


;===============================================================================
;	Процедура обработки событий главного окна
;===============================================================================	
WndProc proc uses ebx esi hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    LOCAL	hDC:DWORD         ; контекст устройства главного окна
    LOCAL	ps:PAINTSTRUCT    ; 
    LOCAL	TempRect:RECT     ;
    
   	;============================================================
	; WM_KEYDOWN
	;============================================================            
	.IF uMsg == WM_KEYDOWN
		;=========================
		; Это кнопки направления?
		;=========================
		.IF wParam == VK_LEFT
			invoke ProcessKey, LEFT                
		.ELSEIF wParam == VK_RIGHT
			invoke ProcessKey, RIGHT
		.ELSEIF wParam == VK_UP
			invoke ProcessKey, UP                
		.ELSEIF wParam == VK_DOWN
			invoke ProcessKey, DOWN   
		.ENDIF
	;============================================================
	; WM_KEYUP
	;============================================================            
	.ELSEIF uMsg == WM_KEYUP
		mov KeyPressed, FALSE
	;============================================================
	; WM_CREATE
	;============================================================
	.ELSEIF uMsg == WM_CREATE
		invoke Do_Status, hWnd           ;Создать строку состояния
		;------------------------------------------- get height of status bar
		invoke GetWindowRect, hStatus, addr TempRect
		mov eax, TempRect.bottom
		sub eax, TempRect.top
		mov ebx, eax
		add eax, 16*TILE_HEIGHT
		invoke SetRect, addr TempRect, 0, 0, 20 * TILE_WIDTH, eax
		;------------------------------------------- calc new dimensions
		invoke AdjustWindowRectEx, addr TempRect, WS_OVERLAPPEDWINDOW, TRUE, NULL
		mov eax, TempRect.right
		sub eax, TempRect.left
		mov ecx, TempRect.bottom
		sub ecx, TempRect.top
		;------------------------------------------- set new window size
		invoke SetWindowPos, hWnd, NULL, 0, 0, eax, ecx, SWP_NOMOVE or SWP_NOZORDER
		;------------------------------------------- reposition statusbar
		invoke GetClientRect, hWnd, addr TempRect
		mov ecx, TempRect.bottom
		sub ecx, ebx
		mov edx, TempRect.right
		sub edx, TempRect.left
		invoke SetWindowPos, hStatus, NULL, 0, ecx, edx, ebx, SWP_NOZORDER
		;=================================================
        ; Заполним структуру для открытия/закрытия файлов
        ;=================================================
		mov  ofn.lStructSize,SIZEOF ofn
		m2m  ofn.hWndOwner, hWnd
		m2m  ofn.hInstance, hInstance
		mov  ofn.lpstrFilter, OFFSET FilterString
		mov  ofn.lpstrFile, OFFSET buffer
		mov  ofn.nMaxFile,MAXSIZE
		mov  ofn.lpstrDefExt, OFFSET DefExt
		
		invoke SetTimer, hWnd, NULL, 40, NULL
		mov Timer, eax
		invoke Prepare, hWnd
		invoke LoadLevel, 0

		.IF LoadFromCmdLine == TRUE
			invoke LevelLoadFile
			dec LoadFromCmdLine
		.ENDIF			
		invoke InvalidateRect, hWnd, NULL, FALSE
	;============================================================
	; WM_COMMAND
	;============================================================            
	.ELSEIF uMsg == WM_COMMAND
		mov eax,wParam		
		.IF wParam == IDM_EXIT
			jmp Exit
		.ELSEIF ax == IDM_NEWGAME
			invoke LoadLevel, 0
			invoke InvalidateRect, hWnd, NULL, FALSE
		.ELSEIF ax == IDM_RESTART
			invoke LoadLevel, CurLevel 
			invoke InvalidateRect, hWnd, NULL, FALSE
		.ELSEIF ax == IDM_SAVE
			invoke LevelSaveFile
		.ELSEIF ax == IDM_LOAD
			invoke LevelLoadFile
		.ELSEIF ax == IDM_UNDO
			invoke UndoPop
			.IF eax == NULL
				mov UndoEnable,eax
				invoke EnableMenuItem,hMenu,IDM_UNDO,MF_GRAYED
			.ENDIF
		.ELSEIF ax == IDM_ABOUT
			invoke DialogBoxParam,hInstance, IDD_ABOUTDLG,hWnd,offset DlgProc,NULL
		.ELSEIF ax == IDM_WANT_LEVEL
			invoke DialogBoxParam,hInstance, IDD_WLEVEL,hWnd,offset DlgWLevProc,NULL
			;mov CurLevel, 8
			;invoke LoadLevel,8
			;invoke InvalidateRect, hWnd, NULL, FALSE
		.ENDIF
	;============================================================
	; WM_TIMER
	;============================================================            
	.ELSEIF uMsg == WM_TIMER
		.IF ManMoving
			mov eax, BoxMoving
			and eax, Pushing
			.IF eax
				invoke MoveBox
			.ENDIF   
			invoke MoveMan
		.ENDIF        
	;============================================================
	; WM_USER+100   -- LEVEL FINISHED
	;============================================================            
	.ELSEIF uMsg == WM_USER+100 ;Уровень завершен
		invoke MessageBox, hWnd, offset Great, offset Great, MB_OK   
		inc CurLevel
		.IF CurLevel > MAX_LEVELS
			invoke MessageBox, hWnd,offset Finish,offset FinishCapt,MB_OK
			jmp Exit
		.ENDIF
		invoke LoadLevel, CurLevel
		invoke InvalidateRect, hWnd, NULL, FALSE
	;============================================================
	; WM_PAINT
	;============================================================            
	.ELSEIF uMsg == WM_PAINT
		invoke GetUpdateRect, hWnd, ADDR TempRect, TRUE
		.IF eax
			invoke BeginPaint, hWnd, ADDR ps
			mov	hDC,eax
			mov eax, TempRect.right
			mov ebx, TempRect.bottom
			sub eax, TempRect.left
			sub ebx, TempRect.top  
			invoke BitBlt, hDC, TempRect.left, TempRect.top, eax, ebx, hBackDC, \
							TempRect.left, TempRect.top, SRCCOPY
			invoke EndPaint, hWnd, ADDR ps
		.ENDIF  
	;============================================================
	; WM_DESTROY
	;============================================================            
	.ELSEIF uMsg == WM_DESTROY
Exit:
		invoke MessageBox, hWnd, offset SaveOnExit, offset Warning, MB_OKCANCEL
		.IF eax == IDOK
			invoke LevelSaveFile
		.ELSE
			invoke KillTimer, hWnd, Timer
			invoke Delete
			invoke PostQuitMessage, NULL
		.ENDIF
	.ELSE
		invoke 	DefWindowProc,hWnd,uMsg,wParam,lParam		
		ret
	.ENDIF
	xor eax,eax
	ret
WndProc endp
;================================================================================
end start
