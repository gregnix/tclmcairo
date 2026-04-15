@echo off
setlocal enabledelayedexpansion

set TCLBIN=C:\Bawt\Bawt86\Windows\x64\Development\opt\Tcl\bin
set TCLSH=%TCLBIN%\tclsh.exe
set LIBDIR=C:\Tcl\lib\tclmcairo0.3.4
set PATH=%LIBDIR%;%TCLBIN%;%PATH%
set TCLMCAIRO_LIBDIR=%LIBDIR%

echo === tclmcairo Tests ===
"%TCLSH%" tests\test-tclmcairo.tcl

echo.
echo === lunasvg Schnelltest ===

for %%n in (1 2 3 4 5 6) do (
    if exist "demos\test%%n.svg" (
        (
            echo lappend auto_path {%LIBDIR%}
            echo package require tclmcairo
            echo set ctx [tclmcairo::new 700 360]
            echo $ctx clear 1 1 1 1
            echo if {[catch {$ctx svg_file_luna demos/test%%n.svg 0 0 -width 700 -height 360} err]} {
            echo     puts "test%%n: FEHLER -- $err"
            echo } else {
            echo     $ctx save demos/test%%n-luna.png
            echo     puts "test%%n: OK"
            echo }
            echo $ctx destroy
        ) > %TEMP%\tlt%%n.tcl
        "%TCLSH%" %TEMP%\tlt%%n.tcl
        del %TEMP%\tlt%%n.tcl >nul 2>nul
    )
)

echo.
echo PNGs in demos\test1-luna.png .. test6-luna.png
