# tclmcairo — Cairo 2D Graphics for Tcl

A lightweight Cairo binding for Tcl — no Tk required.
Runs in `tclsh`. Output: PNG, PDF, SVG, PS, EPS.

**Version:** 0.3  
**License:** BSD  
**Platform:** Linux, Windows (MSYS2 MINGW64, BAWT 3.2), macOS  
**Tcl:** 8.6 or 9.0  
**Tests:** 170/170 (Linux Tcl 8.6 + 9.0, Windows MINGW64 + BAWT)

---

## Features

**Drawing**
- Shapes: `rect` (rounded corners), `circle`, `ellipse`, `arc`, `arc_negative`, `line`, `poly`
- SVG paths: `M L H V C Q A Z` + relative variants
- Low-level path API: `move_to`, `line_to`, `rel_move_to`, `rel_line_to`, `curve_to`, `rel_curve_to`, `close_path`, `new_path`, `new_sub_path`
- Draw ops: `stroke`, `fill`, `fill_preserve`, `stroke_preserve`
- Style setters: `set_line_width`, `set_line_cap`, `set_line_join`, `set_fill_rule`, `set_source_rgb/rgba`
- Text with font parsing (`Sans Bold Italic 14`), anchor, color, alpha
- Text as path (`text_path`, `-outline`): gradient fill, fill+stroke on text
- Font metrics: `font_measure`, `font_options` (antialias, hint_style, hint_metrics)
- Transforms: translate / scale / rotate / matrix / get / reset
- Gradients: linear + radial, `-fillname`, `gradient_extend`, `gradient_filter`
- Source control: `set_source -color/-gradient`, `paint ?alpha?`
- Line options: `-dash`, `-dash_offset`, `-linecap`, `-linejoin`, `-alpha`, `-fillrule`
- Compositing operators: `operator` — 29 Porter-Duff + blend modes

**Coordinates**
- `user_to_device x y` — map user coords to device coords (essential for mouse interaction under transforms)
- `device_to_user dx dy` — reverse mapping
- `recording_bbox` — ink bounding box of vector context
- `path_get` — read current Cairo path as SVG string

**Output**
- Raster mode (ARGB32/RGB24/A8) + Vector mode (true vectors)
- Direct file-mode: `-mode pdf|svg|ps|eps -file filename`
- Multi-page PDF/PS/SVG: `newpage` / `finish`
- Output: `.png` `.pdf` `.svg` `.ps` `.eps`
- `topng` — PNG as bytearray (no file needed)
- `todata` — raw ARGB32 pixels for Tk photo integration
- `surface_copy ?w h?` — new blank context same type/size

**Images**
- Load PNG + JPEG (`image filename x y`)
- Load PNG from bytes (`image_data bytes x y`)
- JPEG auto-embedded as MIME data in PDF/SVG (no re-encoding)
- PNG formats: `argb32` (default), `rgb24`, `a8` (mask)

**Compositing**
- `push` / `pop` — Cairo state stack
- `clip_rect`, `clip_path`, `clip_reset` — clip regions
- `blit src x y` — composite context onto context (layer model)
- `operator` — 29 Porter-Duff + blend mode operators

**Quality**
- Strict error handling: unknown options, invalid values all raise errors
- `Tcl_CallWhenDeleted` — safe interpreter shutdown, no memory leaks

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

```bash
# TEA (recommended)
autoconf && ./configure --with-tcl=/usr/lib/tcl8.6
make && make test && make demo

# Simple (no autoconf)
make && make test
```

### Windows

```bat
:: MSYS2 bash
make -f Makefile.win TARGET=mingw64
make -f Makefile.win TARGET=mingw64 test

:: BAWT (CMD)
build-win.bat 86
test-win.bat         :: must run in CMD, not bash
```

---

## Quick Start

```tcl
package require tclmcairo

set ctx [tclmcairo::new 400 300]
$ctx clear 0.1 0.1 0.2

$ctx gradient_linear bg 0 0 400 0 {{0 0.2 0.5 0.9 1} {1 0.1 0.3 0.6 1}}
$ctx rect 0 0 400 300 -fillname bg
$ctx circle 200 150 80 -fill {1 0.7 0.2 0.9} -stroke {1 1 1} -width 2

$ctx gradient_linear tg 0 0 400 0 {{0 1 0.9 0.2 1} {1 0.2 0.6 1 1}}
$ctx text 200 150 "tclmcairo" -font "Sans Bold 36" \
    -fillname tg -outline 1 -anchor center

$ctx save "output.png"
$ctx save "output.pdf"
$ctx destroy
```

---

## Demos

18 demo files generated in `demos/`:

| # | Content |
|---|---------|
| 1 | Shapes (rect, circle, ellipse, lines, dash) |
| 2 | SVG paths + fillrule evenodd |
| 3 | Gradients (linear + radial) |
| 4 | Text + font metrics + anchors |
| 5 | PDF vector output (A4) |
| 6 | Multi-page PDF (3 pages) |
| 7 | Clip regions (clip_rect, clip_path, push/pop) |
| 8 | text_path (gradient, outline, shadow, clipped) |
| 9 | PNG transparency |
| 10 | Blit / layer compositing |
| 11 | PNG formats, topng, image_data |
| 12 | MIME data embedding (JPEG in PDF/SVG) |
| 13 | Plotchart-style chart (clip_rect + push/pop) |
| 14 | Transform -matrix / -get |
| 15 | Compositing operators (16 blend modes) |
| 16 | user_to_device, arc_negative, -dash_offset |
| 17 | gradient_extend, gradient_filter, paint, set_source |
| 18 | font_options, path_get, surface_copy |

---

## Examples

`examples/` contains ports of the official Cairo C samples from
https://cairographics.org/samples/ (public domain, Øyvind Kolås):

`arc` · `arc_negative` · `clip` · `curve_to` · `dash` · `fill_and_stroke` ·
`fill_style` · `gradient` · `multi_segment_caps` · `rounded_rectangle` ·
`set_line_cap` · `set_line_join` · `text` · `text_align_center` · `text_extents`

```bash
cd examples
TCLMCAIRO_LIBDIR=.. tclsh8.6 arc.tcl   # -> arc.png
```

---

## API Reference

See `docs/api-reference.md` for the complete API documentation.

---

## Thread Safety

**Not thread-safe.** Use one interpreter per thread. Matches Tk's model.

---

## License

BSD 2-Clause — see `LICENSE`.
