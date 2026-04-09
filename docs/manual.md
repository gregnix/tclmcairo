# tclmcairo 0.3 — Manual

Cairo 2D graphics for Tcl. No Tk required. Runs in `tclsh`.

**Version:** 0.3 · **License:** BSD · **Tcl:** 8.6 / 9.0
**Platform:** Linux, Windows (MSYS2, BAWT), macOS
**Repository:** https://github.com/gregnix/tclmcairo

---

## Installation

### Linux

```bash
# Dependencies
sudo apt install libcairo2-dev libjpeg-dev tcl8.6-dev build-essential autoconf

# Build (TEA)
autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make && make test

# Tcl 9
./configure --with-tcl=/usr/lib/tcl9.0
make && make test TCLSH=tclsh9.0
```

### Windows (MSYS2 MINGW64)

```bash
pacman -S mingw-w64-x86_64-cairo mingw-w64-x86_64-libjpeg-turbo
make -f Makefile.win TARGET=mingw64
make -f Makefile.win TARGET=mingw64 test
```

### Windows (BAWT 3.2)

```cmd
build-win.bat 86
test-win.bat 86
```

### Usage

```tcl
tcl::tm::path add /path/to/tclmcairo/tcl
set env(TCLMCAIRO_LIBDIR) /path/to/tclmcairo
package require tclmcairo
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

## Create / Destroy

```tcl
tclmcairo::new width height ?options?
$ctx destroy
```

### Options

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `-mode` | `raster\|vector\|pdf\|svg\|ps\|eps` | `raster` | Output mode |
| `-file` | filename | — | Required for `pdf\|svg\|ps\|eps` |
| `-format` | `argb32\|rgb24\|a8` | `argb32` | Raster pixel format |
| `-svg_version` | `1.1\|1.2` | `1.2` | SVG spec version |
| `-svg_unit` | `pt\|px\|mm\|cm\|in\|em\|ex\|pc` | `pt` | SVG document unit |

### Modes

| Mode | Description |
|------|-------------|
| `raster` | ARGB32 pixel buffer. For PNG, `topng`, `todata`. |
| `vector` | Recording surface. Saves as true vectors to any format. |
| `pdf` | Direct PDF. Multi-page via `newpage`. |
| `svg` | Direct SVG. Multi-page via `newpage`. |
| `ps` | Direct PostScript. |
| `eps` | Direct EPS. |

### Pixel formats (`-format`)

| Value | Bits | Alpha | Use case |
|-------|------|-------|----------|
| `argb32` | 32 | yes | default, transparent background |
| `rgb24` | 32 | no | solid background, no transparency |
| `a8` | 8 | mask only | alpha mask for clipping/compositing |

```tcl
# Raster
set ctx [tclmcairo::new 400 300]
set ctx [tclmcairo::new 400 300 -format rgb24]

# Vector
set ctx [tclmcairo::new 400 300 -mode vector]

# Direct PDF — multi-page
set ctx [tclmcairo::new 595 842 -mode pdf -file "doc.pdf"]
$ctx clear 1 1 1
$ctx text 297 100 "Page 1" -font "Sans 18" -color {0 0 0} -anchor center
$ctx newpage
$ctx text 297 100 "Page 2" -font "Sans 18" -color {0 0 0.8} -anchor center
$ctx finish
$ctx destroy

