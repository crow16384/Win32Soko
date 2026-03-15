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

include <pnglib_internal.inc>

IFNDEF _NOINTERLACE

include	<windows.inc>
include	<kernel32.inc>
include <user32.inc>
include <cdebug.inc>

dwtoa PROTO STDCALL :DWORD, :DWORD
dw2hex PROTO STDCALL :DWORD, :DWORD
.data
extern PNGI_StartOffsetsLog2:BYTE
extern PNGI_HorOffsetsLog2:BYTE
.code
; All procs:
; on enter:
;	esi			pointer to source data
;	edi			pointer to start of current output line
;	ecx			number of source bytes
;	d,[esp+4]	Pass number (1-7)
;	d,[esp+8]	Bits per pixel in output
;	d,[esp+12]	Bytesize of one output line in the full image
;   edx/eax may be used
;
;
stk_c = 0
param_pass		textequ	<esp+4+stk_c>
param_bpp		textequ	<esp+8+stk_c>
param_outlen	textequ	<esp+12+stk_c>

option prologue:none
option epilogue:none

SELECT_PASS MACRO
LOCAL @tmp
	mov		eax, [param_pass]
	cmp		eax, 4
	je		@pass4
	jb		@tmp
	cmp		eax, 6
	jb		@pass5
	je		@pass6
	ja		@pass7
	@tmp:
	cmp		eax, 2
	jb		@pass1
	je		@pass2
	ja		@pass3
ENDM

stk_c = 0
PNGI_DeILproc_1bit	proc
;	esi			pointer to source data
;	edi			pointer to start of current output line
;	ecx			number of source bytes
	push	ebx
	push	ebp
	stk_c = stk_c + 8
	mov		ebp, [param_outlen]
	SELECT_PASS

@pass1:
	mov		edx, ecx
	mov		cl, 1
@pass1a:
	mov		al, [esi]	
	mov		ebx, 8
	@@:
	xor		ch, ch
	shl		al, 1
	rcr		ch, cl
	or		[edi], ch
	inc		edi
	dec		ebp
	jz		@done
	dec		ebx
	jnz		@B
	inc		esi
	dec		edx
	jnz		@pass1a
	jmp		@done
	
@pass2:
	mov		edx, ecx
	mov		cl, 5
	jmp		@pass1a
	
@pass3:
	mov		edx, ecx
	mov		cl, 4
	@pass3a:
	mov		al, [esi]	
	mov		ebx, 4
	@@:
	xor		ch, ch
	shl		al, 1
	rcl		ch, 4
	shl		al, 1
	rcl		ch, cl
	or		[edi], ch
	inc		edi
	dec		ebp
	jz		@done
	dec		ebx
	jnz		@B
	@@:
	inc		esi
	dec		edx
	jnz		@pass3a
	jmp		@done
@pass4:
	mov		edx, ecx
	mov		cl, 2
	jmp		@pass3a
	
@pass5:
	mov		edx, ecx
	mov		cl, 1
	@pass5a:
	mov		al, [esi]
	mov		bl, al		;ABCD
	shl		bx, 4
	mov		ah, 4
	@@:
	shr		bx, 1
	shr		bl, 1
	dec		ah
	jnz		@B
	shl		bl, cl
	or		[edi], bl
	dec		ebp
	jz		@done
	mov		bh, al		;ABCD
	mov		ah, 4
	@@:
	shr		bx, 1
	shr		bl, 1
	dec		ah
	jnz		@B
	shl		bl, cl
	or		[edi+1], bl
	dec		ebp
	jz		@done
	add		edi, 2
	inc		esi
	dec		edx
	jnz		@pass5a
	jmp		@done
	
@pass6:
	mov		edx, ecx
	xor		cl, cl
	jmp		@pass5a
@pass7:
    cld
    mov	edx, ecx
	shr ecx, 2
    rep movsd
    mov ecx, edx
    and ecx, 3
    rep movsb
	
	@done:
	pop		ebp
	pop		ebx
	stk_c = stk_c - 8
retn 12
PNGI_DeILproc_1bit	endp	

stk_c = 0
PNGI_DeILproc_2bit	proc
	push	ebx
	push	ebp
	stk_c = stk_c + 8
	mov		ebp, [param_outlen]
	dec		ebp
	mov		edx, ecx
	xor		ecx, ecx
	SELECT_PASS
@pass1:
	mov		ebx, 2
@pass1a:
	mov		al, [esi]
	mov		ch, 4
	@@:
	mov		ah, al
	and		ah, 11000000b
	shl		al, 2
	shr		ah, cl
	or		[edi], ah
	add		edi, ebx
	sub		ebp, ebx
	js		@done
	dec		ch
	jnz		@B
	inc		esi
	dec		edx
	jnz		@pass1a
	jmp		@done
@pass2:
	inc		edi
	jmp		@pass1 
