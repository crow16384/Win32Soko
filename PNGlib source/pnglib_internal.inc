include <custom.inc>
include <pnglib.inc>

PNGI_Decompress		PROTO 	STDCALL :DWORD
PNGI_GenHufTable	PROTO	STDCALL :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
PNGI_GetNextChunk 	PROTO 	STDCALL :DWORD, :DWORD
PNGI_LoadHeader 	PROTO 	STDCALL :DWORD
PNGI_BitmapInfo		PROTO STDCALL :DWORD, :DWORD, :DWORD
PNGI_Adler32		PROTO 	STDCALL :DWORD, :DWORD
PNGI_CRC32			PROTO 	STDCALL :DWORD, :DWORD
PNGI_GetDecompressedSize PROTO 	STDCALL :DWORD
PNGHelp_zeroMem		PROTO 	STDCALL :DWORD, :DWORD

PNGI_LT_NOTHING		equ		0		;nothing is loaded
PNGI_LT_FILE		equ		1		;PNG_LoadFile was used
PNGI_LT_RESOURCE	equ		2		;PNG_LoadResource was used
PNGI_LT_CUSTOM		equ		3		;PNG_LoadCustom was used

PNG_OUTFMASK_SOURCECOLOR 	equ	0FF000000h
PNG_OUTFMASK_SOURCEDEPTH	equ	000FF0000h
PNG_OUTFMASK_VALIDDIB		equ 00000FF00h
PNG_OUTFMASK_COPYPROC		equ	0000000FFh
;PNGI_OUTF_X format:
;hex: UUXXYYNN
;UU:  source color type
;XX:  source sample bitdepth (not bits per pixel!!)
;YY:   0 if not valid for DIBs
;	  1 if valid for DIBs
;NN:  conversion proc to use:




PNG_CHUNK_UNKOWN			equ	0
PNG_CHUNK_IHDR				equ	1
PNG_CHUNK_PLTE				equ	2
PNG_CHUNK_IDAT				equ	3
PNG_CHUNK_IEND				equ	4
PNG_CHUNK_UNKOWN_CRITICAL	equ	5

PNGI_CHUNKLENGTH_IHDR equ 13

; These states have to be in increasing order
; because comparisons may be relative like this:
; if (stat>PNGI_STAT_DATALOADED), which means:
; some state that comes after loading data.
PNGI_STATE_INITIALIZED	equ	0
PNGI_STATE_DATALOADED	equ	1
PNGI_STATE_DECODED		equ	2




PNG_CHUNKINFO STRUCT
	dwType		dword		?	; PNG_CHUNK_* type
	dwLength	dword		?	; size in bytes of chunk
	dwCRC		dword		?	; CRC code of chunk
PNG_CHUNKINFO ENDS


PNGI_IHDRFORMAT STRUCT
	dwWidth				dword		? ;network byte order!!!
	dwHeight			dword		? ;network byte order!!!
	bitDepth			byte		?
	colorType			byte		?
	compressionMethod	byte		?
	filterMethod		byte		?
	interlaceMethod		byte		?
PNGI_IHDRFORMAT ENDS


PNGI_copyproc_X_X				PROTO	STDCALL
PNGI_copyproc_16_16				PROTO	STDCALL
PNGI_copyproc_16_16_bgr			PROTO	STDCALL
PNGI_copyproc_16_16_bgr_sa		PROTO	STDCALL
PNGI_copyproc_16_16_bgra		PROTO	STDCALL
PNGI_copyproc_16_16_sa			PROTO	STDCALL
PNGI_copyproc_16_8				PROTO	STDCALL
PNGI_copyproc_16_8_bgr			PROTO	STDCALL
PNGI_copyproc_16_8_bgr_sa 		PROTO	STDCALL
PNGI_copyproc_16_8_bgra   		PROTO	STDCALL
PNGI_copyproc_16_8_sa     		PROTO	STDCALL
PNGI_copyproc_2_4         		PROTO	STDCALL
PNGI_copyproc_8_8_bgr     		PROTO	STDCALL
PNGI_copyproc_8_8_bgr_sa  		PROTO	STDCALL
PNGI_copyproc_8_8_bgra    		PROTO	STDCALL
PNGI_copyproc_8_8_sa      		PROTO	STDCALL

PNGI_DeILproc_1bit		PROTO	STDCALL
PNGI_DeILproc_2bit		PROTO	STDCALL
PNGI_DeILproc_4bit		PROTO	STDCALL
PNGI_DeILproc_8plus		PROTO	STDCALL



PNGHelp_alloc	PROTO STDCALL :DWORD
PNGHelp_free	PROTO STDCALL :DWORD


; Bitmap information for internal use
PNG_IBMPINFO	STRUCT
	dwOutputFormat	dword	? ;PNG_OUTF_* output format to use
PNG_IBMPINFO	ENDS

PNG_MAX_SUPPORTED_WIDTH		equ		1600000
PNG_MAX_SUPPORTED_HEIGHT	equ		1600000