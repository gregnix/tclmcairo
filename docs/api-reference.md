# tclmcairo — API Reference

Version 0.2 · BSD License

---

## Create / Destroy Context

```tcl
tclmcairo::new width height ?opts?
$ctx destroy
```

**Options:**

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `-mode` | `raster\|vector\|pdf\|svg\|ps\|eps` | `raster` | Output mode |
| `-file` | filename | — | Required for `pdf\|svg\|ps\|eps` |
| `-format` | `argb32\|rgb24\|a8` | `argb32` | Raster pixel format |
| `-svg_version` | `1.1\|1.2` | `1.2` | SVG spec version (svg mode only) |
| `-svg_unit` | `pt\|px\|mm\|cm\|in\|em\|ex\|pc` | `pt` | SVG document unit (svg mode only) |

| Mode | Description |
|------|-------------|
| `raster` | ARGB32 pixel buffer. For PNG, `todata`, `topng`. |
| `vector` | Recording surface. Save to any format as true vectors. |
| `pdf` | Direct PDF file. Requires `-file`. Multi-page via `newpage`. |
| `svg` | Direct SVG file. Requires `-file`. Multi-page via `newpage`. |
| `ps` | Direct PostScript file. Requires `-file`. |
| `eps` | Direct EPS file. Requires `-file`. |

**`-format` (raster mode only):**

| Value | Description |
|-------|-------------|
| `argb32` | 32-bit with alpha (default, transparent background) |
| `rgb24` | 32-bit without alpha (solid background, no transparency) |
| `a8` | 8-bit alpha only (mask surface) |

```tcl
# Raster — PNG + todata + topng
set ctx [tclmcairo::new 400 300]
set ctx [tclmcairo::new 400 300 -format rgb24]   ;# no alpha channel

# Vector — all formats, true scalable output
set ctx [tclmcairo::new 400 300 -mode vector]

# Direct PDF file — multi-page
set ctx [tclmcairo::new 595 842 -mode pdf -file "doc.pdf"]

# Direct SVG — with unit and version
set ctx [tclmcairo::new 210 297 -mode svg -file "a4.svg" \
    -svg_unit mm -svg_version 1.1]
# -> <svg width="210mm" height="297mm" ...>
```

**`-svg_unit` note:** The unit appears in the SVG `width`/`height` attributes.
Default is `pt` for historical reasons. Use `px` or `mm` for screen/print work.

**`-svg_version` note:** Controls which Cairo features are used internally.
Does not write a `version` attribute to the SVG file.

---

## Basic Operations

```tcl
$ctx size              -> {width height}
$ctx clear r g b ?a?   ;# background color (0.0-1.0)
$ctx save filename     ;# .png .pdf .svg .ps .eps
$ctx todata            ;# bytearray ARGB32 raw pixels (raster only)
$ctx topng             ;# bytearray PNG-compressed (raster + vector)
$ctx newpage           ;# next page (pdf|svg|ps|eps mode only)
$ctx finish            ;# flush + close file (pdf|svg|ps|eps mode)
```

`destroy` calls `finish` automatically if not already done.

**`topng` vs `todata`:**

| Command | Returns | Use case |
|---------|---------|----------|
| `todata` | Raw ARGB32 bytes, stride × height | Tk photo (`-data`) |
| `topng` | PNG-compressed bytes | HTTP, DB, `image_data`, roundtrip |

```tcl
# topng: PNG bytes without writing a file
set bytes [$ctx topng]
set f [open "out.png" wb]; puts -nonewline $f $bytes; close $f

# topng works on vector mode too (renders to raster first)
set ctx [tclmcairo::new 400 300 -mode vector]
$ctx rect 10 10 380 280 -fill {0.2 0.5 1}
set bytes [$ctx topng]   ;# -> PNG bytes
```

---

## State Stack

```tcl
$ctx push   ;# cairo_save  — save transform, clip, color state
$ctx pop    ;# cairo_restore
```

```tcl
$ctx push
$ctx transform -rotate 45
$ctx clip_rect 0 0 200 200
$ctx circle 100 100 80 -fill {1 0.5 0}
$ctx pop    ;# rotation + clip gone
```

---

## Clip Regions

```tcl
$ctx clip_rect x y w h         ;# rectangular clip
$ctx clip_path svgdata          ;# arbitrary shape as clip mask
$ctx clip_reset                 ;# remove all clips
```

Always use `push`/`pop` around clip operations to restore state:
```tcl
$ctx push
$ctx clip_rect 50 50 300 200
$ctx circle 200 150 180 -fill {1 0.3 0.1}
$ctx clip_reset
$ctx pop
```

