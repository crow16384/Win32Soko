;===========================================================
;=  Необходимые заголовки и библиотеки
;===========================================================
include windows.inc
include kernel32.inc
include user32.inc
include GDI32.inc
include comdlg32.inc
include Comctl32.inc
include pnglib.inc
include MASM32.INC



includelib kernel32.lib
includelib user32.lib
includelib GDI32.lib
includelib comdlg32.lib
includelib Comctl32.lib
includelib pnglib.lib
includelib masm32.lib


;===========================================================
; MACRO определения
;===========================================================
m2m MACRO M1:REQ, M2:REQ
		mov eax,M2
		mov M1,eax
ENDM
;===========================================================

WinMain					PROTO	:HINSTANCE,:HINSTANCE,:LPSTR,:DWORD
WndProc					PROTO	:DWORD,:DWORD,:DWORD,:DWORD
ProcessKey				PROTO	:DWORD
Prepare					PROTO	:DWORD
Delete					PROTO
AskForMove				PROTO
UndoPop					PROTO
MoveMan					PROTO
MoveBox					PROTO
LoadLevel				PROTO	:DWORD
Load_PNG				PROTO	:DWORD
LevelSaveFile			PROTO
LevelLoadFile			PROTO
GetCoord				PROTO	:DWORD
DrawTile				PROTO	:DWORD,:DWORD,:DWORD,:DWORD
DrawMan					PROTO	:DWORD,:DWORD,:DWORD
Do_Status				PROTO	:DWORD
DlgProc					PROTO	:HWND,:DWORD,:WPARAM,:LPARAM


;===========================================================
;=  Ресурсы
;===========================================================
IDB_MAN         equ 2000    ;Рисунок человечка
IDB_TILE        equ 2001    ;Рисунок стен и пола
IDB_BOX         equ 2002    ;Рисунок ящика

IDI_ICONBIG     equ 2004    ;Большая иконка приложения
IDI_ICONSMALL   equ 2005    ;Маленькая иконка приложения

ID_DATA			equ 2006

IDR_ACCEL       equ 1000    ;Ускорители

IDD_ABOUTDLG	equ 1000
IDD_WLEVEL		equ	20000

IDC_LEVEL		equ 20005
IDB_LOAD_LEVEL	equ	20006


MainMenu 		equ 10000
IDM_NEWGAME 	equ 10001
IDM_SAVE 		equ	10002
IDM_LOAD 		equ	10003
IDM_EXIT 		equ	10004
IDM_UNDO 		equ 10005
IDM_RESTART 	equ	10006
IDM_ABOUT 		equ	10007
IDM_WANT_LEVEL	equ 10008

IDCD_OK          equ  1001   ;Кнопка "Все!" в диалоге "О программе"
;===========================================================

wWidth          equ  645
wHeight         equ  550

TILE_WIDTH      equ  32
TILE_HEIGHT     equ  32
MAXSIZE         equ 260

.DATA
hInstance 	dd 0
hMenu		dd 0


.CONST
AppName     db "Win32 Sokoban на Ассемблере (138 уровней!)",0
Great		db "Поздравляю!",0
Warning		db "Внимание!",0
SaveOnExit	db "Сохранить перед выходом?",0
BadLevel	db "Уровень неверный!",0	
ClassName   db "Win32Soko",0
MenuName    db "MainMenu",0
MyAccel     db "MyAccel",0
AboutDlg    db "AboutDlg",0

.DATA?
ManRec      RECT <>
BoxRec      RECT <>

LevelMap dd 80 dup (?)

CurLevel    dd ?
Step        dd ?
Boxes       dd ?
KeyPressed  dd ?	
Pushing     dd ?
ManPos      dd ?
BoxPos      dd ?
Direction   dd ?    
Timer       dd ?
hAccel      dd ?
Moves       dd ?


;========================
;Теневой DC (Back buffer)
;========================
    hBackDC     dd ?
    hBackBmp    dd ?
;========================
; hBmp и hDC 
; для стен и пола
;========================
    hTileBmp    dd ?
    hTileDC     dd ?
;====================    
; для человечка    
;====================
    hManBmp     dd ?
    hManDC      dd ?
;====================
; для ящика
;====================    

    hBoxBmp     dd ?

    hBoxDC      dd ?
;====================
    htmpBoxDC   dd ?
    htmpBoxBmp  dd ?

    htmpManDC   dd ?
    htmpManBmp  dd ?  

    hTransDC	dd ?
    hTransBmp   dd ?		

hWindow     DWORD ?
LevStart    dd ?
ManMoving   dd ?
BoxMoving   dd ?

include Data.asm
include DrawingProc.asm
include statusbar.asm
include SaveAndLoad.asm
include Stack.asm
include Undo.asm
include LoadLevel.asm
include PrepareAndDelete.asm
