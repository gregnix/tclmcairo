@echo off
REM build-win.bat -- tkmcairo Windows build using BAWT toolchain
REM
REM NOTE: tkmcairo is NOT a BAWT package.
REM       This script uses BAWT's gcc + Tcl, but Cairo comes from MSYS2 MINGW64.
REM       Prerequisite: MSYS2 installed + pacman -S mingw-w64-x86_64-cairo
REM
REM Aufruf: build-win.bat [86|90]
REM Default: Tcl 8.6

set TCL_VER=%1
if "%TCL_VER%"=="" set TCL_VER=86

if "%TCL_VER%"=="86" (
    set BAWT=C:\Bawt\Bawt86
    set STUBLIB=-ltclstub86
) else (
    set BAWT=C:\Bawt\Bawt903
    set STUBLIB=-l:libtclstub.a
)

REM BAWT 3.2.0 Pfadstruktur
set BAWT_GCCBIN=%BAWT%\Tools\gcc14.2.0_x86_64-w64-mingw32\mingw64\bin
set TCLROOT=%BAWT%\Windows\x64\Development\opt\Tcl

REM Cairo: BAWT-Pfade, dann MSYS2 MINGW64 als Fallback
REM Wenn MSYS2-Cairo: MSYS2 gcc verwenden (verhindert CRT-Mismatch)
set CAIROROOT=
set GCCBIN=%BAWT_GCCBIN%
if exist "%BAWT%\Windows\x64\Development\opt\Cairo\include\cairo\cairo.h" set CAIROROOT=%BAWT%\Windows\x64\Development\opt\Cairo
if exist "%BAWT%\Windows\x64\Development\opt\cairo\include\cairo\cairo.h" set CAIROROOT=%BAWT%\Windows\x64\Development\opt\cairo
if exist "%TCLROOT%\include\cairo\cairo.h"                                 set CAIROROOT=%TCLROOT%
if exist "C:\msys64\mingw64\include\cairo\cairo.h" (
    if "%CAIROROOT%"=="" (
        set CAIROROOT=C:\msys64\mingw64
        set GCCBIN=C:\msys64\mingw64\bin
    )
)

set PATH=%GCCBIN%;%PATH%

echo.
echo === BAWT:   %BAWT%
echo === Tcl:    %TCLROOT%
echo === Cairo:  %CAIROROOT%
echo === GCC:    %GCCBIN%
echo.

REM Prüfen
if not exist "%GCCBIN%\gcc.exe" (
    echo FEHLER: gcc nicht gefunden: %GCCBIN%\gcc.exe
    echo Bitte check-bawt.bat ausfuehren.
    exit /b 1
)
if "%CAIROROOT%"=="" (
    echo FEHLER: cairo.h nicht gefunden.
    echo Bitte check-bawt.bat ausfuehren.
    exit /b 1
)

echo === tkmcairo.dll bauen ===

"%GCCBIN%\gcc.exe" ^
    -shared -O2 -std=c11 ^
    -I"%TCLROOT%\include" ^
    -I"%CAIROROOT%\include" ^
    -DUSE_TCL_STUBS ^
    -DPACKAGE_NAME="tkmcairo" ^
    -DPACKAGE_VERSION="0.1" ^
    -o tkmcairo.dll ^
    src\libtkmcairo.c ^
    -L"%TCLROOT%\lib" ^
    -L"%CAIROROOT%\lib" ^
    %STUBLIB% -lcairo -lm

if errorlevel 1 goto :error

echo.
echo === Build erfolgreich ===
dir tkmcairo.dll
goto :end

:error
echo.
echo === FEHLER beim Build ===
exit /b 1

:end
echo.
echo Test starten:
echo   test-win.bat %TCL_VER%
