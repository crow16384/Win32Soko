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

memfill PROTO STDCALL :DWORD, :DWORD, :DWORD
dwtoa PROTO STDCALL :DWORD, :DWORD
dw2hex PROTO STDCALL :DWORD, :DWORD

include <cdebug.inc>

.data

.code
extern PNG_LUsamplesPerPixel:BYTE
extern PNG_LUcopyprocs:DWORD
IFNDEF	_NOINTERLACE
extern PNG_BPP_FormatsA:DWORD
extern PNG_BPP_FormatsB:BYTE
extern PNG_ILMasks_Hor:BYTE
extern PNG_ILMasks_Ver:BYTE
extern PNG_PassScaling:BYTE
extern PNG_PassLinesScaling:BYTE
extern PNGI_StartOffsetsLog2:BYTE
extern PNGI_HorOffsetsLog2:BYTE
ENDIF

PNG_OutputRaw proc uses esi edi ebx lpPNGInfo:DWORD, lpDest:DWORD, dwFormat:DWORD
LOCAL	dwPNGLineSize:DWORD		;bytesize of one decoded PNG scanline, including filter byte
LOCAL	dwPNGLineSizeNFB:DWORD	;dwPNGLineSize - 1 (like dwPNGLineSize, but not including filter byte)
LOCAL	lpCopyProc:DWORD
LOCAL	lpTempMem:DWORD
LOCAL	curLine:DWORD
LOCAL	nLines:DWORD
LOCAL	pMemPart1:DWORD
LOCAL	pMemPart2:DWORD
LOCAL	bytesPerPixel:DWORD
LOCAL	tmp1:DWORD,tmp2:DWORD,tmp3:DWORD, tmp4:DWORD
LOCAL	tmpBack:DWORD
LOCAL 	prevDestPtr:DWORD
LOCAL	curLineBytes:DWORD
LOCAL	SrcBitsPerPixel:DWORD

IFNDEF _NOINTERLACE
	LOCAL	bInterlaced:DWORD
	LOCAL	pOneOutputLineBuf:DWORD
	LOCAL	lnOneOutputLine:DWORD ;not size aligned to 4 bytes yet!
	LOCAL	outputBPP:DWORD
	LOCAL	imgWidth:DWORD
	LOCAL	passMask:DWORD
	; the 7 lower bits of passMask are a mask for the passes available:
	; bit: ....... 6 5 4 3 2 1 0
	; pass:        7 6 5 4 3 2 1
	; A set bit indicates the pass is available in the image. An unset bit
	; indicates the pass is not used in the image. This mask is important
	; for images with a width or height less than 5, see the PNG docs for
	; more information
	LOCAL	curPass:DWORD ;current pass number
	LOCAL	NextScanLineInPassOffset:DWORD
	LOCAL	linesCurPass:DWORD ;number of scanlines in current pass
	LOCAL 	curPassDest:DWORD
	LOCAL	lnOneOutputLineA4:DWORD	;same as lnOneOutputLine, but size aligned to 4 bytes
	LOCAL	pDeInterlaceProc:DWORD	;procedure used for deinterlacing

