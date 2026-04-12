# tclmcairo — API Reference

Version 0.3.3 · BSD License

---

## Create / Destroy

```tcl
tclmcairo::new width height ?opts?
$ctx destroy
```

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `-mode` | `raster\|vector\|pdf\|svg\|ps\|eps` | `raster` | Output mode |
| `-file` | filename | — | Required for `pdf\|svg\|ps\|eps` |
| `-format` | `argb32\|rgb24\|a8` | `argb32` | Raster pixel format |
| `-svg_version` | `1.1\|1.2` | `1.2` | SVG spec version |
| `-svg_unit` | `pt\|px\|mm\|cm\|in\|em\|ex\|pc` | `pt` | SVG document unit |

```tcl
set ctx [tclmcairo::new 400 300]                          ;# raster ARGB32
set ctx [tclmcairo::new 400 300 -format rgb24]            ;# no alpha
set ctx [tclmcairo::new 400 300 -mode vector]             ;# vector recording
set ctx [tclmcairo::new 595 842 -mode pdf -file "doc.pdf"]
set ctx [tclmcairo::new 210 297 -mode svg -file "a4.svg" -svg_unit mm]
```

---

## Basic Operations

```tcl
$ctx clear r g b ?a?   ;# background fill, 0.0-1.0
$ctx size              ;# -> {width height}
$ctx save filename     ;# .png .pdf .svg .ps .eps
$ctx save -chan ch ?-format pdf|svg|ps|eps|png?  ;# write to open channel
$ctx topng             ;# -> PNG bytearray (raster + vector)
$ctx todata            ;# -> raw ARGB32 bytes (raster only, for Tk photo)
$ctx newpage           ;# next page (pdf|svg|ps|eps)
$ctx finish            ;# flush + close file
$ctx destroy           ;# calls finish if needed
```

---

## State Stack

```tcl
$ctx push   ;# cairo_save  — saves: transform, clip, color, line settings
$ctx pop    ;# cairo_restore
```

Always wrap clips and temporary transforms in push/pop.

---

## Clip Regions

```tcl
$ctx clip_rect  x y w h     ;# rectangular clip
$ctx clip_path  svgdata      ;# arbitrary SVG path as clip mask
$ctx clip_reset              ;# remove all clips in current state
```

---

## Shapes

### Common draw options

| Option | Values | Description |
|--------|--------|-------------|
| `-fill {r g b ?a?}` | color | Fill color |
| `-stroke {r g b ?a?}` | color | Outline color |
| `-color {r g b ?a?}` | color | Line/text color |
| `-width n` | double | Stroke width (default 1.5) |
| `-alpha a` | 0.0–1.0 | Global opacity |
| `-fillname name` | string | Named gradient as fill |
| `-dash {on off ...}` | list | Dash pattern |
| `-dash_offset n` | double | Start offset into dash pattern |
| `-linecap` | `butt\|round\|square` | Line end cap |
| `-linejoin` | `miter\|round\|bevel` | Line join style |
| `-fillrule` | `winding\|evenodd` | Fill rule |
| `-radius r` | double | Rounded corners (rect only) |

### rect
```tcl
$ctx rect x y w h ?opts?
```

### circle
```tcl
$ctx circle cx cy r ?opts?
```

### ellipse
```tcl
$ctx ellipse cx cy rx ry ?opts?
```

### arc
```tcl
$ctx arc cx cy r start_deg end_deg ?opts?
```
Draws clockwise from `start_deg` to `end_deg` (0 = right).

### arc_negative
```tcl
$ctx arc_negative cx cy r start_deg end_deg ?opts?
```
Draws counter-clockwise. Equivalent to `cairo_arc_negative`.

### line
```tcl
$ctx line x1 y1 x2 y2 ?opts?
```

### poly
```tcl
$ctx poly x1 y1 x2 y2 x3 y3 ... ?opts?
```
Minimum 3 coordinate pairs.

### path
```tcl
$ctx path svgdata ?opts?
```
Full SVG path syntax: `M L H V C Q A Z` and lowercase relative variants.

```tcl
$ctx path "M 100 10 L 190 190 L 10 190 Z" -fill {0.8 0.3 0.1}
$ctx path "M 50 200 C 50 100 350 100 350 200" -stroke {0 0.5 1} -width 3
```

