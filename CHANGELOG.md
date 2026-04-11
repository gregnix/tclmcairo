# tclmcairo Changelog

## v0.3.2 (2026-04-11)

### New Features

**`save -chan channel`** — write output to an open Tcl channel:

```tcl
# PDF to channel (Memchan, socket, pipe)
set ch [open output.pdf wb]
$ctx save -chan $ch -format pdf
close $ch

# PNG to channel
set ch [open image.png wb]
$ctx save -chan $ch -format png
close $ch
```

Supported formats: `pdf` `svg` `ps` `eps` `png`. Works with raster and vector contexts.

### Bug Fixes

**`cairo_new_path()` before every shape command** — critical fix:

Cairo's path API accumulates points. Without `cairo_new_path()`, a new shape
inherits the previous current point and Cairo draws an implicit connecting line.
This caused stray lines in PDF/SVG exports (e.g. port-dot connected to distant
text position).

Fixed in all 7 shape commands in `src/libtclmcairo.c`:
`rect`, `line`, `circle`, `ellipse`, `arc`, `arc_negative`, `poly`

### canvas2cairo-0.1.tm (19 changes vs 0.3.1)

| Change | Description |
|--------|-------------|
| `-smooth 1` → Catmull-Rom | Curve passes through all points (cubic, tension 0.5) |
| `render -clip {x1 y1 x2 y2}` | Restrict rendering to canvas region |
| `text_extents` for justify | Cairo `font_measure` for center/right alignment |
| `-smooth raw` | Correct cubic Bézier (`C` commands) |
| `-underline` | Underline under specified character |
| `-arrowshape` | Custom arrow size respected |
| `-justify` | Multi-line text left/center/right |
| `hidden item bug` | `return` → `continue` (one hidden item broke export) |
| `-dashoffset` | Tested and verified |
| `export -scale` | HiDPI export (e.g. `-scale 2.0`) |
| `export -viewport` | Region export `{x1 y1 x2 y2}` |
| scroll position | `canvasx(0)/canvasy(0)` — scrolled canvas correct |
| negative scrollregion | `{-500 -500 1000 1000}` — origin offset correct |
| `-background` | Canvas background always exported |
| `polygon -fill ""` | Empty fill → outline only, no fill |
| `_apply_render` | Extracted from `export` (namespace bug fixed) |
| `clip_bbox bug` | Items outside widget size were wrongly skipped |
| exportFile fix | Full-diagram export: direct `tclmcairo::new + render` |

### shape_renderer-0.1.tm

7 new shapes: `printer` `scanner` `accesspoint` `phone` `wifi` `fiber` `building`  
Total: 15 shapes

### Tests

181/181 tclmcairo ✔  42/42 canvas2cairo ✔

---

## v0.3.1 (2026-04-10)

### canvas2cairo-0.1.tm (initial release)

- PNG export
- Image items (`$img write` instead of base64)
- Text wrapping (`_wrap_text` with `font measure`)
- Multi-line text (`cairo_show_text` single-line fix)
- `-smooth raw` (cubic Bézier)
- `-smooth 1` (B-spline)
- edgehit stipple lines suppressed before export

### shape_renderer-0.1.tm (initial release)

8 shapes: `router` `switch` `server` `firewall` `database` `workstation` `generic` `table`

### demos/nodeeditor.tcl (new)

Full node editor application with canvas2cairo export.

---

## v0.3 (2026-04-09)

### New Features

**Compositing operators** (29 Porter-Duff + CSS blend modes):
```tcl
$ctx operator OVER|MULTIPLY|SCREEN|OVERLAY|DARKEN|LIGHTEN|DIFFERENCE|XOR|...
```

**`-dash_offset`** — starting offset into dash pattern:
```tcl
$ctx line 0 0 400 0 -dash {10 5} -dash_offset 3
```

**`arc_negative`** — counter-clockwise arc:
```tcl
$ctx arc_negative cx cy r start_deg end_deg ?opts?
```