# SVG with millimeter units
set ctx [tclmcairo::new 210 297 -mode svg -file "a4.svg" -svg_unit mm]
```

---

## Basic Operations

```tcl
$ctx clear r g b ?a?    ;# background fill, components 0.0-1.0
$ctx size               ;# -> {width height}
$ctx save filename      ;# write to file (.png .pdf .svg .ps .eps)
$ctx topng              ;# -> PNG bytearray (no file needed)
$ctx todata             ;# -> raw ARGB32 bytes (for Tk photo)
$ctx newpage            ;# next page (pdf|svg|ps|eps mode)
$ctx finish             ;# flush + close file (pdf|svg|ps|eps mode)
$ctx destroy            ;# release context (calls finish if needed)
```

### `topng` vs `todata`

| Command | Returns | Typical use |
|---------|---------|-------------|
| `topng` | PNG-compressed bytes | HTTP, database, `image_data`, roundtrip |
| `todata` | Raw ARGB32 stride×height | Tk photo `-data` |

`topng` works on both raster and vector contexts (renders to raster first).

---

## Drawing Commands

### Colors

All colors are `{r g b}` or `{r g b a}` with components 0.0–1.0.

```tcl
-fill   {1 0.5 0}       ;# orange, fully opaque
-fill   {1 0.5 0 0.8}   ;# orange, 80% opacity
-stroke {0 0 0}         ;# black outline
-color  {1 1 1}         ;# white (for line, text)
```

### rect

```tcl
$ctx rect x y w h ?options?
```

| Option | Description |
|--------|-------------|
| `-fill c` | Fill color |
| `-stroke c` | Outline color |
| `-width n` | Outline width |
| `-radius r` | Rounded corner radius |
| `-alpha a` | Overall opacity |
| `-fillname n` | Fill with named gradient |

```tcl
$ctx rect 10 10 200 100 -fill {0.2 0.5 1} -radius 8
$ctx rect 10 10 200 100 -stroke {1 1 1} -width 2
$ctx rect 10 10 200 100 -fillname mygrad -stroke {0 0 0} -width 1
```

### circle

```tcl
$ctx circle cx cy r ?options?
```

Same options as `rect` (no `-radius`).

### ellipse

```tcl
$ctx ellipse cx cy rx ry ?options?
```

### arc

```tcl
$ctx arc cx cy r start_deg end_deg ?options?
```

Draws arc from `start_deg` to `end_deg` (clockwise, degrees).

```tcl
$ctx arc 200 150 80 0 270 -stroke {1 0.5 0} -width 3
```

### line

```tcl
$ctx line x1 y1 x2 y2 ?options?
```

| Option | Values | Description |
|--------|--------|-------------|
| `-color c` | `{r g b ?a?}` | Line color |
| `-width n` | number | Line width |
| `-dash {on off}` | list | Dash pattern |
| `-linecap` | `butt\|round\|square` | End cap style |
| `-alpha a` | 0.0–1.0 | Opacity |

### poly

```tcl
$ctx poly x1 y1 x2 y2 x3 y3 ... ?options?
```

Minimum 3 coordinate pairs. Same fill/stroke options as `rect`.

### path

```tcl
$ctx path svgdata ?options?
```

Full SVG path syntax: `M L H V C Q A Z` and lowercase relative variants.

```tcl
# Triangle
$ctx path "M 100 10 L 190 190 L 10 190 Z" -fill {0.8 0.3 0.1}

# Bezier curve
$ctx path "M 50 200 C 50 100 350 100 350 200" \
    -stroke {0 0.5 1} -width 3

# Combined fill + stroke
$ctx path "M 10 10 L 200 10 L 200 150 Z" \
    -fill {0.2 0.5 0.9 0.7} -stroke {1 1 1} -width 1.5

# Evenodd fill rule (star with hole)
$ctx path "M 100 10 L 120 70 L 180 70 L 130 110 \
    L 150 170 L 100 130 L 50 170 L 70 110 \
    L 20 70 L 80 70 Z" \
    -fill {1 0.6 0} -fillrule evenodd
```

**`-fillrule`**: `winding` (default) or `evenodd`

---

## Text

### text

```tcl
$ctx text x y string ?options?
```

x/y is the anchor point.

| Option | Values | Description |
|--------|--------|-------------|
| `-font str` | `"Sans Bold 14"` | Font spec: family style size |
| `-color c` | `{r g b ?a?}` | Text color |
| `-anchor` | `center nw n ne e se s sw w` | Anchor point |
| `-alpha a` | 0.0–1.0 | Opacity |
| `-outline 0\|1` | bool | `0`=`show_text` (default), `1`=`text_path` |
| `-fillname n` | gradient name | Fill gradient (requires `-outline 1`) |
| `-stroke c` | color | Outline color (requires `-outline 1`) |
| `-width n` | number | Stroke width (requires `-outline 1`) |

```tcl
# Simple text
$ctx text 200 150 "Hello World" \
    -font "Sans Bold 24" -color {1 1 1} -anchor center

