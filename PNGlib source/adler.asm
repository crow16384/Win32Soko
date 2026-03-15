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

.code
	BASE equ 65521
	
;
; Adler32 Procedure
; Written and optimized by The Svin, bitRAKE and Thomas Bleeker
;
PNGI_Adler32 proc uses ebx edi esi buf:DWORD,len:DWORD
	push	len
    xor     ecx, ecx
    mov     esi, buf
    inc		ecx
    xor		edx, edx
    mov     ebx, 80078071h
    shr     len, 2
_l1:
  
    cmp     len, 0
    jz      _done

    mov     edi, 5552/4
    cmp     len, edi
    ja      _b2
    mov     edi, len
_b2:
    sub     len, edi

  sub		edx, ecx ;**bitRAKE2
next:
	movzx	eax, BYTE PTR [esi+0]
	add		edx, ecx
	add		ecx, eax
	
	movzx	eax, BYTE PTR [esi+1]
	add		edx, ecx
	add		ecx, eax
	
	movzx	eax, BYTE PTR [esi+2]
	add		edx, ecx
	add		ecx, eax

	movzx	eax, BYTE PTR [esi+3]
	add		esi, 4
	add		edx, ecx
	add		ecx, eax
	dec		edi
	
	
jnz		next
add		edx, ecx ;**bitRAKE2

	 mov edi,edx ;devident
	 mov eax,edx
	 mov edx,ebx ;= 80078071h
	 mul ebx
	 mov eax,edx
	 mov edx,65521
	 shr eax,15
	 mul edx
	 sub edi,eax

	 mov eax,ecx
	 mov edx,ebx
	 mul ebx
	 mov eax,edx
	 mov edx,65521
	 shr eax,15
	 mul edx
	 sub ecx,eax
	 mov edx,edi
	 xor eax,eax
    jmp _l1
_done:
    
; slow but small code for the last 1-3 bytes
; if the size is not a multiple of 4:
    pop		edi ;len
    and		edi, 11b
_do_unaligned:
    or		edi, edi
    jz		_done_unaligned
    movzx	eax, byte ptr [esi]
    add		ecx, eax
    inc		esi
    add		edx, ecx
    dec		edi
    jmp		_do_unaligned
_done_unaligned:
	
	@@:
	cmp		ecx, BASE
    jb		@F
    sub		ecx, BASE
    jmp		@B
    @@:
    @@:
	cmp		edx, BASE
    jb		@F
    sub		edx, BASE
    jmp		@B
    @@:
      
    
    mov     eax, edx
    shl     eax, 16
    add     eax, ecx
    ret
PNGI_Adler32 endp


end
