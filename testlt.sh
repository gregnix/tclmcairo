#!/bin/bash
LUNADIR=/home/greg/Project/2026/code/TkMoin/lunasvg

echo "=== Tests ==="
LD_LIBRARY_PATH=${LUNADIR}/build_shared \
TCLMCAIRO_LIBDIR=. tclsh8.6 tests/test-tclmcairo.tcl

echo ""
echo "=== lunasvg Schnelltest ==="
for n in 1 2 3 4 5 6; do
    f="demos/test${n}.svg"
    [ -f "$f" ] || continue
    LD_LIBRARY_PATH=${LUNADIR}/build_shared \
    TCLMCAIRO_LIBDIR=. tclsh8.6 << TCL
lappend auto_path .
tcl::tm::path add tcl
package require tclmcairo
set ctx [tclmcairo::new 700 360]
\$ctx clear 1 1 1 1
if {[catch {\$ctx svg_file_luna ${f} 0 0 -width 700 -height 360} err]} {
    puts "test${n}: FEHLER — \$err"
} else {
    \$ctx save /tmp/luna-test${n}.png
    puts "test${n}: OK ([file size /tmp/luna-test${n}.png] bytes)"
}
\$ctx destroy
TCL
done
echo ""
echo "PNGs in /tmp/luna-test1..6.png"
