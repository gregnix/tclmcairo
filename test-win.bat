@echo off
REM test-win.bat -- tclmcairo Tests unter Windows/BAWT
REM Aufruf: test-win.bat [86|90]
REM Default: Tcl 8.6

set TCL_VER=%1
if "%TCL_VER%"=="" set TCL_VER=86

if "%TCL_VER%"=="86" (
    set TCLBIN=C:\Bawt\Bawt86\Windows\x64\Development\opt\Tcl\bin
) else (
    set TCLBIN=C:\Bawt\Bawt903\Windows\x64\Development\opt\Tcl\bin
)

set PATH=%TCLBIN%;%PATH%

echo === tclmcairo Tests (Tcl %TCL_VER%) ===
REM Cairo.dll liegt in MSYS2 mingw64/bin -- PATH erweitern
set PATH=C:\msys64\mingw64\bin;%PATH%
set TCLMCAIRO_LIBDIR=.
"%TCLBIN%\tclsh.exe" tests\test-tclmcairo.tcl
