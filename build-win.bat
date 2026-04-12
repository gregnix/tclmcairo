@echo off
setlocal enabledelayedexpansion
REM build-win.bat -- tclmcairo Windows build using BAWT toolchain
REM
REM NOTE: tclmcairo is NOT a BAWT package.
REM       This script uses BAWT's gcc + Tcl, but Cairo comes from MSYS2 MINGW64.
REM       Prerequisite: MSYS2 installed + pacman -S mingw-w64-x86_64-cairo
REM
REM JPEG support (optional, default: enabled):
REM   Prerequisite: pacman -S mingw-w64-x86_64-libjpeg-turbo
REM   Disable:  build-win.bat [86|90] nojpeg
REM
REM Aufruf: build-win.bat [86|90] [nojpeg]
REM Default: Tcl 8.6, JPEG enabled
REM
REM OUTPUT: dist\tclmcairo0.3.3\   <-- ready to install
REM   Copy this directory to C:\Tcl\lib\ and run: package require tclmcairo

set VERSION=0.3.3
set TCL_VER=%1
if "%TCL_VER%"=="" set TCL_VER=86

set JPEG=1
if "%2"=="nojpeg" set JPEG=0

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
REM Wenn MSYS2-Cairo: MSYS2-gcc verwenden (Headers + Lib + gcc müssen kompatibel sein)
set CAIROROOT=
set GCCBIN=%BAWT_GCCBIN%
set MSYS2_CAIRO=0
if exist "%BAWT%\Windows\x64\Development\opt\Cairo\include\cairo\cairo.h" set CAIROROOT=%BAWT%\Windows\x64\Development\opt\Cairo
if exist "%BAWT%\Windows\x64\Development\opt\cairo\include\cairo\cairo.h" set CAIROROOT=%BAWT%\Windows\x64\Development\opt\cairo
if exist "%TCLROOT%\include\cairo\cairo.h"                                 set CAIROROOT=%TCLROOT%
if exist "C:\msys64\mingw64\include\cairo\cairo.h" (
    if "%CAIROROOT%"=="" (
        set CAIROROOT=C:\msys64\mingw64
        set GCCBIN=C:\msys64\mingw64\bin
        set MSYS2_CAIRO=1
    )
)

REM JPEG: nur MSYS2 MINGW64
set JPEG_DEFINE=
set JPEG_LIB=
if "%JPEG%"=="1" (
    if exist "C:\msys64\mingw64\include\jpeglib.h" (
        set JPEG_DEFINE=-DHAVE_LIBJPEG
        set JPEG_LIB=-ljpeg
        echo JPEG: enabled (MSYS2 MINGW64 libjpeg-turbo)
    ) else (
        echo JPEG: disabled (jpeglib.h not found - run: pacman -S mingw-w64-x86_64-libjpeg-turbo)
        set JPEG=0
    )
)
if "%JPEG%"=="0" echo JPEG: disabled

set PATH=%GCCBIN%;%PATH%

echo.
echo === BAWT:   %BAWT%
echo === Tcl:    %TCLROOT%
echo === Cairo:  %CAIROROOT%
echo === GCC:    %GCCBIN%
echo === Output: dist\tclmcairo%VERSION%\
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

REM Linker flags — dynamisch gegen MSYS2-Cairo
REM Hinweis: preload_cairo_deps() in libtclmcairo.c lädt die DLLs
REM zur Laufzeit aus dem eigenen Verzeichnis (GetModuleHandleEx)
set CAIRO_LINK=-lcairo
set STATIC_FLAGS=

echo === tclmcairo.dll bauen ===

"%GCCBIN%\gcc.exe" ^
    -shared -O2 -std=c11 ^
    -I"%TCLROOT%\include" ^
    -I"%CAIROROOT%\include" ^
    -DUSE_TCL_STUBS ^
    -DPACKAGE_NAME="tclmcairo" ^
    -DPACKAGE_VERSION="%VERSION%" ^
    %JPEG_DEFINE% ^
    %STATIC_FLAGS% ^
    -o tclmcairo.dll ^
    src\libtclmcairo.c ^
    -L"%TCLROOT%\lib" ^
    -L"%CAIROROOT%\lib" ^
    %STUBLIB% %CAIRO_LINK% %JPEG_LIB% -lm

if errorlevel 1 goto :error

echo.
echo === dist-Verzeichnis zusammenstellen ===

set DIST=dist\tclmcairo%VERSION%
if exist "%DIST%" rmdir /s /q "%DIST%"
mkdir "%DIST%"

REM tclmcairo.dll
copy tclmcairo.dll "%DIST%\tclmcairo.dll" >nul
echo OK: tclmcairo.dll

REM Tcl-Dateien aus tcl\
copy tcl\tclmcairo-%VERSION%.tm  "%DIST%\tclmcairo-%VERSION%.tm"  >nul
copy tcl\canvas2cairo-0.1.tm     "%DIST%\canvas2cairo-0.1.tm"     >nul
copy tcl\shape_renderer-0.1.tm   "%DIST%\shape_renderer-0.1.tm"   >nul
echo OK: .tm Dateien