ENDIF

	mov		curLine, 0
	IFNDEF	_NOINTERLACE
		mov		pOneOutputLineBuf, 0
	ENDIF
	
	mov		esi, lpPNGInfo
	assume	esi:PTR PNGINFO
	
	mov		eax, [esi].iHeight
	mov		nLines, eax
	IFNDEF _NOINTERLACE
		mov		eax, [esi].iWidth
		mov		imgWidth, eax
	ENDIF
	
	xor		eax, eax
	xor		ecx, ecx
	
	IFNDEF	_NOINTERLACE
		mov		al, [esi].PNGInterlaced
		mov		bInterlaced, eax
	ENDIF
	
	mov		al, [esi].PNGColorType
	mov		cl, [esi].PNGBitDepth
	mov		al, [PNG_LUsamplesPerPixel][eax]
	xor		edx, edx
	mul		ecx
	mov		SrcBitsPerPixel, eax 
	mul		[esi].iWidth
	test	eax, 111b
	jz		@F
	add		eax, 8
	@@:
	shr		eax, 3
	inc		eax
	DPrintValH eax, "PNGLineSize(hex)"
	mov		dwPNGLineSize, eax
	dec		eax
	mov		dwPNGLineSizeNFB, eax
	
	mov		eax, SrcBitsPerPixel
	shr		eax, 3
	or		eax, eax
	jnz		@F
	inc		eax
	@@:
	DPrintValD eax, "bytes per pixel"
	mov		bytesPerPixel, eax
	mov		esi, [esi].lpOutput
	assume	esi:nothing
		
	mov		eax, dwPNGLineSizeNFB
	shl		eax, 1 ;2xdwPNGLineSizeNFB
	add		eax, 16	;add some extra bytes
	test	eax, 111b
	jz		@F
	add		eax,8
	@@:
	and		eax, NOT 111b ;aligned to 8 bytes
	push	eax
	invoke	PNGHelp_alloc, eax
	pop		ecx
	shr		ecx, 1
	mov		lpTempMem, eax
	mov		pMemPart1, eax	;aligned to 4 bytes, 8 extra bytes reserved
	add		eax, ecx
	mov		pMemPart2, eax  ;aligned to 4 bytes, 8 extra bytes reserved
	
	mov		eax, dwFormat
	and		eax, PNG_OUTFMASK_COPYPROC		;get copyproc from format
	DPrintValD eax, "Using copyproc"
	mov		eax, [PNG_LUcopyprocs][4*eax]
	mov		lpCopyProc, eax


;=========================== start of support for interlaced images ==============
IFNDEF	_NOINTERLACE
	mov		eax, bInterlaced
	or		eax, eax	; equals cmp eax, PNG_IM_NONE
	je		@not_interlaced
	cmp		eax, PNG_IM_ADAM7
	je		@adam7_interlaced
	DPrint 	"!!!!Unkown interlace method. This error should have been caught by LoadHeader already"
	jmp		@failed
	
	
@adam7_interlaced:
	mov		eax, offset PNG_BPP_FormatsA
	mov		ecx, dwFormat
	@@:
	mov		edx, [eax]
	cmp		edx, -1
	je		@failed
	add		eax, 4
	cmp		edx, ecx
	je		@F
	jmp		@B
@@:
	sub		eax, offset PNG_BPP_FormatsA
	shr		eax, 2
	xor		edx, edx
	mov		dl, [PNG_BPP_FormatsB-1][eax]
	mov		outputBPP, edx
	DPrintValD	edx, "Interlaced image. output bits per pixel is"
	
	; following code does not change EDX
	cmp		edx, 8
	jae		@a7il_proc_8plus
	cmp		edx, 4
	je		@a7il_proc_4
	cmp		edx, 2
	je		@a7il_proc_2
	cmp		edx, 1
	je		@a7il_proc_1
	DPrint	"!!!!!!! Possible bug, really weird number for output bits/pixel"
	jmp		@failed			
	@a7il_proc_8plus:
	mov		eax, offset PNGI_DeILproc_8plus
	jmp		@F
	@a7il_proc_4:
	mov		eax, offset PNGI_DeILproc_4bit
	jmp		@F
	@a7il_proc_2:
	mov		eax, PNGI_DeILproc_2bit
	jmp		@F
	@a7il_proc_1:
	mov		eax, PNGI_DeILproc_1bit
	@@:
	mov		pDeInterlaceProc, eax

	; EDX is still the same here (output bits per pixel)
	
	mov		eax, edx
	mul		imgWidth
	test	eax, 111b
	jz		@F
	add		eax, 8
	@@:
	shr		eax, 3
	mov		lnOneOutputLine, eax
	DPrintValD eax, "Length of one output line, size not yet aligned to 4 bytes"
	test	eax, 11b
	jz		@F
	add		eax, 4
	@@:
	and		eax, NOT 11b
	mov		lnOneOutputLineA4, eax
	add		eax, 16 ;add some extra space to play with
	
	DPrintValD eax, "Buffer allocated of one output line, size aligned to 4 bytes, 16 extra bytes"
	invoke	PNGHelp_alloc, eax
	mov		pOneOutputLineBuf, eax
	
	; --- set passMask ---
	xor		edx, edx
	mov		dl, 1111111b	; by default, all 7 passes are used
	mov		eax, nLines
	mov		ecx, imgWidth
	DPrintValD	ecx, "Image width"
	DPrintValD  eax, "Image height"
	cmp		eax, 5
	jb		@height_or_width_lt_5
	cmp		ecx, 5
	jb		@height_or_width_lt_5
	jmp		@setPassMask_done
	
	@height_or_width_lt_5:
	; lookup limited masks
	DPrint	"Image width or height less than 5, using limited pass mask"
	and		dl, [PNG_ILMasks_Hor][ecx-1]
	and		dl, [PNG_ILMasks_Ver][eax-1]
	@setPassMask_done:
	mov		passMask, edx
	DPrintValH edx, "passMask (hex)"
	mov		curPass, 1
	
	
	cmp		outputBPP, 8
	jae		@F
	; if output BPP is less than 8, the full output 
	; image data has to be zeroed before use.
	mov		eax, lnOneOutputLineA4
	mul		nLines
	invoke	PNGHelp_zeroMem, lpDest, eax
	@@:
	
