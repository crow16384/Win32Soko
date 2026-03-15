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
;
; This is the decompression core. I have written a C version of it before
; implementing the assembly version, I've left the C code between the lines
; most of the time. The C code is not included and will not be included, as 
; it contained some bugs which do not occur in the assembly version.
;
; Thomas
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

.data
clOrder			db		16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15
litLenTable		dw		3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43
				dw		51,59,67,83,99,115,131,163,195,227,258

distLenTable 	dw		1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257
				dw 		385,513,769,1025,1537,2049,3073,4097,6145,8193
				dw		12289,16385,24577

masklookup		dw		00001h,00003h,00007h,0000Fh,0001Fh,0003Fh,0007Fh,000FFh
				dw		001FFh,003FFh,007FFh,00FFFh,01FFFh,03FFFh,07FFFh,0FFFFh
.code

option prologue:none
option epilogue:none

; Parameters:
; esi = pointer to next byte
; eax = curIDATlength
; on return:
; eax = new curIDATlength, update curIDATlength with this value!!
; CH = new byte
; ebp = 8 (8 new bits in CH)
; esi is changed
; **ONLY CH is changed, the rest of ECX stays the same!!! ***
loadNextByte	proc forcenoframe
	; if (endOfFile) return;
	or		esi, esi
	jz		@eof
	;while (curIDATlength==0)
	;{
	@wcidlz:
	or		eax, eax
	jz		@wcidlz_loadnextchunk
	;}
	@wcidlz_done:
	IFDEF	_SAFE
		lea		ebp, [esi+eax]
		cmp		ebp, [esp+4]
		jae		@wci_notfound
	ENDIF
	;curBits = *pSource;
	mov		ch, [esi]
	;nCurBits = 8;
	mov		ebp, 8
	;curIDATlength--;
	dec		eax
	;pSource++;
	inc		esi
@eof:
retn
@wcidlz_loadnextchunk:
	;::DPrint "--------Loading next IDAT block---------"
	; skip checksum
	add		esi, 12 
	IFDEF	_SAFE
		cmp		esi, [esp+4]	;esp+4 is lpMaxInput in safe mode
		jae		@wci_notfound
	ENDIF
	mov		eax, [esi-4]
	and		eax, NOT (1 SHL 29)	;unset bit 5 (4th char always uppercased)
	cmp		eax, 'TADI'
	jne		@wci_notfound
	;found idat:
	mov		eax, [esi-8]	;chunk data length
	bswap	eax				;swap because of network byte order
	jmp	   	@wcidlz
	@wci_notfound:
	xor		ch, ch
	xor		esi, esi	;endOfFile = true
	xor		eax, eax
	retn

loadNextByte	endp

MLOADNEXTBYTE	MACRO
LOCAL addstk, substk
	push	eax
	stk_c = stk_c + 4
	mov		eax, curIDATlength
	IFDEF	_SAFE
		push	lpMaxInput
	ENDIF
	call	loadNextByte
	IFDEF _SAFE
		add		esp, 4
	ENDIF
	mov		curIDATlength, eax
	pop		eax
	stk_c = stk_c - 4
ENDM

SHIFTIN_NEXTBIT		MACRO
LOCAL	@tmp1, @ok
	IFDEF _DEBUG
		cmp ebp, 0
		jge	@ok
		int 3
		@ok:
	ENDIF
;	if (nCurBits==0) loadNextByte();
	or		ebp, ebp
	jnz		@tmp1
	MLOADNEXTBYTE
	@tmp1:
	shr		ch, 1
	dec		ebp
	rcl		eax, 1
ENDM
IFDEF _DEBUG ;$$$$
.data?
breakcount dd ?
.code
ENDIF

