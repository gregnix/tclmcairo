# canvas2cairo — API Reference

Version 0.1 · tclmcairo 0.3.2 · BSD License · Requires: tclmcairo + Tk

---

## Overview

`canvas2cairo` exports any Tk Canvas widget to SVG, PDF, PS, EPS, or PNG using
tclmcairo as the rendering backend. Vector formats (SVG, PDF, PS, EPS) produce
true vector output — no rasterization occurs.

The Canvas does not need to be visible on screen. Size is read from
`[$canvas cget -width]` / `[$canvas cget -height]`.

```tcl
package require canvas2cairo
```

---

## export

```tcl
canvas2cairo::export canvas filename
```

Exports the canvas to a file. The output format is determined by the
file extension:

| Extension | Format | Type |
|-----------|--------|------|
| `.svg` | SVG | vector |
| `.pdf` | PDF | vector |
| `.ps` | PostScript | vector |
| `.eps` | EPS | vector |
| `.png` | PNG | raster (white background) |

```tcl
canvas2cairo::export .c output.svg
canvas2cairo::export .c output.pdf
canvas2cairo::export .c output.png

# HiDPI export (2× resolution)
canvas2cairo::export .c output.png -scale 2.0

# Export a specific region only
canvas2cairo::export .c output.svg -viewport {50 50 600 400}

# Combined: region + scale
canvas2cairo::export .c output.png -viewport {0 0 400 300} -scale 2.0
```

**Options:**

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `-scale` | float | `1.0` | Output scale factor (HiDPI) |
| `-viewport` | `{x1 y1 x2 y2}` | — | Export only this canvas region |

**Canvas size:** reads `[$canvas cget -width/height]`. Scrollregion is honoured
(including negative origins like `{-500 -500 1000 1000}`).

---

## render

```tcl
canvas2cairo::render canvas ctx
canvas2cairo::render canvas ctx -clip {x1 y1 x2 y2}
```

Renders the canvas into an existing tclmcairo context. Useful for:
- Embedding a canvas into a larger document
- Placing a canvas at a specific position on a page
- Combining multiple canvases on one page

The optional `-clip` argument restricts rendering to the given canvas
coordinate region. Items completely outside the clip are skipped.

```tcl
# Embed canvas in a PDF page with a title above it
set ctx [tclmcairo::new 595 842 -mode pdf -file "report.pdf"]
$ctx clear 1 1 1
$ctx text 297 40 "Q3 Results" -font {Sans 20 bold} \
    -color {0 0 0} -anchor center
$ctx push
$ctx transform -translate 47 60
canvas2cairo::render .chart $ctx
$ctx pop
$ctx finish
$ctx destroy

# Render only a region of the canvas
canvas2cairo::render .canvas $ctx -clip {100 100 600 500}
```

---

## Supported Canvas Items

| Item | Support | Notes |
|------|---------|-------|
| `rectangle` | ✔ | fill, outline, width, dash |
| `oval` | ✔ | circle and ellipse |
| `line` | ✔ | dash, capstyle, joinstyle, smooth, arrow |
| `polygon` | ✔ | fill, outline, smooth |
| `text` | ✔ | font, color, anchor, -angle, -width wrapping, multiline |
| `arc` | ✔ | pieslice, chord, arc styles |
| `image` | ✔ | photo images embedded as pixel data |
| `bitmap` | — | skipped |
| `window` | — | skipped (embedded widgets not exportable) |

---

## Item Options Mapping

| Tk Canvas option | canvas2cairo | Notes |
|-----------------|-------------|-------|
| `-fill` | `-fill {r g b}` | via `winfo rgb` conversion |
| `-outline` | `-stroke {r g b}` | |
| `-width` | `-width n` | |
| `-dash` | `-dash {on off ...}` | Tk pattern chars → numeric list |
| `-dashoffset` | `-dash_offset n` | |
| `-capstyle butt/projecting/round` | `-linecap butt/square/round` | `projecting` → `square` |
| `-joinstyle miter/bevel/round` | `-linejoin miter/bevel/round` | direct mapping |
| `-smooth` | Bézier approximation | quadratic via midpoints |
| `-arrow first/last/both` | polygon arrowhead | size from `-width` |
| `-anchor` | `-anchor` | all 9 positions |
| `-angle` | `transform -rotate` | via push/transform/pop |
| `-width` (text) | `_wrap_text` word-wrap | uses `font measure` |
| `-state hidden` | skipped | item not rendered |
| `-stipple` | — | not supported, renders solid |
| `-justify left/center/right` | per-line x offset | multiline text only |
| `-underline n` | line under char n | |
| `-arrowshape {d1 d2 d3}` | custom arrow size | d1=tip d2=wing d3=width |

---

## Known Differences: Tk vs Cairo

These differences were discovered during canvas2cairo development.
See `docs/canvas2cairo-erkenntnisse.md` for full details.

### 1. PNG Export

`.png` extension produces raster output via `tclmcairo::new` + `$ctx save`.
White background, pixel-exact.

### 2. Image Items

`$img data -format png` returns base64 in Tk, not raw bytes.
`binary decode base64` produces a string, not a bytearray — libpng rejects it.

**Fix:** `$img write $tmpf -format png` → `open rb` → `read` → raw bytes → `image_data`.

### 3. Oval Stroke Bleeding

An oval with `-outline white` on a node edge: Cairo renders stroke 0.5px
inside the oval boundary, which bleeds into adjacent items.
Tk hides this because the node body repaints over it (retained mode).

**Fix:** Use `-outline ""` with two concentric ovals as fills only.

