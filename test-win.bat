@echo off
setlocal enabledelayedexpansion
REM test-win.bat -- tclmcairo Tests unter Windows/BAWT
REM
REM Aufruf: test-win.bat [86|90]
REM Default: Tcl 8.6
REM
REM Voraussetzung: build-win.bat muss zuerst gelaufen sein.
REM Testet aus dist\tclmcairo%VERSION%\ heraus (DLLs dort verfuegbar).

set VERSION=0.3.4
set TCL_VER=%1
if "%TCL_VER%"=="" set TCL_VER=86

if "%TCL_VER%"=="86" (
    set TCLBIN=C:\Bawt\Bawt86\Windows\x64\Development\opt\Tcl\bin
) else (
    set TCLBIN=C:\Bawt\Bawt903\Windows\x64\Development\opt\Tcl\bin
)
set TCLSH=%TCLBIN%\tclsh.exe

REM dist-Verzeichnis pruefen
set DIST=dist\tclmcairo%VERSION%
if not exist "%DIST%\tclmcairo.dll" (
    echo FEHLER: %DIST%\tclmcairo.dll nicht gefunden.
    echo Bitte zuerst ausfuehren: build-win.bat %TCL_VER%
    exit /b 1
)
if not exist "%TCLSH%" (
    echo FEHLER: tclsh nicht gefunden: %TCLSH%
    exit /b 1
)

REM DLLs aus dist\ in PATH (fuer Cairo-Abhaengigkeiten)
REM TCLMCAIRO_LIBDIR damit tclmcairo-0.3.4.tm die DLL findet
set DIST_ABS=%CD%\%DIST%
set PATH=%DIST_ABS%;%TCLBIN%;%PATH%
set TCLMCAIRO_LIBDIR=%DIST_ABS%

echo === tclmcairo %VERSION% Tests (Tcl %TCL_VER%) ===
echo LIBDIR: %TCLMCAIRO_LIBDIR%
echo TCLSH:  %TCLSH%
echo.

"%TCLSH%" tests\test-tclmcairo.tcl
if errorlevel 1 (
    echo.
    echo === FEHLER: Tests nicht alle erfolgreich ===
    exit /b 1
)

echo.
echo === canvas2cairo Tests ===
"%TCLSH%" tests\test-canvas2cairo.tcl
if errorlevel 1 (
    echo.
    echo === FEHLER: canvas2cairo Tests nicht alle erfolgreich ===
    exit /b 1
)

echo.
echo === Alle Tests bestanden ===
echo.
echo Naechste Schritte:
echo   Installation: xcopy /e /i /y "%DIST%" "C:\Tcl\lib\tclmcairo%VERSION%"
echo   lunasvg Test: testlt.bat
