# svg2cairo — API Reference

Version 0.1 · tclmcairo 0.3.4 · BSD License · Requires: tclmcairo + tDOM

---

## Overview

`svg2cairo` is a tDOM-based SVG renderer for tclmcairo. It handles SVG features
that nanosvg (built into tclmcairo) does not support: CSS `<style>` blocks,
`<text>` / `<tspan>` elements, and inherited styles from `<g>` groups.

**Strategy:**
- SVG **without** `<style>`: nanosvg renders shapes (fast, no extra dependencies)
- SVG **with** `<style>`: tDOM pass renders all shapes with correct CSS colors;
  nanosvg is skipped to avoid wrong colors

```tcl
package require tclmcairo
package require svg2cairo
```

Requires `package require tdom` at runtime (included in BAWT 3.2 and most
Tcl distributions).

---

## render

```tcl
svg2cairo::render ctx filename ?options?
```

Renders an SVG file into an existing tclmcairo context.

| Option | Default | Description |
|--------|---------|-------------|
| `-scale s` | 1.0 | Scale factor |
| `-x x` | 0 | X offset |
| `-y y` | 0 | Y offset |
| `-width w` | 0 | Target width (0 = use SVG width) |
| `-height h` | 0 | Target height (0 = use SVG height) |
| `-shapes 0\|1` | 1 | Render shapes |
| `-text 0\|1` | 1 | Render text elements |

```tcl
package require svg2cairo

# Basic usage
set ctx [tclmcairo::new 700 360]
svg2cairo::render $ctx "diagram.svg" -scale 2.0
$ctx save "output.png"
$ctx destroy

# Into existing context at offset
svg2cairo::render $ctx "logo.svg" -x 50 -y 20 -width 200 -height 100
```

---

## render_data

```tcl
svg2cairo::render_data ctx svgstring ?options?
```

Same as `render` but takes an SVG string instead of a filename.

```tcl
set svgdata [read [open "file.svg"]]
svg2cairo::render_data $ctx $svgdata -scale 2.0
```

---

## size

```tcl
svg2cairo::size filename -> {width height}
```

Returns the SVG document dimensions from `width` / `height` attributes,
or from `viewBox` if width/height are missing.

```tcl
lassign [svg2cairo::size "diagram.svg"] sw sh
set ctx [tclmcairo::new [expr {int($sw*2)}] [expr {int($sh*2)}]]
```

---

## has_text

```tcl
svg2cairo::has_text filename -> 0|1
```

Returns 1 if the SVG contains `<text>` elements. Used to decide whether
tDOM is needed.

---

## Supported SVG Elements

| Element | Support | Notes |
|---------|---------|-------|
| `<rect>` | ✔ | incl. `rx`/`ry` rounded corners |
| `<circle>` | ✔ | |
| `<ellipse>` | ✔ | |
| `<line>` | ✔ | |
| `<polyline>` | ✔ | |
| `<polygon>` | ✔ | |
| `<path>` | ✔ | via nanosvg; see limitations below |
| `<text>` | ✔ | system fonts via Cairo |
| `<tspan>` | ✔ | x/y positioning |
| `<textPath>` | ~ | fallback: text at path start point |
| `<g>` | ✔ | transform, inherited CSS styles |
| `<svg>` | ✔ | viewBox, width/height |
| `<style>` | ✔ | tag, .class, #id selectors |
| `<defs>` | ~ | stripped before nanosvg pass |
| `<marker>` | ✗ | not implemented |
| `<use>` | ✗ | not implemented |
| `<image>` | ✗ | not implemented |
| `<clipPath>` | ✗ | not implemented |
| `<linearGradient>` | ✗ | in `<defs>` — not resolved |
| `<radialGradient>` | ✗ | in `<defs>` — not resolved |

---

## Supported CSS Properties

| Property | Notes |
|----------|-------|
| `fill` | color name, `#rrggbb`, `rgb(r,g,b)`, `none` |
| `stroke` | same as fill |
| `stroke-width` | px suffix stripped |
| `stroke-opacity` | 0.0–1.0 |
| `opacity` | 0.0–1.0 |
| `fill-opacity` | 0.0–1.0 |
| `font-size` | px, pt |
| `font-family` | system font name |
| `font-weight` | `normal`, `bold` |
| `font-style` | `normal`, `italic` |
| `text-anchor` | `start`, `middle`, `end` |

CSS selectors: `tag`, `.class`, `#id`. Inline `style="..."` attributes
and direct XML attributes are also read.

---

## Color Names

50 W3C color names supported in addition to `#rrggbb` and `rgb(r,g,b)`:

`black white red green blue yellow cyan magenta orange purple`
`pink brown gray grey silver gold navy teal maroon olive lime`
`aqua fuchsia coral salmon khaki indigo violet lavender beige`
`ivory turquoise crimson forestgreen darkgreen darkblue darkred`
`darkgray lightgray lightblue lightyellow lightgreen tomato`
`orchid plum wheat tan sienna chocolate transparent`

---

## Known Limitations

### Path rendering (nanosvg)

- **`a sweep=0`** (counter-clockwise elliptical arc) — may not render
- **`s`** smooth cubic Bezier continuation — may not render
- Complex `a` + `m` combinations — position/size may be wrong

Workaround: use `svg_file_luna` (lunasvg) for full path support.

### Not implemented in svg2cairo

- `<marker>` / `marker-end` / `marker-start` (arrowheads)
- `<use>` / `<symbol>` (element references)
- `<linearGradient>` / `<radialGradient>` in `<defs>` (fill references)
- `<image>` embedded images
- `<clipPath>`
- `<textPath>` — only fallback (text at path start point)
- CSS `transform` property (only `transform` XML attribute)

---

## Comparison: nanosvg vs svg2cairo vs lunasvg

| Feature | nanosvg | svg2cairo | lunasvg |
|---------|---------|-----------|---------|
| Basic shapes | ✔ | ✔ | ✔ |
| CSS `<style>` | ✗ | ✔ | ✔ |
| `<text>` | ✗ | ✔ | ✔ |
| `<use>/<symbol>` | ~ | ✗ | ✔ |
| `<marker>` | ✗ | ✗ | ✔ |
| `<clipPath>` | ✗ | ✗ | ✔ |
| Gradients in `<defs>` | ✗ | ✗ | ✔ |
| `<textPath>` | ✗ | ~ fallback | ✗ upstream |
| Extra DLLs (Windows) | none | none | lunasvg.dll |
| tDOM required | no | yes | no |

---

## Example: luna vs svg2cairo comparison

```tcl
package require tclmcairo
package require svg2cairo

foreach file [glob demos/*.svg] {
    lassign [svg2cairo::size $file] sw sh
    set scale 2.0
    set w [expr {int($sw*$scale)}]
    set h [expr {int($sh*$scale)}]
    set base [file rootname $file]

    # lunasvg (full SVG support)
    set ctx [tclmcairo::new $w $h]
    if {[catch {$ctx svg_file_luna $file 0 0 -width $w -height $h} err]} {
        puts "luna: $err"
    } else {
        $ctx save "${base}-luna.png"
    }
    $ctx destroy

    # svg2cairo (CSS + text)
    set ctx [tclmcairo::new $w $h]
    svg2cairo::render $ctx $file -scale $scale
    $ctx save "${base}-svg2cairo.png"
    $ctx destroy

    puts "$file: OK"
}
```
