# tkmcairo — Cairo 2D Graphics for Tcl

A lightweight Cairo binding for Tcl — no Tk required.
Runs in `tclsh`. Output: PNG, PDF, SVG, PS, EPS.

**Version:** 0.1  
**License:** BSD  
**Platform:** Linux, Windows (MSYS2 MINGW64, BAWT 3.2), macOS  
**Tcl:** 8.6 or 9.0  
**Tests:** 41/41 (Linux Tcl 8.6 + 9.0, Windows MINGW64 + BAWT)

---

## Features

- Shapes: `rect` (rounded corners), `circle`, `ellipse`, `arc`, `line`, `poly`
- SVG paths: `M L H V C Q Z` fully supported; `A` with basic ellipse approximation
- Text with font parsing (`Sans Bold Italic 14`), anchor, color, alpha
- Font metrics: exact Cairo measurements (`font_measure`)
- Transforms: translate / scale / rotate / reset
- Gradients: linear + radial with color stops, `-fillname`
- Line options: `-dash`, `-linecap`, `-linejoin`, `-alpha`
- Output: `.png` `.pdf` `.svg` `.ps` `.eps`
- Raster mode (ARGB32, transparent background) + Vector mode (true vectors in PDF/SVG)
- Strict error handling: unknown options, invalid colors and values all raise errors

---

## Dependencies

```bash
# Linux (Debian/Ubuntu)
sudo apt install libcairo2-dev tcl8.6-dev build-essential autoconf

# macOS
brew install cairo tcl-tk autoconf

# Windows (MSYS2 MINGW64)
pacman -S mingw-w64-x86_64-tcl mingw-w64-x86_64-cairo mingw-w64-x86_64-gcc
```

---

## Build

### Linux / macOS

#### Option A: Simple Makefile (no autoconf needed)

```bash
make check-deps
make
make test
make demo
```

#### Option B: TEA (autoconf)

```bash
autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make && make test && make demo
make install   # optional
```

**Tcl 9.0:**
```bash
./configure --with-tcl=/usr/lib/tcl9.0
make && make test TCLSH=tclsh9.0
```

### Windows (MSYS2 MINGW64)

```bash
make -f Makefile.win TARGET=mingw64
make -f Makefile.win TARGET=mingw64 test
make -f Makefile.win TARGET=mingw64 demo
```

### Windows (BAWT 3.2)

```cmd
check-bawt.bat       # verify BAWT + Cairo paths
build-win.bat        # build with BAWT Tcl 8.6
test-win.bat         # test with BAWT tclsh
```

**Note:** tkmcairo is not integrated into BAWT. The build uses BAWT's
Tcl/gcc toolchain but takes Cairo from MSYS2 MINGW64 (`C:\msys64\mingw64`).
MSYS2 must be installed separately: https://www.msys2.org/

```bash
# In MSYS2 MINGW64 shell — install Cairo once:
pacman -S mingw-w64-x86_64-cairo
```

`test-win.bat` adds `C:\msys64\mingw64\bin` to PATH automatically for `cairo.dll`.

---

## Quick Start

```tcl
package require tkmcairo

set ctx [tkmcairo::new 400 300]              ;# raster mode
set ctx [tkmcairo::new 400 300 -mode vector] ;# vector mode (PDF/SVG)

$ctx clear 0.08 0.10 0.18

$ctx rect    10  10 200 100 -fill {1 0.5 0} -stroke {1 1 1} -radius 8
$ctx circle 300 150  60     -fill {0.2 0.5 1 0.8}
$ctx ellipse 100 200  80 30 -stroke {1 1 0} -width 2
$ctx line      0   0 400 300 -color {0.5 0.5 0.5} -dash {8 4}

$ctx path "M 50 50 L 150 50 L 100 130 Z" -fill {0.8 0.2 0.4}

$ctx text 200 150 "Hello World" -font "Sans Bold 18" -color {1 1 1} -anchor center

$ctx gradient_linear bg 0 0 400 0 {{0 0.1 0.1 0.3 1} {1 0.2 0.1 0.4 1}}
$ctx rect 0 0 400 300 -fillname bg

$ctx save "output.png"   ;# PNG
$ctx save "output.pdf"   ;# PDF (vector if -mode vector)
$ctx save "output.svg"   ;# SVG
$ctx save "output.ps"    ;# PostScript
$ctx save "output.eps"   ;# Encapsulated PostScript

$ctx destroy
```

