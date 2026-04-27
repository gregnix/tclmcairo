@echo off
setlocal enabledelayedexpansion
REM build-win.bat -- tclmcairo Windows build (BAWT Tcl + MSYS2 Cairo)
REM
REM Aufruf: build-win.bat [86|90] [nojpeg]
REM Default: Tcl 8.6, JPEG aktiviert
REM
REM Mit lunasvg (optional):
REM   set LUNASVG_DIR=C:\msys64\home\greg\src\lunasvg
REM   build-win.bat
REM
REM OUTPUT: dist\tclmcairo0.3.6\  -- bereit zum Installieren nach C:\Tcl\lib\

set VERSION=0.3.6
set TCL_VER=%1
if "%TCL_VER%"=="" set TCL_VER=86

set JPEG=1
if "%2"=="nojpeg" set JPEG=0

REM === Tcl / BAWT ===
if "%TCL_VER%"=="86" (
    set BAWT=C:\Bawt\Bawt86
    set STUBLIB=-ltclstub86
) else (
    set BAWT=C:\Bawt\Bawt903
    set STUBLIB=-l:libtclstub.a
)
set BAWT_GCCBIN=%BAWT%\Tools\gcc14.2.0_x86_64-w64-mingw32\mingw64\bin
set TCLROOT=%BAWT%\Windows\x64\Development\opt\Tcl

REM === Cairo (BAWT zuerst, dann MSYS2 MINGW64) ===
set CAIROROOT=
set GCCBIN=%BAWT_GCCBIN%
set MSYS2_CAIRO=0
if exist "%BAWT%\Windows\x64\Development\opt\Cairo\include\cairo\cairo.h" (
    set CAIROROOT=%BAWT%\Windows\x64\Development\opt\Cairo
)
if exist "%BAWT%\Windows\x64\Development\opt\cairo\include\cairo\cairo.h" (
    set CAIROROOT=%BAWT%\Windows\x64\Development\opt\cairo
)
if exist "%TCLROOT%\include\cairo\cairo.h" (
    set CAIROROOT=%TCLROOT%
)
if exist "C:\msys64\mingw64\include\cairo\cairo.h" (
    if "%CAIROROOT%"=="" (
        set CAIROROOT=C:\msys64\mingw64
        set GCCBIN=C:\msys64\mingw64\bin
        set MSYS2_CAIRO=1
    )
)

REM === JPEG (nur MSYS2 MINGW64) ===
set JPEG_DEFINE=
set JPEG_LIB=
if "%JPEG%"=="1" (
    if exist "C:\msys64\mingw64\include\jpeglib.h" (
        set JPEG_DEFINE=-DHAVE_LIBJPEG
        set JPEG_LIB=-ljpeg
        echo JPEG: aktiviert ^(MSYS2 libjpeg-turbo^)
    ) else (
        echo JPEG: deaktiviert ^(jpeglib.h nicht gefunden^)
        echo Tipp: pacman -S mingw-w64-x86_64-libjpeg-turbo
        set JPEG=0
    )
)
if "%JPEG%"=="0" echo JPEG: deaktiviert

REM === lunasvg (optional, via LUNASVG_DIR) ===
set HAVE_LUNASVG=
set LUNASVG_CFLAGS=
if not "%LUNASVG_DIR%"=="" (
    if exist "%LUNASVG_DIR%\include\lunasvg.h" (
        set HAVE_LUNASVG=1
        set LUNASVG_CFLAGS=-I"%LUNASVG_DIR%\include" -I"%LUNASVG_DIR%\plutovg\include" -DHAVE_LUNASVG
        echo lunasvg: %LUNASVG_DIR%
    ) else (
        echo WARN: LUNASVG_DIR gesetzt aber lunasvg.h nicht gefunden: %LUNASVG_DIR%\include\lunasvg.h
    )
)
if "%HAVE_LUNASVG%"=="" echo lunasvg: nicht verfuegbar ^(svg_file_luna deaktiviert^)

set PATH=%GCCBIN%;%PATH%