**`user_to_device`** / **`device_to_user`** — coordinate mapping under transforms:
```tcl
set d [$ctx user_to_device 10 20]   ;# -> {dx dy}
set u [$ctx device_to_user 60 70]   ;# -> {x y}
```

**`recording_bbox`** — ink bounding box of vector context:
```tcl
set bb [$ctx recording_bbox]   ;# -> {x y w h}
```

**`gradient_extend`** — gradient repeat/reflect/pad/none:
```tcl
$ctx gradient_extend name repeat|reflect|pad|none
```

**`gradient_filter`** — interpolation quality:
```tcl
$ctx gradient_filter name fast|good|best|nearest|bilinear
```

**`paint`** — fill entire surface with current source:
```tcl
$ctx set_source -color {r g b ?a?}   ;# or -gradient name
$ctx paint ?alpha?
```

**`set_source`** — set Cairo source without drawing:
```tcl
$ctx set_source -color {r g b ?a?}
$ctx set_source -gradient name
```

**`font_options`** — font rendering quality:
```tcl
$ctx font_options -antialias default|none|gray|subpixel|fast|good|best \
                  -hint_style default|none|slight|medium|full \
                  -hint_metrics default|on|off
set fo [$ctx font_options]   ;# -> {-antialias gray -hint_style full ...}
```

**`path_get`** — read current Cairo path as SVG string:
```tcl
set svg [$ctx path_get]   ;# -> "M 10 10 L 100 50" or ""
```

**`surface_copy`** — new blank context of same type/format:
```tcl
set cid [$ctx surface_copy]          ;# same size
set cid [$ctx surface_copy 200 150]  ;# custom size
tclmcairo circle $cid 100 75 60 -fill {1 0.5 0}
tclmcairo destroy $cid
```

**`transform -matrix`** / **`transform -get`**:
```tcl
$ctx transform -matrix xx yx xy yy x0 y0   ;# affine 2x3
set m [$ctx transform -get]                 ;# -> {xx yx xy yy x0 y0}
```

**Low-level path API** (for porting Cairo C examples):
```tcl
$ctx move_to x y         $ctx rel_move_to dx dy
$ctx line_to x y         $ctx rel_line_to dx dy
$ctx curve_to x1 y1 x2 y2 x3 y3
$ctx rel_curve_to dx1 dy1 dx2 dy2 dx3 dy3
$ctx close_path          $ctx new_path     $ctx new_sub_path
$ctx stroke              $ctx fill
$ctx fill_preserve       $ctx stroke_preserve
$ctx set_line_width n    $ctx set_line_cap butt|round|square
$ctx set_line_join miter|round|bevel
$ctx set_fill_rule winding|evenodd
$ctx set_source_rgb r g b   $ctx set_source_rgba r g b a
```

### Examples

`examples/` directory added with 15 ports of the official Cairo C samples
from https://cairographics.org/samples/ (public domain, Øyvind Kolås):
`arc`, `arc_negative`, `clip`, `curve_to`, `dash`, `fill_and_stroke`,
`fill_style`, `gradient`, `multi_segment_caps`, `rounded_rectangle`,
`set_line_cap`, `set_line_join`, `text`, `text_align_center`, `text_extents`.

### Demos

4 new demos (14–18):
- Demo 14: Transform -matrix / -get
- Demo 15: Compositing operators (16 blend modes)
- Demo 16: user_to_device, arc_negative, -dash_offset
- Demo 17: gradient_extend, filter, paint, set_source
- Demo 18: font_options, path_get, surface_copy

### Robustness / Bug Fixes

- **Version consistency**: `Tcl_PkgProvide` and `package provide` both say `0.3`
  (was `0.2` in C, `0.3` in Tcl — caused `package require` conflict)
- **pkgIndex.tcl.in**: fixed layout — `.tm` at `$dir/` not `$dir/tcl/`
- **`create` option validation**: unknown options and odd argument lists now
  raise `TCL_ERROR` (previously silently ignored)
