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


.686
.model	flat,stdcall

option 	casemap:none
include	<windows.inc>
include	<kernel32.inc>
include <user32.inc>
include <pnglib_internal.inc>

dwtoa PROTO STDCALL :DWORD, :DWORD
dw2hex PROTO STDCALL :DWORD, :DWORD

include <cdebug.inc>


.code
IFDEF _SAFE


CRC MACRO
	movzx edx,al
	shr eax,8
	xor eax,[edi+4*edx]
ENDM

; The following CRC proc has been written by Nexo
;
PNGI_CRC32 proc uses ebx esi edi buf:DWORD, len:DWORD
LOCAL	CRCtable[256]:DWORD
		lea		edi,[CRCtable]
		xor		ebx,ebx
		mov		edx,0EDB88320h
@@lp:	mov		eax,ebx
		mov		ecx,8
@@:		xor		esi,esi
		shr		eax,1
		cmovc	esi,edx
		xor		eax,esi
		dec		ecx
		jne		@B
		mov		[edi],eax
		add		edi,4
		inc		bl
		jne		@@lp

		mov 	ecx,[len]
		or 		eax,-1
		mov 	esi,[buf]
		lea 	edi, [CRCtable]
		sub 	ecx,4
		jl 		@@b
	@@:	xor 	eax,[esi]
		add 	esi,4
		CRC
		CRC
		CRC
		CRC
		sub 	ecx,4
		jge 	@B
.data
	align 8
	tblmsk	dd 0,0FFh,0FFFFh,0FFFFFFh
	u_delta = unr_d-unr
	tblunr	dd unr+3*u_delta,unr+2*u_delta,unr+1*u_delta,unr

.code

	@@b:
		mov 	edx,[tblmsk+4*ecx+16]
		and 	edx,[esi]
		xor 	eax,edx
		lea 	esi,[esi+4+ecx]
		jmp 	[tblunr+4*ecx+16]
unr:	CRC
unr_d:	CRC
		CRC
	not eax
	ret
PNGI_CRC32 endp


ENDIF

end