echo.
echo === BAWT:    %BAWT%
echo === Tcl:     %TCLROOT%
echo === Cairo:   %CAIROROOT%  (MSYS2=%MSYS2_CAIRO%)
echo === GCC:     %GCCBIN%
echo === lunasvg: %HAVE_LUNASVG%
echo === Output:  dist\tclmcairo%VERSION%\
echo.

REM === Voraussetzungen prüfen ===
if not exist "%GCCBIN%\gcc.exe" (
    echo FEHLER: gcc nicht gefunden: %GCCBIN%\gcc.exe
    echo Bitte check-bawt.bat ausfuehren.
    exit /b 1
)
if "%CAIROROOT%"=="" (
    echo FEHLER: cairo.h nicht gefunden.
    echo Bitte MSYS2 installieren: pacman -S mingw-w64-x86_64-cairo
    exit /b 1
)

REM === DLL bauen ===
if "%HAVE_LUNASVG%"=="1" (
    echo === Kompilieren: C-Teil ===
    "%GCCBIN%\gcc.exe" ^
        -shared -O2 -std=c11 ^
        -I"%TCLROOT%\include" ^
        -I"%CAIROROOT%\include" ^
        %LUNASVG_CFLAGS% ^
        -Isrc ^
        -DUSE_TCL_STUBS ^
        -DPACKAGE_NAME="tclmcairo" ^
        -DPACKAGE_VERSION=\"%VERSION%\" ^
        %JPEG_DEFINE% ^
        -c src\libtclmcairo.c ^
        -o src\libtclmcairo_c.o
    if errorlevel 1 goto :error

    echo === Kompilieren: C++ Wrapper ^(lunasvg^) ===
    "%GCCBIN%\g++.exe" ^
        -std=c++17 -O2 ^
        %LUNASVG_CFLAGS% ^
        -I"%TCLROOT%\include" ^
        -DUSE_TCL_STUBS ^
        -c src\lunasvg_wrap.cpp ^
        -o src\lunasvg_wrap.o
    if errorlevel 1 goto :error

    echo === Linken: tclmcairo.dll ^(mit lunasvg^) ===
    "%GCCBIN%\g++.exe" -shared ^
        src\libtclmcairo_c.o ^
        src\lunasvg_wrap.o ^
        -L"%TCLROOT%\lib" ^
        -L"%CAIROROOT%\lib" ^
        -L"%LUNASVG_DIR%\build_shared" ^
        %STUBLIB% -lcairo %JPEG_LIB% -llunasvg -lm ^
        -static-libstdc++ -static-libgcc ^
        -o tclmcairo.dll
) else (
    echo === Kompilieren + Linken: tclmcairo.dll ^(ohne lunasvg^) ===
    "%GCCBIN%\gcc.exe" ^
        -shared -O2 -std=c11 ^
        -I"%TCLROOT%\include" ^
        -I"%CAIROROOT%\include" ^
        -Isrc ^
        -DUSE_TCL_STUBS ^
        -DPACKAGE_NAME="tclmcairo" ^
        -DPACKAGE_VERSION=\"%VERSION%\" ^
        %JPEG_DEFINE% ^
        -o tclmcairo.dll ^
        src\libtclmcairo.c ^
        -L"%TCLROOT%\lib" ^
        -L"%CAIROROOT%\lib" ^
        %STUBLIB% -lcairo %JPEG_LIB% -lm
)
if errorlevel 1 goto :error
echo OK: tclmcairo.dll erzeugt

REM === dist\ zusammenstellen ===
set DIST=dist\tclmcairo%VERSION%
if exist "%DIST%" (
    rmdir /s /q "%DIST%" 2>nul
    if exist "%DIST%" (
        echo WARN: dist-Verzeichnis nicht vollstaendig loeschbar ^(DLL noch gesperrt?^)
        echo       Dateien werden ueberschrieben.
    )
)
if not exist "%DIST%" mkdir "%DIST%"

REM tclmcairo.dll
copy /Y tclmcairo.dll "%DIST%\tclmcairo.dll" >nul
echo OK: tclmcairo.dll