---

## Blit (Layer Compositing)

```tcl
$ctx blit src_ctx x y ?-alpha a? ?-width w? ?-height h?
```

Composites `src_ctx` onto `$ctx` at position (x, y). Both raster and
vector sources are supported. `dst` and `src` must be different contexts.

| Option | Default | Description |
|--------|---------|-------------|
| `-alpha` | `1.0` | Compositing opacity 0.0–1.0 |
| `-width` | src width | Scale to width |
| `-height` | src height | Scale to height |

```tcl
# Layer model: sky + mountains + clouds each on own context
set sky   [tclmcairo::new 600 400]
set fg    [tclmcairo::new 600 400]   ;# transparent

$sky gradient_linear bg 0 0 0 400 {{0 0.5 0.7 1 1} {1 0.7 0.9 1 1}}
$sky rect 0 0 600 400 -fillname bg

$fg circle 500 80 60 -fill {1 1 0.8 0.9}   ;# sun

# Composite fg onto sky
$sky blit $fg 0 0
$sky blit $overlay 0 0 -alpha 0.6

$sky save "composite.png"
$sky destroy; $fg destroy
```

**Note:** File-mode contexts (pdf|svg|ps|eps) cannot be used as `src`.

---

## Shapes

### rect
```tcl
$ctx rect x y w h ?opts?
```
Rectangle. `-radius` for rounded corners.

### line
```tcl
$ctx line x1 y1 x2 y2 ?opts?
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
Arc from `start_deg` to `end_deg` (0 = right, clockwise).

### poly
```tcl
$ctx poly x1 y1 x2 y2 x3 y3 ... ?opts?
```
Filled/outlined polygon. **Minimum 3 points (6 coordinate values).**

### path
```tcl
$ctx path svgdata ?opts?
```
SVG path syntax. Supported commands:

| Command | Description |
|---------|-------------|
| `M x y` | Move to (absolute) |
| `m x y` | Move to (relative) |
| `L x y` | Line to (absolute) |
| `l x y` | Line to (relative) |
| `H x` | Horizontal line |
| `V y` | Vertical line |
| `C x1 y1 x2 y2 x y` | Cubic Bezier |
| `Q x1 y1 x y` | Quadratic Bezier |
| `A rx ry rot large sweep x y` | Elliptical arc (xrot ignored) |
| `Z` | Close path |

Uppercase = absolute coordinates, lowercase = relative.

---

## Images

```tcl
$ctx image filename x y ?-width w? ?-height h? ?-alpha a?
```

Loads and draws an image at (x, y).

| Format | Support |
|--------|---------|
| PNG | always (via Cairo) |
| JPEG | if built with `HAVE_LIBJPEG` (default on Linux/MSYS2) |

```tcl
$ctx image "foto.png" 10 10
$ctx image "foto.jpg" 100 50 -width 200 -height 150
$ctx image "logo.png" 300 20 -alpha 0.7
```

In PDF/SVG mode, JPEG is embedded as MIME data — no re-encoding,
no quality loss. PNG is re-encoded as pixel data in PDF (Cairo limitation);
in SVG both JPEG and PNG are embedded as base64 MIME data.

---

## image_data

```tcl
$ctx image_data bytes x y ?-width w? ?-height h? ?-alpha a?
```

Draws a PNG from a bytearray — no filename needed. Useful for in-memory
pipelines, network data, or roundtrip with `topng`.

```tcl
# Roundtrip: draw -> topng -> image_data
set src [tclmcairo::new 100 100]
$src circle 50 50 40 -fill {1 0.5 0}
set bytes [$src topng]
$src destroy

set dst [tclmcairo::new 400 300]
$dst clear 0.1 0.1 0.2
$dst image_data $bytes  10 10
$dst image_data $bytes 120 10 -width 80 -alpha 0.7
$dst image_data $bytes 210 10 -width 60 -height 60
$dst save "out.png"
$dst destroy
```

---

## Text

### text
```tcl
$ctx text x y string ?opts?
```
x/y is the anchor point (see `-anchor`).

**`-outline` option** controls the rendering backend:

| `-outline` | Cairo API | Supports |
|------------|-----------|----------|
| `0` (default) | `cairo_show_text` | `-color` only |
| `1` | `cairo_text_path` | `-fill`, `-stroke`, `-fillname` (gradient) |

```tcl
# Standard: single color
$ctx text 200 60 "Hello" -font "Sans Bold 18" -color {0 0 0}

