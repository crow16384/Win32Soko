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
.data
dw255	dd	255

.code

extern PNG_DIBcpLU:BYTE                    
                                
PNGI_BitmapInfo proc uses esi edi ebx lpPNGInfo:DWORD, lpBitmapInfo:DWORD, lpIBMPInfo:DWORD
	mov		esi, lpPNGInfo
	mov		edi, lpBitmapInfo
	assume	esi: PTR PNGINFO
	assume	edi: PTR BITMAPINFOHEADER

	mov		[edi].biSize, SIZEOF BITMAPINFOHEADER
	mov		eax, [esi].iWidth
	mov		ecx, [esi].iHeight
	mov		[edi].biWidth, eax
	neg		ecx
	mov		[edi].biHeight, ecx
	mov		[edi].biPlanes, 1
	mov		[edi].biCompression, BI_RGB
	xor		eax, eax
	mov		[edi].biSizeImage, eax
	mov		[edi].biXPelsPerMeter, eax
	mov		[edi].biYPelsPerMeter, eax
	mov		[edi].biClrImportant, eax
	mov		[edi].biClrUsed, 0
	
   	mov		eax, [esi].pHeader
   	mov		cl, (PNGI_IHDRFORMAT ptr [eax]).colorType
   	mov		ch, (PNGI_IHDRFORMAT ptr [eax]).bitDepth

		;bitcount
	
	;-------------------------------------
	; determine bitcount for bitmap
	; when done (ct_done), eax will hold
	; the bitcount, edx will be:
	; 0: no palette
	; 1: use palette from PLTE chunk
	; 2: create custom palette (grayscale)
	;
	; This code assumes that color type is
	; valid and is either 0,2,3,4 or 6
	xor		eax, eax
	xor		edx, edx
	cmp		cl, 3
	ja		@cth3
	jb		@ctb3
	;color type 3
	mov		al, ch
	mov		dl, 1		;use palette from PLTE chunk
	cmp		ch, 2
	jne		@F
	mov		al, 4
	@@:
	jmp		@ct_done
	@ctb3:
	cmp		cl, 2
	je		@ct_2
	;color type 0
	mov		al, ch
	mov		dl, 2
	cmp		ch, 2
	jne		@F
	mov		al, 4
	@@:
	cmp		ch, 16
	jne		@F
	mov		al, 8
	@@:
	jmp		@ct_done
	@ct_2:
	;color type 2
	mov		al, 24
	jmp		@ct_done
	@cth3:
	cmp		cl, 4
	jne		@ct_6
	; color type 4
	mov		al, 8
	mov		dl, 2
	jmp		@ct_done
	@ct_6:
	; color type 6
	mov		al, 32
		
	@ct_done:
	mov		[edi].biBitCount,ax 		;bitcount

	
	.IF		edx==0
    	mov		[edi].biClrUsed, 0
    .ELSEIF edx==2
        mov		cl, al
    	mov		eax, 1
    	shl		eax, cl
	   	; eax = 2 ^ bitcount
	   	cmp		eax, 4
	   
	   	mov		ebx, [esi].pHeader
   		mov		bl, (PNGI_IHDRFORMAT ptr [ebx]).bitDepth
   		cmp		bl, 2
   		jne		@F
   		mov		eax, 4
   		@@:
   		cmp		bl, 16
   		jne		@F
   		mov		eax, 256
   		@@:
   	
    	mov		[edi].biClrUsed, eax
    	mov		ebx, eax
    	dec		ebx			;ebx = biClrUsed - 1
    	add		edi, SIZEOF BITMAPINFOHEADER
    	; edi now points to palette
		xor		ecx, ecx
		@@:
		mov		eax, ecx
		mul		dw255
		div		ebx
		mov		ah, al
		mov		word ptr [edi], ax
		inc		ecx
		xor		ah, ah
		mov		word ptr [edi+2], ax
		add		edi, 4
		cmp		ecx, ebx
		jbe		@B
    .ELSEIF	edx==1
       	add		edi, SIZEOF BITMAPINFOHEADER
    	; edi now points to palette
		sub		edi, 4    	
		mov		edx, [esi].pPNGPalette
		xor		ecx, ecx
		@@:
		mov		eax, [edx]	; ?? BB GG RR
		add		edi, 4
		shl		eax, 8		; BB GG RR 00
		shr		ax, 8		; BB GG 00 RR
		rol		eax, 16		; 00 RR BB GG
		add		edx, 3
		ror		ax, 8		; 00 RR GG BB
		mov		dword ptr [edi], eax
		inc		ecx
		cmp		ecx, [esi].nColors	
		jb		@B
    .ENDIF
    

; Bitmap information for internal use

   	mov		ecx, [esi].pHeader
   	mov		ah, (PNGI_IHDRFORMAT ptr [ecx]).colorType
   	mov		al, (PNGI_IHDRFORMAT ptr [ecx]).bitDepth
   	xor		ecx, ecx
   	mov		cx, ax
   	shl		ecx, 16		; UUXX0000
   	or		ecx, 0100h	; UUXXYY00
   	
   	ror		ax, 8
 	mov		edx, offset PNG_DIBcpLU
 	@ofc_lp:
 	mov		bx, [edx]
 	cmp		bx, -1
 	je		@ofc_done
 	cmp		ax, bx
 	jne		@F
 	mov		cl, [edx+2]
 	jmp		@ofc_done
 	@@:
 	add		edx, 3
 	jmp		@ofc_lp
	@ofc_done:
	
	mov		eax, lpIBMPInfo
	mov		(PNG_IBMPINFO ptr [eax]).dwOutputFormat, ecx

	xor		eax, eax
	inc		eax
	ret
	assume 	edi:nothing
	assume	esi:nothing
PNGI_BitmapInfo endp

end