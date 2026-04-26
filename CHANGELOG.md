# tclmcairo Changelog

## v0.3.5 (2026-04-16)

**Image Buffer Pool — fast pan/zoom without disk access**

Load images once into RAM and blit quickly — no repeated disk
reads on pan/zoom. Essential for the tkmcairo imageviewer.

New commands:
```tcl
$ctx image_load filename        -> image_id   # load once -> RAM
$ctx image_info image_id        -> {w h}
$ctx image_blit image_id x y ?-width w? ?-height h? ?-alpha a?
$ctx image_scale image_id w h   -> new_id     # scaled copy
$ctx image_free image_id
$ctx image_load_surface src_ctx_id -> image_id  # no PNG round-trip
```

Example:
```tcl
set id [$ctx image_load "photo.jpg"]     ;# load once
lassign [$ctx image_info $id] w h        ;# query size
$ctx image_blit $id 0 0 -width 400       ;# fast draw
$ctx image_blit $id 0 0 -alpha 0.5       ;# with transparency
$ctx image_free $id                      ;# release
```

**`toppm`** — PPM bytearray (~10× faster than topng, no zlib):
```tcl
$ctx toppm -> PPM bytearray (P6 RGB24)
$tkphoto put [$ctx toppm] -format ppm
```

- PNG (always) and JPEG (when `HAVE_LIBJPEG`) supported
- Pool: max. 64 simultaneously loaded images (`MAX_IMG`)
- IDs are global (independent of the Cairo context)
- `image_scale`: bilinear filter (`CAIRO_FILTER_BILINEAR`)
- OO wrapper: all 7 new methods in `tclmcairo-0.3.5.tm`
- New tests: 8 tests (`image_load-1.0` to `image_load-1.7`)

**tkmcairo imageviewer:** `imgtools` + Tk Canvas instead of surface/topng —
pan and zoom now smooth even for large images.

**201/201 tests: Tcl 8.6 ✔**

## v0.3.4 (2026-04-15)

### svg2cairo-0.1.tm — Bug fixes

7 bugs fixed (after testing against decode/, vgs/, w3org/ SVG suites):

- **SV-1:** Early `return` on missing CSS match — with `hasStyle=1`,
  shapes without a CSS class/id were not rendered (missing shapes).
  SVG default `fill=black` introduced.

- **SV-2:** `<defs>` rendered as a shape by nanosvg — marker paths
  inside `<defs>` appeared as misplaced lines.
  Fix: strip `<defs>…</defs>` before the nanosvg pass via
  `string first/replace`.

- **SV-3:** `[$node asText]` returns child contents recursively — text
  was rendered twice (once at (0,0), once via the textPath fallback).
  Fix: iterate only direct `TEXT_NODE` children.

- **SV-4:** `NOT_AN_ELEMENT` error on text nodes in `childNodes` —
  tDOM also returns text and comment nodes.
  Fix: `nodeType eq "ELEMENT_NODE"` check in `_renderNode`.

- **SV-5:** CSS not inherited by `<g>` children — `#group1 { stroke:red }`
  on `<g>` had no effect on child shapes.
  Fix: evaluate `_cssForNode` in `_renderNode` for every node.

- **SV-6:** `path` without transform scaling — SVG paths ignored
  sx/sy/ox/oy and were misplaced when scale > 1.
  Fix: set/restore the Cairo transform matrix around the `path` call.

- **SV-7:** `stroke-width` / `stroke-opacity` not read as direct attributes —
  `_nodeStyle` ignored these XML attributes.

### Build fixes

- `build-win.bat`: parentheses inside `echo` lines within `if` blocks
  escaped with `^` (CMD bug — `)` closed the `if` block prematurely,
  so the DLL was built without lunasvg).
- `pkgIndex.tcl.in`: added `svg2cairo 0.1` entry; `@PACKAGE_VERSION@`
  used consistently (no more hard-coded version).

### Documentation

- `docs/svg2cairo.md` — new: complete API reference
- `docs/api-reference.md` — SVG section (nanosvg/lunasvg/svg2cairo),
  `image_size`, `select_font_face`, `text_extents`