# Outline mode: fill + stroke
$ctx text 200 60 "Hello" -font "Sans Bold 18" \
    -fill {1 0.8 0.2} -stroke {0.8 0.3 0} -width 1.5 -outline 1

# Outline mode: gradient fill
$ctx gradient_linear g 0 0 400 0 {{0 1 0.3 0 1} {1 0 0.3 1 1}}
$ctx text 200 60 "GRADIENT" -font "Sans Bold 28" \
    -fillname g -outline 1 -anchor center
```

**Note on SVG output:** Cairo's SVG backend always writes text as path
outlines regardless of `-outline` value. The difference is purely in
what drawing options are available in Tcl.

### text_path
```tcl
$ctx text_path x y string ?opts?
```
Always uses `cairo_text_path`. Equivalent to `text ... -outline 1`.
Useful when you always want path-based rendering without `-outline 1`.

### Font spec
```tcl
"Sans 14"
"Sans Bold 18"
"Sans Italic 12"
"Sans Bold Italic 14"
"DejaVu Sans 16"
"Monospace 12"
```
Format: `"Family ?Bold? ?Italic? ?Oblique? Size"`

### Anchors
```
nw    n    ne
 w  center  e
sw    s    se
```
Default anchor: `sw` (baseline-left, Cairo default).

### font_measure
```tcl
$ctx font_measure string font -> {width height ascent descent}
```
Returns exact Cairo text metrics in pixels (as doubles).

---

## Options

All invalid option names and values raise a Tcl error.

| Option | Type | Applies to | Description |
|--------|------|------------|-------------|
| `-fill` | `{r g b ?a?}` | shapes, text(-outline 1) | Fill color |
| `-stroke` | `{r g b ?a?}` | shapes, text(-outline 1) | Stroke color |
| `-color` | `{r g b ?a?}` | text, line | Text/line color |
| `-width` | double | line, stroke | Line width in px (default 1.0) |
| `-alpha` | 0.0–1.0 | all | Global transparency |
| `-radius` | double | rect | Corner radius |
| `-font` | string | text | Font spec |
| `-anchor` | string | text | Anchor point |
| `-fillname` | string | shapes, text(-outline 1) | Gradient as fill |
| `-dash` | list | line, stroke | Dash pattern `{on off ...}` |
| `-linecap` | string | line | `butt` \| `round` \| `square` |
| `-linejoin` | string | stroke | `miter` \| `round` \| `bevel` |
| `-fillrule` | string | path, poly | `winding` \| `evenodd` |
| `-outline` | bool | text | `0`=show_text `1`=text_path |

**Colors:** all values 0.0–1.0. Alpha optional (default 1.0).
```tcl
{1 0 0}        ;# red, opaque
{0 0.5 1 0.8}  ;# blue, 80% opaque
```

---

## Gradients

```tcl
$ctx gradient_linear name x1 y1 x2 y2 stops
$ctx gradient_radial  name cx cy r stops
```

**stops:** list of `{offset r g b a}` — offset 0.0–1.0.
```tcl
{{0 1 0 0 1} {0.5 1 1 0 1} {1 0 0 1 1}}
```

Use gradient as fill with `-fillname`:
```tcl
$ctx gradient_linear mygrad 0 0 400 0 {{0 1 0 0 1} {1 0 0 1 1}}
$ctx rect 0 0 400 100 -fillname mygrad
$ctx text 200 60 "TITLE" -font "Sans Bold 32" \
    -fillname mygrad -outline 1 -anchor center
```

Redefining a gradient by name replaces it.
Maximum 64 gradients per context.

---

## Transforms

```tcl
$ctx transform -translate x y
$ctx transform -scale sx sy
$ctx transform -rotate deg     ;# degrees (not radians)
$ctx transform -reset          ;# identity matrix
```

Transforms accumulate. Use `push`/`pop` to scope them:
```tcl
$ctx push
$ctx transform -translate 100 100
$ctx transform -rotate 45
$ctx circle 0 0 50 -fill {1 0 0}
$ctx pop
```

---

## Output Formats

| Extension | Format | Notes |
|-----------|--------|-------|
| `.png` | PNG | ARGB32, transparent if `clear` not called |
| `.pdf` | PDF | True vectors in vector/pdf mode |
| `.svg` | SVG | True vectors in vector/svg mode |
| `.ps` | PostScript | For printing |
| `.eps` | EPS | For LaTeX, InDesign |

**`save` vs file-mode:**
```tcl
# save: works with any mode, exports snapshot
$ctx save "output.pdf"

