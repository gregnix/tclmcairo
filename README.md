# tclmcairo — Cairo 2D Graphics for Tcl

A lightweight Cairo binding for Tcl — no Tk required.
Runs in `tclsh`. Outputs PNG, PDF, SVG, PS, EPS.

**Version:** 0.3.3 · **License:** BSD · **Tcl:** 8.6 / 9.0  
**Platform:** Linux, Windows (MSYS2 MINGW64, BAWT 3.2), macOS  
**Tests:** 187/187 (Linux tclmcairo) · 67/67 (Linux canvas2cairo) · 170/170 (Windows)

---

## Packages

| Package | Requires | Description |
|---------|----------|-------------|
| `tclmcairo` | Tcl 8.6+ | Core Cairo binding — headless, no Tk needed |
| `canvas2cairo` | tclmcairo + Tk | Export Tk Canvas to SVG/PDF/PS/EPS |

---

## Quick Start

```tcl
package require tclmcairo

set ctx [tclmcairo::new 400 300]
$ctx clear 0.05 0.05 0.1

$ctx gradient_linear bg 0 0 400 0 {{0 0.2 0.5 0.9 1} {1 0.1 0.3 0.6 1}}
$ctx rect 0 0 400 300 -fillname bg
$ctx circle 200 150 80 -fill {1 0.7 0.2 0.9} -stroke {1 1 1} -width 2

$ctx gradient_linear tg 0 0 400 0 {{0 1 0.9 0.2 1} {1 0.2 0.6 1 1}}
$ctx text 200 150 "tclmcairo" -font {Sans Bold 36} \
    -fillname tg -outline 1 -anchor center

$ctx save "output.png"
$ctx save "output.pdf"   ;# same drawing, true vectors
$ctx destroy
```

### canvas2cairo — Export Tk Canvas

```tcl
package require canvas2cairo

# Export any Tk canvas — format by file extension
canvas2cairo::export .c output.svg    ;# SVG vector
canvas2cairo::export .c output.pdf    ;# PDF vector
canvas2cairo::export .c output.ps     ;# PostScript

# Or render into an existing tclmcairo context
set ctx [tclmcairo::new 595 842 -mode pdf -file "report.pdf"]
$ctx text 297 30 "Report Title" -font {Sans 18 bold} \
    -color {0 0 0} -anchor center
canvas2cairo::render .mycanvas $ctx
$ctx finish; $ctx destroy
```

---

## Features

### tclmcairo (core)

**Shapes:** `rect` (rounded corners), `circle`, `ellipse`, `arc`,
`arc_negative`, `line`, `poly`, `path` (SVG syntax)

**Low-level path API:** `move_to`, `line_to`, `rel_move_to`, `rel_line_to`,
`curve_to`, `rel_curve_to`, `close_path`, `new_path`, `new_sub_path`,
`stroke`, `fill`, `fill_preserve`, `stroke_preserve`

**Style setters:** `set_line_width`, `set_line_cap`, `set_line_join`,
`set_fill_rule`, `set_source_rgb`, `set_source_rgba`

**Text:** font parsing (`{Sans Bold Italic 14}`), anchors, color, alpha,
`text_path` / `-outline` for gradient fill + stroke, `font_measure`,
`font_options` (antialias, hint_style, hint_metrics)

**Transforms:** `-translate`, `-scale`, `-rotate`, `-matrix`, `-get`, `-reset`

**Gradients:** linear + radial, `-fillname`, `gradient_extend`, `gradient_filter`

**Source/Paint:** `set_source -color/-gradient`, `paint ?alpha?`

**Compositing:** `operator` — 29 Porter-Duff + CSS blend modes,
`push`/`pop`, `clip_rect`, `clip_path`, `clip_reset`, `blit`

**Coordinates:** `user_to_device`, `device_to_user`, `recording_bbox`, `path_get`

**Output:** PNG, PDF, SVG, PS, EPS · `topng` (bytes) · `todata` (ARGB32 for Tk photo)
· `surface_copy` · multi-page via `newpage`/`finish`

**Images:** PNG + JPEG load · `image_data` (from bytes) · JPEG MIME embedding in PDF/SVG

### canvas2cairo (Tk addon)