- `docs/manual.md` — SVG rendering section, demos 20 + 21
- `nogit/TODO-0.4.md` — svg2cairo known issues (SV-KI-1 to SV-KI-7)

---

## v0.3.4 (2026-04-13)

**nanosvg embedded — render SVG directly onto a Cairo context**

New commands:
```tcl
$ctx svg_file  filename x y ?-width w? ?-height h? ?-scale s?
$ctx svg_data  svgstring x y ?-width w? ?-height h? ?-scale s?
```

- `nanosvg.h` + `nanosvgrast.h` (Mikko Mononen, zlib/libpng license)
  embedded directly
- No librsvg, no GLib, no extra DLLs on Windows
- Correct RGBA → ARGB premultiplied-alpha conversion
- Tk 8.6 + Tk 9.0 compatible (independent of tksvg)
- `THIRD-PARTY-LICENSES.txt` updated

**svg2cairo-0.1.tm** — new Tcl module (tDOM SVG postprocessor):
- CSS `<style>` (tag, .class, #id), 50 W3C color names
- `<text>`, `<tspan>`, `<textPath>` fallback
- DOCTYPE strip before tDOM parse

**lunasvg optional** (C++ wrapper, `HAVE_LUNASVG`):
```tcl
$ctx svg_file_luna filename x y ?-width w? ?-height h? ?-scale s?
$ctx svg_data_luna svgstring x y ?opts?
$ctx svg_size_luna filename -> {width height}
```

**193/193 tests: Tcl 8.6 + Tcl 9.0 ✔**

## v0.3.3 (2026-04-12)

**`image_size`** — read PNG/JPEG dimensions without drawing:
```tcl
lassign [$ctx image_size $file] w h
```

**`select_font_face`** — direct font family/slant/weight control:
```tcl
$ctx select_font_face "Serif" -slant italic -weight bold -size 18
```
Complements `-font` string parsing — avoids re-parsing overhead in
draw loops where the font doesn't change.

**`text_extents` — full dict** (9 keys):
`width height x_bearing y_bearing x_advance y_advance ascent descent line_height`

**193/193 tests: Tcl 8.6 + Tcl 9.0**

## v0.3.3 (2026-04-11) [base]

**Windows: DLL loading fully resolved**

`pkgIndex.tcl` pre-loads all Cairo dependency DLLs with absolute paths
before loading `tclmcairo.dll`. No PATH modification, no admin rights,
works with BAWT Tcl and any other Tcl installation.

`build-win.bat` copies all 19 required MSYS2 DLLs into `dist\tclmcairo0.3.3\`
automatically.

**Windows test result: 187/187 ✔**

**`save -chan`**: write-mode check + auto binary translation

**`canvas2cairo::export -chan`**: export directly to a Tcl channel

**`make test/demo`**: auto-detect tclsh from configured prefix

## v0.3.2 (2026-04-11)

**`save -chan channel`** — write output to an open Tcl channel.

**`cairo_new_path()` before every shape command** — critical fix.

**canvas2cairo-0.1.tm** — 19 improvements including `-smooth 1` Catmull-Rom,
`render -clip`, `text_extents` for justify, `-underline`, `-arrowshape`,
HiDPI `-scale`, region export `-viewport`.

**shape_renderer-0.1.tm** — 7 new shapes (total 15).

Tests: 181/181 tclmcairo ✔  42/42 canvas2cairo ✔

## v0.3.1 (2026-04-10)

canvas2cairo-0.1.tm initial release. demos/nodeeditor.tcl (new).

## v0.3 (2026-04-09)

29 compositing operators, `-dash_offset`, `arc_negative`,
`user_to_device` / `device_to_user`, `recording_bbox`,
`gradient_extend`, `gradient_filter`, `paint`, `set_source`,
`font_options`, `path_get`, `surface_copy`, `transform -matrix/-get`,
low-level path API, 15 Cairo C sample ports in `examples/`.

Tests: 181/181 Linux · 170/170 Windows

## v0.2 (2026-04-08)

`transform -matrix`, `write -chan`, ISO B/C paper formats.
Tests: 105/105

## v0.1 (2026-03-30)

Initial release. Core Cairo binding for Tcl.
Tests: 41/41