; if nBits = 0, ebx is nBits!!!
; nBits/ebx can not be higher than 16 !!
GET_X_BITS	MACRO 	nBits:REQ
LOCAL	@tmp1, @done,@tmp2,@ok,@tmp3,@ok2
;	IFDEF _DEBUG ;$$$$
;		inc breakcount
;		;::DPrintValD ecx, "lastECX"
;		;::DPrintValD eax, "lastEAX"
;		;::DPrintValD ebp, "lastEBP"
;		;::DPrintValD ebx, "lastEBX"
;		;::DPrintValD breakcount, "breakcount"
;		.IF	breakcount==55
;			int 3
;		.ENDIF
;		
;	ENDIF
;::DPrintValH esi, "esi"
;::DPrintValH ebp, "ebp"
	IFDEF _DEBUG
		IF nBits EQ 0
			.IF !ebx
				int 3
				;::DPrint "BUG: Get_x_bits with ebx=0!!!!!!!!!!!!"
			.ENDIF
		ENDIF
	ENDIF
	IF nBits LE 8
		IF		nBits eq 0 ;ebx register used
			cmp		ebp, ebx
		ELSE
			cmp		ebp, nBits
		ENDIF
		jbe		@tmp1
			mov		al, ch
			IF		nBits eq 0 ;ebx register used
				sub		ebp, ebx
				and		ax, [masklookup+ebx*2-2]
				mov		bh, cl ; save cl
				mov 	cl, bl
				shr		ch, cl
				mov		cl, bh ; restore cl
				xor		bh, bh ; restore bh (0 because ebx<16)
			ELSE
				sub		ebp, nBits
				shr		ch, nBits
				and		eax, (1 SHL nBits) - 1
			ENDIF
			jmp		@done
		@tmp1:
	ENDIF
	xor		eax, eax
	mov		al, ch
	mov		ecx, ebp
	ror		eax, cl
	
	MLOADNEXTBYTE
	mov		al, ch	
	
	IF		nBits EQ 0
		sub		bl, cl		; wanted bits - used bits
		cmp		ebx, 8
		ja		@tmp2
			add		bl, cl
			rol		eax, cl
			and		ax, [masklookup+ebx*2-2]
			; bits used: nBits - CL
			neg		cl
			add		cl, bl
			shr		ch, cl
			; bits left: 8 - (nBits - CL)
			movzx	ebp, cl
			neg		ebp
			add		ebp, 8
			jmp		@done
		@tmp2:
			add		bl, cl
			MLOADNEXTBYTE
			mov		ah, ch	
			rol		eax, cl
			and		eax, 0FFFFh ;make sure bit#>15 are zero
			and		ax, [masklookup+ebx*2-2]
			; bits used: nBits - 8 - CL
			neg		cl
			add		cl, bl 
			sub		cl, 8
			shr		ch, cl
			; bits left: 8 - (nBits - 8 - CL)
			movzx	ebp, cl
			neg		ebp
			add		ebp, 8
	ELSE
		movsx	ebp, cl	;free to use ebp, as it will be overwritten anyway
		neg		ebp
		add		ebp, nBits
		cmp		ebp, 8
		ja		@tmp3
			rol		eax, cl
			and		eax, (1 SHL nBits) - 1
			; bits used: nBits - CL
			neg		cl
			add		cl, nBits
			shr		ch, cl
			; bits left: 8 - (nBits - CL)
			movzx	ebp, cl
			neg		ebp
			add		ebp, 8
			jmp		@done
		@tmp3:
			MLOADNEXTBYTE
			mov		ah, ch	
			rol		eax, cl
			and		eax, (1 SHL nBits) - 1
			; bits used: nBits - 8 - CL
			neg		cl
			add		cl, (nBits - 8)
			shr		ch, cl
			; bits left: 8 - (nBits - 8 - CL)
			movzx	ebp, cl
			neg		ebp
			add		ebp, 8
	ENDIF
	@done:
	IFDEF _DEBUG
		cmp ebp, 0
		jge	@ok
		int 3
		@ok:
		cmp	ebp, 8
		jle	@ok2
		int 3
		@ok2:
	ENDIF
	
ENDM

; Decodes next huffman code, given the name of the lookup table
; returns huffman code in EAX, EDX is value represented by that code
DECODE_NEXT_HUFFMAN_CODE MACRO lookupTable:REQ, maxBitLength:REQ
LOCAL	@shiftin_nextbit
				IFDEF	_SAFE
   					lea		eax, [lookupTable+4*maxBitLength]
   					mov		lpMaxLUPointer, eax
   				ENDIF
   
;			    //-------- get next huffman code - start --------
;				tmpBits = 0;
				xor		eax, eax
;				pA = (DWORD*)&arrLITlookup;
				lea		ebx, [lookupTable]
				xor		edx, edx
;				shiftin_nextbit;
				@shiftin_nextbit:
				IFDEF	_SAFE
					;::DPrint	"check for max LU ptr"
					cmp		ebx, lpMaxLUPointer
					jae		@invalidPNG
				ENDIF
				SHIFTIN_NEXTBIT
				mov		dx, [ebx]
;				pA++;
				
				or		edx, edx
				lea		ebx, [ebx+4]
;				while(*pA==0 || ...
				jz		@shiftin_nextbit
				; ...(tmpBits >= (*pA & 0xFFFF)))
				cmp		ax, dx
				jae		@shiftin_nextbit
				; ---- end while loop in C version ----
				;// R = cur_addr +  2 * (Q  + P - code)
;				pB = (WORD*)((long)pA + 2 * ((*pA & 0xFFFF) + (*pA>>16) - tmpBits));
				sub		dx, ax			  ;	dx: P - code
				; NOTE: -4 because 4 was added to ebx already
				add		dx, [ebx+2-4]	  ; dx: Q + P - code
				mov		dx, [ebx+2*edx-4] ; same here

ENDM



PNGI_Decompress proc forcenoframe
; PNGI_Decompress(pPNGInfo)

