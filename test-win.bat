@echo off
setlocal enabledelayedexpansion
REM test-win.bat -- tclmcairo Tests unter Windows/BAWT
REM Aufruf: test-win.bat [86|90]
REM Default: Tcl 8.6

set VERSION=0.3.3
set TCL_VER=%1
if "%TCL_VER%"=="" set TCL_VER=86

if "%TCL_VER%"=="86" (
    set TCLBIN=C:\Bawt\Bawt86\Windows\x64\Development\opt\Tcl\bin
) else (
    set TCLBIN=C:\Bawt\Bawt903\Windows\x64\Development\opt\Tcl\bin
)

set DIST=dist\tclmcairo%VERSION%
if not exist "%DIST%\tclmcairo.dll" (
    echo FEHLER: %DIST%\tclmcairo.dll nicht gefunden.
    echo Bitte zuerst: build-win.bat %TCL_VER%
    exit /b 1
)

REM DLLs aus dist\ in PATH aufnehmen (libcairo-2.dll etc. liegen dort)
set PATH=%CD%\%DIST%;%TCLBIN%;%PATH%
set TCLMCAIRO_LIBDIR=%CD%\%DIST%

echo === tclmcairo Tests (Tcl %TCL_VER%) ===
echo LIBDIR: %TCLMCAIRO_LIBDIR%
echo.

"%TCLBIN%\tclsh.exe" tests\test-tclmcairo.tcl
