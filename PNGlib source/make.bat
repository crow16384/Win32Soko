@echo off
ml /c /IC:\masm32\include\ /coff *.asm
lib /subsystem:windows /NODEFAULTLIB /out:pnglib.lib *.obj
pause>nul