REM pkgIndex.tcl generieren
powershell -Command "(Get-Content pkgIndex.tcl.in) -replace '@PACKAGE_NAME@','tclmcairo' -replace '@PACKAGE_VERSION@','%VERSION%' | Set-Content '%DIST%\pkgIndex.tcl'"
if not exist "%DIST%\pkgIndex.tcl" (
    echo FEHLER: pkgIndex.tcl konnte nicht erzeugt werden.
    exit /b 1
)
echo OK: pkgIndex.tcl

REM Cairo-DLL immer mitkopieren
if exist "%CAIROROOT%\bin\libcairo-2.dll" (
    copy "%CAIROROOT%\bin\libcairo-2.dll" "%DIST%\libcairo-2.dll" >nul
    echo OK: libcairo-2.dll (aus %CAIROROOT%\bin)
) else if exist "C:\msys64\mingw64\bin\libcairo-2.dll" (
    copy "C:\msys64\mingw64\bin\libcairo-2.dll" "%DIST%\libcairo-2.dll" >nul
    echo OK: libcairo-2.dll (aus MSYS2)
) else (
    echo WARN: libcairo-2.dll nicht gefunden - muss manuell kopiert werden
)

REM MSYS2-Abhängigkeiten: nur bei dynamischem Linking nötig
REM Bei statischem Linking (-static-libgcc etc.) sind keine MSYS2-DLLs nötig
if "%MSYS2_CAIRO%"=="1" (
    if "%STATIC_FLAGS%"=="" (
        echo.
        echo === MSYS2-Abhaengigkeiten kopieren ===
        set MSYS2BIN=C:\msys64\mingw64\bin
        for %%d in (libcairo-2.dll libpixman-1-0.dll libfontconfig-1.dll libfreetype-6.dll libpng16-16.dll libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll zlib1.dll libexpat-1.dll libbrotlidec.dll libbrotlicommon.dll libharfbuzz-0.dll libglib-2.0-0.dll libgraphite2.dll libintl-8.dll libiconv-2.dll libbz2-1.dll libpcre2-8-0.dll) do (
            if exist "!MSYS2BIN!\%%d" (
                copy "!MSYS2BIN!\%%d" "%DIST%\%%d" >nul
                echo OK: %%d
            ) else (
                echo INFO: %%d nicht gefunden (optional)
            )
        )
    ) else (
        echo INFO: Statisch gelinkt -- keine MSYS2-DLLs noetig
    )
)

REM Lizenzdatei
copy THIRD-PARTY-LICENSES.txt "%DIST%\THIRD-PARTY-LICENSES.txt" >nul 2>nul
copy LICENSE "%DIST%\LICENSE" >nul 2>nul

echo.
echo === Build + Package erfolgreich ===
echo.
echo Inhalt von %DIST%:
dir "%DIST%" /b
echo.
echo Installation:
echo   xcopy /e /i "%DIST%" "C:\Tcl\lib\tclmcairo%VERSION%"
echo   oder manuell den Ordner nach C:\Tcl\lib\ kopieren.
echo.
echo Test:
echo   test-win.bat %TCL_VER%

goto :end

:error
echo.
echo === FEHLER beim Build ===
exit /b 1

:end


set TCL_VER=%1
if "%TCL_VER%"=="" set TCL_VER=86

set JPEG=1
if "%2"=="nojpeg" set JPEG=0

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

REM JPEG: nur MSYS2 MINGW64 (BAWT hat kein libjpeg)
set JPEG_DEFINE=
set JPEG_LIB=
if "%JPEG%"=="1" (
    if exist "C:\msys64\mingw64\include\jpeglib.h" (
        set JPEG_DEFINE=-DHAVE_LIBJPEG
        set JPEG_LIB=-ljpeg
        echo JPEG: enabled (MSYS2 MINGW64 libjpeg-turbo)
    ) else (
        echo JPEG: disabled (jpeglib.h not found - run: pacman -S mingw-w64-x86_64-libjpeg-turbo)
        set JPEG=0
    )
)
if "%JPEG%"=="0" echo JPEG: disabled

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

echo === tclmcairo.dll bauen ===

"%GCCBIN%\gcc.exe" ^
    -shared -O2 -std=c11 ^
    -I"%TCLROOT%\include" ^
    -I"%CAIROROOT%\include" ^
    -DUSE_TCL_STUBS ^
    -DPACKAGE_NAME="tclmcairo" ^
    -DPACKAGE_VERSION="0.3.3" ^
    %JPEG_DEFINE% ^
    %STATIC_FLAGS% ^
    -o tclmcairo.dll ^
    src\libtclmcairo.c ^
    -L"%TCLROOT%\lib" ^
    -L"%CAIROROOT%\lib" ^
    %STUBLIB% -lcairo %JPEG_LIB% -lm

if errorlevel 1 goto :error

echo.
echo === pkgIndex.tcl erzeugen ===
powershell -Command "(Get-Content pkgIndex.tcl.in) -replace '@PACKAGE_NAME@','tclmcairo' -replace '@PACKAGE_VERSION@','0.3.3' | Set-Content pkgIndex.tcl"
if not exist pkgIndex.tcl (
    echo FEHLER: pkgIndex.tcl konnte nicht erzeugt werden.
    exit /b 1
)
echo pkgIndex.tcl erzeugt.

echo.
echo === Build erfolgreich ===
dir tclmcairo.dll pkgIndex.tcl
goto :end

:error
echo.
echo === FEHLER beim Build ===
exit /b 1

:end
echo.
echo Test starten:
echo   test-win.bat %TCL_VER%
REM