DEC_LOCAL_SIZE = 1256
stk_c = 0
;parameters:
pPNGInfo			textequ	<dword ptr [esp+DEC_LOCAL_SIZE+stk_c+4]>		;1st parameter
PARAMETER_COUNT = 1
;locals:
curIDATlength		textequ	<dword ptr [esp+stk_c+0000]>	;length of current IDAT chunk data
isLastBlock			textequ	<dword ptr [esp+stk_c+0004]>	;set if last deflate block
nHLIT				textequ <dword ptr [esp+stk_c+0008]>	;number of literal codes
nHDIST				textequ <dword ptr [esp+stk_c+0012]>	;number of distance codes
nHCLEN				textequ <dword ptr [esp+stk_c+0016]>	;number of code length codes
oArrTmpLengths		textequ <esp+stk_c+0020>	; size: 320 bytes
oArrTmpFreqs		textequ <esp+stk_c+0340>	; size: 2x16=32 bytes
oArrLITlookup		textequ <esp+stk_c+0372>	; size: 640 bytes
oArrDISTlookup		textequ <esp+stk_c+1012>	; size: 148 bytes
oArrCLENlookup		textequ <esp+stk_c+1160>	; size: 68 bytes
dwLength			textequ <dword ptr [esp+stk_c+1228]>
dwDistance			textequ	<dword ptr [esp+stk_c+1232]>
dwTemp				textequ <dword ptr [esp+stk_c+1236]>
lpMaxOutput			textequ	<dword ptr [esp+stk_c+1240]>	;used in safe mode, max output pointer
lpMaxInput			textequ	<dword ptr [esp+stk_c+1244]>	;used in safe mode, max input pointer
lpMaxLUPointer		textequ	<dword ptr [esp+stk_c+1248]>	;used in safe mode, max lookup table pointer
lpCurDecBlockStart	textequ	<dword ptr [esp+stk_c+1252]>	;used in safe mode, start of decoded data for current block
;BYTE outputData[10000];
;
;BYTE *pSource = realIDATs-4;
;BYTE *pDest = outputData;
	sub		esp, DEC_LOCAL_SIZE

	push	edi
	push	esi
	push	ebx
	push	ebp
	stk_c = stk_c + 16	;account for 4 pushes

	xor		ecx, ecx
	xor		ebp, ebp
	xor		eax, eax
	mov		isLastBlock, eax
	mov		curIDATlength, eax
	; Get needed PNG info
	mov		eax, pPNGInfo
	assume	eax:ptr	PNGINFO
	mov		eax, pPNGInfo

	
	mov		[eax].dwLastError, PNGLIB_ERR_INVALIDPNG ;if anything goes wrong
	
	;Current pointer, should point to first IDAT chunk
	mov		esi, [eax].pIDAT
	IFDEF	_SAFE
		mov		ecx, [eax].lpPNGData
		add		ecx, [eax].lnPNGData
		mov		lpMaxInput, ecx	;safe mode
	ENDIF
	
	sub		esi, 4	;required for algo
	;Output pointer, should point to free memory to hold
	;the decompressed deflate data
	mov		edi, [eax].lpOutput	
	IFDEF	_SAFE
		mov		ecx, edi
		add		ecx, [eax].lnOutput
		mov		lpMaxOutput, ecx
	ENDIF
	
	assume	eax:nothing
	
	
	GET_X_BITS 16
	;::DPrintValH eax, "First two bytes in zlib stream (hex)"
	mov		dl, al
	mov		dh, al
	and		dl, 1111b
	shr		dh, 4
	
	IFDEF _DEBUG
		.IF dl!=8h
			;::DPrint "compression method not 8 (deflate) - invalid PNG"
		.ENDIF
	ENDIF
	cmp		dl, 8h
	jne		@invalidPNG	
	
	IFDEF _DEBUG
		.IF dh>7
			;::DPrint "compression window size > 32 KB - invalid PNG"
		.ENDIF
	ENDIF
	cmp		dh, 7
	jg		@invalidPNG	
	
	
	
	IFDEF _DEBUG
		.IF eax&(1 SHL 13)
			;::DPrint "FDICT bit set in FLG value - invalid PNG"
		.ENDIF
	ENDIF
	test	eax, (1 SHL 13)
	jne		@invalidPNG	
	
	;::DPrint	"First two bytes are okay."
	
		
