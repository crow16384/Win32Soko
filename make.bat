@echo off
ml /c /IC:\masm32\include\ /coff Win32Soko.asm
rc  Win32Soko.rc
link /SUBSYSTEM:WINDOWS /RELEASE /VERSION:4.0 /LIBPATH:C:\masm32\lib\ pnglib.lib Win32Soko.obj Win32Soko.RES 
pause>nul