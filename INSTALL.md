# tclmcairo — Installation

## Directory Layout

All files install into a single directory — no split layout:

```
<prefix>/lib/tcltk/tclmcairo0.3.4/
    pkgIndex.tcl
    libtclmcairo.so      (Linux)
    libtclmcairo.dylib   (macOS)
    tclmcairo.dll        (Windows)
    tclmcairo-0.3.4.tm
    canvas2cairo-0.1.tm
    shape_renderer-0.1.tm
    svg2cairo-0.1.tm
```

After installation, `package require tclmcairo`, `package require canvas2cairo`,
and `package require svg2cairo` work without any `lappend auto_path` because
`<prefix>/lib/tcltk` is already in Tcl's `auto_path` on Debian/Ubuntu.

---

## Linux — Standard Build (ohne lunasvg)

```bash
autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make
sudo make install
make test
```

Installs to `/usr/lib/tcltk/tclmcairo0.3.4/` — already in `auto_path`.

---

## Linux — Build mit lunasvg

lunasvg muss einmalig gebaut sein:

```bash
cd ~/Project/2026/code/TkMoin/lunasvg
cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
cmake --build build_shared
```

Dann tclmcairo mit lunasvg — **Reihenfolge beachten:**

```bash
cd ~/Project/2026/code/TkMoin/tclmcairo/tclmcairo03

autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make clean && make
sudo make install      # pkgIndex.tcl + .tm Dateien installieren
bash buildlt.sh        # libtclmcairo.so mit HAVE_LUNASVG neu bauen
```

**Wichtig:** `sudo make install` muss **vor** `buildlt.sh` laufen.
`buildlt.sh` ersetzt nur `libtclmcairo.so` — `pkgIndex.tcl` und `.tm`
Dateien werden ausschließlich von `sudo make install` installiert.

Nur `.so` neu bauen (wenn `pkgIndex.tcl` bereits aktuell):
```bash
bash buildlt.sh
```

### Verify (mit lunasvg)

```bash
tclsh8.6 << 'TCL'
package require tclmcairo
package require svg2cairo
set ctx [tclmcairo::new 200 200]
$ctx svg_file_luna demos/test1.svg 0 0 -width 200 -height 200
$ctx save /tmp/luna-test.png
$ctx destroy
puts "OK: [file size /tmp/luna-test.png] bytes"
TCL
```

---

## Custom Tcl Installation (self-compiled)

```bash
autoconf
./configure --with-tcl=/home/mark/opt/tcl9/lib
make && make test
sudo make install
```

`make test` and `make demo` automatically use the tclsh from the
configured prefix — no `TCLSH=...` override needed.

---

## Quick Install (no configure required)

```bash
mkdir -p ~/lib/tclmcairo0.3.4
cp libtclmcairo.so              ~/lib/tclmcairo0.3.4/
cp pkgIndex.tcl                 ~/lib/tclmcairo0.3.4/
cp tcl/tclmcairo-0.3.4.tm      ~/lib/tclmcairo0.3.4/
cp tcl/canvas2cairo-0.1.tm      ~/lib/tclmcairo0.3.4/
cp tcl/shape_renderer-0.1.tm    ~/lib/tclmcairo0.3.4/
cp tcl/svg2cairo-0.1.tm         ~/lib/tclmcairo0.3.4/
```

Then in any script or `~/.tclshrc`:
```tcl
lappend auto_path ~/lib/tclmcairo0.3.4
package require tclmcairo
package require svg2cairo
```

---

## Troubleshooting

### `configure: error: Cannot find private header tclInt.h`

Fixed in 0.3.2+. The `TEA_PRIVATE_TCL_HEADERS` call has been removed.
tclmcairo only uses the public Tcl API.

### `can't find package svg2cairo`

`pkgIndex.tcl` is outdated — run `sudo make install` again to install
the current `pkgIndex.tcl` which includes the `svg2cairo` entry.

---

## Verify

```tcl
package require tclmcairo
puts [package present tclmcairo]   ;# -> 0.3.4

set ctx [tclmcairo::new 100 100]
$ctx circle 50 50 40 -fill {1 0.5 0}
$ctx save /tmp/test.png
$ctx destroy
puts "OK: [file size /tmp/test.png] bytes"
```

---

## Windows (BAWT + MSYS2)

**Do not install into `C:\Program Files\`** — that requires admin rights.

### Prerequisites

- BAWT 3.2 — `C:\Bawt\`
- MSYS2 MINGW64 — `C:\msys64\`
- Cairo via MSYS2: `pacman -S mingw-w64-x86_64-cairo`
- JPEG via MSYS2: `pacman -S mingw-w64-x86_64-libjpeg-turbo`

### Build + Install

```bat
REM ohne lunasvg:
build-win.bat 86

REM mit lunasvg:
set LUNASVG_DIR=C:\msys64\home\greg\src\lunasvg
build-win.bat 86
```

Produces `dist\tclmcairo0.3.4\` — ready to install:

```bat
xcopy /e /i /y dist\tclmcairo0.3.4 C:\Tcl\lib\tclmcairo0.3.4
```

### dist\ contents

```
tclmcairo.dll
pkgIndex.tcl
tclmcairo-0.3.4.tm
canvas2cairo-0.1.tm
shape_renderer-0.1.tm
svg2cairo-0.1.tm
libcairo-2.dll
libpixman-1-0.dll
libfontconfig-1.dll
libfreetype-6.dll
libpng16-16.dll
libharfbuzz-0.dll
libglib-2.0-0.dll
libgraphite2.dll
libbrotlidec.dll
libbrotlicommon.dll
libexpat-1.dll
libintl-8.dll
libiconv-2.dll
libbz2-1.dll
libpcre2-8-0.dll
zlib1.dll
libgcc_s_seh-1.dll
libstdc++-6.dll
libwinpthread-1.dll
liblunasvg.dll        (nur mit LUNASVG_DIR)
libplutovg.dll        (nur mit LUNASVG_DIR)
LICENSE
THIRD-PARTY-LICENSES.txt
```

### Test

```bat
test-win.bat 86
```

Tests run from `dist\tclmcairo0.3.4\` — all DLLs available there.

### lunasvg Test (nach Installation)

```bat
cd C:\Tcl\lib\tclmcairo0.3.4
testlt.bat
```

**Wichtig:** lunasvg Tests immer aus dem Installationsverzeichnis starten —
dort liegen alle DLL-Abhängigkeiten.

---

## Runtime Dependencies

```bash
# Linux (Debian/Ubuntu)
sudo apt install libcairo2 libjpeg8

# macOS
brew install cairo jpeg

# Windows
# All DLLs are shipped in dist\tclmcairo0.3.4\ by build-win.bat
```

---

## Per-user install via TCLLIBPATH (Windows, no admin)

Control Panel → System → Environment Variables → User variables:
```
TCLLIBPATH=C:/Users/greg/tcllib
```

Then:
```bat
xcopy /e /i /y dist\tclmcairo0.3.4 C:\Users\greg\tcllib\tclmcairo0.3.4
```

`TCLLIBPATH` is automatically added to `auto_path` — no `lappend` needed.