;	while(!isLastBlock)
;	{
	IFDEF _SAFE
		mov		lpCurDecBlockStart, edi
	ENDIF
		
	@notlastblock:
	cmp		isLastBlock, 0
	jnz		@last_block_reached
		;::DPrint "----next deflate block----"


;		///////////////////////////////////////////////////////////////
;		//	BFINAL and BCODE
;		///////////////////////////////////////////////////////////////

		GET_X_BITS 3
		; bit 0 is BFINAL
		; bit 1 and 2 are BCODE

		;isLastBlock = tmpBits & 1;
		mov		isLastBlock, eax
		and		isLastBlock, 1
		IFDEF	_DEBUG
			.IF	eax&1
				;::DPrint "--last block bit set---"
			.ENDIF
		ENDIF
		;switch(tmpBits>>1)
		shr		eax, 1
		dec		al 
		js		@non_compressed_block 		;BCODE=00b
		jz		@compressed_fixed_block 	;BCODE=01b
		dec		al
		jz		@compressed_dynamic_block	;BCODE=10b
		;::DPrint  "BCODE = 11b - invalid PNG"
		jmp		@invalidPNG

		;========================================================================
		; Non compressed block
		;========================================================================
		;case BCODE_NON_COMPRESSED:
		@non_compressed_block:
			;::DPrint "Non compressed blcok found."
;			len = (WORD)getXBits(16);
			cmp 	ebp, 8
			je		@F
			xor		ebp, ebp ; skip any remaining bits in current byte
			@@:
			
			GET_X_BITS 16
			mov		ebx, eax	;ebx = len
			;::DPrintValH ebx, "LEN: "
			GET_X_BITS 16
			not		eax
			;::DPrintValH ebx, "LEN again: "
			;::DPrintValH eax, "NLEN: "
			IFDEF _DEBUG
				.IF ax!=bx
					;::DPrint "!!!! ERROR: NLEN is not LEN's 1-complement!!!"
				.ENDIF
			ENDIF
			cmp		ax, bx
			jne		@invalidPNG
			
;			nCurBits = 0;	//skip all bits left in current byte
			cmp		ebp, 8
			je		@F
			xor		ebp, ebp
			@@:
			IFDEF	_SAFE
				;::DPrint	"check for max max out 1"
				mov		eax, ebx
				add		eax, edi
				cmp		eax, lpMaxOutput
				ja		@invalidPNG
			ENDIF
			@nc_copy_start:
			or		ebx, ebx
			jz		@nc_copy_done
			MLOADNEXTBYTE			
			mov		[edi], ch
			inc		edi
			dec		ebx
			jmp		@nc_copy_start
			@nc_copy_done:
;			for (i=0;i<len;i++)
;			{
;				loadNextByte();
;				*pDest = curBits & 0xFF;
;			}
;			nCurBits = 0;	//byte is already used
			xor		ebp, ebp
			jmp		@eof_deflate_block
		;========================================================================
		; Compressed block - fixed
		;========================================================================
		;case BCODE_FIXED_COMPRESSION:
		@compressed_fixed_block:
		;::DPrint "Fixed compression block found."
			; Set code lengths for fixed
			; huffman codes
			
			; codes 0-143 have code length 8
			xor	edx, edx
			@@:
			mov		dword ptr [oArrTmpLengths+8*edx+0], 08080808h
			mov		dword ptr [oArrTmpLengths+8*edx+4], 08080808h
			inc		edx
			cmp		edx, (144/8)
			jne		@B
			; codes 144-255 have code length 9
			@@:
			mov		dword ptr [oArrTmpLengths+8*edx+0], 09090909h
			mov		dword ptr [oArrTmpLengths+8*edx+4], 09090909h
			inc		edx
			cmp		edx, (256/8)
			jne		@B
			; codes 256-279 have code length 7
			@@:
			mov		dword ptr [oArrTmpLengths+8*edx+0], 07070707h
			mov		dword ptr [oArrTmpLengths+8*edx+4], 07070707h
			inc		edx
			cmp		edx, (280/8)
			jne		@B
			; codes 280-287 have code length 8
			@@:
			mov		dword ptr [oArrTmpLengths+8*edx+0], 08080808h
			mov		dword ptr [oArrTmpLengths+8*edx+4], 08080808h
			inc		edx
			cmp		edx, (288/8)
			jne		@B
			
			;--- Setting code frequencies ---
			
			;for (i=0;i<arrcount(arrTmpFreqs);i++)
			;arrTmpFreqs[i]=0;
			xor		edx, edx
			@@:
			mov		dword ptr [oArrTmpFreqs+8*edx+0], 0
			mov		dword ptr [oArrTmpFreqs+8*edx+4], 0
			inc		edx
			cmp		edx, (32/8)
			jne		@B

			;arrTmpFreqs[7]=24;
			;arrTmpFreqs[8]=152;
			;arrTmpFreqs[9]=112;
			mov		word ptr [oArrTmpFreqs+2*7], 24
			mov		word ptr [oArrTmpFreqs+2*8], 152
			mov		word ptr [oArrTmpFreqs+2*9], 112


;			genHuffLUTable(arrLITlookup,arrTmpLengths,arrTmpFreqs,288,9);				
			push	9			; maxBitLength
			push	288			; nCodes
			stk_c = stk_c + 8
			lea		eax, [oArrTmpFreqs]
			lea		edx, [oArrTmpLengths]
			push	eax
			push	edx
			stk_c = stk_c + 8
			lea		eax, [oArrLITlookup]
			stk_c = stk_c + 4
			push	eax
			call 	PNGI_GenHufTable
			stk_c = stk_c - 5 * 4

			
;			// ----- Decode one huffman code ------ //

;			while(true)
;			{
			@fx_next_huffman_code:
	
				DECODE_NEXT_HUFFMAN_CODE oArrLITlookup, 9

				; edx is value represented by huffman code
				IFDEF	_SAFE
					;::DPrint	"check for max max outDX285 1"
					cmp		dx, 285
					ja		@invalidPNG
				ENDIF
				cmp		dx, 256
				je		@eof_deflate_block		;end of block
				ja		@fx_back_pointer		;length/dist pait
				@fx_copy_value:					;normal code value
				;::DPrintValH edx, "Normal output value "
;				*pDest = *pB & 0xFF;
				IFDEF	_SAFE
					;::DPrint	"check for max max out 2"
					cmp		edi, lpMaxOutput
					jae		@invalidPNG
				ENDIF
				mov		byte ptr [edi], dl
;				pDest++;
				inc		edi
				
				
				jmp		@fx_next_huffman_code	
					
				@fx_back_pointer:
					;::DPrintValH edx, "Backpointer found, value"
;					// determine number of extra bits:
;					// extrabits is used as # of extra bits
;					if (*pB==285 || *pB<265)
;						extrabits = 0;
					mov		ebx, edx
					cmp		edx, 285
					jz		@F
					cmp		edx, 265
					jae		@fx_nb_notzero
					@@:
					xor		eax, eax
					xor		ebx, ebx
					;::DPrint	"    No extra bits."
					jmp		@fx_no_extra_bits
					@fx_nb_notzero:
					;extrabits = ((*pB-265)>>2) + 1;
					sub		ebx, 265
					shr		ebx, 2
					inc		ebx
					GET_X_BITS 0 ;use ebx as number of bits to get
					
					;::DTrace "    Number of extra bits: %d, extra bits are: 0x%02X",ebx,eax
					@fx_no_extra_bits:
;					extrabits is now used to hold the extra bits
;					(eax = extrabits)
;					length = litLenTable[*pB-257] + extrabits;
					add		ax, word ptr [litLenTable+edx*2 - 257 * 2]
					mov		dwLength, eax
					;::DPrintValD eax, "    The extra bits and code represent length"
;					// -------- read distance --------
;					// distance is 5 bits for fixed huffman table
					; Note: the asm version first uses GET_X_BITS to get 5 bits,
					; then reverses the bit order because huffman codes are encoded
					; that way.
					GET_X_BITS 5
					REPEAT 5
						shr		al, 1
						rcl		ah, 1
					ENDM
					shr	eax, 8
					
					mov		edx, eax
					;::DPrintValD edx, "   Distance code is (dec)"
					;::DPrintValH edx, "   Distance code is (hex)"
			
;					// determine number of extra bits:
;					// extrabits is used as # of extra bits
;					if (tmpBits<2)
;						extrabits = 0;
;					else
;						extrabits = ((tmpBits-2)>>1);

					mov		ebx, eax
					cmp		edx, 4
					jae		@fx_deb_notzero
					xor		ebx, ebx
					xor		eax, eax
					;::DPrint  "   No extra distance bits"
					jmp		@fx_deb_no_extra_bits
					@fx_deb_notzero:
					sub		ebx, 2
					shr		ebx, 1
					GET_X_BITS 0	;use ebx as number of bits to get
					;::DTrace "    Number of extra distance bits: %d, extra bits are: 0x%02X",ebx,eax
					@fx_deb_no_extra_bits:

;					// extrabits is now used to hold the extra bits (eax=extrabits)
;					distance = distLenTable[tmpBits] + extrabits;
					add		ax, [distLenTable+2*edx]

					;::DPrintValD eax, "    The extra bits and code represent distance"
					;mov	dwDistance, eax 
					;note: eax is used below directly

					; following loop has to be optimized yet!!!
					; maybe with movsb?
					; Note: you can only copy byte per byte, because
					; your source may overlap with the destination
					; (see png docs)
;					// do copy
;					for (i=0;i<length;i++)
					IFDEF _SAFE
						;::DPrint	"check for max max out 3"
						mov		edx, edi
						add		edx, dwLength
						cmp		edx, lpMaxOutput
						ja		@invalidPNG
					ENDIF
					xor		edx, edx
					mov		ebx, edi
					sub		ebx, eax ; pDest - distance
					@fx_copy_start:
					cmp		edx, dwLength
					je		@fx_copy_done
;						*pDest = *(pDest-distance);
						mov		al, byte ptr [ebx]
						mov		byte ptr [edi], al
;						pDest++;
						inc		ebx
						inc		edi
						inc		edx
;					}
					jmp	@fx_copy_start
					@fx_copy_done:
;					///!! end of un-tested code !!!!!!!!!!!!!
				jmp		@fx_next_huffman_code	
;				else

;			}
;
;			break;
		;========================================================================
		; Compressed block - dynamic
		;========================================================================
		;case BCODE_DYNAMIC_COMPRESSION:
		@compressed_dynamic_block:
			;::DPrint "dynamic compression block found"			

			; read HLIT, HDIST and HCLEN:
			GET_X_BITS (5+5+4)