@pass4:
	mov		cl, 4	
@pass3:
	mov		ebx, 1
	jmp		@pass1a



@pass5:
	mov		cl, 2
@pass6:
@pass5a:
	xor		eax, eax
	mov		al, [esi] ;		      .AABBCCDD
	mov		ch, al
	shl		ax, 2	  ;         AA.BBCCDD00
	shl		ah, 2	  ;		  AA00.BBCCDD00
	and		ch,	11b	  ;           .000000DD
	shl		ax, 2	  ;     AA00BB.CCDD0000
	shr		al, 2	  ;     AA00BB.00CCDD00
	and		al, 110000b;    AA00BB.00CC0000
	or		al, ch	  ;	    AA00BB.00CC00DD
	ror		ax, 8	  ;   00CC00DD.00AA00BB
	shl		ax, cl
	inc		esi
	or		[edi], ax
	add 	edi, 2
	sub		ebp, 2
	js		@done
	dec		edx
	jnz		@pass5a
	jmp		@done
@pass7:
    cld
    mov	ecx, edx
	shr ecx, 2
    rep movsd
    mov ecx, edx
    and ecx, 3
    rep movsb
@done:
	pop		ebp
	pop		ebx
	stk_c = stk_c - 8
	
retn 12
PNGI_DeILproc_2bit	endp
.data
DeILData_4bitA	db	0,2,0,1,0,0,0	; # of bytes hor start offset
DeILData_4bitB	db	0,0,0,0,0,4,0	; bit offset
DeILData_4bitC	db	4,4,2,2,1,1,0	; next pixel byte distance
.code
stk_c = 0
PNGI_DeILproc_4bit	proc
	push	ebx
	push	ebp
	stk_c = stk_c + 8
	mov		ebp, [param_outlen]
	dec		ebp
	mov		ebx, ecx
	mov		eax, [param_pass]
	xor		edx, edx
	cmp		eax, 7
	je		@pass7
	mov		cl, [DeILData_4bitB-1][eax]
	mov		dl, [DeILData_4bitA-1][eax]
	add		edi, edx
	sub		ebp, edx
	js		@done
	mov		dl, [DeILData_4bitC-1][eax]
@pass_next:
	mov		al, [esi]
	mov		ah, al
	shl		ah, 4
	and		al, 11110000b
	
	shr		ah, cl
	shr		al, cl
	or		[edi], al
	sub		ebp, edx
	js		@done
	or		[edi+edx], ah
	sub		ebp, edx
	js		@done
	lea		edi, [edi+2*edx]
	inc		esi
	dec		ebx
	jnz		@pass_next
	jmp		@done


@pass7:
    cld
    mov	edx, ecx
	shr ecx, 2
    rep movsd
    mov ecx, edx
    and ecx, 3
    rep movsb
	
@done:
	pop		ebp
	pop		ebx
	stk_c = stk_c - 8
	
retn 12
PNGI_DeILproc_4bit	endp

stk_c = 0
PNGI_DeILproc_8plus	proc
;	esi			pointer to source data
;	edi			pointer to start of current output line
;	ecx			number of source bytes
;	d,[esp+4]	Pass number (1-7)
;	d,[esp+8]	Bits per pixel in output
	push	ebx
	push	ebp
	stk_c = stk_c + 8
	mov		eax, [param_pass]
	mov		ebx, [param_bpp]
	shr		ebx, 3		;bytes per pixel
	push	ecx
	stk_c = stk_c + 4
	mov		cl,  [PNGI_StartOffsetsLog2-1][eax]
	xor		eax, eax
	cmp		cl, -1
	je		@no_start_offset
	mov		eax, ebx	;bytes per pixel
	shl		eax, cl		;multiply
	@no_start_offset:
	add		edi, eax	;add start offset

	mov		eax, [param_pass]
	mov		cl,  [PNGI_HorOffsetsLog2-1][eax]
	mov		eax, ebx	;bytes per pixel
	shl		eax, cl
	mov		edx, eax	;hor distance
	DPrintValD edx, "hor dist"
	pop		ecx
	stk_c = stk_c - 4
	
	dec		ecx
	@st:
	xor		ebp, ebp
	@@:
	mov		al, [esi+ebp]
	mov		[edi+ebp], al
	inc		ebp
	cmp		ebp, ebx
	jb		@B
		
	add		esi, ebx
	add		edi, edx ; next hor offset

	sub		ecx, ebx
	jns		@st
	
	pop		ebp
	pop		ebx
	stk_c = stk_c - 8
	;cmp		eax,
@set_start_offset:
@set_start_offset2:
retn 12
PNGI_DeILproc_8plus	endp

;1-bit		A
;2-bit		B
;4-bit		C
;8-bit		copy
;16-bit		copy
;24-bit		copy
;32-bit		copy
;48-bit		copy
;64-bit		copy
ENDIF
end