# tclmcairo Examples — Cairo Samples

Ports of the official Cairo C samples from https://cairographics.org/samples/

Original C code by Øyvind Kolås, submitted to GUADEC 2004.
**All original snippets are public domain.**

Tcl ports by gregnix, 2026. BSD 2-Clause.

## Running

```bash
cd examples
TCLMCAIRO_LIBDIR=.. tclsh8.6 arc.tcl
# -> output: arc.png

# All samples at once:
TCLMCAIRO_LIBDIR=.. tclsh8.6 run_all.tcl
```

## Files

| File | Cairo sample | Key features |
|------|-------------|--------------|
| `arc.tcl` | arc | arc, stroke, helping lines |
| `arc_negative.tcl` | arc negative | arc_negative |
| `clip.tcl` | clip | clip_path, new_path |
| `curve_to.tcl` | curve to | curve_to, control lines |
| `dash.tcl` | dash | set_dash, rel_line_to, curve_to |
| `fill_and_stroke.tcl` | fill and stroke2 | fill_preserve, close_path |
| `fill_style.tcl` | fill style | new_sub_path, fill_rule |
| `gradient.tcl` | gradient | gradient_linear, gradient_radial |
| `multi_segment_caps.tcl` | multi segment caps | set_line_cap, multiple segments |
| `rounded_rectangle.tcl` | rounded rectangle | arc-based rounding |
| `set_line_cap.tcl` | set line cap | butt, round, square |
| `set_line_join.tcl` | set line join | miter, bevel, round |
| `text.tcl` | text | text, text_path |
| `text_align_center.tcl` | text align center | font_measure, centering |
| `text_extents.tcl` | text extents | font_measure bounding box |