;			nHLIT = getXBits(5) + 257; //HLIT (5-bits) = # of literal/length codes-257
;			nHDIST = getXBits(5) + 1;  //HDIST (5-bits) = # of distance codes - 1
;			nHCLEN = getXBits(4) + 4;  //HCLEN (4-bits) = # of code length codes - 4
			mov		edx, eax
			and		edx, 11111b	;HLIT mask
			add		edx, 257
			;::DPrintValD	edx, "HLIT + 257 = nHLIT"
			mov		nHLIT, edx
			;-
			shr		eax, 5
			mov		edx, eax
			and		edx, 11111b	;HDIST mask
			inc		edx
			;::DPrintValD	edx, "HDIST + 1 = nHDIST"
			mov		nHDIST, edx
			;-
			shr		eax, 5
			add		eax, 4
			;::DPrintValD eax, "HCLEN + 4 = nHCLEN"
			mov		nHCLEN, eax
			
			
;			// Clear tmpLength table (first 19 bytes, enough for HCLEN alphabet)
;			for (i=0;i<19;i++)
;				arrTmpLengths[i]=0;
			;note: asm version clears 20 bytes

			mov		edx, (20/4) - 1
			@@:
			mov		dword ptr [oArrTmpLengths+4*edx],0
			dec		edx
			jns		@B
			
