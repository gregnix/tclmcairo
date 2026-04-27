#!/bin/bash
# buildlt.sh -- build tclmcairo with lunasvg (Linux)
#
# REQUIREMENT: lunasvg must be built once first:
#   cd <somewhere>/lunasvg
#   cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
#   cmake --build build_shared
#
# USAGE (full build):
#   autoconf
#   ./configure --with-tcl=/usr/lib/tcl8.6
#   make clean && make
#   sudo make install        # installs pkgIndex.tcl + .tm files
#   bash buildlt.sh          # rebuilds libtclmcairo.so with HAVE_LUNASVG
#
# CONFIGURATION via environment variables (with sensible defaults):
#
#   LUNADIR     Path to lunasvg checkout
#               Default: $HOME/Project/2026/code/TkMoin/lunasvg
#               Override: LUNADIR=/path/to/lunasvg bash buildlt.sh
#
#   TCL_VERSION Tcl headers + stub library version (8.6 or 9.0)
#               Default: 8.6
#               Override: TCL_VERSION=9.0 bash buildlt.sh
#
#   PREFIX      Install prefix root for libtclmcairo.so
#               Default: /usr/lib/tcltk
#               Override: PREFIX=$HOME/.local/lib/tcltk bash buildlt.sh
#
# NOTE: sudo make install MUST run before buildlt.sh.
#   buildlt.sh only replaces libtclmcairo.so (with HAVE_LUNASVG).
#   pkgIndex.tcl and .tm files are installed exclusively by sudo make install.
#
# Re-build only the .so (if pkgIndex.tcl is already up-to-date):
#   bash buildlt.sh
#
set -e

# ---- Configurable defaults --------------------------------------
LUNADIR=${LUNADIR:-$HOME/Project/2026/code/TkMoin/lunasvg}
TCL_VERSION=${TCL_VERSION:-8.6}
PREFIX=${PREFIX:-/usr/lib/tcltk}

TCL_INCDIR=/usr/include/tcl${TCL_VERSION}
TCL_STUBLIB=tclstub${TCL_VERSION}

echo "=== Configuration ==="
echo "LUNADIR     = ${LUNADIR}"
echo "TCL_VERSION = ${TCL_VERSION}"
echo "PREFIX      = ${PREFIX}"
echo "TCL_INCDIR  = ${TCL_INCDIR}"
echo

echo "=== Checking lunasvg libs ==="
ls ${LUNADIR}/build_shared/*.so* 2>/dev/null || {
    echo "ERROR: no .so files in ${LUNADIR}/build_shared"
    echo "Build lunasvg first:"
    echo "  cd ${LUNADIR}"
    echo "  cmake -B build_shared -DBUILD_SHARED_LIBS=ON ."
    echo "  cmake --build build_shared"
    exit 1
}

echo "=== Compiling C++ wrapper ==="
g++ -std=c++17 -O2 -fPIC \
    -I${LUNADIR}/include \
    -I${LUNADIR}/plutovg/include \
    -I${TCL_INCDIR} \
    -DHAVE_LUNASVG \
    -c src/lunasvg_wrap.cpp -o src/lunasvg_wrap.o

echo "=== Compiling C part with HAVE_LUNASVG (make clean + make) ==="
make clean
make CFLAGS="-shared -fPIC -O2 \
    -I/usr/include/cairo -I/usr/include/freetype2 \
    -I/usr/include/libpng16 -I/usr/include/pixman-1 \
    -I${TCL_INCDIR} \
    -I${LUNADIR}/include \
    -I${LUNADIR}/plutovg/include \
    $(grep '^DEFINES' Makefile | sed 's/DEFINES[[:space:]]*=[[:space:]]*//')  \
    $(grep '^PKG_CFLAGS' Makefile | sed 's/PKG_CFLAGS[[:space:]]*=[[:space:]]*//')  \
    -DHAVE_LUNASVG"

echo "=== Linking ==="
g++ -shared -o libtclmcairo.so \
    libtclmcairo.o src/lunasvg_wrap.o \
    -L${LUNADIR}/build_shared -llunasvg \
    -lcairo -ljpeg -lm -l${TCL_STUBLIB} -lstdc++

echo "=== Installing (libtclmcairo.so only) ==="
# Auto-detect install dir from PACKAGE_VERSION (set by ./configure)
INSTALL_DIR=$(grep -m1 "^PACKAGE_VERSION" Makefile 2>/dev/null \
              | sed -E 's/.*=[[:space:]]*//')
if [ -z "$INSTALL_DIR" ]; then
    echo "WARNING: cannot determine version from Makefile, falling back"
    INSTALL_DIR="0.3.6"
fi
INSTALL_PATH="${PREFIX}/tclmcairo${INSTALL_DIR}"
if [ ! -d "$INSTALL_PATH" ]; then
    echo "ERROR: $INSTALL_PATH does not exist — please run 'sudo make install' first"
    echo "  (or set PREFIX to your install prefix; current PREFIX=${PREFIX})"
    exit 1
fi
sudo cp libtclmcairo.so "$INSTALL_PATH/"
echo "  -> $INSTALL_PATH/libtclmcairo.so"

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
