# tclmcairo — Cairo 2D Graphics for Tcl

A lightweight Cairo binding for Tcl — no Tk required.
Runs in `tclsh`. Outputs PNG, PDF, SVG, PS, EPS.

**Version:** 0.3.4 · **License:** BSD · **Tcl:** 8.6 / 9.0  
**Platform:** Linux, Windows (MSYS2 MINGW64, BAWT 3.2), macOS  
**Tests:** 193/193 (Linux tclmcairo) · 67/67 (Linux canvas2cairo) · 193/193 (Windows)

---

## Packages

| Package | Requires | Description |
|---------|----------|-------------|
| `tclmcairo` | Tcl 8.6+ | Core Cairo binding — headless, no Tk needed |
| `canvas2cairo` | tclmcairo + Tk | Export Tk Canvas to SVG/PDF/PS/EPS |
| `shape_renderer` | tclmcairo | Network diagram shapes (router, server, ...) |
| `svg2cairo` | tclmcairo + tDOM | SVG renderer via tDOM (CSS, text, gradients) |

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

### SVG rendering

```tcl
# nanosvg (eingebettet, keine Abhängigkeiten)
package require tclmcairo
set ctx [tclmcairo::new 400 300]
$ctx svg_file "logo.svg" 0 0 -width 400 -height 300
$ctx save "output.png"
$ctx destroy

# lunasvg (optional, volle CSS + Text-Unterstützung)
$ctx svg_file_luna "diagram.svg" 0 0 -width 400 -height 300

# svg2cairo (tDOM-basiert, CSS <style>, <text>, <tspan>)
package require svg2cairo
svg2cairo::render $ctx "diagram.svg" -scale 2.0
```

### canvas2cairo — Export Tk Canvas

```tcl
package require canvas2cairo

canvas2cairo::export .c output.svg    ;# SVG vector
canvas2cairo::export .c output.pdf    ;# PDF vector
canvas2cairo::export .c output.ps     ;# PostScript
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
`text_path` / `-outline`, `font_measure`, `font_options`,
`select_font_face`, `text_extents` (9-key dict)

**Transforms:** `-translate`, `-scale`, `-rotate`, `-matrix`, `-get`, `-reset`

**Gradients:** linear + radial, `-fillname`, `gradient_extend`, `gradient_filter`

**Images:** PNG + JPEG load · `image_data` · `image_size` (w/h without drawing)
· JPEG MIME embedding in PDF/SVG

**SVG:** `svg_file`, `svg_data` (nanosvg, eingebettet) ·
`svg_file_luna`, `svg_data_luna`, `svg_size_luna` (lunasvg, optional)

**Output:** PNG, PDF, SVG, PS, EPS · `save -chan` · `topng` · `todata` (ARGB32)
· `surface_copy` · multi-page via `newpage`/`finish`

**Compositing:** `operator` (29 Porter-Duff + CSS blend modes),
`push`/`pop`, `clip_rect`, `clip_path`, `clip_reset`, `blit`

**Coordinates:** `user_to_device`, `device_to_user`, `recording_bbox`, `path_get`

### svg2cairo (Tcl module)

tDOM-based SVG renderer — handles CSS `<style>` (tag, .class, #id),
`<text>`, `<tspan>`, `<textPath>` fallback, 50 W3C color names,
DOCTYPE strip. Requires `package require tdom`.

```tcl
package require svg2cairo

svg2cairo::render $ctx "file.svg" ?-scale 2.0?
svg2cairo::render_data $ctx $svgstring
lassign [svg2cairo::size "file.svg"] w h
svg2cairo::has_text "file.svg"   ;# -> 1 if <text> elements present
```

### canvas2cairo (Tk addon)

Exports any Tk Canvas to all Cairo output formats.

**Supported items:** `rectangle`, `oval`, `line`, `polygon`, `text`, `arc`,
`image` (photo)

**Features:** `-dash`, `-dashoffset`, `-capstyle`, `-joinstyle`, `-smooth`,
`-arrow`, text `-angle`, `-state hidden` items skipped,
`export -scale` (HiDPI), `export -viewport` (region export)

---

## Build

### Linux — Standard

```bash
autoconf && ./configure --with-tcl=/usr/lib/tcl8.6
make && sudo make install
make test
```

### Linux — mit lunasvg

```bash
# lunasvg einmalig bauen:
cd ~/lunasvg && cmake -B build_shared -DBUILD_SHARED_LIBS=ON . && cmake --build build_shared

# tclmcairo mit lunasvg:
autoconf && ./configure --with-tcl=/usr/lib/tcl8.6
make clean && make && sudo make install
bash buildlt.sh
```

Reihenfolge beachten: `sudo make install` vor `buildlt.sh`.
Details: `INSTALL.md`, `nogit/lunasvg-build.md`.

### Windows (BAWT + MSYS2)

```bat
REM ohne lunasvg:
build-win.bat 86

REM mit lunasvg:
set LUNASVG_DIR=C:\msys64\home\greg\src\lunasvg
build-win.bat 86

xcopy /e /i /y dist\tclmcairo0.3.4 C:\Tcl\lib\tclmcairo0.3.4
test-win.bat 86
```

See `INSTALL.md` for full details.

---

## Demos

```bash
make demo   # -> demos/*.png, demos/*.pdf, demos/*.svg
wish demos/demo-coordinates.tcl   # interactive
wish demos/demo-canvas2cairo.tcl
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
| 20 | text_extents + select_font_face |
| 21 | svg_file + svg_data (nanosvg) |

**`demos/nodeeditor.tcl`** — full node editor application:
drag-and-drop nodes, port connections, undo/redo, save/load, export.

---

## Documentation

| File | Content |
|------|---------|
| `docs/api-reference.md` | Complete API reference |
| `docs/manual.md` | Manual with examples |
| `docs/canvas2cairo.md` | canvas2cairo reference |
| `examples/SAMPLES.md` | Cairo samples with images + code |
| `INSTALL.md` | Installation (Linux + Windows + lunasvg) |
| `CHANGELOG.md` | Version history |
| `nogit/lunasvg-build.md` | lunasvg build instructions |

---

## Thread Safety

**Not thread-safe.** Use one interpreter per thread. Matches Tk's model.

---

## License

tclmcairo itself: **BSD 2-Clause** — see `LICENSE`.

- **Cairo** — LGPL 2.1 or MPL 1.1 (dynamically linked)
- **libjpeg** — IJG License (permissive, optional)
- **nanosvg** — zlib/libpng License (embedded)
- **lunasvg** — MIT (optional, separate build)
