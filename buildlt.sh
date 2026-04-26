#!/bin/bash
# buildlt.sh -- tclmcairo mit lunasvg bauen und installieren (lxpro)
#
# VORAUSSETZUNG: lunasvg muss einmalig gebaut sein:
#   cd ~/Project/2026/code/TkMoin/lunasvg
#   cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
#   cmake --build build_shared
#
# AUFRUF (vollständiger Build):
#   autoconf
#   ./configure --with-tcl=/usr/lib/tcl8.6
#   make clean && make
#   sudo make install        <-- pkgIndex.tcl + .tm Dateien installieren
#   bash buildlt.sh          <-- libtclmcairo.so mit lunasvg neu bauen
#
# HINWEIS: sudo make install MUSS vor buildlt.sh laufen.
#   buildlt.sh ersetzt nur libtclmcairo.so (mit HAVE_LUNASVG).
#   pkgIndex.tcl und .tm Dateien werden von buildlt.sh NICHT installiert --
#   das macht ausschließlich sudo make install.
#
# Nur die .so neu bauen (wenn pkgIndex.tcl bereits aktuell):
#   bash buildlt.sh
#
set -e

LUNADIR=/home/greg/Project/2026/code/TkMoin/lunasvg

echo "=== lunasvg libs prüfen ==="
ls ${LUNADIR}/build_shared/*.so* 2>/dev/null || { echo "FEHLER: keine .so in build_shared"; exit 1; }

echo "=== C++ Wrapper kompilieren ==="
g++ -std=c++17 -O2 -fPIC \
    -I${LUNADIR}/include \
    -I${LUNADIR}/plutovg/include \
    -I/usr/include/tcl8.6 \
    -DHAVE_LUNASVG \
    -c src/lunasvg_wrap.cpp -o src/lunasvg_wrap.o

echo "=== C-Teil mit HAVE_LUNASVG (make clean + make) ==="
make clean
make CFLAGS="-shared -fPIC -O2 \
    -I/usr/include/cairo -I/usr/include/freetype2 \
    -I/usr/include/libpng16 -I/usr/include/pixman-1 \
    -I/usr/include/tcl8.6 \
    -I${LUNADIR}/include \
    -I${LUNADIR}/plutovg/include \
    $(grep '^DEFINES' Makefile | sed 's/DEFINES[[:space:]]*=[[:space:]]*//')  \
    $(grep '^PKG_CFLAGS' Makefile | sed 's/PKG_CFLAGS[[:space:]]*=[[:space:]]*//')  \
    -DHAVE_LUNASVG"

echo "=== Linken ==="
g++ -shared -o libtclmcairo.so \
    libtclmcairo.o src/lunasvg_wrap.o \
    -L${LUNADIR}/build_shared -llunasvg \
    -lcairo -ljpeg -lm -ltclstub8.6 -lstdc++

echo "=== Installieren (nur libtclmcairo.so) ==="
sudo cp libtclmcairo.so /usr/lib/tcltk/tclmcairo0.3.5/

echo "=== lunasvg libs systemweit ==="
for f in ${LUNADIR}/build_shared/*.so*; do
    [ -f "$f" ] && sudo cp -v "$f" /usr/local/lib/
done
sudo ldconfig

echo "=== Fertig ==="
LD_LIBRARY_PATH=${LUNADIR}/build_shared TCLMCAIRO_LIBDIR=. tclsh8.6 << 'TCL'
lappend auto_path .
tcl::tm::path add tcl
package require tclmcairo
set ctx [tclmcairo::new 100 100]
if {[catch {$ctx svg_file_luna /dev/null 0 0} err]} {
    # expected error for /dev/null
}
puts "svg_file_luna: verfügbar ✔"
$ctx destroy
TCL
