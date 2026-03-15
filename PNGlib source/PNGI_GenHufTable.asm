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


dwtoa PROTO STDCALL :DWORD, :DWORD
dw2hex PROTO STDCALL :DWORD, :DWORD


include <cdebug.inc>

.code
option prologue:none
option epilogue:none

;===========================================================================
; PNGI_GenHufTable procedure
;===========================================================================
; Generates LU tables A & B based on code lengths and length frequencies
; destroys edx and eax, all other registers are preserved
; Should be called according to the commented proc declaration below.
; Uses stdcall.
PNGI_GenHufTable proc lpLUtables:DWORD, lpCodeLengths:DWORD,\
				 lpLengthFreqs:DWORD, nCodes:DWORD, maxBitLength:DWORD
stk_c = 0
DECLOCALSPACE = 64
PARAMETER_COUNT = 5 
prm_lpLUtables 		textequ <dword ptr [stk_c+DECLOCALSPACE+esp+04]>
prm_lpCodeLengths 	textequ <dword ptr [stk_c+DECLOCALSPACE+esp+08]>
prm_lpLengthFreqs 	textequ <dword ptr [stk_c+DECLOCALSPACE+esp+12]>
prm_nCodes 			textequ <dword ptr [stk_c+DECLOCALSPACE+esp+16]>
prm_maxBitLength	textequ <dword ptr [stk_c+DECLOCALSPACE+esp+20]>

olcl_lengthAddr	textequ <esp+stk_c> ; size 16 DWORDS = 64 bytes
;---------------------------------------------------------------------------
	sub		esp, DECLOCALSPACE

	push esi
	push edi
	push ebx
	push esi
	push ecx
	stk_c = stk_c + 5 * 4 ;compensate stack for 5 DWORDs

;	edi		= pA
;	ebx		= pB
;	eax		= basecode
;	esi		= lpLengthFreqs
;	ecx		= bits

;	for (int i=0;i<16;i++)
;		length_addr[i]=0;
	xor		ecx, ecx
	@@:
	mov		dword ptr [olcl_lengthAddr+4*ecx], 0
	inc		ecx
	cmp		ecx, 16
	jne		@B
	
;	pA = (DWORD*)lpLUtables;
	mov		edi, prm_lpLUtables
;	pB = (WORD*)(pA + maxBitLength);
	mov		ebx, prm_maxBitLength
	mov		esi, prm_lpLengthFreqs
	lea		ebx, [edi + 4 * ebx]
	
;	long basecode = 0;
	xor		eax, eax
	
	
;	for (int bits = 1; bits <= maxBitLength; bits++)
;	{
	mov		ecx, 1
	@ml_start:
	cmp		ecx, prm_maxBitLength
	ja		@ml_end
		
;		basecode = (basecode + codeFreqs[bits-1]) << 1;
		xor		edx, edx
		mov		dx, [esi + 2 * ecx - 2]			; edx = codeFreqs[bits-1]
		add		eax, edx						; eax = basecode + codeFreqs[bits-1]
		shl		eax, 1							; eax = (basecode + codeFreqs[bits-1]) << 1

;		if (codeFreqs[bits] != 0)
		mov		dx, [esi + 2 * ecx]				; edx = codeFreq[bits]
		or		edx, edx
		jz		@cfb_zero
;		{
;			length_addr[bits] = pB;
			mov		dword ptr [olcl_lengthAddr+ecx*4], ebx
;			long P = basecode + codeFreqs[bits];
;			long Q = (long)((char*)pB - (char*)pA) / 2 - 1;
;			*pA = Q << 16 | P; 
			add		edx, eax		; edx = codeFreqs[bits] + basecode
			shl		edx, 16			; edx = P << 16
			mov		dx, bx			; dx = pB
			sub		dx, di			; dx = pB - pA
			shr		dx, 1			; dx = (pB - pA) / 2
			dec		dx				; dx = (pB - pA) / 2 - 1
			ror		edx, 16			; edx = Q << 16 | P
			mov		dword ptr [edi], edx	;*pA = edx
;			pB += codeFreqs[bits];
			xor		edx, edx
			mov		dx, [esi + 2 * ecx]			; edx = codeFreqs[bits]	
			lea		ebx, [ebx + 2 * edx]		; ebx += codeFreqs[bits] (WORDS)
;		}
		jmp @cfb_end
		@cfb_zero:
;		else
;		{
;			*pA = 0;
			mov		dword ptr [edi], edx ;edx=zero !
;			length_addr[bits] = 0;
			mov		dword ptr [olcl_lengthAddr+ecx*4],edx ;edx=zero!
;		}
		@cfb_end:
;		pA++;   
		add		edi, 4	
	
;	}
	inc	ecx
	jmp	@ml_start
	@ml_end:
	
	
	; following loop has to be optimized yet!!
	; ecx = i
	; edx = len
	; esi = lpCodeLengths
;	for (i = (nCodes-1); i>=0 ; i--)
;	{
	mov		ecx, prm_nCodes
	mov		esi, prm_lpCodeLengths
	dec		ecx
	@m2_start:
	cmp		ecx, 0
	jl		@m2_end
;		int len = codeLengths[i];
		xor		edx, edx
		mov		dl, [esi+ecx]
		or		edx, edx	
		jz		@F				;this shouldn't happen actually (so can be optimized)
;		if (len!=0)
;		{
			lea		eax, [olcl_lengthAddr+4*edx]
			mov		edx, dword ptr [eax]
;			*length_addr[len] = i;
;			length_addr[len]++;
			add		dword ptr [eax], 2
			mov		word ptr [edx], cx
;		}
		@@:
;	}
	dec		ecx
	jmp		@m2_start
	@m2_end:
;}

	pop ecx
	pop esi
	pop ebx
	pop edi
	pop esi
	stk_c = stk_c - 5 * 4 ;compensate stack for 5 DWORDs
	add		esp, DECLOCALSPACE
retn PARAMETER_COUNT*4
PNGI_GenHufTable endp

;===========================================================================



end