This is the source code folder of PNGlib. The debug version is mainly intended for myself as the author of PNGlib. Most of the debug output statements in the code have been commented (with ;::) as too much debug info would be generated if you use them all. The debug output is stored in a file ("debug logfile$$.txt"), unless you set USE_FILE in cdebug.asm to 0. In that case, vkims debug output window is used.

The normal builds automatically leave the debug stuff out.

clean.bat will delete all .obj & .lib files in this directory.
copy_to_bin will copy all the current libs and pnglib.inc to ..\bin\.

When building the lib, do not run several make_* batch files at the same time. All builds use the same object files, and this would cause a strange mix of objects with different build types.

Thomas