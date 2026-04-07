# tkmcairo — API Reference

Version 0.1 · BSD License

---

## Create / Destroy Context

```tcl
tkmcairo::new width height ?-mode raster|vector?  -> ctx
$ctx destroy
```

**-mode raster** (default): ARGB32 pixel buffer in memory.
Good for PNG output and `todata` (Tk photo integration).
Transparent background if `clear` is not called.

**-mode vector**: Cairo Recording Surface. All drawing commands are
stored as vectors. Saving as PDF/SVG/PS/EPS produces true vector output —
scalable without quality loss.

---

## Basic Operations

```tcl
$ctx size              -> {width height}
$ctx clear r g b ?a?   ;# background color (0.0-1.0)
$ctx save filename     ;# .png .pdf .svg .ps .eps
$ctx todata            ;# bytearray ARGB32 (raster mode only)
```

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

### text
```tcl
$ctx text x y string ?opts?
```
x/y is the anchor point (see `-anchor`).

---

## Options

All invalid option names and values raise a Tcl error.

| Option | Type | Description |
|--------|------|-------------|
| `-fill` | `{r g b ?a?}` | Fill color (0.0–1.0 each) |
| `-stroke` | `{r g b ?a?}` | Stroke color |
| `-color` | `{r g b ?a?}` | Text / line color |
| `-width` | double | Line width in px (default 1.0) |
| `-alpha` | 0.0–1.0 | Global transparency (validated) |
| `-radius` | double | Corner radius (`rect` only) |
| `-font` | string | Font spec (see below) |
| `-anchor` | string | Text anchor point (see below) |
| `-fillname` | string | Gradient name as fill |
| `-dash` | list | Dash pattern `{on off ...}` in px |
| `-linecap` | string | `butt` \| `round` \| `square` |
| `-linejoin` | string | `miter` \| `round` \| `bevel` |

**Colors:** all values 0.0–1.0. Alpha optional (default 1.0).
```tcl
{1 0 0}        ;# red, opaque
{0 0.5 1 0.8}  ;# blue, 80% opaque
```

**-linecap / -linejoin:** validated — invalid values raise error.

**-alpha:** validated 0.0–1.0 — values outside range raise error.

**-dash:** tolerant — invalid elements truncate the list (by design).

---

## Text

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

Transforms accumulate:
```tcl
$ctx transform -translate 100 100
$ctx transform -rotate 45
$ctx circle 0 0 50 -fill {1 0 0}   ;# at (100,100), rotated
$ctx transform -reset
```

---

## Output Formats

| Extension | Format | Mode | Notes |
|-----------|--------|------|-------|
| `.png` | PNG | Raster | ARGB32, transparent if no clear |
| `.pdf` | PDF | Vector* | *true vectors if `-mode vector` |
| `.svg` | SVG | Vector* | |
| `.ps`  | PostScript | Vector* | for printing |
| `.eps` | Encapsulated PS | Vector* | for LaTeX, InDesign etc. |

In raster mode, all formats embed a bitmap.

---

## todata — Tk Photo Integration

```tcl
set ctx [tkmcairo::new 200 100]
$ctx clear 0 0 0
$ctx circle 100 50 40 -fill {1 0.5 0}
set data [$ctx todata]    ;# bytearray ARGB32 (raster mode only)
$ctx destroy
```

Cairo uses ARGB32 (little-endian BGRA). To display in Tk photo,
convert to RGBA first (platform-dependent byte swap).

---

## Error Handling

tkmcairo follows strict Tcl conventions — all errors raise `TCL_ERROR`:

```tcl
# Unknown option
$ctx rect 10 10 100 50 -flll {1 0 0}
# -> unknown option "-flll"

# Invalid color
$ctx rect 10 10 100 50 -fill {1 x 0}
# -> expected floating-point number but got "x"

# Too few color components
$ctx rect 10 10 100 50 -fill {1 0}
# -> color must be {r g b} or {r g b a}

# Alpha out of range
$ctx rect 10 10 100 50 -alpha 5
# -> -alpha must be 0.0..1.0

# Invalid linecap
$ctx line 0 0 100 100 -linecap foo
# -> invalid -linecap: foo (butt|round|square)

# Poly: too few points
$ctx poly 10 10 50 50
# -> poly: need at least 3 coordinate pairs (6 values)

# Odd option list
$ctx rect 10 10 100 50 -fill
# -> option without value (odd number of option arguments)
```

---

## Example: Chart

```tcl
package require tkmcairo

set ctx [tkmcairo::new 500 350 -mode vector]
$ctx clear 0.95 0.95 0.95

$ctx text 250 30 "Quarterly Revenue 2026" \
    -font "Sans Bold 16" -color {0.1 0.1 0.3} -anchor center

set data   {120 180 150 210}
set colors {{0.2 0.5 0.9} {0.3 0.7 0.4} {0.9 0.6 0.1} {0.8 0.3 0.3}}
set labels {Q1 Q2 Q3 Q4}
set x 60

foreach val $data color $colors label $labels {
    set h [expr {$val * 1.2}]
    set y [expr {320 - $h}]
    $ctx rect $x $y 80 $h -fill $color -radius 4
    $ctx text [expr {$x+40}] [expr {$y-10}] "${val}k" \
        -font "Sans Bold 11" -color {0.2 0.2 0.2} -anchor center
    $ctx text [expr {$x+40}] 338 $label \
        -font "Sans 12" -color {0.3 0.3 0.3} -anchor center
    incr x 110
}

$ctx line 40 320 480 320 -color {0.4 0.4 0.4} -width 1.5

$ctx save "chart.pdf"
$ctx save "chart.svg"
$ctx save "chart.png"
$ctx destroy
```