;			for (i=0;i<8;i++)
;				arrTmpFreqs[i]=0;
			lea		edx, [oArrTmpFreqs]
			mov		dword ptr [edx+0], 0
			mov		dword ptr [edx+4], 0
			mov		dword ptr [edx+8], 0
			mov		dword ptr [edx+12], 0
			
			;::DPrint "Reading code lengths for code length alphabet:"
			
;			// Read nHCLEN x 3 bits containing code lengths for the code length alphabet
			xor		edx, edx
			xor		ebx, ebx
			@dn_readCLCLengths:
;			for (i=0;i<nHCLEN;i++)
;				tmpBits = getXBits(3);
				GET_X_BITS 3
;				arrTmpLengths[clOrder[i]] = (unsigned char)tmpBits;
				mov		bl, byte ptr [clOrder+edx]
				mov		byte ptr [oArrTmpLengths+ebx], al
;				arrTmpFreqs[tmpBits]++;
				inc		word ptr [oArrTmpFreqs+2*eax]
				;::DTrace "    code length for code length code %d = %d", ebx, eax
			inc		edx
			cmp		edx, nHCLEN
			jb		@dn_readCLCLengths
			
;			arrTmpFreqs[0] = 0; // code length NULL should be zeroed out!!!			
			mov		word ptr [oArrTmpFreqs+0], 0 		

			;::DPrint "Reading code lengths done. Codes not mentioned have length zero(not used)"
			;::DPrint "---"
			
;			// --------- build lookup table for code length alphabet ----
;			genHuffLUTable(arrCLENlookup,arrTmpLengths,arrTmpFreqs,19,7);
			push	7
			stk_c = stk_c + 4
			push	19
			stk_c = stk_c + 4
			lea		eax, [oArrTmpFreqs]
			lea		edx, [oArrTmpLengths]
			lea		ebx, [oArrCLENlookup]
			push	eax
			push	edx
			push	ebx
			stk_c = stk_c + 12
			call	PNGI_GenHufTable
			stk_c = stk_c - 5 * 4
			
;			// --------- read HLIT and HDIST code lengths ---------
;			// code lengths for these two alphabets are stored as 
;			// one continious block so they are read as one block
;			// arrTmpLengths will hold

			;::DPrint "Now reading code lengths for HLIT and HDIST alphabets:"			


			push	edi
			stk_c = stk_c + 4
			mov		edx, nHLIT
			add		edx, nHDIST
;			i = 0;
			xor		edi, edi
			mov		dwTemp, edx
			@readLDtables:
;			while (i < (nHLIT + nHDIST))
			DECODE_NEXT_HUFFMAN_CODE oArrCLENlookup, 7
			cmp		edx, 16
			jb		@dn_cl_normal
			jne		@dn_cl_17or18
			;--- code 16
			; Repeat the previous code length 3-6 times
			; next two bits indicate repeat length - 3
			; (0=3,1=4,2=5,3=6)
;			if (*pB==16)
;			tmpBits = getXBits(2) + 3;
			GET_X_BITS 2
			add		eax, 3
			mov		dl, byte ptr [oArrTmpLengths+edi-1] ;previous code
			;::DPrintValD	eax, "    repeating previous code length, count"
;			for (k=0;k<(int)tmpBits;k++)
			jmp		@dn_copy_DLxEAX
			
			@dn_cl_17or18:    
			sub		edx, 18                          
			jz		@dn_cl_code18                      
			@dn_cl_code17:
			IFDEF	_SAFE
				;::DPrint	"check for edx=17 1"
				cmp		edx, 17-18
				je		@F
				pop		edi
				jmp		@invalidPNG
				@@:
			ENDIF
;			else if (*pB==17)
;			// Repeat a code length of 0 for 3-10 times
;			// Next 3 bits indicate repeat length
;			// (0=3,1=4...)
;			tmpBits = getXBits(3) + 3;
			GET_X_BITS 3
			add		eax, 3	;count
			xor		dl,dl	;byte
			;::DPrintValD eax, "    repeating zero code length, count"
			jmp		@dn_copy_DLxEAX

			;else if (*pB==18)
			@dn_cl_code18:
;			// Repeat a code length of 0 for 11-138 times
;			// Next 7 bits indicate repeat length
;			// (0=11,1=12...)
			GET_X_BITS 7
			add	eax, 11	;count
			xor	dl, dl  ;byte
			;::DPrintValD eax, "    repeating zero code length, count"			
			jmp		@dn_copy_DLxEAX
		
			
			; Copies value in DL in the next EAX codelengths
			
			@dn_copy_DLxEAX:
				mov		byte ptr [oArrTmpLengths+edi], dl
				inc		edi 
			dec		eax
			jnz		@dn_copy_DLxEAX
			jmp		@dn_rld_next

			
;			else if (*pB<16)
			@dn_cl_normal:
				;::DPrintValD edx, "    adding code length"
;				// Represents code length of 0-15:
;				arrTmpLengths[i] = *pB & 0xFF;
				mov		byte ptr [oArrTmpLengths+edi], dl
				inc		edi		; i++
				;jmp		@dn_rld_next

