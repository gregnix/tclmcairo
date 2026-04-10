# tclmcairo — Demos

| File | Description | Run with |
|------|-------------|----------|
| `demo-tclmcairo.tcl` | 18 API demos: shapes, gradients, text, PDF, compositing, transforms | `tclsh` |
| `demo-canvas2cairo.tcl` | Tk Canvas → SVG/PDF export (5 demos) | `wish` |
| `demo-coordinates.tcl` | Interactive: user_to_device, recording_bbox, path_get | `wish` |
| `canvas_explorer.tcl` | **Learning tool:** Tk Canvas vs Cairo export side by side | `wish` |
| `nodeeditor.tcl` | **Node editor application:** drag-to-connect, shape icons, export | `wish` |

## Run

```bash
cd tclmcairo03

# API demos
TCLMCAIRO_LIBDIR=. tclsh demos/demo-tclmcairo.tcl

# Canvas export demos
TCLMCAIRO_LIBDIR=. wish demos/demo-canvas2cairo.tcl

# Canvas explorer (Tk required)
TCLMCAIRO_LIBDIR=. wish demos/canvas_explorer.tcl

# Node editor (Tk required)
TCLMCAIRO_LIBDIR=. wish demos/nodeeditor.tcl
```

After `sudo make install`:
```bash
wish demos/canvas_explorer.tcl
wish demos/nodeeditor.tcl
```
