@echo off
REM check-bawt.bat -- Check BAWT + MSYS2 paths for tclmcairo
REM
REM NOTE: tclmcairo is NOT a BAWT package.
REM       Build uses BAWT's gcc + Tcl, Cairo comes from MSYS2 MINGW64.
REM       MSYS2: https://www.msys2.org/
REM       Cairo: pacman -S mingw-w64-x86_64-cairo
REM       JPEG:  pacman -S mingw-w64-x86_64-libjpeg-turbo

set BAWT86=C:\Bawt\Bawt86
set BAWT90=C:\Bawt\Bawt903

echo === Prüfe MSYS2 MINGW64 ===
if exist "C:\msys64\mingw64\bin\gcc.exe" (
    echo OK: MSYS2 gcc gefunden
) else (
    echo FEHLER: MSYS2 nicht gefunden (C:\msys64\mingw64\bin\gcc.exe)
    echo Installieren: https://www.msys2.org/
)
if exist "C:\msys64\mingw64\include\cairo\cairo.h" (
    echo OK: MSYS2 Cairo gefunden
) else (
    echo FEHLER: MSYS2 Cairo nicht gefunden
    echo Installieren: pacman -S mingw-w64-x86_64-cairo
)
if exist "C:\msys64\mingw64\include\jpeglib.h" (
    echo OK: MSYS2 libjpeg-turbo gefunden (JPEG-Support aktiviert)
) else (
    echo INFO: MSYS2 libjpeg-turbo nicht gefunden (JPEG-Support deaktiviert)
    echo       Installieren: pacman -S mingw-w64-x86_64-libjpeg-turbo
)

echo.
echo === Prüfe BAWT 8.6 ===
if exist "%BAWT86%\Tools\gcc14.2.0_x86_64-w64-mingw32\mingw64\bin\gcc.exe" (
    echo OK: gcc gefunden
) else (
    echo FEHLER: gcc nicht gefunden
    dir "%BAWT86%\Tools\" 2>nul | findstr /i "gcc"
)

if exist "%BAWT86%\Windows\x64\Development\opt\Tcl\bin\tclsh86.exe" (
    echo OK: tclsh86 gefunden
) else if exist "%BAWT86%\Windows\x64\Development\opt\Tcl\bin\tclsh.exe" (
    echo OK: tclsh gefunden
) else (
    echo FEHLER: tclsh nicht gefunden
    dir "%BAWT86%\Windows\x64\Development\opt\Tcl\bin\" 2>nul
)

if exist "%BAWT86%\Windows\x64\Development\opt\Tcl\lib\tclstub86.lib" (
    echo OK: tclstub86.lib gefunden
) else (
    echo FEHLER: tclstub86.lib nicht gefunden
    dir "%BAWT86%\Windows\x64\Development\opt\Tcl\lib\tcl*.lib" 2>nul
)

REM Cairo suchen (verschiedene mögliche BAWT-Pfade)
set CAIRO_FOUND=0
for %%p in (
    "%BAWT86%\Windows\x64\Development\opt\Cairo\include\cairo\cairo.h"
    "%BAWT86%\Windows\x64\Development\opt\cairo\include\cairo\cairo.h"
    "%BAWT86%\Windows\x64\Development\opt\Tcl\include\cairo\cairo.h"
) do (
    if exist %%p (
        echo OK: cairo.h gefunden: %%p
        set CAIRO_FOUND=1
    )
)
if "%CAIRO_FOUND%"=="0" (
    echo INFO: cairo.h nicht in BAWT - wird von MSYS2 MINGW64 genommen
)

echo.
echo === Prüfe BAWT 9.0 ===
if exist "%BAWT90%\Windows\x64\Development\opt\Tcl\lib\libtclstub.a" (
    echo OK: libtclstub.a gefunden
) else (
    echo FEHLER: libtclstub.a nicht gefunden
    dir "%BAWT90%\Windows\x64\Development\opt\Tcl\lib\*stub*" 2>nul
)