# Gradient fill on text
$ctx gradient_linear tg 0 0 400 0 {{0 1 0.9 0 1} {1 0 0.5 1 1}}
$ctx text 200 150 "GRADIENT" \
    -font "Sans Bold 36" -fillname tg -outline 1 -anchor center

# Outline only
$ctx text 200 150 "OUTLINE" \
    -font "Sans Bold 36" -stroke {0.2 0.6 1} -width 1.5 \
    -outline 1 -anchor center
```

**Font spec format:** `"Family Style Size"` or `"Family Size"`

```
"Sans 14"
"Sans Bold 18"
"Sans Bold Italic 12"
"Serif 16"
"Monospace 11"
"DejaVu Sans Bold 20"
```

### text_path

```tcl
$ctx text_path x y string ?options?
```

Always uses `cairo_text_path` (equivalent to `text ... -outline 1`).
Supports all the same options as `text`.

### font_measure

```tcl
$ctx font_measure string font
;# -> {width height ascent descent}
```

Returns exact Cairo text metrics.

```tcl
set m [$ctx font_measure "Hello" "Sans Bold 18"]
lassign $m w h asc desc
```

---

## Gradients

Gradients must be defined before use, scoped to the context.

### gradient_linear

```tcl
$ctx gradient_linear name x1 y1 x2 y2 stops
```

`stops`: list of `{offset r g b a}` — offset 0.0–1.0.

```tcl
# Horizontal blue-to-red
$ctx gradient_linear g 0 0 400 0 \
    {{0 0.2 0.4 0.9 1} {1 0.9 0.2 0.1 1}}

# With midpoint
$ctx gradient_linear g2 0 0 0 300 \
    {{0 1 1 1 1} {0.5 0.5 0.7 1 1} {1 0 0 0 1}}

$ctx rect 0 0 400 300 -fillname g
```

### gradient_radial

```tcl
$ctx gradient_radial name cx cy radius stops
```

```tcl
$ctx gradient_radial gr 200 150 100 \
    {{0 1 0.9 0.2 1} {0.6 0.5 0.8 1 0.8} {1 0 0 0 0}}
$ctx circle 200 150 100 -fillname gr
```

---

## State Stack

`push`/`pop` save and restore: transforms, clip, color state.
Always use them around clips and temporary transforms.

```tcl
$ctx push
$ctx transform -rotate 45
$ctx rect 10 10 80 80 -fill {1 0.5 0}
$ctx pop   ;# rotation gone, state restored
```

---

## Clip Regions

```tcl
$ctx clip_rect x y w h         ;# rectangular clip
$ctx clip_path svgdata          ;# arbitrary path as clip mask
$ctx clip_reset                 ;# remove all clips in current state
```

Always wrap in `push`/`pop`:

```tcl
$ctx push
$ctx clip_rect 50 50 300 200
$ctx circle 200 150 180 -fill {1 0.3 0.1}
$ctx clip_reset
$ctx pop

# Clip to triangle
$ctx push
$ctx clip_path "M 200 10 L 390 390 L 10 390 Z"
$ctx gradient_linear g 0 0 400 0 {{0 1 0 0 1} {1 0 0 1 1}}
$ctx rect 0 0 400 400 -fillname g
$ctx pop
```

### Plotchart-style: clip_rect + push/pop

```tcl
# Map data coordinates to pixels
proc px x { expr {$lm + ($x-$xmin)/($xmax-$xmin)*$pw} }
proc py y { expr {$H-$bm - ($y-$ymin)/($ymax-$ymin)*$ph} }

# Clip to plot area — data lines stay inside
$ctx push
$ctx clip_rect $lm $tm $pw $ph
$ctx path $sin_path -stroke {0.2 0.4 0.9} -width 2
$ctx path $cos_path -stroke {0.9 0.3 0.2} -width 2
$ctx pop   ;# clip released

# Axes and labels drawn freely outside
$ctx line $lm [expr {$H-$bm}] [expr {$lm+$pw}] [expr {$H-$bm}] \
    -color {0.2 0.2 0.3} -width 1.5