# file-mode: writes directly, supports newpage
set ctx [tclmcairo::new 595 842 -mode pdf -file "doc.pdf"]
$ctx newpage
$ctx finish
```

---

## PNG with Transparency

Cairo's raster mode uses ARGB32 — full alpha channel support.

**Rule: No `clear` call = transparent background.**

```tcl
# Transparent background (no clear)
set ctx [tclmcairo::new 200 200]
$ctx circle 100 100 80 -fill {1 0.5 0}        ;# fully opaque
$ctx circle  50  50 30 -fill {0 0.5 1 0.5}    ;# 50% transparent
$ctx save "icon.png"
$ctx destroy
```

```tcl
# Explicit transparent background
set ctx [tclmcairo::new 300 100]
$ctx clear 0 0 0 0    ;# r g b alpha=0 -> transparent
$ctx text 150 60 "PNG!" -font "Sans Bold 24" \
    -color {1 1 1} -anchor center
$ctx save "label.png"
$ctx destroy
```

```tcl
# Semi-transparent shadow effect
set ctx [tclmcairo::new 300 150]
# Background stays transparent (no clear)
$ctx rect 40 30 220 90 -fill {0 0 0 0.4} -radius 8   ;# shadow, alpha=0.4
$ctx rect 30 20 220 90 -fill {0.2 0.5 1} -radius 8   ;# box, fully opaque
$ctx text 140 72 "Card" -font "Sans Bold 18" \
    -color {1 1 1} -anchor center
$ctx save "card.png"    ;# shadow area: alpha ~102 (=0.4*255)
$ctx destroy
```

**Alpha values verified:**

| Area | Alpha |
|------|-------|
| Background (no clear) | 0 — fully transparent |
| `clear 0 0 0 0` | 0 — fully transparent |
| `-fill {r g b 0.5}` | 128 — 50% transparent |
| `-fill {r g b 0.4}` shadow | 102 — 40% transparent |
| `-fill {r g b}` (no alpha) | 255 — fully opaque |

---

## todata — Tk Photo Integration

```tcl
set ctx [tclmcairo::new 200 100]
$ctx clear 0 0 0
$ctx circle 100 50 40 -fill {1 0.5 0}
set data [$ctx todata]    ;# bytearray ARGB32 (raster mode only)
$ctx destroy
```

Cairo uses ARGB32 (little-endian: B G R A byte order).
To display in Tk photo, convert BGRA→RGBA first.

---

## Error Handling

tclmcairo follows strict Tcl conventions — all errors raise `TCL_ERROR`:

```tcl
$ctx rect 10 10 100 50 -flll {1 0 0}
# -> unknown option "-flll"

$ctx rect 10 10 100 50 -fill {1 x 0}
# -> expected floating-point number but got "x"

$ctx rect 10 10 100 50 -fill {1 0}
# -> color must be {r g b} or {r g b a}

$ctx rect 10 10 100 50 -alpha 5
# -> -alpha must be 0.0..1.0

$ctx line 0 0 100 100 -linecap foo
# -> invalid -linecap: foo (butt|round|square)

$ctx path "M 10 10 Z" -fillrule nonsense
# -> invalid -fillrule: nonsense (winding|evenodd)

$ctx poly 10 10 50 50
# -> poly: need at least 3 coordinate pairs (6 values)

$ctx newpage    ;# on raster context
# -> newpage only valid for -mode pdf|svg|ps|eps
```

---

## Example: Multi-page Report

```tcl
package require tclmcairo

set ctx [tclmcairo::new 595 842 -mode pdf -file "report.pdf"]

foreach {title color} {
    "Q1 Results" {0.2 0.5 0.9}
    "Q2 Results" {0.3 0.7 0.4}
    "Q3 Results" {0.9 0.6 0.1}
} {
    $ctx clear 1 1 1
    $ctx rect 0 0 595 60 -fill $color
    $ctx text 297 38 $title -font "Sans Bold 20" \
        -color {1 1 1} -anchor center
    $ctx newpage
}

$ctx finish
$ctx destroy
```

## Example: Gradient Text

```tcl
package require tclmcairo

set ctx [tclmcairo::new 500 120 -mode vector]
$ctx clear 0.05 0.05 0.1

$ctx gradient_linear g 0 0 500 0 \
    {{0 1 0.3 0 1} {0.5 0.2 0.8 1 1} {1 1 0.8 0 1}}

$ctx text 250 80 "tclmcairo" \
    -font "Sans Bold 64" \
    -fillname g \
    -stroke {0.2 0.2 0.3} -width 1 \
    -outline 1 -anchor center

$ctx save "title.svg"
$ctx save "title.pdf"
$ctx save "title.png"
$ctx destroy
```