---

## Output Formats

| Format | Vector mode | Raster mode | Notes |
|--------|-------------|-------------|-------|
| `.png` | rasterized | ARGB32 | transparent background possible |
| `.pdf` | true vectors | bitmap embedded | scalable |
| `.svg` | true vectors | bitmap embedded | |
| `.ps`  | true vectors | bitmap embedded | for printing |
| `.eps` | true vectors | bitmap embedded | for LaTeX etc. |

Use `-mode vector` for PDF/SVG/PS/EPS to get true vector output.

---

## Directory Structure

```
tkmcairo/
├── configure.in          TEA build definition
├── Makefile.in           TEA Makefile template
├── Makefile              Simple fallback (no autoconf)
├── Makefile.win          Windows build (MSYS2 + BAWT)
├── build-win.bat         Windows BAWT build
├── test-win.bat          Windows BAWT test
├── check-bawt.bat        Check BAWT installation
├── pkgIndex.tcl.in       Package index template
├── aclocal.m4            Links tclconfig/tcl.m4
├── tclconfig/            TEA scripts (git submodule)
├── src/
│   └── libtkmcairo.c     C extension (~1050 lines)
├── tcl/
│   └── tkmcairo-0.1.tm   TclOO wrapper (~170 lines)
├── tests/
│   └── test-tkmcairo.tcl 41 tests
├── demos/
│   └── demo-tkmcairo.tcl 5 demos x 5 formats (PNG/PDF/SVG/PS/EPS)
└── docs/
    └── api-reference.md  Full API documentation
```

---

## API Summary

```tcl
tkmcairo::new width height ?-mode raster|vector?  -> ctx
$ctx destroy
$ctx size    -> {width height}
$ctx save    filename
$ctx todata  -> bytearray ARGB32
$ctx clear   r g b ?a?

$ctx rect    x y w h    ?opts?
$ctx line    x1 y1 x2 y2 ?opts?
$ctx circle  cx cy r    ?opts?
$ctx ellipse cx cy rx ry ?opts?
$ctx arc     cx cy r start_deg end_deg ?opts?
$ctx poly    x1 y1 x2 y2 x3 y3 ... ?opts?
$ctx path    svgdata ?opts?
$ctx text    x y string ?opts?

$ctx font_measure string font  -> {width height ascent descent}

$ctx transform -translate x y
$ctx transform -scale sx sy
$ctx transform -rotate deg
$ctx transform -reset

$ctx gradient_linear name x1 y1 x2 y2 {{offset r g b a} ...}
$ctx gradient_radial  name cx cy r    {{offset r g b a} ...}
```

---

## Notes

- **Text:** Cairo Toy API — Latin scripts only. 
- **Windows:** Tcl 8.6 only (Tcl 9 not packaged in MSYS2 MINGW64/UCRT64).
- **poly:** minimum 3 coordinate pairs (6 values).
- **-alpha:** validated 0.0–1.0; -linecap/-linejoin: validated against allowed values.

---

## Relation to Other Projects

```
tkmcairo          Cairo for tclsh, no Tk required
    |
    +-- tkpath    Tk-Canvas SVG extension (separate, Cairo on Linux)
    |             https://wiki.tcl-lang.org/page/tkpath
    |             https://github.com/tcltk-depot/tkpath
    +-- pdf4tcl   PDF document library (forms, encryption, multi-page)
```

tkmcairo and tkpath are complementary: tkpath for interactive Tk-Canvas,
tkmcairo for headless file output.

---

## License

BSD 2-Clause. See LICENSE.