```

This replaces `raise`/`lower` in Tk Canvas — no Z-order manipulation needed.

---

## Transforms

All transforms accumulate on the current transformation matrix (CTM).

```tcl
$ctx transform -translate dx dy
$ctx transform -rotate degrees      ;# clockwise
$ctx transform -scale sx sy
$ctx transform -matrix xx yx xy yy x0 y0   ;# affine 2x3
$ctx transform -get                 ;# -> {xx yx xy yy x0 y0}
$ctx transform -reset               ;# identity matrix
```

### The affine matrix

Cairo uses a 2×3 affine matrix `{xx yx xy yy x0 y0}`:

```
x' = xx*x + xy*y + x0
y' = yx*x + yy*y + y0
```

| Transform | Matrix |
|-----------|--------|
| Identity | `1 0 0 1 0 0` |
| Translate (tx, ty) | `1 0 0 1 tx ty` |
| Scale (sx, sy) | `sx 0 0 sy 0 0` |
| Rotate θ | `cos(θ) sin(θ) -sin(θ) cos(θ) 0 0` |
| Shear-X by k | `1 0 k 1 0 0` |

```tcl
# 45° rotation around center (200, 150)
set r [expr {45 * 3.14159 / 180.0}]
set c [expr {cos($r)}]
set s [expr {sin($r)}]
$ctx transform -matrix $c $s [expr {-$s}] $c 200 150

# Read current CTM
set m [$ctx transform -get]
# -> e.g. {0.707 0.707 -0.707 0.707 200.0 150.0}

# Transforms stack — use push/pop to scope
$ctx push
$ctx transform -translate 100 100
$ctx transform -rotate 30
$ctx rect 0 0 80 40 -fill {1 0.5 0}
$ctx pop   ;# both transforms gone
```

---

## Images

### image

```tcl
$ctx image filename x y ?options?
```

Supported formats: PNG (always), JPEG (if built with `HAVE_LIBJPEG`).

| Option | Description |
|--------|-------------|
| `-width w` | Scale to width |
| `-height h` | Scale to height |
| `-alpha a` | Opacity 0.0–1.0 |

**JPEG MIME embedding:** When saving to PDF or SVG, JPEG files are
automatically embedded as MIME data (`CAIRO_MIME_TYPE_JPEG`) — original
bytes are written 1:1, no re-encoding, no quality loss, ~20-25% smaller
files compared to PNG.

### image_data

```tcl
$ctx image_data bytes x y ?options?
```

Draws a PNG from a Tcl bytearray — no filename needed.
Same `-width`, `-height`, `-alpha` options as `image`.

```tcl
# In-memory pipeline: draw -> topng -> image_data
set src [tclmcairo::new 100 100]
$src circle 50 50 45 -fill {1 0.5 0}
set bytes [$src topng]
$src destroy

set dst [tclmcairo::new 400 300]
$dst image_data $bytes  10 10
$dst image_data $bytes 120 10 -width 80 -alpha 0.7
$dst image_data $bytes 210 10 -width 60 -height 60
$dst save "composed.png"
$dst destroy
```

---

## Blit / Layer Compositing

```tcl
$ctx blit src_ctx x y ?options?
```

Composites `src_ctx` onto `$ctx` at position (x, y).

| Option | Default | Description |
|--------|---------|-------------|
| `-alpha a` | `1.0` | Compositing opacity |
| `-width w` | src width | Scale to width |
| `-height h` | src height | Scale to height |

Both raster and vector sources supported.
File-mode contexts (pdf/svg/ps/eps) cannot be used as source.

```tcl
# Layer model
set sky   [tclmcairo::new 600 400]
set mtn   [tclmcairo::new 600 400]
set cloud [tclmcairo::new 600 400]

# Draw each layer independently
$sky   gradient_linear bg 0 0 0 400 {{0 0.5 0.7 1 1} {1 0.7 0.9 1 1}}
$sky   rect 0 0 600 400 -fillname bg
$mtn   poly 0 400 150 200 300 300 450 180 600 400 \
       -fill {0.3 0.4 0.3}
$cloud circle 150 80 50 -fill {1 1 1 0.7}

