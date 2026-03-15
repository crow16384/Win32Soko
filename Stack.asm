;======================================================================
; Работа со стеком FILO
; ---------------------------------------------------------------------
; Всё это мне нужно для органицазии Undo бесконечной (теоретически)
; глубины
;
; ---------------------------------------------------------------------
; Ларченко В.А. 13.08.2004 
;======================================================================
.DATA
STACK STRUCT
	data	dd 0
	next	dd 0
STACK ends

StackTmp	dd 0			;Временная переменная для хранения верхушки стека

.CODE
;======================================================================
; Заталкивает значение в стек и возвращает указатель на него
;======================================================================
PushStack proc stData:DWORD
	
	;Выделим пямять для новых данных	
	invoke LocalAlloc,LMEM_FIXED,sizeof STACK
	assume eax: ptr STACK
	push stData
	pop [eax].data
	push StackTmp
	pop [eax].next
	mov StackTmp,eax
	assume eax: nothing
	
	ret
PushStack endp

;======================================================================
; Выталкиваем значение из стека и чистим пямять
;======================================================================
PopStack proc
	
	mov edi,StackTmp
	.IF edi == NULL
		xor eax,eax			;В стеке нет ничего
		ret
	.ENDIF
	assume edi: ptr STACK
	mov eax,[edi].data
	mov edx,[edi].next
	mov StackTmp,edx
	push eax
	invoke LocalFree,edi
	pop eax	
	assume edi: nothing
	ret
PopStack endp

;======================================================================
; Разматываем стек
;======================================================================
UnwindStack proc
	;Если стек пустой, то ничего не делать
	mov edi,StackTmp
	.IF edi == NULL
		xor eax,eax
		ret
	.ENDIF
	assume edi: ptr STACK
	.WHILE edi != NULL
		push [edi].next
		invoke LocalFree,edi
		pop edi
	.ENDW
	assume edi: nothing
	ret
UnwindStack endp
;=======================================================================