;			} // while(i<nHLIT+nHDIST)
			@dn_rld_next:
			cmp		edi, dwTemp ;dwTemp = nHLIT + nHDIST
			jb		@readLDtables
			IFDEF _SAFE
				;::DPrint	"check for max max edit 6"
				cmp		edi, dwTemp
				je		@F
				pop		edi
				jmp		@invalidPNG
				@@:
			ENDIF
			IFDEF _DEBUG
				.IF edi==dwTemp
					;::DPrint "Total number of code lengths decoded matches expected number "
					;::DPrint "decoding was probably successful!"
				.ELSE
					;::DPrint "ERROR!!!!"
					;::DPrint "Code length arrays not build correctly, total number of codes"
					;::DPrint "according to the decoded data does not match the expected number"
					;::DPrint "of codes!"
				.ENDIF
			ENDIF
			pop		edi
			stk_c = stk_c - 4

			;::DPrint "Reading done. building code length frequency table for LIT codes"
;			// Setup frequencies for LIT part of length array:
;			for (i=0;i<16;i++)
;				arrTmpFreqs[i]=0;
			mov		edx, (16*2/4) - 1
			@@:
			mov		dword ptr [oArrTmpFreqs+4*edx],0
			dec		edx
			jns		@B

;			for (i=0;i<nHLIT;i++)
			xor		edx, edx
			xor		eax, eax ;eax=i
			@@:
;				arrTmpFreqs[arrTmpLengths[i]]++;
				mov	 dl, byte ptr [oArrTmpLengths+eax] 	   ;arrTmpLengths[i]
				inc  word ptr [oArrTmpFreqs+2*edx] 
				inc eax
			cmp		eax, nHLIT
			jb		@B
;			arrTmpFreqs[0]=0;
			mov		word ptr [oArrTmpFreqs+0], 0
			
;			printf("Generating LIT lookup table\n");
			;::DPrint "Generating LIT lookup table"
			
			;genHuffLUTable(arrLITlookup,arrTmpLengths,arrTmpFreqs,nHLIT,15);

			push	15
			stk_c = stk_c + 4
			push	nHLIT
			stk_c = stk_c + 4
			lea		eax, [oArrTmpFreqs]
			lea		edx, [oArrTmpLengths]
			lea		ebx, [oArrLITlookup]
			push	eax
			push	edx
			push	ebx
			stk_c = stk_c + 3*4
			call 	PNGI_GenHufTable
			stk_c = stk_c - 5*4
			
			;::DPrint "Building code length frequency table for DIST codes"
;			// Setup frequencies for DIST part of length array:
;			for (i=0;i<16;i++)
;				arrTmpFreqs[i]=0;
			mov		edx, (16*2/4) - 1
			@@:
			mov		dword ptr [oArrTmpFreqs+4*edx],0
			dec		edx
			jns		@B

;			for (i=nHLIT;i<(nHLIT+nHDIST);i++)
			xor		edx, edx
			mov		eax, nHLIT
			@@:
;				arrTmpFreqs[arrTmpLengths[i]]++;
				mov	 dl, byte ptr [oArrTmpLengths+eax] 	   ;arrTmpLengths[i]
				inc  word ptr [oArrTmpFreqs+2*edx] 
				inc eax
			cmp		eax, dwTemp ;dwTemp is still nHLIT + nHDIST
			jb		@B
;			arrTmpFreqs[0]=0;
			mov		word ptr [oArrTmpFreqs+0], 0
			
			;::DPrint "Generating DIST lookup table"
			
;			genHuffLUTable(arrDISTlookup,arrTmpLengths + nHLIT,arrTmpFreqs,nHDIST,15);
			push	15
			stk_c = stk_c + 4
			push	nHDIST
			stk_c = stk_c + 4
			lea		eax, [oArrTmpFreqs]
			lea		edx, [oArrTmpLengths]
			add		edx, nHLIT
			lea		ebx, [oArrDISTlookup]
			push	eax
			push	edx
			push	ebx
			stk_c = stk_c + 3*4
			call 	PNGI_GenHufTable
			stk_c = stk_c - 5*4

			;::DPrint "----all lookup tables build - let's start decoding! ----"
;			while(true)
			@dyn_next_huffman_code:
				DECODE_NEXT_HUFFMAN_CODE oArrLITlookup, 15
				IFDEF	_SAFE
					;::DPrint	"check for max max outdx285 3"
					cmp		dx, 285
					ja		@invalidPNG
				ENDIF
				; edx is value represented by huffman code
				cmp		dx, 256
				je		@eof_deflate_block		;end of block
				ja		@dyn_back_pointer		;length/dist pait
				@dyn_copy_value:					;normal code value
				;::DPrintValH edx, "dyn.Normal output value "
;				*pDest = *pB & 0xFF;
				IFDEF	_SAFE
					;::DPrint	"check for max max out 8"
					cmp		edi, lpMaxOutput
					jae		@invalidPNG
				ENDIF
				mov		byte ptr [edi], dl
;				pDest++;
				inc		edi
				jmp		@dyn_next_huffman_code	

				@dyn_back_pointer:
				;::DPrintValH edx, "dyn.Backpointer found, value"
