IFDEF _CUSTOM
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

; This file is included if custom build is used. You can change the options
; below to create a customized version of the library.
; To include an option, leave it as it is
; To remove an option, comment it by putting a semi-collon before it.
; Do NOT change 1 to 0, it will have no effect.
; For example:
;            _DEBUG equ 1			;debug enabled
;			 ;_DEBUG equ 1			;debug disabled



; Dump debug comments:
;_DEBUG		equ		1

; Enable safe mode:
_SAFE		equ		1

; Disable support for interlacing:
;_NOINTERLACE	equ		1




;------------------------------------------------------------------------------;
ENDIF