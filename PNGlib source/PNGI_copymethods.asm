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
;==============================================================================;
; Changes:                                                                     ;
;  - 2002.04.04 bitRAKE: general optimization                                  ;
;------------------------------------------------------------------------------;
;
; Note: These procedures can be further otpimized - Thomas
;


.486
.model	flat,stdcall

option 	casemap:none

include	<windows.inc>
include	<kernel32.inc>
include <user32.inc>
include <pnglib_internal.inc>

dwtoa PROTO STDCALL :DWORD, :DWORD
dw2hex PROTO STDCALL :DWORD, :DWORD

include <cdebug.inc>

option prologue:none
option epilogue:none


.code
; For all the functions in this source file:
; input:
;	esi 	= source data
;	ecx		= number of source data bytes
;	edi		= destination pointer
;
; return:
;	esi		= pointer to byte after last source data byte
;	edi		= pointer to byte after last destination byte
;
; all other registers may be destroyed.
; ebx, esp and ebp are preserved
;
; Note!!!!!
; Values spanning more than 1 byte are stored in network
; byte order (big endian) in the input stream, but have to
; be stored in little endian byte order for the output, regardless
; of the procedure type. 
; Furthermore, input color order is mostly Red, Green, Blue. These 
; have to be converted to the blue,green,red order used in DIBs


;X_X
;Status: checked and working correctly
;Notes: Simple unrolled memory copy used, can be optimized further
;       using MMX etc
PNGI_copyproc_X_X proc
    cld
	push	ebp
	push 	ebx
	push 	ecx
	and		ecx, NOT 1111b
	or		ecx, ecx
	jz		@no_16
	add		esi, ecx
	add		edi, ecx
	shr		ecx, 3
	neg		ecx
	@@:
	mov		eax, [esi+8*ecx+00]
	mov		edx, [esi+8*ecx+04]
	mov		ebx, [esi+8*ecx+08]
	mov		ebp, [esi+8*ecx+12]
	
	mov		[edi+8*ecx+00], eax
	mov		[edi+8*ecx+04], edx
	mov		[edi+8*ecx+08], ebx
	mov		[edi+8*ecx+12], ebp

	add		ecx, 2
	jnz		@B
	@no_16:
		
	pop		ecx
	and		ecx, 1111b
	rep		movsb

	pop	ebx
	pop	ebp
	ret
PNGI_copyproc_X_X endp



;2_4
;Status: checked and working correctly
;Notes: need to do a dword version - bitRAKE
PNGI_copyproc_2_4 proc
;Upscale 2 bits to 4 bits.
;Value stays the same, i.e. 2 bits will be
;the lower 2 bits of the 4 output bits
	shr ecx,1
	jc j2
j1:
	mov al,[esi]			
		mov dl,[esi+1]		
	mov ah,al
		mov dh,dl
	and al,11001100y
	and ah,00110011y
		and dl,11001100y
		and dh,00110011y
	rol al,2
		rol dl,2
	add	esi, 2
	rol ax,4
		rol dx,4
	add edi,4
	rol ah,4
		rol dh,4
	mov [edi-4],ax
		mov [edi-4+2],dx
jx:
	dec ecx
	jg	j1
	ret

; do the odd one...
j2:	mov al,[esi]     ;         AABBCCDD
	inc esi
	mov ah,al        ; AABBCCDDAABBCCDD
	and al,11001100y ;         AA..CC..
	and ah,00110011y ; ..BB..DD
	rol al,2         ;         ..CC..AA
	rol ax,4         ; ..DD..CC..AA..BB
	rol ah,4         ; ..CC..DD..AA..BB
	mov [edi],ax
	add edi,2
	jmp jx
PNGI_copyproc_2_4 endp


;16_8
;Status: checked and working correctly
PNGI_copyproc_16_8 proc
; Downscale 16-bit pixels to 8-bit pixels
	shr		ecx, 1		;2 bytes at a time, 16-bits
@st:
	mov		al, [esi]	;ax = LB HB (low pixel byte, high pixel byte)
	add		esi, 2
	mov		[edi], al	;store high byte only
	inc		edi
	dec		ecx
	jnz		@st
ret
PNGI_copyproc_16_8 endp






;16_8_sa
;Status: checked and working correctly
PNGI_copyproc_16_8_sa proc
;16 bit source: PIXEL WORD, ALPHA WORD
;8 bit dest   : PIXEL BYTE only (downscaled from 16-bit to 8-bit)
	shr		ecx, 2	  ;4 bytes at a time (16bit px & alpha)
