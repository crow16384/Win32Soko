@echo off
ml /Zi /Zd /ID:\masm32\includeex\ /c /coff /D_DEBUG *.asm
lib /DEBUGTYPE:CV /NODEFAULTLIB /subsystem:windows /out:pnglib_dbg.lib *.obj
pause>nul