;------------- start defiltering & output for interlaced images ------------------
@adam7_nextpass:
	mov		eax, lpDest
	mov		curPassDest, eax
	
	DPrintValD	curPass, "Current pass"
	test	passMask, 1
	jz		@empty_pass
	
	
	mov		edx, curPass
	
	mov		cl, [PNGI_StartOffsetsLog2-1][edx]
	xor		eax, eax
	cmp		cl, -1
	je		@F
	inc		eax
	shl		eax, cl
	neg		eax
	@@:
	add		eax, imgWidth
	
	mov		cl, [PNG_PassScaling-1][edx]
	dec		eax
	shr		eax, cl
	inc		eax
	mul		SrcBitsPerPixel;bytesPerPixel
	test	eax, 111b
	jz		@F
	add		eax, 8
	@@:
	shr		eax, 3
	
	; eax now contains line size of image represented by one pass
	xor		edi, edi ; no previous scanline
	or		eax, eax
	jnz		@F
	inc		eax ;at least one byte
	@@:
	
	mov		curLineBytes, eax ;store size

	
	DPrintValD	eax, "Number of bytes in one scanline for this pass"
	
	mov		edx, lnOneOutputLineA4
	mov		eax, curPass
	cmp		eax, 3
	je		@adam7_ver_offset4
	cmp		eax, 5
	je		@adam7_ver_offset3
	cmp		eax, 7
	je		@adam7_ver_offset2
	xor		eax, eax
	jmp		@adam7_no_ver_offset
	@adam7_ver_offset3:
	mov		eax, -2
	shl		edx, 1
	jmp		@F
	@adam7_ver_offset4:
	mov		eax, -4
	shl		edx, 2
	jmp		@F
	@adam7_ver_offset2:
	mov		eax, -1
	@@:
	add		curPassDest, edx
	@adam7_no_ver_offset:
		
	mov		edx, curPass
	add		eax, nLines ;nLines - vertical start offset
	dec		eax
	mov		cl, [PNG_PassLinesScaling-1][edx]
	shr		eax, cl
	inc		eax
	mov		linesCurPass, eax	; # of scanlines in current pass
	DPrintValD 	eax, "Number of scanlines for this pass"
	mov		eax, lnOneOutputLineA4
	shl		eax, cl
	mov		NextScanLineInPassOffset, eax
	DPrintValH	eax, "Vertical byte offset for next scanline in this pass"
	
	
	

	mov		curLine, 0
	mov		ebx, pMemPart1

	@adam7_next_scanline:
		; De-filter one scanline:
		jmp		@next_scanline
		; De-filter code will jump to the label below when done
		@adam7_filter_done:
		
		; ebx: ptr to line just decoded
		push	esi
		push	edi
		mov		esi, ebx
		mov		edi, pOneOutputLineBuf
		mov		ecx, curLineBytes
		call	dword ptr [lpCopyProc]
		;DbgDump pOneOutputLineBuf, curLineBytes
		mov		ecx, edi
		mov		esi, pOneOutputLineBuf
		mov		edi, curPassDest
		sub		ecx, esi

		push	lnOneOutputLineA4
		push	outputBPP
		push	curPass	
		call	dword ptr [pDeInterlaceProc]

		mov		eax, NextScanLineInPassOffset
		add		curPassDest, eax
		
		pop		edi
		pop		esi
		
	
	
		;---- swap buffers------
		mov		edi, ebx
		cmp		ebx, pMemPart1
		jne		@F
		mov		ebx, pMemPart2
		jmp		@adam7_swap_done
		@@:
		mov		ebx, pMemPart1
		@adam7_swap_done:
		;--------------------------
		
	
		inc		curLine
		mov		eax, linesCurPass
		cmp		curLine, eax
		jb		@adam7_next_scanline