### 4. Z-Order

`$canvas raise node` pushes all items tagged `node` to the top — including
background rectangles that cover icons drawn before them.

**Fix:** Draw items in strict Z-order inside `drawNode`; only use global
`lower/raise` for top-level layers (grid, edges, ports).

### 5. Text Wrapping (-width)

Tk Canvas `-width` auto-wraps text. canvas2cairo ignored this option.

**Fix:** `_wrap_text` proc uses `font measure` (with original Tk font, not
Cairo font string) to compute line breaks.

```tcl
# Use original Tk font for measurement:
set text [_wrap_text $text $font $width]   ;# $font = Tk font, not Cairo string
```

### 6. Multiline Text

`cairo_show_text` is single-line — `\n` is rendered as a glyph, not a newline.

**Fix:** Split text at `\n`, render each line individually with Y-offset:
```tcl
set lines [split $text "\n"]
set line_height [expr {$fsize * 1.3}]
set y0 [expr {$y - [llength $lines] * $line_height / 2.0 + $fsize * 0.5}]
foreach line $lines {
    $ctx text $x $y0 $line {*}$opts
    set y0 [expr {$y0 + $line_height}]
}
```

### 7. edgehit Lines with Stipple

Wide hit-area lines with `-fill "#ffffff" -stipple gray12`:
Tk renders them transparent (stipple = dotted pattern).
Cairo renders stipple as a solid white line.

**Fix:** Delete `edgehit` items before export, recreate after:
```tcl
$canvas delete edgehit          ;# before export
# ... export ...
drawEdges                       ;# after export (recreates edgehit)
```

### 8. window/bitmap Items

Canvas `window` items (embedded Tk widgets) cannot be exported to vector.
canvas2cairo skips them with an optional stderr message.

```tcl
# Uncomment in canvas2cairo-0.1.tm to debug:
# puts stderr "canvas2cairo: skipping window item $id"
```

### 9. Scroll Position

When a canvas is scrolled, `canvasx(0)/canvasy(0)` gives the current origin.
`render` reads this automatically — the export reflects the current scroll
position unless `-viewport` is specified.

### 10. Negative Scrollregion

Scrollregions with negative origins (e.g. `{-500 -500 1000 1000}`) are handled
correctly — the origin offset is applied as a translation.

### 11. polygon -fill ""

An empty fill string means transparent (no fill), not black.
Only the outline is drawn.

### 12. -smooth raw

Tk `-smooth raw` passes explicit cubic Bézier control points.
canvas2cairo converts these to SVG `C` path commands correctly.

### 13. -smooth 1

Tk B-spline: original points are control points, midpoints are on-curve.
canvas2cairo 0.3.2 uses **Catmull-Rom** spline — the curve passes through
all original points (tension 0.5), mapped to cubic Bézier segments.
More accurate than the previous quadratic B-spline approximation.

### 14. Performance: bbox clipping

Items completely outside the export viewport are skipped.
The clip region is derived from the `-viewport` option, not the widget size.
(Using widget size as clip was a bug — it caused items at off-screen canvas
coordinates to be silently dropped.)

---

## Arc Styles

```tcl
# pieslice (default): filled sector
.c create arc 10 10 190 190 -start 0 -extent 270 -style pieslice -fill blue

# chord: arc closed with a straight line
.c create arc 10 10 190 190 -start 30 -extent 200 -style chord -fill green

# arc: open arc, stroke only
.c create arc 10 10 190 190 -start 45 -extent 270 -style arc -outline red -width 3
```

**Note on angles:** Tk angles are counter-clockwise from 3 o'clock.
Cairo angles are clockwise. canvas2cairo converts automatically.

---

## Color Conversion

Tk colors (`red`, `#336699`, `SystemButtonFace`) are converted to
Cairo `{r g b}` using `winfo rgb`.

---

## Font Conversion

Tk font specs are converted via `font actual`:

```tcl
# Tk font spec       -> Cairo font string
{Sans 14}            -> "Sans 14"
{Sans 16 bold}       -> "Sans Bold 16"
{Courier 12 italic}  -> "Courier Italic 12"
```

**Font size:** Tk reports sizes in points (positive) or pixels (negative).
canvas2cairo uses points directly — Cairo renders them correctly at 72 DPI.

---

## Headless Operation

The Canvas does not need to be visible:

```tcl
wm withdraw .
canvas .c -width 800 -height 600
.c create rectangle 50 50 750 550 -fill "#336699"
update idletasks   ;# important before export
canvas2cairo::export .c output.svg
```

**Call `update idletasks` before export** — ensures Tk has fully rendered
all items (especially important for image items).

---

## Complete Example

```tcl
package require canvas2cairo

wm withdraw .

canvas .chart -width 500 -height 350 -background "#0d1117"
.chart create rectangle 0 0 500 350 -fill "#0d1117" -outline ""
.chart create text 250 30 -text "Monthly Sales" \
    -font {Sans 16 bold} -fill "#c9d1d9" -anchor center

set data {42 78 55 91 67 83 49 72 88 61 94 76}
set x 40
foreach val $data {
    set barh [expr {$val * 2.5}]
    .chart create rectangle $x [expr {320-$barh}] [expr {$x+28}] 320 \
        -fill "#58a6ff" -outline ""
    incr x 38
}
.chart create line 35 320 495 320 -fill "#8b949e" -width 1
.chart create line 35  50  35 320 -fill "#8b949e" -width 1

update idletasks
canvas2cairo::export .chart sales.svg
canvas2cairo::export .chart sales.pdf
canvas2cairo::export .chart sales.png
```