@st:
	mov		al, [esi]  ;lowword=pixel, hiword=alpha
	add		esi, 4
	mov		[edi], al  ;downscale pixel (high byte only, remember:network byte order)
	inc		edi
	dec		ecx
	jnz		@st
ret
PNGI_copyproc_16_8_sa endp



;16_8_bgra
;Status: checked and working correctly
;Note: this one MMX instruction! ;)
PNGI_copyproc_16_8_bgra proc
;16-bit source: Red word, green word, blue word, alpha word
;8-bit dest:    Blue byte, green byte, Red byte, alpha byte [all downscaled]
	shr ecx,4
	jc j2
j1:
	mov al,[esi+0] ; R
	mov ah,[esi+6] ; A
		mov dl,[esi+8+0] ; R
		mov dh,[esi+8+6] ; A
	shl eax,16
		shl edx,16
	mov al,[esi+4] ; B
	mov ah,[esi+2] ; G
		mov dl,[esi+8+4] ; B
		mov dh,[esi+8+2] ; G
	mov [edi],eax
		mov [edi+4],edx
	add esi,16
	add edi,8
jx:
	dec ecx
	jg j1
	ret

j2:	mov al,[esi+0] ; R
	mov ah,[esi+6] ; A
	shl eax,16
	mov al,[esi+4] ; B
	mov ah,[esi+2] ; G
	add esi,8
	mov [edi],eax
	add edi,4
	jmp jx

PNGI_copyproc_16_8_bgra endp

;8_8_bgra
;Status: checked and working correctly
PNGI_copyproc_8_8_bgra proc
;8-bit source:  Red byte, green byte, blue byte, alpha byte
;8-bit dest:    Blue byte, green byte, Red byte, alpha byte 
	shr		ecx, 2 ; 4 bytes at a time
@st:
	mov		eax, [esi] ; A B G R 
	bswap	eax		   ; R G B A
	ror		eax, 8 	   ; A R G B
	add		esi, 4
	mov		[edi], eax ; B G R A
	add		edi, 4
	dec		ecx
	jnz		@st
ret
PNGI_copyproc_8_8_bgra endp


;8_8_bgr
;Status: checked and working correctly
PNGI_copyproc_8_8_bgr proc
;8-bit source:  Red byte, green byte, blue byte
;8-bit dest:    Blue byte, green byte, Red byte
	dec		ecx
	sub		edi, 3
@st:
	mov		ax, [esi]		;GG RR
	mov		dx, [esi+2]		;BB
	add		edi, 3
	rol		ax, 8			;RR GG
	mov		[edi], dl		;BB
	add		esi, 3
	mov		[edi+1], ax		;GG RR
	sub		ecx, 3
	jns		@st
	add		edi, 3
ret
PNGI_copyproc_8_8_bgr endp

;16_8_bgr
;Status: checked and working correctly
PNGI_copyproc_16_8_bgr proc
;16-bit source:  Red word, green word, blue word
;8-bit dest:     Blue byte, green byte, Red byte [all downscaled]
	dec		ecx
@st:
	mov		ax, [esi+0]
	mov		dx, [esi+2] 
	mov		[edi+1],dl  
	mov		[edi+2],al
	mov		ax, [esi+4]
	add		esi, 6
	mov		[edi+0], al
	add		edi, 3
	sub		ecx, 6
	jns		@st
ret
PNGI_copyproc_16_8_bgr endp

;============================== NON STANDARD TYPES ================================

;16_16_sa
;Status: checked and working correctly
PNGI_copyproc_16_16_sa proc
;16 bit source: PIXEL WORD, ALPHA WORD
;16 bit dest  : PIXEL WORD only
	shr		ecx, 2	  ;4 bytes at a time (16bit px & alpha)
@st:
	mov		eax, [esi] ;lowword=pixel, hiword=alpha
	ror		ax, 8	   ;swap al & ah, was network byte order
	mov		[edi], ax ;store pixel only
	add		esi, 4
	add		edi, 2
	dec		ecx
	jnz		@st
ret
PNGI_copyproc_16_16_sa  endp

;16_16_bgra
;Status: checked and working correctly
PNGI_copyproc_16_16_bgra proc
;16 bit source: Red WORD, Green WORD, Blue WORD, Alpha WORD
;16 bit dest  : Blue WORD, Green WORD, Red WORD, Alpha WORD
	shr		ecx, 3
	sub		edi, 8