;	push	esi
;	push	edi
;	mov		edi, lpDest
;	mov		esi, ebx
;	mov		ecx, curLineBytes
;	call	dword ptr [lpCopyProc]
;	;--- align---
;	sub		edi, lpDest
;	test	edi, 11b ;size is multiple of 4?
;	jz		@F
;	add		edi, 4
;	and		edi, (NOT 11b)
;	@@:
;	;--- end align ----
;	add		lpDest, edi
;	pop		edi
;	pop		esi
;	

	
	
	
	@empty_pass:
	inc		curPass
	shr		passMask, 1
	cmp		curPass, 7
	jbe		@adam7_nextpass
	jmp		@success


ENDIF ; IFNDEF _NOINTERLACE	


;------------- start defiltering & output for NON interlaced images ------------------
@not_interlaced:
	mov		eax, dwPNGLineSizeNFB
	mov		curLineBytes, eax
;Scanline loop:
; ebx-> base of current scanline being processed
; edi-> base of previous scanline being processed
;       NULL if ebx is the first scanline
; ecx-> index of byte currently being processed
	mov		ebx, pMemPart1
	xor		edi, edi
@next_scanline:
	xor		ecx, ecx
	mov		al, [esi]
	inc		esi
	cmp		al, 2
	je		@filter_up
	ja		@F
	dec		al
	js		@filter_none
	jmp		@filter_sub
	@@:
	cmp		al, 4
	js		@filter_average
	jz		@filter_paeth
	DPrint	"!!!!!INVALID FILTER!!!!!"
	jmp		@invalid_filter

	@filter_none:
		DPrint	"---NO filter---"	
		mov		ebx, esi
		add		esi, curLineBytes
	jmp		@filter_done
	
	@filter_sub:
		DPrint	"---SUB filter---"
		mov		edx, bytesPerPixel 
		neg		edx  ; edx = x-bpp = 0-bpp
		xor		eax, eax
		;Output = Sub(x) + Raw(x-bpp)
		@fs_main:
		mov		al, [esi+ecx]
		cmp		edx, 0
		jl		@F
		add		al, [ebx+edx]
		@@:
		mov		[ebx+ecx], al
		inc		ecx
		inc		edx
		cmp		ecx, curLineBytes
		jb		@fs_main
		add		esi, ecx
	jmp		@filter_done
	
	@filter_up:
		DPrint	"---UP filter---"
		; Output = Up(x) + Prior(x)
		@fu_main:
		mov		al, [esi+ecx]
		or		edi, edi
		jz		@F
		add		al, [edi+ecx]
		@@:
		mov		[ebx+ecx], al
		inc		ecx
		cmp		ecx, curLineBytes
		jb		@fu_main
		add		esi, ecx
	jmp		@filter_done
	
	@filter_average:
		DPrint "---Average filter----"
		; Output = Average(x) + floor((Raw(x-bpp)+Prior(x))/2)
		mov		edx, bytesPerPixel
		neg		edx
		
		@fa_main:
		xor		eax, eax
		or		edi, edi		;note: optimisation possible:create two loops 
								;      based on the value of edi (0 and non-0)
		jz		@F
		mov		al, [edi+ecx]
		@@:
		cmp		edx, 0
		jl		@F
		add		al, [ebx+edx]
		adc		ah,0
		@@:
		sar		ax, 1
		add		al, [esi+ecx]
		inc		edx

		mov		[ebx+ecx],al
		inc		ecx
		cmp		ecx, curLineBytes
		jb		@fa_main
        add		esi, ecx
	         
	jmp		@filter_done
	
	;!!!! filter paeth has to be optimized yet,
	;!!!! slow straight-forward version used now!!
	@filter_paeth:
		DPrint	"---Paeth filter (juck)---"
		mov		eax, bytesPerPixel
		neg		eax
		mov		tmpBack, eax
		
		@fp_main:

	    
		xor		eax, eax
		xor		edx, edx
		cmp		tmpBack, 0
		jl		@F
		add		ebx, tmpBack

		mov		al, byte ptr [ebx]	; a = Raw(x-bpp)
		sub		ebx, tmpBack
		@@:
		mov		tmp1, eax	;tmp1 = a
		;DPrintValD eax, "  A   "
		xor		eax, eax
		or		edi, edi
		jz		@F
		mov		al, byte ptr [edi+ecx]		; prior(x)
		cmp		tmpBack,0
		jl		@F
		add		edi, tmpBack
		mov		dl, byte ptr [edi]	; prior(x-bpp)
		sub		edi, tmpBack
		@@:
		mov		tmp2, eax	;tmp2 = b
		mov		tmp3, edx	;tmp3 = c
		;DPrintValD eax, "  B   "
		;DPrintValD edx, "  C   "
		
		sub		eax, edx	; b-c
		jns		@F
		neg		eax
		@@:
		; eax = pa
		;DPrintValD eax, " pa   "
		
		neg		edx
		add		edx, tmp1	; -c + a
		jns		@F
		neg		edx
		@@:
		; edx = pb
		;DPrintValD edx, " pb   "
	    
	    mov		tmp4, edx	;tmp4 = pb
	    mov		edx, tmp3
	    shl		edx, 1
	    neg		edx
	    add		edx, tmp1
	    add		edx, tmp2
	    jns		@F
	    neg		edx
	    @@:
	    ; edx = pc
	    ;DPrintValD edx, " pc   "

	    		    
	    cmp		eax, tmp4
		ja		@fp_notA
				
	    cmp		eax, edx
	    ja		@fp_notA 
	    mov		eax, tmp1 ; eax = A
	  	;DPrint	"chosen A"
	    jmp		@fp_next
	    
	    @fp_notA:
	    cmp		tmp4, edx
	    ja		@fp_notB
	    mov		eax, tmp2 ; eax = B
	    ;DPrint	"chosen B"
	    jmp		@fp_next
	    
	    @fp_notB:
	    mov		eax, tmp3 ; eax =C
	    ;DPrint	"chosen C"
	    @fp_next:

	    add		al, [esi+ecx]
	    inc		tmpBack
	    		
		mov		[ebx+ecx],al
		inc		ecx
		cmp		ecx, curLineBytes
		jb		@fp_main
        add		esi, ecx

	;jmp		@filter_done
	
	
	@filter_done:
	IFNDEF	_NOINTERLACE
		cmp		bInterlaced, 0
		je		@F
		jmp		@adam7_filter_done
		@@:
	ENDIF
	
	
	; ebx: ptr to line just decoded
	;
	push	esi
	push	edi
	mov		edi, lpDest
	mov		esi, ebx
	mov		ecx, curLineBytes
	call	dword ptr [lpCopyProc]
	;--- align---
	sub		edi, lpDest
	test	edi, 11b ;size is multiple of 4?
	jz		@F
	add		edi, 4
	and		edi, (NOT 11b)
	@@:
	;--- end align ----
	add		lpDest, edi
	pop		edi
	pop		esi
	;---- swap buffers------
	mov		edi, ebx
	cmp		ebx, pMemPart1
	jne		@F
	mov		ebx, pMemPart2
	jmp		@bs_swap_done
	@@:
	mov		ebx, pMemPart1
	@bs_swap_done:
	;--------------------------
	
	inc		curLine
	mov		eax, nLines
	cmp		curLine, eax
	jb		@next_scanline
	
	
@success:
	xor		esi, esi
	inc		esi
	@done:
	invoke	PNGHelp_free, lpTempMem
	IFNDEF	_NOINTERLACE
		mov		eax, pOneOutputLineBuf
		or		eax, eax
		jz		@F
		invoke	PNGHelp_free, eax
		@@:
	ENDIF
	mov		eax, esi
	ret
@failed:
@invalid_filter:
	xor		esi, esi
	jmp		@done
PNG_OutputRaw endp

end