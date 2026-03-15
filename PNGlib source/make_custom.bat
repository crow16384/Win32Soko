@echo off
ml /c /ID:\masm32\includeex\ /D_CUSTOM /coff *.asm
lib /subsystem:windows /NODEFAULTLIB /out:pnglib_custom.lib *.obj
pause>nul