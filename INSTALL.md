# tclmcairo — Installation

## Directory Layout

All files install into a single directory — no split layout:

```
<prefix>/lib/tcltk/tclmcairo0.3.3/
    pkgIndex.tcl
    libtclmcairo.so      (Linux)
    libtclmcairo.dylib   (macOS)
    tclmcairo.dll        (Windows)
    tclmcairo-0.3.3.tm
    canvas2cairo-0.1.tm
```

After installation, `package require tclmcairo` and `package require canvas2cairo`
work without any `lappend auto_path` because `<prefix>/lib/tcltk` is already
in Tcl's `auto_path` on Debian/Ubuntu.

---

## Quick Install (no configure required)

After building with `make`, copy all files manually:

```bash
mkdir -p ~/lib/tclmcairo0.3.3
cp libtclmcairo.so         ~/lib/tclmcairo0.3.3/
cp pkgIndex.tcl            ~/lib/tclmcairo0.3.3/
cp tcl/tclmcairo-0.3.3.tm    ~/lib/tclmcairo0.3.3/
cp tcl/canvas2cairo-0.1.tm ~/lib/tclmcairo0.3.3/
```

Then in any script or in `~/.tclshrc`:
```tcl
lappend auto_path ~/lib/tclmcairo0.3.3
package require tclmcairo
package require canvas2cairo   ;# optional Tk Canvas export addon
```

---

## Custom Tcl Installation (self-compiled)

If you compiled Tcl yourself into a custom prefix (e.g. `/home/mark/opt/tcl9`):

```bash
autoconf
./configure --with-tcl=/home/mark/opt/tcl9/lib
make && make test   # automatically uses tclsh from /home/mark/opt/tcl9/bin/
make install
```

No Tcl source tree required. `make test` and `make demo` automatically use
the tclsh from the configured prefix — no `TCLSH=...` override needed (0.3.3+).

---

## Troubleshooting

### `configure: error: Cannot find private header tclInt.h`

This error occurred in versions before 0.3.2 (fixed in 0.3.2+). Upgrade to 0.3.2 or later — the
`TEA_PRIVATE_TCL_HEADERS` call has been removed from `configure.in`.
tclmcairo only uses the public Tcl API and never needed `tclInt.h`.

---

## System-wide Install (make install)

```bash
autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make
sudo make install
```

Installs to `/usr/lib/tcltk/tclmcairo0.3.3/` — already in `auto_path`.

```bash
# Custom prefix:
./configure --prefix=/usr/local --with-tcl=/usr/lib/tcl8.6
sudo make install
# -> /usr/local/lib/tcltk/tclmcairo0.3.3/
```

---

## Verify

```tcl
package require tclmcairo
puts [package present tclmcairo]   ;# -> 0.3.3

set ctx [tclmcairo::new 100 100]
$ctx circle 50 50 40 -fill {1 0.5 0}
$ctx save /tmp/test.png
$ctx destroy
puts "OK: [file size /tmp/test.png] bytes"
```

---

## Windows (MSYS2 / BAWT)

**Do not install into `C:\Program Files\`** — that requires admin rights.

### Build + Install (one step)

```bat
build-win.bat 86       # Tcl 8.6
build-win.bat 90       # Tcl 9.0
```

`build-win.bat` produces a ready-to-install package in `dist\tclmcairo0.3.3\`:

```
dist\tclmcairo0.3.3\
    pkgIndex.tcl
    tclmcairo.dll
    tclmcairo-0.3.3.tm
    canvas2cairo-0.1.tm
    shape_renderer-0.1.tm
    libcairo-2.dll        (MSYS2, copied automatically)
    libpixman-1-0.dll
    libfontconfig-1.dll
    libfreetype-6.dll
    libexpat-1.dll
    libharfbuzz-0.dll
    libglib-2.0-0.dll
    libgraphite2.dll
    libbrotlidec.dll
    libbrotlicommon.dll
    libintl-8.dll
    libiconv-2.dll
    libbz2-1.dll
    libpcre2-8-0.dll
    libpng16-16.dll
    zlib1.dll
    libgcc_s_seh-1.dll
    libstdc++-6.dll
    libwinpthread-1.dll
    LICENSE
    THIRD-PARTY-LICENSES.txt
```

Copy this directory to your Tcl lib folder:

```bat
REM Tcl 8.6 (C:\Tcl):
xcopy /e /i dist\tclmcairo0.3.3 C:\Tcl\lib\tclmcairo0.3.3

REM Tcl 9.0 (C:\Tcl903):
xcopy /e /i dist\tclmcairo0.3.3 C:\Tcl903\lib\tclmcairo0.3.3
```

`C:\Tcl\lib` is already in `auto_path` → `package require tclmcairo` works immediately.

### Test after build

```bat
test-win.bat 86    # Tcl 8.6
test-win.bat 90    # Tcl 9.0
```

---

### Windows DLL Dependencies

All required DLLs are automatically included in `dist\tclmcairo0.3.3\`
by `build-win.bat`. The DLLs are loaded automatically by `pkgIndex.tcl`
before `tclmcairo.dll` — no PATH modification, no admin rights needed.

**Requires:** MSYS2 with `mingw-w64-x86_64-cairo` installed.

License information for redistributed DLLs: see `THIRD-PARTY-LICENSES.txt`.

---

### Per-user install via TCLLIBPATH

Set `TCLLIBPATH` as a **user** environment variable (no admin needed):
Control Panel → System → Environment Variables → User variables:

```
TCLLIBPATH=C:/Users/greg/tcllib
```

Then install:
```bat
mkdir C:\Users\greg\tcllib\tclmcairo0.3.3
copy tclmcairo.dll           C:\Users\greg\tcllib\tclmcairo0.3.3\
copy pkgIndex.tcl            C:\Users\greg\tcllib\tclmcairo0.3.3\
copy tcl\tclmcairo-0.3.3.tm    C:\Users\greg\tcllib\tclmcairo0.3.3\
copy tcl\canvas2cairo-0.1.tm C:\Users\greg\tcllib\tclmcairo0.3.3\
```

`TCLLIBPATH` is automatically added to `auto_path` — no `lappend` needed.

### Find your lib directory (BAWT)

```tcl
puts [file dirname [info library]]
;# e.g. C:/Bawt/Bawt86/Windows/x64/Install/tcl8.6/lib
;# -> install into that lib directory
```

---

## Runtime Dependencies

Only runtime libraries are needed — no -dev packages:

```bash
# Linux (Debian/Ubuntu)
sudo apt install libcairo2 libjpeg8

# macOS
brew install cairo jpeg

# Windows
# Cairo and JPEG are either statically linked (BAWT)
# or shipped as separate DLLs alongside tclmcairo.dll (MSYS2)
```
