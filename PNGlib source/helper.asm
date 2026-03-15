;==============================================================================;
;                      +--\ |\  | +----   |    | +---\                         ;
;                      |  | | \ | | __    |    | |___/                         ;
;                      +--/ |  \| |   \   |    | |   \                         ;
;                      |    |   | +---/   +--- ' +---/                         ;
;==============================================================================;
; PNGLIB v1.0                                                                  ;    
;                                                                              ;
; Written by Thomas Bleeker. (C) 2002.                                         ;
; Thomas@MadWizard.org                                                         ;
; www.MadWizard.org                                                            ;
;------------------------------------------------------------------------------;


.486
.model	flat,stdcall

option 	casemap:none
include	<windows.inc>
include	<kernel32.inc>
include <user32.inc>
include <pnglib_internal.inc>

.code

PNGHelp_alloc proc dwSize:DWORD
	invoke	GetProcessHeap
	invoke	HeapAlloc, eax, 0, dwSize
ret
PNGHelp_alloc endp


PNGHelp_free proc lpMem:DWORD
	invoke	GetProcessHeap
	invoke	HeapFree, eax, 0, lpMem
ret
PNGHelp_free endp

PNGHelp_zeroMem	proc	lpMem:DWORD, dwSize:DWORD
; Slow but small procedure for zeroing small pieces
; of memory.
	xor		eax, eax
	mov		edx, lpMem
	mov		ecx, dwSize
	shr		ecx, 2
	@@:
	mov		[edx], eax
	add		edx, 4
	dec		ecx
	jnz		@B
	@@:
	mov		ecx, dwSize
	and		ecx, 3
	jz		@d
	@@:
	mov		[edx], al
	inc		edx
	dec		ecx
	jnz		@B
	@d:
ret
PNGHelp_zeroMem endp
end