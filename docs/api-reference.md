# tclmcairo — API Reference

Version 0.3.6 · BSD License

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

**Note:** nanosvg is used internally. Known limitations:
elliptical arc `a` with `sweep-flag=0` and smooth cubic `s` may not render correctly.
Use `svg_file_luna` for full SVG path support.

---

## Low-Level Path API

For porting Cairo C code directly.

```tcl
$ctx move_to      x y
$ctx line_to      x y
$ctx rel_move_to  dx dy
$ctx rel_line_to  dx dy
$ctx curve_to     x1 y1 x2 y2 x3 y3
$ctx rel_curve_to dx1 dy1 dx2 dy2 dx3 dy3
$ctx close_path
$ctx new_path
$ctx new_sub_path
$ctx stroke
$ctx fill
$ctx fill_preserve
$ctx stroke_preserve
$ctx set_line_width  n
$ctx set_line_cap    butt|round|square
$ctx set_line_join   miter|round|bevel
$ctx set_fill_rule   winding|evenodd
$ctx set_source_rgb  r g b
$ctx set_source_rgba r g b a
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
| `-color {r g b ?a?}` | Text color |
| `-anchor` | `center nw n ne e se s sw w` |
| `-fill` | Fill color (outline 1 only) |
| `-stroke` | Outline color (outline 1 only) |
| `-fillname name` | Gradient fill (outline 1 only) |
| `-outline 0\|1` | `0`=show_text, `1`=text_path |
| `-alpha` | Opacity |

### select_font_face
```tcl
$ctx select_font_face family ?-slant normal|italic|oblique? \
                             ?-weight normal|bold? \
                             ?-size n?
```
Direct font selection — avoids string parsing overhead in draw loops.

```tcl
$ctx select_font_face "Serif" -slant italic -weight bold -size 18
$ctx text 100 100 "Hello" -color {0 0 0}
```

### text_extents
```tcl
$ctx text_extents string ?-font fontspec?
```
Returns a dict with 9 keys:
`width height x_bearing y_bearing x_advance y_advance ascent descent line_height`

```tcl
set ext [$ctx text_extents "Hello" -font "Sans Bold 24"]
set w [dict get $ext width]
set h [dict get $ext height]
```

### font_measure
```tcl
$ctx font_measure string font -> {width height ascent descent}
```

### font_options
```tcl
$ctx font_options ?-antialias default|none|gray|subpixel|fast|good|best? \
                  ?-hint_style default|none|slight|medium|full? \
                  ?-hint_metrics default|on|off?
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

### gradient_filter
```tcl
$ctx gradient_filter name fast|good|best|nearest|bilinear
```

---

## Source / Paint

```tcl
$ctx set_source -color {r g b ?a?}
$ctx set_source -gradient name
$ctx paint ?alpha?
```

---

## Compositing Operator

```tcl
$ctx operator NAME
```

Supported operators (case-insensitive):
`OVER SOURCE CLEAR IN OUT ATOP DEST DEST_OVER DEST_IN DEST_OUT DEST_ATOP`
`XOR ADD SATURATE MULTIPLY SCREEN OVERLAY DARKEN LIGHTEN`
`COLOR_DODGE COLOR_BURN HARD_LIGHT SOFT_LIGHT DIFFERENCE EXCLUSION`
`HSL_HUE HSL_SATURATION HSL_COLOR HSL_LUMINOSITY`

---

## Transforms

```tcl
$ctx transform -translate dx dy
$ctx transform -scale sx sy
$ctx transform -rotate degrees
$ctx transform -matrix xx yx xy yy x0 y0
$ctx transform -get                    ;# -> {xx yx xy yy x0 y0}
$ctx transform -reset
```

---

## Coordinate Mapping

```tcl
$ctx user_to_device  x y   -> {dx dy}
$ctx device_to_user  dx dy -> {x y}
$ctx recording_bbox        -> {x y w h}   ;# vector mode only
$ctx path_get              -> SVG-string
$ctx surface_copy ?w h?    -> raw-id
```

---

## Images

```tcl
$ctx image      filename x y ?-width w? ?-height h? ?-alpha a?
$ctx image_data bytes    x y ?-width w? ?-height h? ?-alpha a?
$ctx image_size filename                               -> {width height}
```

`image_size` reads PNG or JPEG dimensions without drawing anything.

```tcl
lassign [$ctx image_size "photo.jpg"] w h
puts "Image: ${w}x${h}"
```

---

## SVG Rendering

### nanosvg (built-in, no dependencies)

```tcl
$ctx svg_file filename x y ?-width w? ?-height h? ?-scale s?
$ctx svg_data svgstring x y ?-width w? ?-height h? ?-scale s?
```

Renders SVG via embedded nanosvg. Supports basic shapes, fills, strokes,
gradients. Does **not** support CSS `<style>`, `<text>`, `<use>`, `<marker>`.

### lunasvg (optional, requires HAVE_LUNASVG)

```tcl
$ctx svg_file_luna filename x y ?-width w? ?-height h? ?-scale s? ?-bg 0xrrggbbaa?
$ctx svg_data_luna svgstring x y ?opts?
$ctx svg_size_luna filename -> {width height}
```

Full SVG support: CSS, text, `<use>`, `<clipPath>`, `<marker>`, system fonts.
Requires `liblunasvg.so` / `liblunasvg.dll`.

```tcl
lassign [$ctx svg_size_luna "diagram.svg"] sw sh
set ctx [tclmcairo::new [expr {int($sw*2)}] [expr {int($sh*2)}]]
$ctx svg_file_luna "diagram.svg" 0 0 -width [expr {int($sw*2)}] -height [expr {int($sh*2)}]
$ctx save "output.png"
$ctx destroy
```

### svg2cairo (Tcl module, tDOM-based)

```tcl
package require svg2cairo

svg2cairo::render   ctx filename ?-scale s? ?-x x? ?-y y? ?-width w? ?-height h?
svg2cairo::render_data ctx svgstring ?opts?
svg2cairo::size     filename       -> {width height}
svg2cairo::has_text filename       -> 0|1
```

tDOM-based SVG postprocessor. Handles CSS `<style>` (tag, .class, #id),
`<text>`, `<tspan>`, `<textPath>` fallback, 50 W3C color names.
Uses nanosvg for shapes (without CSS), tDOM for CSS-styled elements.

Requires `package require tdom`.

```tcl
package require svg2cairo

set ctx [tclmcairo::new 700 360]
svg2cairo::render $ctx "diagram.svg" -scale 2.0
$ctx save "output.png"
$ctx destroy
```

Known limitations: `<marker>`, `<use>`, `<linearGradient>` in `<defs>`,
`a sweep=0` arcs, smooth cubic `s` bezier. See `nogit/TODO-0.4.md`.

---

## Blit

```tcl
$ctx blit src x y ?-alpha a? ?-width w? ?-height h?
```

---

## Error Handling

All unknown options and invalid values raise `TCL_ERROR`.

---

## canvas2cairo

See `docs/canvas2cairo.md`.

```tcl
package require canvas2cairo
canvas2cairo::export .c output.svg
canvas2cairo::render .c $ctx
```

## shape_renderer

```tcl
package require shape_renderer
shape_renderer::draw $ctx type x y w h ?opts?
```

Shapes: `router switch server firewall database workstation generic table`
`printer scanner accesspoint phone wifi fiber building`

## svg2cairo

See SVG Rendering section above and `nogit/TODO-0.4.md` for known limitations.