---

## Low-Level Path API

For porting Cairo C code directly. All commands operate on the current
path buffer — combine with `stroke`, `fill`, etc. to draw.

### Path construction
```tcl
$ctx move_to      x y
$ctx line_to      x y
$ctx rel_move_to  dx dy
$ctx rel_line_to  dx dy
$ctx curve_to     x1 y1 x2 y2 x3 y3
$ctx rel_curve_to dx1 dy1 dx2 dy2 dx3 dy3
$ctx close_path
$ctx new_path       ;# clears current path
$ctx new_sub_path   ;# starts new sub-path without moving current point
```

### Draw operations
```tcl
$ctx stroke           ;# stroke path, clear path
$ctx fill             ;# fill path, clear path
$ctx fill_preserve    ;# fill path, keep path for subsequent stroke
$ctx stroke_preserve  ;# stroke path, keep path
```

### Style setters (low-level)
```tcl
$ctx set_line_width  n
$ctx set_line_cap    butt|round|square
$ctx set_line_join   miter|round|bevel
$ctx set_fill_rule   winding|evenodd
$ctx set_source_rgb  r g b
$ctx set_source_rgba r g b a
```

```tcl
# Example: fill_and_stroke (Cairo sample port)
$ctx move_to 128 25.6
$ctx line_to 230.4 230.4
$ctx rel_line_to -102.4 0
$ctx curve_to 51.2 230.4 51.2 128 128 128
$ctx close_path

$ctx set_source_rgb 0 0 1
$ctx fill_preserve
$ctx set_source_rgb 0 0 0
$ctx set_line_width 10
$ctx stroke
```

---

## Text

```tcl
$ctx text x y string ?opts?
```

x/y is the anchor point. Default anchor: `sw` (baseline-left).

| Option | Description |
|--------|-------------|
| `-font "Family ?Bold? ?Italic? Size"` | Font spec |
| `-color {r g b ?a?}` | Text color (outline 0 only) |
| `-anchor` | `center nw n ne e se s sw w` |
| `-fill` | Fill color (outline 1 only) |
| `-stroke` | Outline color (outline 1 only) |
| `-fillname name` | Gradient fill (outline 1 only) |
| `-outline 0\|1` | `0`=`cairo_show_text`, `1`=`cairo_text_path` |
| `-alpha` | Opacity |

```tcl
# Standard text
$ctx text 200 60 "Hello" -font "Sans Bold 18" -color {0 0 0} -anchor center

# Gradient fill via text_path
$ctx gradient_linear g 0 0 400 0 {{0 1 0.9 0 1} {1 0 0.5 1 1}}
$ctx text 200 80 "GRADIENT" -font "Sans Bold 36" \
    -fillname g -outline 1 -anchor center

# Outline only
$ctx text 200 80 "OUTLINE" -font "Sans Bold 36" \
    -stroke {0.2 0.6 1} -width 2 -outline 1 -anchor center
```

### text_path
```tcl
$ctx text_path x y string ?opts?
```
Equivalent to `text ... -outline 1`.

### font_measure
```tcl
$ctx font_measure string font -> {width height ascent descent}
```

### font_options
```tcl
$ctx font_options ?-antialias default|none|gray|subpixel|fast|good|best? \
                  ?-hint_style default|none|slight|medium|full? \
                  ?-hint_metrics default|on|off?
# Without args: returns current settings as flat list
set fo [$ctx font_options]   ;# -> {-antialias gray -hint_style full ...}
```

---

## Gradients

```tcl
$ctx gradient_linear name x1 y1 x2 y2 stops
$ctx gradient_radial  name cx cy r stops
```

`stops`: list of `{offset r g b a}` — offset 0.0–1.0.

```tcl
$ctx gradient_linear g 0 0 400 0 {{0 1 0 0 1} {0.5 1 1 0 1} {1 0 0 1 1}}
$ctx gradient_radial r 200 150 100 {{0 1 0.9 0.2 1} {1 0 0 0 0}}
$ctx rect 0 0 400 300 -fillname g
```

### gradient_extend
```tcl
$ctx gradient_extend name none|pad|repeat|reflect
```
Controls how the pattern tiles outside its defined region.

### gradient_filter
```tcl
$ctx gradient_filter name fast|good|best|nearest|bilinear
```
Controls interpolation quality for image-based patterns.