Exports any Tk Canvas to all Cairo output formats — all vector, no rasterization.

**Supported items:** `rectangle`, `oval`, `line`, `polygon`, `text`, `arc`
(pieslice / chord / arc), `image` (photo embedded as pixel data)

**Features:** `-dash`, `-dashoffset`, `-capstyle`, `-joinstyle`, `-smooth`,
`-arrow`, text `-angle` rotation, `-state hidden` items skipped,
works without visible window (uses `[$canvas cget -width/height]`)

---

## Build

### Linux / macOS

```bash
autoconf && ./configure --with-tcl=/usr/lib/tcl8.6
make && make test
make demo      # generate demo PNGs
make samples   # generate examples/SAMPLES.md
```

For a custom Tcl installation (e.g. self-compiled):

```bash
autoconf && ./configure --with-tcl=/path/to/tcl/lib
make && make test
```

Note: `TEA_PRIVATE_TCL_HEADERS` has been removed — only the installed
headers are needed. No Tcl source tree required.

### Windows

```bash
# MSYS2
make -f Makefile.win TARGET=mingw64
make -f Makefile.win TARGET=mingw64 test
```

```bat
rem BAWT (CMD)
build-win.bat 86
```

See `INSTALL.md` for installation instructions.

After `make install` all files land in one directory:
```
/usr/lib/tcltk/tclmcairo0.3.3/   libtclmcairo.so  pkgIndex.tcl
                                tclmcairo-0.3.3.tm  canvas2cairo-0.1.tm
```

---

## Demos

```bash
make demo   # -> demos/*.png
wish demos/demo-coordinates.tcl   # interactive coordinates explorer
wish demos/demo-canvas2cairo.tcl  # canvas2cairo showcase
```

| # | Content |
|---|---------|
| 1 | Shapes: rect, circle, ellipse, lines, dash |
| 2 | SVG paths + fillrule |
| 3 | Gradients: linear + radial |
| 4 | Text + font metrics + anchors |
| 5 | PDF vector output (A4) |
| 6 | Multi-page PDF |
| 7 | Clip regions |
| 8 | text_path: gradient fill, outline, shadow |
| 9 | PNG transparency |
| 10 | Blit / layer compositing |
| 11 | PNG formats, topng, image_data |
| 12 | JPEG MIME embedding in PDF/SVG |
| 13 | Plotchart-style chart |
| 14 | Transform -matrix / -get |
| 15 | Compositing operators |
| 16 | user_to_device, arc_negative, -dash_offset |
| 17 | gradient_extend, gradient_filter, paint, set_source |
| 18 | font_options, path_get, surface_copy |
| 19 | save -chan: PNG/PDF/SVG to open channel |

**`demos/nodeeditor.tcl`** — full node editor application:
- Drag-and-drop nodes, port-to-port connections
- Orthogonal (Manhattan) routing
- Undo/Redo, Save/Load (.dia)
- Export full diagram or region → SVG, PDF, PS, EPS, PNG

---

## Examples

`examples/` — 15 ports of the official [Cairo C samples](https://cairographics.org/samples/)
(public domain, Øyvind Kolås). See `examples/SAMPLES.md` for images + code.

```bash
cd examples && TCLMCAIRO_LIBDIR=.. tclsh8.6 run_all.tcl
```

---

## Documentation

| File | Content |
|------|---------|
| `docs/api-reference.md` | Complete API reference |
| `docs/manual.md` | Manual with examples |
| `docs/canvas2cairo.md` | canvas2cairo reference |
| `examples/SAMPLES.md` | Cairo samples with images + code |
| `INSTALL.md` | Installation instructions |
| `CHANGELOG.md` | Version history |

---

## Thread Safety

**Not thread-safe.** Use one interpreter per thread. Matches Tk's model.

---

## License

tclmcairo itself: **BSD 2-Clause** — see `LICENSE`.

Dependencies:
- **Cairo** — LGPL 2.1 or MPL 1.1 (dynamically linked — no license infection)
- **libjpeg** — IJG License (permissive, optional)

Distributing tclmcairo binaries requires libcairo to be available as a shared
library (`.so` / `.dll`) — this satisfies the LGPL requirement.