# Composite
$sky blit $mtn   0 0
$sky blit $cloud 0 0 -alpha 0.8

$sky save "landscape.png"
$sky destroy; $mtn destroy; $cloud destroy
```

---

## Output

### save

```tcl
$ctx save filename
```

Extension determines format: `.png` `.pdf` `.svg` `.ps` `.eps`

For vector/file-mode contexts, saving as `.pdf`/`.svg`/`.ps`/`.eps`
produces true vector output. Raster contexts always rasterize.

### topng

```tcl
set bytes [$ctx topng]
```

Returns PNG as a Tcl bytearray. Works on both raster and vector contexts.
Vector contexts are rendered to raster first.

```tcl
# Write to file without $ctx save
set bytes [$ctx topng]
set f [open "out.png" wb]
puts -nonewline $f $bytes
close $f

# Use as Tk photo image
image create photo myimg
myimg put $bytes -format png

# Send via HTTP (httpd/ncgi)
set body $bytes
set content_type "image/png"
```

### todata

```tcl
set bytes [$ctx todata]
```

Returns raw ARGB32 pixel data (stride × height bytes).
Raster mode only. Use for Tk photo direct pixel manipulation.

---

## SVG-specific Options

```tcl
# SVG version (controls which Cairo features are used internally)
tclmcairo::new 400 300 -mode svg -file out.svg -svg_version 1.1
tclmcairo::new 400 300 -mode svg -file out.svg -svg_version 1.2  ;# default

# Document unit (appears in SVG width/height attributes)
tclmcairo::new 210 297 -mode svg -file a4.svg -svg_unit mm
# -> <svg width="210mm" height="297mm" ...>

tclmcairo::new 800 600 -mode svg -file screen.svg -svg_unit px
# -> <svg width="800px" height="600px" ...>
```

Available units: `pt` (default), `px`, `mm`, `cm`, `in`, `em`, `ex`, `pc`

**SVG text note:** Cairo always renders text as glyph outlines — no
`<text>` elements in output. Text is not searchable in SVG viewers.

**MIME data in SVG:** Both JPEG and PNG are embedded as base64 data URIs
in SVG (`<image href="data:image/jpeg;base64,...">` etc.).

---

## Build Reference

### Linux (TEA)

```bash
autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make
make test
make demo              ;# generates 14 demo files in demos/

# Tcl 9
./configure --with-tcl=/usr/lib/tcl9.0
make && make test TCLSH=tclsh9.0

# Disable JPEG
make JPEG=0
```

### Windows (MSYS2 MINGW64)

```bash
# Prerequisites
pacman -S mingw-w64-x86_64-cairo
pacman -S mingw-w64-x86_64-libjpeg-turbo   # optional