---

## Source / Paint

```tcl
$ctx set_source -color {r g b ?a?}
$ctx set_source -gradient name
$ctx paint ?alpha?
```

Sets the current Cairo source without drawing, then `paint` fills the
entire surface with it.

```tcl
$ctx gradient_radial g 200 150 100 {{0 1 0.9 0 1} {1 0 0 0 0}}
$ctx set_source -gradient g
$ctx paint         ;# full opacity
$ctx paint 0.5     ;# 50% opacity
```

---

## Compositing Operator

```tcl
$ctx operator NAME
```

Sets the Cairo compositing operator. Default is `OVER`.

Supported operators (case-insensitive):
`OVER` `SOURCE` `CLEAR` `IN` `OUT` `ATOP`
`DEST` `DEST_OVER` `DEST_IN` `DEST_OUT` `DEST_ATOP`
`XOR` `ADD` `SATURATE`
`MULTIPLY` `SCREEN` `OVERLAY` `DARKEN` `LIGHTEN`
`COLOR_DODGE` `COLOR_BURN` `HARD_LIGHT` `SOFT_LIGHT`
`DIFFERENCE` `EXCLUSION`
`HSL_HUE` `HSL_SATURATION` `HSL_COLOR` `HSL_LUMINOSITY`

```tcl
$ctx operator MULTIPLY   ;# blend with background
$ctx circle 150 150 80 -fill {1 0.5 0.1 0.9}

$ctx operator OVER       ;# reset to default
```

---

## Transforms

```tcl
$ctx transform -translate dx dy
$ctx transform -scale sx sy
$ctx transform -rotate degrees         ;# clockwise, degrees
$ctx transform -matrix xx yx xy yy x0 y0   ;# affine 2x3
$ctx transform -get                    ;# -> {xx yx xy yy x0 y0}
$ctx transform -reset                  ;# identity matrix
```

The `-matrix` values map as:
```
x' = xx*x + xy*y + x0
y' = yx*x + yy*y + y0
```

```tcl
# Read current CTM
set m [$ctx transform -get]
# After -translate 30 20: -> {1.0 0.0 0.0 1.0 30.0 20.0}

# 45° rotation matrix
set r [expr {45 * 3.14159 / 180.0}]
$ctx transform -matrix [expr {cos($r)}] [expr {sin($r)}] \
               [expr {-sin($r)}] [expr {cos($r)}] 200 150
```

---

## Coordinate Mapping

```tcl
$ctx user_to_device  x y   -> {dx dy}
$ctx device_to_user  dx dy -> {x y}
```

Maps coordinates through the current transformation matrix (CTM).
Essential for mouse interaction under active transforms.

```tcl
$ctx transform -translate 100 50
$ctx transform -rotate 30
set device [$ctx user_to_device 10 20]   ;# -> device coords
set user   [$ctx device_to_user {*}$device]  ;# -> {10.0 20.0}
```

---

## recording_bbox

```tcl
$ctx recording_bbox -> {x y w h}
```

Returns the ink bounding box of a vector (recording surface) context.
Only valid on `-mode vector` contexts.

```tcl
set v [tclmcairo::new 400 300 -mode vector]
$v circle 200 150 80 -fill {0.5 0.8 0.2}
$v text 200 80 "Hello" -font "Sans Bold 24" -color {1 1 1} -anchor center
set bb [$v recording_bbox]   ;# -> {x y w h} of drawn content
```

---

## path_get

```tcl
$ctx path_get -> SVG-string
```

Returns the current Cairo path as an SVG path string.
The path is empty after `stroke`, `fill`, etc. (Cairo clears it).

```tcl
$ctx move_to 10 10; $ctx line_to 100 50
set p [$ctx path_get]   ;# -> "M 10 10 L 100 50"
```

---

## surface_copy

```tcl
$ctx surface_copy ?w h? -> raw-id
```

Creates a new blank raster context of the same pixel format.
Without `w h`: same size as source. Returns a raw C context id.

```tcl
set cid [$ctx surface_copy]          ;# same size
set cid [$ctx surface_copy 200 150]  ;# custom size

tclmcairo circle $cid 100 75 60 -fill {1 0.5 0}
tclmcairo save    $cid "copy.png"
tclmcairo destroy $cid
```

