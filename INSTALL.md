# tclmcairo — Installation

## Directory Layout

All files install into a single directory — no split layout:

```
<prefix>/lib/tcltk/tclmcairo0.3/
    pkgIndex.tcl
    libtclmcairo.so      (Linux)
    libtclmcairo.dylib   (macOS)
    tclmcairo.dll        (Windows)
    tclmcairo-0.3.tm
    canvas2cairo-0.1.tm
```

After installation, `package require tclmcairo` and `package require canvas2cairo`
work without any `lappend auto_path` because `<prefix>/lib/tcltk` is already
in Tcl's `auto_path` on Debian/Ubuntu.

---

## Quick Install (no configure required)

After building with `make`, copy all files manually:

```bash
mkdir -p ~/lib/tclmcairo0.3
cp libtclmcairo.so         ~/lib/tclmcairo0.3/
cp pkgIndex.tcl            ~/lib/tclmcairo0.3/
cp tcl/tclmcairo-0.3.tm    ~/lib/tclmcairo0.3/
cp tcl/canvas2cairo-0.1.tm ~/lib/tclmcairo0.3/
```

Then in any script or in `~/.tclshrc`:
```tcl
lappend auto_path ~/lib/tclmcairo0.3
package require tclmcairo
package require canvas2cairo   ;# optional Tk Canvas export addon
```

---

## System-wide Install (make install)

```bash
autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make
sudo make install
```

Installs to `/usr/lib/tcltk/tclmcairo0.3/` — already in `auto_path`.

```bash
# Custom prefix:
./configure --prefix=/usr/local --with-tcl=/usr/lib/tcl8.6
sudo make install
# -> /usr/local/lib/tcltk/tclmcairo0.3/
```

---

## Verify

```tcl
package require tclmcairo
puts [package present tclmcairo]   ;# -> 0.3

set ctx [tclmcairo::new 100 100]
$ctx circle 50 50 40 -fill {1 0.5 0}
$ctx save /tmp/test.png
$ctx destroy
puts "OK: [file size /tmp/test.png] bytes"
```

---

## Windows (MSYS2 / BAWT)

**Do not install into `C:\Program Files\`** — that requires admin rights.
Install next to your Tcl distribution instead.

### Next to Tcl (recommended)

#### Tcl 8.6 (e.g. C:\Tcl)

```bat
build-win.bat 86

mkdir C:\Tcl\lib\tclmcairo0.3
copy tclmcairo.dll         C:\Tcl\lib\tclmcairo0.3\
copy pkgIndex.tcl          C:\Tcl\lib\tclmcairo0.3\
copy tcl\tclmcairo-0.3.tm  C:\Tcl\lib\tclmcairo0.3\
copy tcl\canvas2cairo-0.1.tm C:\Tcl\lib\tclmcairo0.3\
```

`C:\Tcl\lib` is already in `auto_path` → `package require tclmcairo` works immediately.

#### Tcl 9.0 (e.g. C:\Tcl903)

```bat
build-win.bat 90

mkdir C:\Tcl903\lib\tclmcairo0.3
copy tclmcairo.dll           C:\Tcl903\lib\tclmcairo0.3\
copy pkgIndex.tcl            C:\Tcl903\lib\tclmcairo0.3\
copy tcl\tclmcairo-0.3.tm    C:\Tcl903\lib\tclmcairo0.3\
copy tcl\canvas2cairo-0.1.tm C:\Tcl903\lib\tclmcairo0.3\
```

### Per-user install via TCLLIBPATH

Set `TCLLIBPATH` as a **user** environment variable (no admin needed):
Control Panel → System → Environment Variables → User variables:

```
TCLLIBPATH=C:/Users/greg/tcllib
```

Then install:
```bat
mkdir C:\Users\greg\tcllib\tclmcairo0.3
copy tclmcairo.dll           C:\Users\greg\tcllib\tclmcairo0.3\
copy pkgIndex.tcl            C:\Users\greg\tcllib\tclmcairo0.3\
copy tcl\tclmcairo-0.3.tm    C:\Users\greg\tcllib\tclmcairo0.3\
copy tcl\canvas2cairo-0.1.tm C:\Users\greg\tcllib\tclmcairo0.3\
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