make -f Makefile.win TARGET=mingw64
make -f Makefile.win TARGET=mingw64 test
make -f Makefile.win TARGET=mingw64 demo
```

### Windows (BAWT 3.2)

```cmd
build-win.bat 86         ;# Tcl 8.6
build-win.bat 86 nojpeg  ;# without JPEG
test-win.bat 86
```

### Environment

```tcl
# Make tclmcairo available without installing
tcl::tm::path add /path/to/tclmcairo/tcl
set env(TCLMCAIRO_LIBDIR) /path/to/tclmcairo
package require tclmcairo
```

---

## Demos

```bash
make demo
make demo TCLSH=tclsh9.0
```

| # | File | Content |
|---|------|---------|
| 1 | demo-shapes | rect, circle, ellipse, line, poly, arc |
| 2 | demo-paths | SVG paths, fillrule evenodd |
| 3 | demo-gradients | linear + radial gradients |
| 4 | demo-text | fonts, metrics, anchors |
| 5 | demo-output | A4 PDF vector |
| 6 | demo-multipage | 3-page PDF |
| 7 | demo-clip | clip_rect, clip_path, push/pop |
| 8 | demo-textpath | gradient/outline/shadow/clipped text |
| 9 | demo-transparent | PNG transparency, alpha |
| 10 | demo-blit | layer compositing |
| 11 | demo-png-formats | argb32/rgb24/a8, topng, image_data |
| 12 | demo-mime | JPEG MIME embedding (~25% smaller PDF) |
| 13 | demo-plotchart | Plotchart-style chart with clip_rect |
| 14 | demo-matrix | -matrix transforms and -get CTM |
| 15 | demo-operators | Compositing operators (16 blend modes) |
| 16 | demo-coords | user_to_device, arc_negative, -dash_offset |
| 17 | demo-gradient-ops | gradient_extend, filter, paint, set_source |
| 18 | demo-prio3 | font_options, path_get, surface_copy |

---


---

## 0.3 Features

### Compositing Operator

```tcl
$ctx operator OVER|MULTIPLY|SCREEN|OVERLAY|DARKEN|LIGHTEN|DIFFERENCE|XOR|...
```

Sets how new drawing combines with existing pixels. Default is `OVER`.
29 operators total: full Porter-Duff set + CSS blend modes.

### Coordinate Mapping

```tcl
set d [$ctx user_to_device 10 20]   ;# -> {dx dy} in device space
set u [$ctx device_to_user 60 70]   ;# -> {x y} in user space
```

Essential for mouse interaction when transforms are active.

### arc_negative

```tcl
$ctx arc_negative cx cy r start_deg end_deg ?opts?
```

Counter-clockwise arc. Equivalent to `cairo_arc_negative`.

### -dash_offset

```tcl
$ctx line 0 0 400 0 -dash {10 5} -dash_offset 3
```

Starting offset into the dash pattern (third parameter of `cairo_set_dash`).

### gradient_extend / gradient_filter

```tcl
$ctx gradient_extend name none|pad|repeat|reflect
$ctx gradient_filter name fast|good|best|nearest|bilinear
```

### paint / set_source

```tcl
$ctx set_source -color {r g b ?a?}   ;# set Cairo source
$ctx set_source -gradient name
$ctx paint ?alpha?                    ;# fill entire surface with source
```

### recording_bbox

```tcl
set bb [$ctx recording_bbox]   ;# -> {x y w h}  (vector mode only)
```

### font_options

```tcl
$ctx font_options -antialias gray -hint_style full -hint_metrics on
set fo [$ctx font_options]   ;# get current settings
```

### path_get

```tcl
set svg [$ctx path_get]   ;# -> "M x y L x y ..." or ""
```

Path is cleared by Cairo after `stroke`/`fill` — call `path_get` before drawing.

### surface_copy

```tcl
set cid [$ctx surface_copy]          ;# same size, blank
set cid [$ctx surface_copy 200 150]  ;# custom size
tclmcairo circle $cid 100 75 50 -fill {1 0.5 0}
tclmcairo destroy $cid
```

### Low-Level Path API

Direct Cairo path commands for porting C examples:

```tcl
$ctx move_to x y           $ctx rel_move_to dx dy
$ctx line_to x y           $ctx rel_line_to dx dy
$ctx curve_to x1 y1 x2 y2 x3 y3
$ctx rel_curve_to dx1 dy1 dx2 dy2 dx3 dy3
$ctx close_path            $ctx new_path       $ctx new_sub_path
$ctx stroke                $ctx fill
$ctx fill_preserve         $ctx stroke_preserve
$ctx set_line_width n      $ctx set_line_cap butt|round|square
$ctx set_line_join miter|round|bevel
$ctx set_fill_rule winding|evenodd
$ctx set_source_rgb r g b  $ctx set_source_rgba r g b a
```

## Known Limitations

- **Text:** Cairo Toy Font API — no HarfBuzz, no BiDi, no complex script
  shaping (Arabic, Devanagari, etc.). Use Pango for complex text.
- **Thread safety:** NOT thread-safe. One context per thread.
- **SVG text:** Always rendered as glyph outlines, not `<text>` elements.
- **PNG MIME in PDF:** Cairo's PDF backend re-encodes PNG as pixel data —
  only JPEG benefits from MIME embedding. PNG MIME works in SVG.

---

## License

BSD 2-Clause — see `LICENSE`.

```
Copyright (c) 2026 gregnix
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice...
2. Redistributions in binary form must reproduce the above copyright notice...
```
