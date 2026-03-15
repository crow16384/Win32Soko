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

.data
public PNG_LUsamplesPerPixel
public PNG_LUcopyprocs
public PNG_DIBcpLU
public PNGI_ValidColorTypes


PNG_LUsamplesPerPixel db 1,0,3,1,2,0,4



PNG_LUcopyprocs	dd offset		PNGI_copyproc_X_X				;PNGCP_X_X			  equ		0
				dd offset		PNGI_copyproc_16_16				;PNGCP_16_16		  equ		1
				dd offset		PNGI_copyproc_16_16_bgr			;PNGCP_16_16_BGR	  equ		2
				dd offset		PNGI_copyproc_16_16_bgr_sa		;PNGCP_16_16_BGR_SA	  equ		3
				dd offset		PNGI_copyproc_16_16_bgra		;PNGCP_16_16_BGRA	  equ		4
				dd offset		PNGI_copyproc_16_16_sa			;PNGCP_16_16_SA		  equ		5
				dd offset		PNGI_copyproc_16_8				;PNGCP_16_8			  equ		6
				dd offset		PNGI_copyproc_16_8_bgr			;PNGCP_16_8_BGR		  equ		7
				dd offset		PNGI_copyproc_16_8_bgr_sa       ;PNGCP_16_8_BGR_SA    equ		8
				dd offset		PNGI_copyproc_16_8_bgra         ;PNGCP_16_8_BGRA      equ		9
				dd offset		PNGI_copyproc_16_8_sa       	;PNGCP_16_8_SA        equ		10	
				dd offset		PNGI_copyproc_2_4               ;PNGCP_2_4            equ		11
				dd offset		PNGI_copyproc_8_8_bgr           ;PNGCP_8_8_BGR        equ		12
				dd offset		PNGI_copyproc_8_8_bgr_sa     	;PNGCP_8_8_BGR_SA     equ		13
				dd offset		PNGI_copyproc_8_8_bgra          ;PNGCP_8_8_BGRA       equ		14
			                                                                    
IFNDEF _NOINTERLACE 
public PNG_BPP_FormatsA
public PNG_BPP_FormatsB
public PNG_ILMasks_Hor
public PNG_ILMasks_Ver
public PNG_PassScaling
public PNG_PassLinesScaling
public PNGI_StartOffsetsLog2
public PNGI_HorOffsetsLog2

	; color types:
	PNG_BPP_FormatsA dd	PNG_OUTF_G1_G1	
					dd	PNG_OUTF_G2_G2               
					dd	PNG_OUTF_G2_G4               
					dd	PNG_OUTF_G4_G4               
					dd	PNG_OUTF_G8_G8               
					dd	PNG_OUTF_G16_G16             
					dd	PNG_OUTF_G16_G8              
	                              
					dd	PNG_OUTF_T8_T8_BGR           
					dd	PNG_OUTF_T16_T16_BGR         
					dd	PNG_OUTF_T16_T8_BGR          
	                              
					dd	PNG_OUTF_P1_P1               
					dd	PNG_OUTF_P2_P2               
					dd	PNG_OUTF_P2_P4               
					dd	PNG_OUTF_P4_P4               
					dd	PNG_OUTF_P8_P8					
	                              
					dd	PNG_OUTF_GA8_GA8             
					dd	PNG_OUTF_GA8_G8              
					dd	PNG_OUTF_GA16_GA16           
					dd	PNG_OUTF_GA16_G16            
					dd	PNG_OUTF_GA16_GA8            
					dd	PNG_OUTF_GA16_G8             
	                              
					dd	PNG_OUTF_TA8_TA8_BGRA        
					dd	PNG_OUTF_TA8_T8_BGR          
					dd	PNG_OUTF_TA16_TA16_BGRA      
					dd	PNG_OUTF_TA16_T16_BGR        
					dd	PNG_OUTF_TA16_TA8_BGRA       
					dd	PNG_OUTF_TA16_T8_BGR         
					dd  -1
	; Bits per pixel in output:
	PNG_BPP_FormatsB db 1,2,4,4,8,16,8
					 db 3*8,3*16,3*8
					 db 1,2,4,4,8
					 db 2*8,8,2*16,16,2*8,8
					 db 4*8,3*8,4*16,3*16,4*8,3*8		
	; deinterlace proc to use
	;PNG_BPP_FormatsC db 
	
	
	; bitmasks for small widths and heights
	; each byte is a mask for the passes that are available:
	; bit : 7 6 5 4 3 2 1 0
	; pass: X 7 6 5 4 3 2 1
	;
	; For images with a width or height less than 5, lookup
	; the mask in the following table ([table_offset+width-1]), and
	; AND the hor mask with the ver mask. The result will be a mask
	; where all the passes available are 1, the others ar zero.
	PNG_ILMasks_Hor	db 1010101b, 1110101b, 1111101b, 1111101b, 1111111b
	PNG_ILMasks_Ver	db 0101011b, 1101011b, 1111011b, 1111011b, 1111111b
	
	; width of image represented by one pass, relative to the width of the
	; full image. Values are LOG 2, e.g. value 1 means 2^1 times smaller.
	PNG_PassScaling	db 3,3,2,2,1,1,0
	
	; Like PassScaling but for the number of scanlines
	PNG_PassLinesScaling db 3,3,3,2,2,1,1
	
	PNGI_StartOffsetsLog2	db	-1,2,-1,1,-1,0,-1
	PNGI_HorOffsetsLog2		db	3,3,2,2,1,1,0

ENDIF
			    
PNG_DIBcpLU	db	0,2,PNGCP_2_4
			db	0,16,PNGCP_16_8
			
			db	2,8,PNGCP_8_8_BGR
			db  2,16,PNGCP_16_8_BGR
			
			db	3,2,PNGCP_2_4
			
			db	4,8,PNGCP_8_8_SA
			db  4,16,PNGCP_16_8_SA
			
			db	6,8,PNGCP_8_8_BGRA
			db  6,16,PNGCP_16_8_BGRA
			db  -1,-1,-1
PNGI_ValidColorTypes	db	0,1,0,2,0,4,0,8,0,16
						db	2,8,2,16,3,1,3,2,3,4,3,8
						db  4,8,4,16,6,8,6,16,-1,-1

                                 	
end