---

## Images

```tcl
$ctx image filename x y ?-width w? ?-height h? ?-alpha a?
$ctx image_data bytes x y ?-width w? ?-height h? ?-alpha a?
```

Supported formats: PNG (always), JPEG (if built with `HAVE_LIBJPEG`).

In PDF/SVG mode, JPEG is embedded as MIME data (no re-encoding).

```tcl
# In-memory PNG roundtrip
set bytes [$src topng]
$dst image_data $bytes 10 10 -width 150 -alpha 0.8
```

---

## Blit

```tcl
$ctx blit src x y ?-alpha a? ?-width w? ?-height h?
```

Composites `src` context onto `$ctx`. Both raster and vector sources work.

---

## Output

| Extension | Notes |
|-----------|-------|
| `.png` | ARGB32, transparent if `clear` not called |
| `.pdf` | True vectors in vector/pdf mode |
| `.svg` | True vectors; text always as path outlines |
| `.ps` | PostScript |
| `.eps` | For LaTeX, InDesign |

---

## Important: Path Isolation

Every high-level shape command (`rect`, `circle`, `ellipse`, `arc`,
`arc_negative`, `line`, `poly`) internally calls `cairo_new_path()` before
adding geometry. This prevents the implicit connecting line Cairo draws
between consecutive shape commands when a current point exists.

When using the **low-level path API** (`move_to`, `line_to`, `curve_to`...),
call `new_path` explicitly to start a fresh path:

```tcl
$ctx new_path
$ctx move_to 10 10
$ctx line_to 100 50
$ctx stroke
```

The high-level commands are safe to call in sequence without `new_path`:

```tcl
$ctx circle 50 50 20 -fill {1 0 0}   ;# new_path called internally
$ctx circle 100 50 20 -fill {0 1 0}  ;# new_path called internally — no stray line
```

---

## Error Handling

All unknown options and invalid values raise `TCL_ERROR`:

```tcl
$ctx rect 10 10 100 50 -flll {1 0 0}      ;# unknown option "-flll"
$ctx operator BOGUS                         ;# unknown operator "BOGUS"
$ctx gradient_extend nosuch repeat          ;# unknown gradient "nosuch"
$ctx font_options -antialias BOGUS          ;# invalid -antialias: BOGUS
$ctx set_line_cap foo                       ;# invalid linecap "foo"
$ctx recording_bbox                         ;# error on non-vector context
```

---

## Full Example

```tcl
package require tclmcairo

# Multi-operator compositing
set ctx [tclmcairo::new 400 300]
$ctx clear 0.1 0.1 0.18

$ctx gradient_linear bg 0 0 400 300 \
    {{0 0.2 0.4 0.8 1} {1 0.1 0.2 0.5 1}}
$ctx rect 0 0 400 300 -fillname bg

# Clip to oval
$ctx push
$ctx clip_path "M 200 30 A 180 120 0 1 0 200 270 A 180 120 0 1 0 200 30 Z"

$ctx operator MULTIPLY
$ctx circle 150 140 100 -fill {1 0.6 0.1 0.9}
$ctx operator SCREEN
$ctx circle 250 140 100 -fill {0.2 0.5 1.0 0.9}
$ctx operator OVER
$ctx pop

$ctx gradient_linear tg 0 0 400 0 \
    {{0 1 0.9 0.2 1} {0.5 0.5 0.3 0.9 1} {1 0.2 0.7 1 1}}
$ctx text 200 165 "tclmcairo 0.3" -font "Sans Bold 32" \
    -fillname tg -stroke {0.1 0.1 0.2} -width 1 \
    -outline 1 -anchor center

$ctx save "banner.png"
$ctx destroy
```

---

## canvas2cairo

See `docs/canvas2cairo.md` for the full canvas2cairo API reference.

Quick reference:

```tcl
package require canvas2cairo

canvas2cairo::export canvas filename   ;# .svg .pdf .ps .eps
canvas2cairo::render canvas ctx        ;# into existing tclmcairo context
```

Supported items: `rectangle` `oval` `line` `polygon` `text`
`arc` (pieslice/chord/arc) `image` (photo)

All output formats are true vectors. The canvas does not need to be
visible — size is read from `[$canvas cget -width/height]`.
