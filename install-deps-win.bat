@echo off
REM install-deps-win.bat -- Copy MSYS2 Cairo dependencies to Tcl bin directory
REM
REM tclmcairo.dll depends on Cairo which is built against MSYS2 MINGW64 libraries.
REM These DLLs must be in a directory on PATH (usually C:\Tcl\bin).
REM
REM License notice: see THIRD-PARTY-LICENSES.txt
REM   libcairo-2.dll     -- LGPL 2.1
REM   libpixman-1-0.dll  -- MIT
REM   libfontconfig-1.dll -- MIT
REM   libstdc++-6.dll    -- GPL v3 + GCC Runtime Library Exception
REM
REM Usage:
REM   install-deps-win.bat                  (copies to C:\Tcl\bin)
REM   install-deps-win.bat C:\MyTcl\bin     (copies to custom directory)
REM   install-deps-win.bat .                (copies next to tclmcairo.dll)

set MSYS2=C:\msys64\mingw64\bin
set DEST=%1
if "%DEST%"=="" set DEST=C:\Tcl\bin

echo === tclmcairo dependency installer ===
echo Source: %MSYS2%
echo Dest:   %DEST%
echo.

if not exist "%MSYS2%\gcc.exe" (
    echo FEHLER: MSYS2 nicht gefunden unter %MSYS2%
    echo Installieren: https://www.msys2.org/
    echo Dann: pacman -S mingw-w64-x86_64-cairo
    exit /b 1
)

if not exist "%DEST%" (
    echo FEHLER: Zielverzeichnis nicht gefunden: %DEST%
    exit /b 1
)

REM Required DLLs for libcairo-2.dll
set DLLS=libpixman-1-0.dll libfontconfig-1.dll libfreetype-6.dll libpng16-16.dll libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll zlib1.dll libexpat-1.dll

REM Optional but commonly needed
set DLLS_OPT=libexpat-1.dll libbrotlidec.dll libbrotlicommon.dll libharfbuzz-0.dll

set COPIED=0
set SKIPPED=0

for %%d in (%DLLS%) do (
    if exist "%DEST%\%%d" (
        echo SKIP (already exists): %%d
        set /a SKIPPED+=1
    ) else if exist "%MSYS2%\%%d" (
        copy "%MSYS2%\%%d" "%DEST%\%%d" >nul
        echo OK: %%d
        set /a COPIED+=1
    ) else (
        echo WARN: not found in MSYS2: %%d
    )
)

echo.
echo Optional dependencies:
for %%d in (%DLLS_OPT%) do (
    if exist "%DEST%\%%d" (
        echo SKIP (already exists): %%d
    ) else if exist "%MSYS2%\%%d" (
        copy "%MSYS2%\%%d" "%DEST%\%%d" >nul
        echo OK: %%d
        set /a COPIED+=1
    ) else (
        echo INFO: not in MSYS2 (may not be needed): %%d
    )
)

echo.
echo === Fertig: %COPIED% kopiert, %SKIPPED% bereits vorhanden ===
echo.
echo Test:
echo   tclsh -e "load {%DEST%\..\lib\tclmcairo0.3.6\tclmcairo.dll}; puts OK"
