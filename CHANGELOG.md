# tclmcairo Changelog

## v0.3.6 (2026-04-27)

**`tclmcairo::locate` — find install paths**

Centralised path discovery for tclmcairo and its companion modules.
Replaces the per-consumer path-search dance that labeledit and others
had to write. Soft fallback (returns `""`) instead of an error so
callers can branch cleanly:

```tcl
set p [tclmcairo::locate]                ;# install dir of tclmcairo itself
set p [tclmcairo::locate canvas2cairo]   ;# path to canvas2cairo-*.tm or ""
set p [tclmcairo::locate svg2cairo]      ;# path to svg2cairo-*.tm or ""
array set paths [tclmcairo::locate -all] ;# all four at once
```

Strategies tried in order: loaded C-extension path, `TCLMCAIRO_LIBDIR`
env var, then standard install paths under `/usr/lib/tcltk` etc. For
companion modules: `tcl::tm::path list` first, then fall back to the
tclmcairo install directory (TEA installs siblings together).

7 new tests in `test-tclmcairo.tcl`.

**`canvas2cairo::ready` / `canvas2cairo::probe` — capability checks**

Editors used to write 60+ lines to figure out whether `canvas2cairo`
was actually usable. Now:

```tcl
if {![canvas2cairo::ready]} {
    error "canvas2cairo not usable"
}

# For diagnostics:
array set info [canvas2cairo::probe]
puts $info(status)        ;# ok | tclmcairo-missing | tk-missing | error
puts $info(tclmcairo)     ;# version string
puts $info(features)      ;# list from tclmcairo hasFeature
```

`probe -test 1` additionally runs a tiny canvas → PNG round-trip and
verifies the output is a real PNG (8-byte signature check) — useful
in CI to catch broken installs.

5 new tests in `test-canvas2cairo.tcl`.

**`canvas2cairo::svgItem` / `svgResize` — high-level SVG-on-canvas helper**

Six steps boil down to one call:

```tcl
# Old (~30 lines): tempfile + tclmcairo::new + svg2cairo::render +
#                  ctx save + image create photo + tempfile delete +
#                  canvas create image + remember svg path for resize

# New:
set itemId [canvas2cairo::svgItem $canvas $x $y $svgFile -size {200 150}]

# On resize handle drag:
canvas2cairo::svgResize $canvas $itemId -size {400 300}

# When done with an item (eager photo release):
canvas2cairo::svgItemDelete $canvas $itemId
```

Uses `image_from_ppm` round-trip when available (no tempfile),
`sizeForFit` for automatic clamping, and lunasvg if present (auto
fallback to nanosvg+svg2cairo).

State cleanup: `svgItemDelete` for explicit early release; otherwise
state is dropped automatically when the canvas widget itself is
destroyed (Tk Canvas has no per-item destroy event, only widget-level).

Options:
- `-size {w h}` — explicit target size
- `-maxsize {w h}` — auto-fit clamp box (default `{1200 1200}`)
- `-minscale` / `-maxscale` — clamp range (defaults 0.5 / 2.0)
- `-anchor` — canvas anchor (default `nw`)
- `-tags` — extra canvas tags
- `-renderer auto|nano|luna` — explicit renderer choice (default auto)

5 new tests in `test-canvas2cairo.tcl`.

**svg2cairo helpers — `size_data`, `sizeForFit`**

Two new helper procs that previously every SVG consumer had to write
themselves:

```tcl
# Read dimensions of an in-memory SVG (matches existing render_data naming)
lassign [svg2cairo::size_data $svgstring] w h

# Fit-to-box with clamping — common pattern when dropping an SVG
# into a canvas at a "sensible" size
lassign [svg2cairo::sizeForFit $file $maxW $maxH] tw th scale
lassign [svg2cairo::sizeForFit $file $maxW $maxH -min 0.5 -max 4.0] tw th scale
```