@st:
	mov		ax, [esi]			;RED
	mov		dx, [esi+2]			;GREEN
	add		edi, 8
	ror		ax, 8
	ror		dx, 8
	mov		[edi+4], ax			
	mov		[edi+2], dx
	mov		ax, [esi+4]			;BLUE
	mov		dx, [esi+6]			;ALPHA
	ror		ax, 8
	ror		dx, 8
	add		esi, 8
	mov		[edi+0], ax
	mov		[edi+6], dx
	dec		ecx
	jnz		@st
	add		edi, 8
ret
PNGI_copyproc_16_16_bgra endp

;16_16_bgr_sa
;Status: checked and working correctly
PNGI_copyproc_16_16_bgr_sa proc
;16 bit source: Red WORD, Green WORD, Blue WORD, Alpha WORD
;16 bit dest  : Blue WORD, Green WORD, Red WORD
	shr		ecx, 3
	sub		edi, 6
@st:
	mov		ax, [esi]
	mov		dx, [esi+2]
	add		edi, 6
	ror		ax, 8
	ror		dx, 8
	mov		[edi+4], ax
	mov		[edi+2], dx
	mov		ax, [esi+4]
	mov		dx, [esi+6]
	ror		ax, 8
	ror		dx, 8
	add		esi, 8
	mov		[edi+0], ax
	dec		ecx
	jnz		@st
	add		edi, 6
ret
PNGI_copyproc_16_16_bgr_sa endp


;16_8_bgr_sa
;Status: checked and working correctly
PNGI_copyproc_16_8_bgr_sa proc
;16 bit source: Red WORD, Green WORD, Blue WORD, Alpha WORD
;16 bit dest  : Blue WORD, Green WORD, Red WORD
	shr		ecx, 3
	sub		edi, 3
@st:
	mov		ax, [esi]
	mov		dx, [esi+2]
	add		edi, 3
	mov		[edi+2], al
	mov		[edi+1], dl
	mov		ax, [esi+4]
	add		esi, 8
	mov		[edi+0], al
	dec		ecx
	jnz		@st
	add		edi, 3
ret
PNGI_copyproc_16_8_bgr_sa endp


;8_8_bgra_sa
;Status: checked and working correctly
PNGI_copyproc_8_8_bgr_sa proc
;8-bit source:  Red byte, green byte, blue byte, alpha byte
;8-bit dest:    Blue byte, green byte, Red byte
	shr ecx, 2 ; 4 bytes at a time
@st:
	mov eax, [esi] ; A B G R 
	add esi, 4
	mov [edi+2],al ; R
	bswap eax		   ; R G B A
	add edi, 3
	ror eax, 8 	   ; A R G B
	dec ecx
	mov [edi-3], ax ; B G
	jnz @st
ret
PNGI_copyproc_8_8_bgr_sa endp

;16_16_bgr
;Status: checked and working correctly
PNGI_copyproc_16_16_bgr proc
;16-bit source:  Red word, green word, blue word
;16-bit dest:    Blue word, green word, Red word
	dec		ecx
j1:
;	mov		ax, [esi+0]
;	mov		dx, [esi+2] 
;	ror		ax, 8
;	ror		dx, 8
;	mov		[edi+4],ax
;	mov		[edi+2],dx
;	mov		ax, [esi+4]
;	ror		ax, 8
;	add		esi, 6
;	mov		[edi+0], ax
;	add		edi, 6

	mov eax,[esi + 0] ; red1, green1
	mov edx,[esi + 2] ; green1, blue1
	add esi,6
	bswap eax
	bswap edx
	mov [edi + 2],eax ; green1, red1
	mov [edi + 0],edx ; blue1, green1
	add edi,6

	sub ecx,6
	jns j1
	ret
PNGI_copyproc_16_16_bgr endp


;16_16
;Status: checked and working correctly
PNGI_copyproc_16_16 proc
;16-bit source, 16-bit dest but byte order swapped
	shr		ecx, 1
	sub		edi, 2
@st:
	mov		ax, [esi]
	add		edi, 2
	ror		ax, 8
	add		esi, 2
	mov		[edi], ax
	dec		ecx
	jnz		@st
	add		edi, 2
ret
PNGI_copyproc_16_16 endp


end