set CAIRO_FOUND=0
for %%p in (
    "%BAWT90%\Windows\x64\Development\opt\Cairo\include\cairo\cairo.h"
    "%BAWT90%\Windows\x64\Development\opt\cairo\include\cairo\cairo.h"
    "%BAWT90%\Windows\x64\Development\opt\Tcl\include\cairo\cairo.h"
) do (
    if exist %%p (
        echo OK: cairo.h gefunden: %%p
        set CAIRO_FOUND=1
    )
)
if "%CAIRO_FOUND%"=="0" (
    echo INFO: cairo.h nicht in BAWT - wird von MSYS2 MINGW64 genommen
)

echo.
echo === PowerShell (fuer pkgIndex.tcl) ===
powershell -Command "Write-Host 'OK: PowerShell verfuegbar'" 2>nul
if errorlevel 1 (
    echo FEHLER: PowerShell nicht verfuegbar
    echo pkgIndex.tcl muss manuell erzeugt werden
)

echo.
echo === Fertig ===
echo.
echo Build starten mit:
echo   build-win.bat 86         (Tcl 8.6, JPEG automatisch)
echo   build-win.bat 86 nojpeg  (Tcl 8.6, ohne JPEG)
echo   build-win.bat 90         (Tcl 9.0)

set BAWT86=C:\Bawt\Bawt86
set BAWT90=C:\Bawt\Bawt903

echo === Prüfe BAWT 8.6 ===
if exist "%BAWT86%\Tools\gcc14.2.0_x86_64-w64-mingw32\mingw64\bin\gcc.exe" (
    echo OK: gcc gefunden
) else (
    echo FEHLER: gcc nicht gefunden
    dir "%BAWT86%\Tools\" 2>nul | findstr /i "gcc"
)

if exist "%BAWT86%\Windows\x64\Development\opt\Tcl\bin\tclsh86.exe" (
    echo OK: tclsh86 gefunden
) else if exist "%BAWT86%\Windows\x64\Development\opt\Tcl\bin\tclsh.exe" (
    echo OK: tclsh gefunden
) else (
    echo FEHLER: tclsh nicht gefunden
    dir "%BAWT86%\Windows\x64\Development\opt\Tcl\bin\" 2>nul
)

if exist "%BAWT86%\Windows\x64\Development\opt\Tcl\lib\tclstub86.lib" (
    echo OK: tclstub86.lib gefunden
) else (
    echo FEHLER: tclstub86.lib nicht gefunden
    dir "%BAWT86%\Windows\x64\Development\opt\Tcl\lib\tcl*.lib" 2>nul
)

REM Cairo suchen (verschiedene mögliche BAWT-Pfade)
set CAIRO_FOUND=0
for %%p in (
    "%BAWT86%\Windows\x64\Development\opt\Cairo\include\cairo\cairo.h"
    "%BAWT86%\Windows\x64\Development\opt\cairo\include\cairo\cairo.h"
    "%BAWT86%\Windows\x64\Development\opt\Tcl\include\cairo\cairo.h"
) do (
    if exist %%p (
        echo OK: cairo.h gefunden: %%p
        set CAIRO_FOUND=1
    )
)
if "%CAIRO_FOUND%"=="0" (
    echo FEHLER: cairo.h nicht gefunden
    echo SUCHE cairo in BAWT86...
    dir "%BAWT86%\Windows\x64\Development\opt\" 2>nul
)

echo.
echo === Prüfe BAWT 9.0 ===
if exist "%BAWT90%\Windows\x64\Development\opt\Tcl\lib\libtclstub.a" (
    echo OK: libtclstub.a gefunden
) else (
    echo FEHLER: libtclstub.a nicht gefunden
    dir "%BAWT90%\Windows\x64\Development\opt\Tcl\lib\*stub*" 2>nul
)

set CAIRO_FOUND=0
for %%p in (
    "%BAWT90%\Windows\x64\Development\opt\Cairo\include\cairo\cairo.h"
    "%BAWT90%\Windows\x64\Development\opt\cairo\include\cairo\cairo.h"
    "%BAWT90%\Windows\x64\Development\opt\Tcl\include\cairo\cairo.h"
) do (
    if exist %%p (
        echo OK: cairo.h gefunden: %%p
        set CAIRO_FOUND=1
    )
)
if "%CAIRO_FOUND%"=="0" (
    echo FEHLER: cairo.h nicht gefunden
    echo SUCHE cairo in BAWT90...
    dir "%BAWT90%\Windows\x64\Development\opt\" 2>nul
)

echo.
echo === Fertig ===