`sizeForFit` returns `{targetW targetH scale}`, with `scale` clamped to
`-min`/`-max` (defaults 0.5/2.0). Replaces the boilerplate that
labeledit had inside `svgToCanvasNative`:

```tcl
# old: 8 lines of min/max/clamp/multiply
# new: lassign [svg2cairo::sizeForFit $f $maxW $maxH] tw th _
```

15 new tests in `tests/test-svg2cairo.tcl`.

Run with: `make test-svg2cairo` (also: `make test-all`).

**`canvas2cairo::export -exclude-tags` — skip UI items in exports**

Editors typically have to delete or hide selection markers, grid lines,
rubber-band rectangles etc. before calling `canvas2cairo::export`, then
restore them afterwards. The new `-exclude-tags` option does the
filtering inside the renderer:

```tcl
canvas2cairo::export $canvas $filename \
    -exclude-tags {selMarker selRubber gridLine}
```

Items carrying any of those tags are skipped (regardless of `-state`)
without modifying the canvas. Works with all formats and with `-chan`:

```tcl
canvas2cairo::export $canvas -chan $ch -format pdf \
    -exclude-tags {selMarker}
```

Replaces this boilerplate that labeledit and similar editors had to
write around every export call:

```tcl
$canvas delete "selMarker"
$canvas delete "selRubber"
$canvas itemconfigure "gridLine" -state hidden
update idletasks
canvas2cairo::export $canvas $filename
$canvas itemconfigure "gridLine" -state normal
::le::select::updateMarker $canvas
```

5 new tests in `tests/test-canvas2cairo.tcl` (constraints: `hasTk`).

Run with: `make test-canvas2cairo` (also: `make test-all`).

**`image_from_ppm` — inverse of `toppm`**

Round-trip closes: read PPM bytes from a Tk photo (or any other source)
straight into a Cairo context — no tempfile, no PNG re-encoding. Mirrors
the existing `toppm` (which goes the other way).

```tcl
set ppm [$photo data -format ppm]            ;# Tk photo -> bytes
$ctx image_from_ppm $ppm 10 20               ;# bytes -> Cairo

# round-trip:
set bytes [$src toppm]
$dst image_from_ppm $bytes 0 0
```

Supports `-width` / `-height` for direct scaled blit and `-alpha` for
transparency. PPM grammar accepts standard P6 with comments
(`#` lines). Only 8-bit (maxval 255) is supported — 16-bit PPM is
rejected with a clear error.

This eliminates the disk-cache pattern that svg2cairo and labeledit
were using:
```tcl
# old: $ctx save tempPng + image create photo -file + file delete
# new: pure in-memory round-trip
```

9 new tests (`image_from_ppm-1.0` to `-1.8`).

**`hasFeature` — capability probe**

New top-level command for runtime feature detection. Replaces the
`package require` + path-search dance that consumers (labeledit,
tkmcairo) had to write to figure out which optional features were
compiled in.

```tcl
tclmcairo hasFeature                 ;# -> list of all enabled features
tclmcairo hasFeature lunasvg         ;# -> 1 if compiled with lunasvg
tclmcairo hasFeature jpeg            ;# -> 0|1, depending on HAVE_LIBJPEG
tclmcairo::hasFeature image_load     ;# OO-style helper (same result)
```

- No context required — pure capability query.
- Unknown feature names return 0 (forwards-compatible probing).
- Covers: `image_load` / `image_load_surface` / `image_scale` /
  `image_blit` / `image_free` / `image_info` / `image_size` /
  `image_data` / `toppm` / `topng` / `todata` /
  `svg_file` / `svg_data` / `lunasvg` / `svg_file_luna` /
  `svg_data_luna` / `svg_size_luna` / `jpeg` / `png` /
  `select_font_face` / `text_extents` / `font_measure` /
  `gradient_linear` / `gradient_radial` / `clip_rect` / `clip_path` /
  `transform` / `save` / `save_chan` / `newpage`.
- 12 new tests (`hasFeature-1.0` to `hasFeature-1.11`).

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