REM lunasvg DLLs (wenn vorhanden)
if "%HAVE_LUNASVG%"=="1" (
    if exist "%LUNASVG_DIR%\build_shared\liblunasvg.dll" (
        copy /Y "%LUNASVG_DIR%\build_shared\liblunasvg.dll" "%DIST%\liblunasvg.dll" >nul
        echo OK: liblunasvg.dll
    )
    if exist "%LUNASVG_DIR%\build_shared\libplutovg.dll" (
        copy /Y "%LUNASVG_DIR%\build_shared\libplutovg.dll" "%DIST%\libplutovg.dll" >nul
        echo OK: libplutovg.dll
    )
    if exist "%LUNASVG_DIR%\build_shared\plutovg\libplutovg.dll" (
        copy /Y "%LUNASVG_DIR%\build_shared\plutovg\libplutovg.dll" "%DIST%\libplutovg.dll" >nul
        echo OK: libplutovg.dll ^(aus plutovg subdir^)
    )
)

REM MSYS2 Cairo + Abhängigkeiten
set MSYS2BIN=C:\msys64\mingw64\bin
for %%d in (
    libcairo-2.dll
    libpixman-1-0.dll
    libfontconfig-1.dll
    libfreetype-6.dll
    libpng16-16.dll
    zlib1.dll
    libexpat-1.dll
    libbrotlidec.dll
    libbrotlicommon.dll
    libharfbuzz-0.dll
    libglib-2.0-0.dll
    libgraphite2.dll
    libintl-8.dll
    libiconv-2.dll
    libbz2-1.dll
    libpcre2-8-0.dll
    libgcc_s_seh-1.dll
    libwinpthread-1.dll
) do (
    if exist "!MSYS2BIN!\%%d" (
        copy /Y "!MSYS2BIN!\%%d" "%DIST%\%%d" >nul
        echo OK: %%d
    ) else (
        echo INFO: %%d nicht in MSYS2 gefunden
    )
)
REM libstdc++ braucht Anfuehrungszeichen wegen + im Namen
if exist "!MSYS2BIN!\libstdc++-6.dll" (
    copy /Y "!MSYS2BIN!\libstdc++-6.dll" "%DIST%\libstdc++-6.dll" >nul
    echo OK: libstdc++-6.dll
)

REM Tcl-Module
copy /Y "tcl\tclmcairo-%VERSION%.tm"  "%DIST%\tclmcairo-%VERSION%.tm"  >nul
copy /Y tcl\canvas2cairo-0.1.tm       "%DIST%\canvas2cairo-0.1.tm"      >nul
copy /Y tcl\shape_renderer-0.1.tm     "%DIST%\shape_renderer-0.1.tm"    >nul
copy /Y tcl\svg2cairo-0.1.tm          "%DIST%\svg2cairo-0.1.tm"         >nul
echo OK: .tm Dateien

REM pkgIndex.tcl generieren
powershell -Command "(Get-Content pkgIndex.tcl.in) -replace '@PACKAGE_NAME@','tclmcairo' -replace '@PACKAGE_VERSION@','%VERSION%' | Set-Content '%DIST%\pkgIndex.tcl'"
if not exist "%DIST%\pkgIndex.tcl" (
    echo FEHLER: pkgIndex.tcl konnte nicht erzeugt werden.
    exit /b 1
)
echo OK: pkgIndex.tcl

REM Lizenzen
if exist THIRD-PARTY-LICENSES.txt copy /Y THIRD-PARTY-LICENSES.txt "%DIST%\" >nul
if exist LICENSE copy /Y LICENSE "%DIST%\" >nul

echo.
echo === Build erfolgreich ===
echo.
echo Inhalt von %DIST%:
dir "%DIST%" /b
echo.
echo Installation:
echo   xcopy /e /i /y "%DIST%" "C:\Tcl\lib\tclmcairo%VERSION%"
echo.
echo Test (aus Source-Verzeichnis):
echo   test-win.bat %TCL_VER%
echo.
echo Test nach Installation:
echo   testlt.bat
goto :eof

:error
echo.
echo === FEHLER beim Build -- Abbruch ===
exit /b 1