- **SVG path parser**: `parse_num` now returns int; `PARSE_NUM` macro uses
  `goto path_parse_error` to abort on invalid numbers — no more potential
  infinite loops
- **Low-level commands**: `move_to`, `line_to`, `rel_move_to`, `rel_line_to`,
  `curve_to` etc. now validate `objc` before accessing `objv`
- **Error messages**: migrated from `Tcl_AppendResult` (deprecated in Tcl 9)
  to `Tcl_SetObjResult(Tcl_ObjPrintf(...))` throughout


### canvas2cairo-0.1.tm (new)

Tk Canvas → Cairo export module. Included in `tcl/`.

```tcl
package require canvas2cairo
canvas2cairo::export .c output.svg   ;# SVG vector
canvas2cairo::export .c output.pdf   ;# PDF vector
canvas2cairo::export .c output.ps    ;# PostScript
canvas2cairo::render .c $ctx         ;# into existing context
```

Supported items: `rectangle`, `oval`, `line`, `polygon`, `text`,
`arc` (pieslice/chord/arc), `image` (photo).

Features: `-state hidden` skip, `-dash`/`-dashoffset`, `-capstyle`,
`-joinstyle`, `-smooth`, `-arrow`, text `-angle` rotation.

### demos/nodeeditor.tcl (new)

Full node editor application demonstrating canvas2cairo in a real use case:

- Drag-and-drop nodes with ports (left/right/top/bottom)
- Port-to-port connections via rubber-band drag
- Orthogonal (Manhattan) routing with U-bypass for backward edges
- Undo/Redo (Ctrl+Z/Y, 50-step history)
- Save/Load diagram (`.dia`, Tcl-native format)
- Export full diagram → SVG/PDF/PS/EPS
- Export region — rubber-band crop selection → any format incl. PNG
- Grid toggle, pan (middle mouse), zoom (scroll wheel)

### Build

- `PACKAGE_VERSION`: `0.3`
- `.tm`: `tclmcairo-0.3.tm`
- `configure.in`: `AC_INIT([tclmcairo], [0.3])`
- `Makefile.win`: `PACKAGE_VERSION = 0.3`
- `build-win.bat`: updated for 0.3

### Test Results

| Platform | Tcl | Tests |
|----------|-----|-------|
| Linux Debian x86_64 | 8.6.17 | 181/181 |
| Linux Debian x86_64 | 9.0.3  | 181/181 |
| Windows 11 MSYS2 MINGW64 | 8.6 | 170/170 |
| Windows 11 BAWT 3.2 | 8.6 | 170/170 |
| Windows 11 BAWT 3.2 | 9.0 | 170/170 |

---

## v0.2 (2026-04-08)

### New Features

- `transform -matrix xx yx xy yy x0 y0` — affine matrix transform
- `transform -get` — read current CTM as `{xx yx xy yy x0 y0}`
- Demo 14: Transform matrix demo

### Changes

- `write -chan channel` support (ported from AndroWish fork)
- ISO B/C paper formats added
- cheatsheet.csd added to docs/

### Test Results

| Platform | Tcl | Tests |
|----------|-----|-------|
| Linux Debian x86_64 | 8.6.17 | 105/105 |
| Windows MSYS2 MINGW64 | 8.6 | 105/105 |

---

## v0.1 (2026-03-30)

Initial release. Core features:
- Shapes: rect, circle, ellipse, arc, line, poly, path (SVG)
- Text with font_measure, anchors, outline/gradient mode
- Gradients: linear + radial
- Transforms: translate/scale/rotate/reset
- Modes: raster, vector, pdf, svg, ps, eps
- Images: PNG + JPEG (MIME embedding)
- Blit / layer compositing
- Clip: clip_rect, clip_path, push/pop
- topng, todata (Tk photo integration)
- TEA build (Linux), Makefile.win (Windows)
- 41/41 tests
