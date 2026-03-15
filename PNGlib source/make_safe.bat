@echo off
ml /c /ID:\masm32\includeex\ /D_SAFE /coff *.asm
lib /subsystem:windows /NODEFAULTLIB /out:pnglib_safe.lib *.obj
pause>nul