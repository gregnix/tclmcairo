# tclmcairo — Manual

Cairo 2D graphics for Tcl. No Tk required. Runs in `tclsh`.

**Version:** 0.3.4 · **License:** BSD · **Tcl:** 8.6 / 9.0  
**Platform:** Linux, Windows (MSYS2, BAWT), macOS  
**Repository:** https://github.com/gregnix/tclmcairo

---

## Contents

1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Output Formats](#output-formats)
4. [Drawing Shapes](#drawing-shapes)
5. [Text](#text)
6. [Gradients](#gradients)
7. [SVG Rendering](#svg-rendering)
8. [Images](#images)
9. [Transforms](#transforms)
10. [Compositing](#compositing)
11. [canvas2cairo — Tk Canvas Export](#canvas2cairo)
12. [shape_renderer — Shape Icons](#shape_renderer)
13. [svg2cairo — SVG Renderer](#svg2cairo)
14. [Demos](#demos)

---

## Installation

### Linux — Standard

```bash
sudo apt install libcairo2-dev libjpeg-dev tcl8.6-dev build-essential autoconf

autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make && sudo make install
make test
```

### Linux — mit lunasvg (svg_file_luna)

```bash
# lunasvg einmalig bauen:
cd ~/lunasvg
cmake -B build_shared -DBUILD_SHARED_LIBS=ON .
cmake --build build_shared

# tclmcairo mit lunasvg:
autoconf && ./configure --with-tcl=/usr/lib/tcl8.6
make clean && make && sudo make install   # pkgIndex + .tm Dateien
bash buildlt.sh                           # libtclmcairo.so mit lunasvg
```

**Wichtig:** `sudo make install` muss **vor** `buildlt.sh` laufen.

### Windows (BAWT 3.2 + MSYS2)

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
$ctx save "output.pdf"   ;# same drawing, true vectors
$ctx destroy
```

---

## Output Formats

| Extension | Type | Notes |
|-----------|------|-------|
| `.png` | Raster | ARGB32, transparent if `clear` not called |
| `.pdf` | Vector | True vectors in vector/pdf mode |
| `.svg` | Vector | Text as path outlines |
| `.ps` | Vector | PostScript |
| `.eps` | Vector | For LaTeX, InDesign |

```tcl
$ctx save "output.png"
$ctx save "output.pdf"
$ctx save "output.svg"
$ctx save -chan $ch -format pdf   ;# write to open channel
```

---

## Drawing Shapes

```tcl
$ctx rect    x y w h ?opts?             ;# rounded: -radius r
$ctx circle  cx cy r ?opts?
$ctx ellipse cx cy rx ry ?opts?
$ctx arc     cx cy r start end ?opts?   ;# clockwise
$ctx arc_negative cx cy r start end ?opts?   ;# counter-clockwise
$ctx line    x1 y1 x2 y2 ?opts?
$ctx poly    x1 y1 x2 y2 x3 y3... ?opts?
$ctx path    svgdata ?opts?             ;# SVG path syntax
```

Common options: `-fill` `-stroke` `-color` `-width` `-alpha`
`-fillname` `-dash` `-dash_offset` `-linecap` `-linejoin` `-fillrule`

```tcl
$ctx rect 10 10 200 100 -fill {0.2 0.5 1} -stroke {0 0 0} -width 2 -radius 8
$ctx circle 200 150 60 -fill {1 0.5 0 0.8}
$ctx path "M 10 10 Q 100 0 200 10 T 390 10" -stroke {0.8 0.2 0.2} -width 3
```

---

## Text

```tcl
$ctx text x y string ?opts?
```

`x/y` = anchor point. Default anchor `sw` = baseline-left.

```tcl
# Standard text
$ctx text 200 60 "Hello" -font "Sans Bold 18" -color {0 0 0} -anchor center

# Font selection without string parsing
$ctx select_font_face "Serif" -slant italic -weight bold -size 18
$ctx text 100 100 "Direct" -color {0 0 0}

# Gradient fill
$ctx gradient_linear g 0 0 400 0 {{0 1 0.9 0 1} {1 0 0.5 1 1}}
$ctx text 200 80 "GRADIENT" -font "Sans Bold 36" -fillname g -outline 1 -anchor center

# Measure text
set ext [$ctx text_extents "Hello" -font "Sans Bold 24"]
set w [dict get $ext width]
set a [dict get $ext ascent]
```

`text_extents` returns: `width height x_bearing y_bearing x_advance y_advance ascent descent line_height`

---

## Gradients

```tcl
$ctx gradient_linear name x1 y1 x2 y2 stops
$ctx gradient_radial  name cx cy r stops
```

`stops`: `{{offset r g b a} ...}`

```tcl
$ctx gradient_linear g 0 0 400 0 {{0 1 0 0 1} {0.5 1 1 0 1} {1 0 0 1 1}}
$ctx rect 0 0 400 300 -fillname g

$ctx gradient_extend g repeat
$ctx gradient_filter g best
```

---

## SVG Rendering

Three options depending on SVG complexity:

### 1. nanosvg — built-in, no dependencies

```tcl
$ctx svg_file "icon.svg" 0 0 -width 64 -height 64
$ctx svg_data $svgstring 0 0 -scale 2.0
```

Good for: simple icons, basic shapes. No CSS, no text.

### 2. lunasvg — full SVG (optional)

```tcl
lassign [$ctx svg_size_luna "diagram.svg"] sw sh
set w [expr {int($sw*2)}]; set h [expr {int($sh*2)}]
$ctx svg_file_luna "diagram.svg" 0 0 -width $w -height $h
```

Full SVG support: CSS, text, `<use>`, `<clipPath>`, `<marker>`.
Requires `liblunasvg.so` / `liblunasvg.dll`.

### 3. svg2cairo — CSS + text via tDOM

```tcl
package require svg2cairo

lassign [svg2cairo::size "chart.svg"] sw sh
set ctx [tclmcairo::new [expr {int($sw*2)}] [expr {int($sh*2)}]]
svg2cairo::render $ctx "chart.svg" -scale 2.0
```

Handles CSS `<style>` and `<text>`. Requires `tdom`.
See `docs/svg2cairo.md` for details and limitations.

---

## Images

```tcl
$ctx image      "photo.jpg" 10 10 -width 200
$ctx image_data $pngbytes   10 10 -alpha 0.8
lassign [$ctx image_size "photo.jpg"] w h
```

In PDF/SVG mode, JPEG is embedded as MIME data (no re-encoding).

---

## Transforms

```tcl
$ctx push
$ctx transform -translate 100 50
$ctx transform -scale 2.0 2.0
$ctx transform -rotate 45
$ctx circle 0 0 40 -fill {1 0.5 0}
$ctx pop

set m [$ctx transform -get]            ;# {xx yx xy yy x0 y0}
$ctx transform -matrix {*}$m
$ctx transform -reset
```

---

## Compositing

```tcl
$ctx push
$ctx operator MULTIPLY
$ctx circle 150 150 80 -fill {1 0.6 0.1 0.9}
$ctx operator SCREEN
$ctx circle 250 150 80 -fill {0.2 0.5 1.0 0.9}
$ctx pop

$ctx set_source -gradient g
$ctx paint 0.5        ;# fill entire surface at 50% opacity
```

Operators: `OVER SOURCE MULTIPLY SCREEN OVERLAY DARKEN LIGHTEN`
`DIFFERENCE XOR ADD COLOR_DODGE COLOR_BURN HARD_LIGHT SOFT_LIGHT`
`HSL_HUE HSL_SATURATION HSL_COLOR HSL_LUMINOSITY` and more.

---

## canvas2cairo

Export any Tk Canvas to vector formats.

```tcl
package require canvas2cairo

canvas2cairo::export .c output.svg
canvas2cairo::export .c output.pdf
canvas2cairo::export .c output.ps
canvas2cairo::export .c -chan $ch -format pdf

# Into existing context
canvas2cairo::render .c $ctx
canvas2cairo::export .c output.png -scale 2.0       ;# HiDPI
canvas2cairo::export .c output.png -viewport {0 0 400 300}  ;# region
```

See `docs/canvas2cairo.md` for full reference.

---

## shape_renderer

Network diagram shapes rendered via tclmcairo.

```tcl
package require shape_renderer

shape_renderer::draw $ctx router  50  50 60 60
shape_renderer::draw $ctx server 150  50 60 60
shape_renderer::draw $ctx firewall 250 50 60 60 -color {0.8 0.2 0.1}
```

Available shapes: `router switch server firewall database workstation`
`generic table printer scanner accesspoint phone wifi fiber building`

---

## svg2cairo

See `docs/svg2cairo.md`.

```tcl
package require svg2cairo

svg2cairo::render $ctx "file.svg" -scale 2.0
lassign [svg2cairo::size "file.svg"] w h
svg2cairo::has_text "file.svg"   ;# -> 1 if <text> elements present
```

---

## Demos

```bash
make demo   ;# generates demos/*.png *.pdf *.svg
```

| # | Demo |
|---|------|
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
| 12 | JPEG MIME embedding |
| 13 | Plotchart-style chart |
| 14 | Transform -matrix / -get |
| 15 | Compositing operators |
| 16 | user_to_device, arc_negative, -dash_offset |
| 17 | gradient_extend, gradient_filter, paint, set_source |
| 18 | font_options, path_get, surface_copy |
| 19 | save -chan |
| 20 | text_extents + select_font_face |
| 21 | svg_file + svg_data (nanosvg) |

Interactive: `wish demos/demo-coordinates.tcl`  
Node editor: `wish demos/nodeeditor.tcl`