;				// determine number of extra bits:
;				// extrabits is used as # of extra bits
;				if (*pB==285 || *pB<265)
;					extrabits = 0;
				mov		ebx, edx
				cmp		edx, 285
				jz		@F
				cmp		edx, 265
				jae		@dyn_nb_notzero
				@@:
				xor		eax, eax
				xor		ebx, ebx
				;::DPrint	"    No extra bits."
				jmp		@dyn_no_extra_bits
				@dyn_nb_notzero:
				;extrabits = ((*pB-265)>>2) + 1;
				sub		ebx, 265
				shr		ebx, 2
				inc		ebx
				GET_X_BITS 0 ;use ebx as number of bits to get
				
				;::DTrace "    Number of extra bits: %d, extra bits are: 0x%02X",ebx,eax
				@dyn_no_extra_bits:
;				extrabits is now used to hold the extra bits
;				(eax = extrabits)
;				length = litLenTable[*pB-257] + extrabits;
				add		ax, word ptr [litLenTable+edx*2 - 257 * 2]
				mov		dwLength, eax
				;::DPrintValD eax, "    The extra bits and code represent length"
					
;				// -------- read distance --------
				DECODE_NEXT_HUFFMAN_CODE oArrDISTlookup, 15
				IFDEF	_SAFE
					;::DPrint	"check for max max dx 29  99"
					cmp		dx, 29
					ja		@invalidPNG
				ENDIF
				;::DPrintValD edx, "   Distance code is (dec)"
				;::DPrintValH edx, "   Distance code is (hex)"
				mov		ebx, edx
				cmp		edx, 4
				jae		@dyn_deb_notzero
				xor		ebx, ebx
				xor		eax, eax
				;::DPrint  "   No extra distance bits"
				jmp		@dyn_deb_no_extra_bits
				@dyn_deb_notzero:
				sub		ebx, 2
				shr		ebx, 1
				GET_X_BITS 0	;use ebx as number of bits to get
				;::DTrace "    Number of extra distance bits: %d, extra bits are: 0x%02X",ebx,eax
				@dyn_deb_no_extra_bits:

;				// extrabits is now used to hold the extra bits (eax=extrabits)
;				distance = distLenTable[tmpBits] + extrabits;
				add		ax, [distLenTable+2*edx]

				;::DPrintValD eax, "    The extra bits and code represent distance"
				;mov	dwDistance, eax 
				;note: eax is used below directly

				; following loop has to be optimized yet!!!
				; (see same look for fixed code)
;				// do copy
;				for (i=0;i<length;i++)
				IFDEF	_SAFE
					;::DPrint	"check for max max out 9"
					mov		edx, edi
					add		edx, dwLength
					cmp		edx, lpMaxOutput
					ja		@invalidPNG
				ENDIF
				xor		edx, edx
				mov		ebx, edi
				sub		ebx, eax ; pDest - distance
				@dyn_copy_start:
				cmp		edx, dwLength
				je		@dyn_copy_done
;					*pDest = *(pDest-distance);
					mov		al, byte ptr [ebx]
					mov		byte ptr [edi], al
;					pDest++;
					inc		ebx
					inc		edi
					inc		edx
;					}
				jmp	@dyn_copy_start
				@dyn_copy_done:
;					///!! end of un-tested code !!!!!!!!!!!!!
				jmp		@dyn_next_huffman_code
		@eof_deflate_block:
		;::DPrint	"---End of deflate block reached---"
		jmp		@notlastblock
	@last_block_reached:
	; checksum, read 2x16 btis
	; skip remaining bits if any
	cmp		ebp, 8
	je		@F
	xor		ebp, ebp
	@@:
	
	xor		ebx, ebx
	mov		edx, 1
	@@:
	GET_X_BITS 16
	rol		ebx, 16
	or		ebx, eax
	;::DPrintValH eax, "next word adler checksum:"
	dec		edx
	jns		@B
	IFDEF	_SAFE
		ror		ebx, 16
		bswap	ebx
		;ebx is adler
		;::DPrintValH ebx, "full adler code "
		mov		eax, edi
		mov		ecx, lpCurDecBlockStart
		sub		eax, ecx
		invoke	PNGI_Adler32, ecx, eax
		IFDEF _DEBUG
			.IF	eax!=ebx
				;::DPrint	"!!!!!!!!!!! Adler32 code not correct!!!!!!!!!!!!!!"
			.ENDIF
		ENDIF
		cmp		eax, ebx
		jne		@invalidPNG
	ENDIF	
	
	;::DPrint "---all IDAT blocks processed---"
	mov		eax, pPNGInfo
	mov		(PNGINFO ptr [eax]).dwLastError, 0
	mov		eax, 1
	@return:
	pop		ebp
	pop		ebx
	pop		esi
	pop		edi
	stk_c = stk_c - 16	;account for 4 pops

	add		esp, DEC_LOCAL_SIZE
retn PARAMETER_COUNT * 4

@invalidPNG:
	xor		eax, eax
	jmp		@return

PNGI_Decompress endp



option prologue:DefPrologue
option epilogue:DefEpilogue


end