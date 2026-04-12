# tclmcairo — Manual

Cairo 2D graphics for Tcl. No Tk required. Runs in `tclsh`.

**Version:** 0.3.3 · **License:** BSD · **Tcl:** 8.6 / 9.0  **Platform:** Linux, Windows (MSYS2, BAWT), macOS  
**Repository:** https://github.com/gregnix/tclmcairo

---

## Contents

1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Core Concepts](#core-concepts)
4. [Output Formats](#output-formats)
5. [Drawing Shapes](#drawing-shapes)
6. [Paths](#paths)
7. [Text](#text)
8. [Gradients](#gradients)
9. [Images](#images)
10. [Transforms](#transforms)
11. [Transparency and Compositing](#transparency-and-compositing)
12. [canvas2cairo — Tk Canvas Export](#canvas2cairo)
13. [shape_renderer — Shape Icons](#shape_renderer)
14. [Demos](#demos)

---

## Installation

### Linux (Debian/Ubuntu)

```bash
sudo apt install libcairo2-dev libjpeg-dev tcl8.6-dev build-essential autoconf

autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make && make test
sudo make install
```

For Tcl 9:
```bash
./configure --with-tcl=/usr/lib/tcl9.0
make && make test TCLSH=tclsh9.0
```

### Windows (MSYS2 MINGW64)

```bash
pacman -S mingw-w64-x86_64-cairo mingw-w64-x86_64-libjpeg-turbo
make -f Makefile.win TARGET=mingw64
```

### Windows (BAWT 3.2)

```cmd
build-win.bat 86
```

### Usage Without Install

```tcl
tcl::tm::path add /path/to/tclmcairo/tcl
set env(TCLMCAIRO_LIBDIR) /path/to/tclmcairo
package require tclmcairo
```

---

## Quick Start

```tcl
package require tclmcairo

# Create a 400x300 raster context
set ctx [tclmcairo::new 400 300]

# Background
$ctx clear 0.1 0.1 0.2

# Draw a circle with gradient fill
$ctx gradient_radial grad 200 150 80 {
    {0   1.0 0.8 0.2 1}
    {0.6 0.9 0.4 0.1 1}
    {1   0.6 0.1 0.0 0}
}
$ctx circle 200 150 80 -fillname grad

# Text
$ctx text 200 280 "Hello, Cairo!" \
    -font "Sans 20 Bold" -color {1 1 1} -anchor center

# Save as PNG
$ctx save output.png
$ctx destroy
```

---

## Core Concepts

### Context

Every drawing operation works on a **context** — a Cairo surface with a
coordinate system. The context tracks: current transform, clip region,
line settings, fill/stroke color, and a state stack.

```tcl
set ctx [tclmcairo::new width height ?options?]
$ctx destroy
```

### Coordinate System

Origin (0,0) is top-left. X increases right, Y increases down.
All coordinates are floating-point (sub-pixel precision).

### Colors

Colors are specified as `{r g b}` or `{r g b a}` with values 0.0–1.0:

```tcl
{1 0 0}       ;# red, fully opaque
{0 0.5 1 0.8} ;# blue, 80% opacity
```

### State Stack

```tcl
$ctx push   ;# save: transform, clip, color, line settings
# ... draw ...
$ctx pop    ;# restore saved state
```

---

## Output Formats

| Mode | Format | Use |
|------|--------|-----|
| `raster` (default) | PNG via `$ctx save` | Screen output, image processing |
| `pdf` | PDF vector | Documents, print |
| `svg` | SVG vector | Web, scalable graphics |
| `ps` | PostScript | Print |
| `eps` | EPS | Embedded in documents |

```tcl
# Raster (PNG)
set ctx [tclmcairo::new 800 600]
$ctx save output.png

# PDF vector
set ctx [tclmcairo::new 595 842 -mode pdf -file "doc.pdf"]
$ctx finish   ;# flushes PDF

# SVG
set ctx [tclmcairo::new 400 300 -mode svg -file "image.svg"]
$ctx finish

# Multi-page PDF
set ctx [tclmcairo::new 595 842 -mode pdf -file "report.pdf"]
# ... page 1 ...
$ctx newpage
# ... page 2 ...
$ctx finish
$ctx destroy
```

**Get PNG bytes** (for embedding in Tk, etc.):
```tcl
set bytes [$ctx topng]   ;# raw PNG bytearray
```

**Write to channel** (Memchan, socket, pipe — new in 0.3.2):
```tcl
set ch [open output.pdf wb]
$ctx save -chan $ch -format pdf   ;# pdf svg ps eps png
close $ch
```

---

## Drawing Shapes

All shapes accept `-fill`, `-stroke`, `-width` options.
Colors as `{r g b}` or `{r g b a}`.

### Rectangle

```tcl
$ctx rect x y width height ?options?
```

```tcl
$ctx rect 10 10 200 100 -fill {0.3 0.6 0.9}
$ctx rect 10 10 200 100 -fill {0.3 0.6 0.9} -stroke {0 0 0} -width 2
$ctx rect 10 10 200 100 -fill {0.3 0.6 0.9} -radius 12   ;# rounded corners
```

### Circle / Ellipse

```tcl
$ctx circle cx cy radius ?options?
$ctx ellipse cx cy rx ry ?options?
```

```tcl
$ctx circle 200 150 80 -fill {1 0.5 0}
$ctx ellipse 200 150 100 60 -stroke {0 0 1} -width 2
```

### Line / Polyline

```tcl
$ctx line x1 y1 x2 y2 ?options?
```

```tcl
$ctx line 10 10 200 200 -color {1 0 0} -width 3
$ctx line 10 10 200 200 -color {1 0 0} -width 3 -dash {8 4}
$ctx line 10 10 200 200 -color {1 0 0} -width 3 -linecap round
```

**Dash patterns:** `{on off}` or `{on off on off ...}` in pixels.

**Line caps:** `butt` (default) · `round` · `square`  
**Line joins:** `miter` (default) · `round` · `bevel`

### Arc

```tcl
$ctx arc cx cy rx ry start_deg end_deg ?options?
```

```tcl
$ctx arc 200 150 80 80 0 270 -stroke {0 0.5 1} -width 3
$ctx arc 200 150 80 60 45 315 -fill {1 0.8 0.2 0.7}
```

Angles in degrees, clockwise from 3 o'clock (East).

```tcl
$ctx arc_negative cx cy rx ry start end ?options?   ;# counter-clockwise
```

### Polygon

```tcl
$ctx poly x1 y1 x2 y2 ... ?options?
```

```tcl
$ctx poly 100 20 180 160 20 160 -fill {0.3 0.7 0.3} -stroke {0 0.4 0} -width 2
```

---

## Paths

Full SVG path syntax:

```tcl
$ctx path "M x y L x y C x1 y1 x2 y2 x y Z" ?options?
```

| Command | Description |
|---------|-------------|
| `M x y` | Move to |
| `L x y` | Line to |
| `C x1 y1 x2 y2 x y` | Cubic Bézier |
| `Q x1 y1 x y` | Quadratic Bézier |
| `A rx ry rot large sweep x y` | Arc |
| `Z` | Close path |

```tcl
# Star
$ctx path "M 100 10 L 120 80 L 190 80 L 135 120 L 160 190
           L 100 145 L 40 190 L 65 120 L 10 80 L 80 80 Z" \
    -fill {1 0.8 0} -stroke {0.8 0.5 0} -width 2

# Cubic Bézier curve
$ctx path "M 50 150 C 100 50 200 50 250 150" \
    -stroke {0.2 0.5 1} -width 3

# Get path as coordinate list
set coords [$ctx path_get "M 50 100 L 200 100 A 50 50 0 0 1 250 150"]
```

---

## Text

```tcl
$ctx text x y string ?options?
```

| Option | Values | Notes |
|--------|--------|-------|
| `-font` | `"Family ?Bold? ?Italic? size"` | e.g. `"Sans Bold 14"` |
| `-color` | `{r g b}` | text color |
| `-anchor` | `center nw n ne e se s sw w` | position relative to x,y |
| `-outline` | `0\|1` | render as path (scalable in SVG) |

```tcl
$ctx text 200 100 "Hello" -font "Sans 24 Bold" -color {1 1 1} -anchor center
$ctx text 10 50 "Italic" -font "Serif 16 Italic" -color {0.2 0.4 0.8}
```

**Text as outline path** (for SVG/PDF font-independence):
```tcl
$ctx text 100 100 "Outlined" -font "Sans 36 Bold" \
    -fill {0.2 0.5 0.9} -stroke {0 0 0} -width 1 -outline 1
```

**Text metrics:**
```tcl
# Font extents: {ascent descent height max_x_advance max_y_advance}
set fe [$ctx font_extents "Sans 14"]

# Text extents: {x_bearing y_bearing width height x_advance y_advance}
set te [$ctx text_extents "Hello" "Sans 14"]
set text_width [lindex $te 2]
```

---

## Gradients

### Linear Gradient

```tcl
$ctx gradient_linear name x1 y1 x2 y2 stops
```

```tcl
$ctx gradient_linear grad 0 0 400 0 {
    {0   0.2 0.5 0.9 1}
    {0.5 0.1 0.3 0.7 1}
    {1   0.0 0.1 0.4 1}
}
$ctx rect 0 0 400 200 -fillname grad
```

### Radial Gradient

```tcl
$ctx gradient_radial name cx cy radius stops
```

```tcl
$ctx gradient_radial glow 200 150 100 {
    {0   1.0 0.9 0.3 1}
    {0.7 0.9 0.4 0.1 1}
    {1   0.5 0.1 0.0 0}
}
$ctx circle 200 150 100 -fillname glow
```

**Stops:** `{offset r g b a}` — offset 0.0–1.0.

### Gradient Options

```tcl
$ctx gradient_extend name pad|repeat|reflect
$ctx gradient_filter name fast|good|best
```

---

## Images

### Load Image

```tcl
$ctx image file x y ?-width w? ?-height h? ?-alpha a?   ;# .png or .jpg
```

```tcl
$ctx image "photo.png" 10 10
$ctx image "photo.jpg" 0 0 -width 200 -height 150 -alpha 0.8
```

### Raw PNG Bytes

```tcl
$ctx image_data bytes x y    ;# PNG bytearray from file or topng
```

```tcl
# Copy one context onto another
set bytes [$ctx2 topng]
$ctx image_data $bytes 50 50
```

### Blit (Surface Copy)

```tcl
$ctx blit src_ctx x y ?options?
```

```tcl
# Composite src onto dst at (100, 50) with 70% opacity
$ctx blit $src 100 50 -alpha 0.7 -operator over
```

---

## Transforms

All transforms apply to subsequent drawing operations.

```tcl
$ctx transform -translate dx dy
$ctx transform -scale sx sy
$ctx transform -rotate degrees
$ctx transform -matrix {a b c d tx ty}
$ctx transform -reset            ;# identity
```

```tcl
# Rotate text around center
$ctx push
$ctx transform -translate 200 150
$ctx transform -rotate 45
$ctx text 0 0 "Rotated" -font "Sans 20" -color {1 1 1} -anchor center
$ctx pop
```

**Query current transform:**
```tcl
set m [$ctx transform -get]   ;# {a b c d tx ty}
```

**Coordinate conversion:**
```tcl
lassign [$ctx user_to_device $x $y]   sx sy   ;# user → screen
lassign [$ctx device_to_user $sx $sy] ux uy   ;# screen → user
```

---

## Transparency and Compositing

### Global Alpha

```tcl
$ctx alpha 0.5   ;# all subsequent drawing at 50% opacity
$ctx alpha 1.0   ;# reset
```

### Compositing Operators

```tcl
$ctx operator over|source|in|out|atop|dest|xor|add|...
```

```tcl
# Punch a hole using 'out' operator
$ctx push
$ctx operator out
$ctx circle 200 150 60 -fill {0 0 0 1}
$ctx pop
```

### Clip Region

```tcl
$ctx clip_rect x y width height
$ctx clip_path "M ..."
$ctx clip_reset
```

```tcl
# Draw only within a circle
$ctx push
$ctx clip_path "M 250 150 m -80 0 a 80 80 0 1 0 160 0 a 80 80 0 1 0 -160 0"
$ctx image "photo.png" 0 0
$ctx pop
```

---

## canvas2cairo — Tk Canvas Export

`canvas2cairo` exports Tk Canvas widgets to any tclmcairo output format.

```tcl
package require canvas2cairo

# Full export (format from file extension)
canvas2cairo::export .canvas output.svg
canvas2cairo::export .canvas output.pdf
canvas2cairo::export .canvas output.png

# HiDPI export
canvas2cairo::export .canvas output.png -scale 2.0

# Export only a region
canvas2cairo::export .canvas output.svg -viewport {50 50 600 400}

# Render into existing context (embedding)
set ctx [tclmcairo::new 595 842 -mode pdf -file "page.pdf"]
$ctx push
$ctx transform -translate 50 100
canvas2cairo::render .canvas $ctx
$ctx pop
$ctx finish; $ctx destroy
```

**Supported items:** rectangle, oval, line, polygon, text, arc, image  
**New in 0.3.2:** `-smooth raw/1`, `-underline`, `-arrowshape`, `-justify`,
`-scale`, `-viewport`, scroll position, negative scrollregion, polygon outline-only,
`_apply_render` namespace fix, `clip_bbox` fix  
**New in 0.3.3:** `export -chan channel -format fmt` — write directly to channel  
**Not supported:** window (embedded widgets), bitmap, stipple patterns

**Export to channel (new in 0.3.3):**
```tcl
set ch [open report.pdf wb]
canvas2cairo::export .canvas -chan $ch -format pdf
close $ch

# Combined with scale
set ch [open hires.png wb]
canvas2cairo::export .canvas -chan $ch -format png -scale 2.0
close $ch
```

**Before export, always call:**
```tcl
update idletasks   ;# ensures Tk has rendered all items
```

See `docs/canvas2cairo.md` for full documentation.

---

## shape_renderer — Shape Icons

`shape_renderer` draws Cairo-based shape icons for use in diagrams.

```tcl
package require shape_renderer

# Render directly to file (recommended)
shape_renderer::render_to_file server 64 64 /tmp/icon.png \
    -color {0.35 0.35 0.6}

# Use in Tk Canvas
set img [image create photo -file /tmp/icon.png]
.canvas create image $x $y -image $img -anchor nw

# Clear cache after zoom changes
shape_renderer::clear_cache
```

**Available shapes:**

| Category | Shapes |
|----------|--------|
| Network | `router` `switch` `server` `firewall` `accesspoint` `wifi` `fiber` |
| End-user | `workstation` `printer` `scanner` `phone` |
| Infrastructure | `database` `building` `cloud` |
| Generic | `generic` `table` |

---

## Demos

Run all demos from the `demos/` directory:

```bash
# API demos (18 examples: shapes, gradients, text, PDF, compositing...)
TCLMCAIRO_LIBDIR=. tclsh demos/demo-tclmcairo.tcl

# canvas2cairo: Tk Canvas → SVG/PDF
wish demos/demo-canvas2cairo.tcl

# Interactive: Canvas vs Cairo export side by side
wish demos/canvas_explorer.tcl

# Node editor application
wish demos/nodeeditor.tcl

# Cairo samples (ports of cairographics.org examples)
TCLMCAIRO_LIBDIR=. tclsh examples/run_all.tcl
```

---

## License

tclmcairo: **BSD 2-Clause** — see `LICENSE`.

Dependencies:
- Cairo — LGPL 2.1 or MPL 1.1 (dynamically linked)
- libjpeg — IJG License (optional)
