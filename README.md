# tclmcairo — Cairo 2D Graphics for Tcl

A lightweight Cairo binding for Tcl — no Tk required.
Runs in `tclsh`. Output: PNG, PDF, SVG, PS, EPS.

**Version:** 0.2  
**License:** BSD  
**Platform:** Linux, Windows (MSYS2 MINGW64, BAWT 3.2), macOS  
**Tcl:** 8.6 or 9.0  
**Tests:** 82/82 (Linux Tcl 8.6 + 9.0, Windows MINGW64 + BAWT)

---

## Features

**Drawing**
- Shapes: `rect` (rounded corners), `circle`, `ellipse`, `arc`, `line`, `poly`
- SVG paths: `M L H V C Q A Z` + relative variants
- Text with font parsing (`Sans Bold Italic 14`), anchor, color, alpha
- Text as path (`text_path`, `-outline`): gradient fill, fill+stroke on text
- Font metrics: exact Cairo measurements (`font_measure`)
- Transforms: translate / scale / rotate / reset
- Gradients: linear + radial with color stops, `-fillname`
- Line options: `-dash`, `-linecap`, `-linejoin`, `-alpha`, `-fillrule`

**Output**
- Raster mode (ARGB32/RGB24/A8) + Vector mode (true vectors)
- Direct file-mode: `-mode pdf|svg|ps|eps -file filename`
- Multi-page PDF/PS/SVG: `newpage` / `finish`
- Output: `.png` `.pdf` `.svg` `.ps` `.eps`
- `topng` — PNG as bytearray (no file needed)
- `todata` — raw ARGB32 pixels for Tk photo integration

**Images**
- Load PNG + JPEG (`image filename x y`)
- Load PNG from bytes (`image_data bytes x y`)
- JPEG auto-embedded as MIME data in PDF/SVG (no re-encoding)
- PNG formats: `argb32` (default), `rgb24`, `a8` (mask)

**Compositing**
- `push` / `pop` — Cairo state stack
- `clip_rect`, `clip_path`, `clip_reset` — clip regions
- `blit src x y` — composite context onto context (layer model)

**Quality**
- Strict error handling: unknown options, invalid values all raise errors
- `Tcl_CallWhenDeleted` — safe interpreter shutdown, no memory leaks
- Cairo status checked after surface/context creation

---

## Dependencies

```bash
# Linux (Debian/Ubuntu)
sudo apt install libcairo2-dev libjpeg-dev tcl8.6-dev build-essential autoconf

# macOS
brew install cairo jpeg tcl-tk autoconf

# Windows (MSYS2 MINGW64)
pacman -S mingw-w64-x86_64-tcl mingw-w64-x86_64-cairo \
          mingw-w64-x86_64-libjpeg-turbo mingw-w64-x86_64-gcc
```

JPEG support is optional (`make JPEG=0` to disable).

---

## Build

### Linux / macOS

#### Option A: TEA (recommended)

```bash
autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make
make test
make demo
```

#### Option B: Simple Makefile (no autoconf)

```bash
make -f Makefile
make test
```

### Windows (MSYS2 or BAWT)

```bat
build-win.bat 86         # Tcl 8.6, JPEG auto-detected
build-win.bat 86 nojpeg  # without JPEG
test-win.bat 86
```

Or with GNU make in MSYS2:

```bash
make -f Makefile.win
make -f Makefile.win test
```

---

## Quick Start

```tcl
package require tclmcairo

# Create context
set ctx [tclmcairo::new 400 300]
$ctx clear 0.1 0.1 0.2

# Draw
$ctx gradient_linear bg 0 0 400 0 {{0 0.2 0.5 0.9 1} {1 0.1 0.3 0.6 1}}
$ctx rect 0 0 400 300 -fillname bg
$ctx circle 200 150 80 -fill {1 0.7 0.2 0.9} -stroke {1 1 1} -width 2

# Text as path with gradient
$ctx gradient_linear tg 0 0 400 0 {{0 1 0.9 0.2 1} {1 0.2 0.6 1 1}}
$ctx text 200 150 "tclmcairo" -font "Sans Bold 36" \
    -fillname tg -outline 1 -anchor center

# Output
$ctx save "output.png"
$ctx save "output.pdf"
set pngbytes [$ctx topng]   ;# PNG bytes without file
$ctx destroy
```

### Multi-page PDF

```tcl
set ctx [tclmcairo::new 595 842 -mode pdf -file "report.pdf"]
$ctx clear 1 1 1
$ctx text 297 100 "Page 1" -font "Sans Bold 24" -color {0 0 0} -anchor center
$ctx newpage
$ctx clear 1 1 1
$ctx text 297 100 "Page 2" -font "Sans Bold 24" -color {0 0 0.8} -anchor center
$ctx finish
$ctx destroy
```

### Layer compositing

```tcl
set bg  [tclmcairo::new 600 400]
set fg  [tclmcairo::new 600 400]   ;# transparent
# ... draw on each layer ...
$bg blit $fg 0 0
$bg blit $overlay 20 300 -alpha 0.8
$bg save "composite.png"
```

---

## Demos

```bash
make demo       # Linux
make demo TCLSH=tclsh9.0
```

Generates 12 demo files in `demos/`:

| Demo | Content |
|------|---------|
| 1 | Shapes (rect, circle, ellipse, lines) |
| 2 | SVG paths + fillrule evenodd |
| 3 | Gradients (linear + radial) |
| 4 | Text + font metrics + anchors |
| 5 | PDF vector output (A4) |
| 6 | Multi-page PDF (3 pages) |
| 7 | Clip regions (clip_rect, clip_path, push/pop) |
| 8 | text_path (gradient, outline, shadow, clipped) |
| 9 | PNG transparency (transparent BG, alpha, fade) |
| 10 | Blit / layer compositing |
| 11 | PNG formats (argb32, rgb24, a8), topng, image_data |
| 12 | MIME data embedding (JPEG 1:1 in PDF, 25% smaller) |

---

## API Reference

See `docs/api-reference.md` for the full API.

---

## Thread Safety

**Not thread-safe.** Use one tclmcairo interpreter per thread,
or add external locking. This matches Tk's threading model.

---

## License

BSD 2-Clause — see `LICENSE`.
