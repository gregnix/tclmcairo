
---

## v0.3 (2026-04-09)

### New Features

**`operator`** — compositing operator (Porter-Duff + blend modes):
```tcl
$ctx operator OVER        ;# default
$ctx operator MULTIPLY    ;# photo multiply blend
$ctx operator SCREEN      ;# screen blend
$ctx operator XOR         ;# exclusive or
$ctx operator DIFFERENCE  ;# difference
$ctx operator DARKEN      ;# darken
$ctx operator LIGHTEN     ;# lighten
# + SOURCE CLEAR IN OUT ATOP DEST DEST_OVER DEST_IN DEST_OUT
#   DEST_ATOP ADD SATURATE OVERLAY COLOR_DODGE COLOR_BURN
#   HARD_LIGHT SOFT_LIGHT EXCLUSION HSL_HUE HSL_SATURATION
#   HSL_COLOR HSL_LUMINOSITY
```

**`-dash_offset`** — starting offset into dash pattern:
```tcl
$ctx line 0 0 400 0 -dash {10 5} -dash_offset 3
$ctx path "M 10 10 ..." -stroke {1 0 0} -dash {8 4} -dash_offset 0
```

**`arc_negative`** — arc counter-clockwise:
```tcl
$ctx arc_negative cx cy r start_deg end_deg ?opts?
```

**`user_to_device`** / **`device_to_user`** — coordinate mapping:
```tcl
set d [$ctx user_to_device 10 20]   ;# -> {dx dy}
set u [$ctx device_to_user 60 70]   ;# -> {x y}
# Essential for mouse interaction under active transforms
```

**`recording_bbox`** — ink bounding box of vector context:
```tcl
set bb [$ctx recording_bbox]   ;# -> {x y w h}
# Only valid on -mode vector contexts
```

**`font_options`** — font rendering quality:
```tcl
$ctx font_options -antialias default|none|gray|subpixel|fast|good|best
$ctx font_options -hint_style default|none|slight|medium|full
$ctx font_options -hint_metrics default|on|off
set fo [$ctx font_options]   ;# -> {-antialias gray -hint_style full ...}
```

**`path_get`** — read current Cairo path as SVG string:
```tcl
$ctx path "M 10 10 L 100 50"   ;# path is consumed after stroke/fill
# Use path_get before draw commands:
set svg [$ctx path_get]   ;# -> "M 10 10 L 100 50" or ""
```

**`surface_copy`** — new blank context same type/format:
```tcl
set cid [$ctx surface_copy]          ;# same size
set cid [$ctx surface_copy 400 300]  ;# custom size
tclmcairo circle $cid 100 75 60 -fill {1 0.5 0}
tclmcairo save $cid output.png
tclmcairo destroy $cid
```

**`gradient_extend`** — repeat/reflect/pad/none:
```tcl
$ctx gradient_linear g 0 0 50 0 {{0 1 0 0 1} {1 0 1 0 1}}
$ctx gradient_extend g repeat   ;# tile the gradient
$ctx rect 0 0 400 300 -fillname g
```

**`gradient_filter`** — interpolation quality:
```tcl
$ctx gradient_filter g best|good|fast|nearest|bilinear
```

**`paint`** — fill entire surface with current source:
```tcl
$ctx set_source -color {0.2 0.5 0.8}
$ctx paint            ;# full opacity
$ctx paint 0.4        ;# with alpha
$ctx set_source -gradient mygrad
$ctx paint
```

**`set_source`** — set source without drawing:
```tcl
$ctx set_source -color {r g b ?a?}
$ctx set_source -gradient name
```


### Build

- `PACKAGE_VERSION`: `0.3`
- `.tm`: `tclmcairo-0.3.tm`

### Test Results

| Platform | Tcl | Tests |
|----------|-----|-------|
| Linux Debian | 8.6.17 | 123/123 |

# tclmcairo Changelog

## v0.2 (2026-04-08)

### New Features

**Multi-page output** — new `-mode pdf|svg|ps|eps -file filename` option:
```tcl
set ctx [tclmcairo::new 595 842 -mode pdf -file "doc.pdf"]
$ctx clear 1 1 1
$ctx text 100 100 "Page 1" -font "Sans 14" -color {0 0 0}
$ctx newpage
$ctx text 100 100 "Page 2" -font "Sans 14" -color {0 0 0.8}
$ctx finish
$ctx destroy
```

**Image embedding** — PNG and JPEG support:
```tcl
$ctx image "photo.jpg" 50 20 -width 200 -height 150 -alpha 0.9
$ctx image "logo.png"  10 10
```
JPEG is automatically embedded as MIME data in PDF and SVG (no re-encoding,
no quality loss, ~20-25% smaller files).

**`image_data`** — draw PNG from bytearray (no filename needed):
```tcl
$ctx image_data $pngbytes x y ?-width w? ?-height h? ?-alpha a?
```

**`topng`** — get PNG as bytearray (no file written):
```tcl
set bytes [$ctx topng]   ;# works on raster and vector contexts
```

**`-format` option for `create`** — pixel format for raster contexts:
```tcl
tclmcairo::new 400 300 -format argb32   ;# default: 32-bit + alpha
tclmcairo::new 400 300 -format rgb24    ;# 32-bit, no alpha channel
tclmcairo::new 400 300 -format a8       ;# 8-bit alpha mask
```

**SVG options for `create`**:
```tcl
# Restrict to SVG 1.1 (limits Cairo features used internally)
tclmcairo::new 595 842 -mode svg -file out.svg -svg_version 1.1

# Set document unit — appears in width/height SVG attributes
tclmcairo::new 210 297 -mode svg -file a4.svg -svg_unit mm
# -> <svg width="210mm" height="297mm" ...>
# Available units: pt (default) px mm cm in em ex pc
```

**State stack** — `push` / `pop` (`cairo_save` / `cairo_restore`):
```tcl
$ctx push
$ctx transform -rotate 45
$ctx rect 10 10 100 50 -fill {1 0 0}
$ctx pop    ;# rotation gone
```

**Clip regions**:
```tcl
$ctx push
$ctx clip_rect 50 50 300 200        ;# rectangular clip
$ctx clip_path "M 100 100 L ..."    ;# arbitrary shape
$ctx circle 200 150 180 -fill {1 0.3 0.1}
$ctx clip_reset
$ctx pop
```

**Blit / layer compositing**:
```tcl
$ctx blit $other_ctx x y ?-alpha a? ?-width w? ?-height h?
```

**`-outline` option for `text`** — text as path (fill/stroke/gradient):
```tcl
$ctx text 200 60 "Hello" -font "Sans Bold 18" \
    -fillname mygrad -stroke {0.8 0.3 0} -width 1.5 -outline 1
```

**`text_path`** — always uses `cairo_text_path`:
```tcl
$ctx text_path 250 100 "TITLE" -font "Sans Bold 48" \
    -fillname grad -stroke {1 1 1} -width 1 -anchor center
```

**`-fillrule evenodd|winding`**:
```tcl
$ctx path "M 150 30 ..." -fill {0.2 0.4 0.9} -fillrule evenodd
```

### Hardening

- **Early load**: `.so`/`.dll` loaded immediately at `package require` —
  errors appear at load time, not at first `tclmcairo::new`
- **Cairo status checks**: `cairo_image_surface_create()` and
  `cairo_create()` checked; `check_cairo()` helper in save path
- **Interpreter cleanup**: `Tcl_CallWhenDeleted()` frees all contexts
  on interpreter deletion — no memory leak on `interp delete`
- **Double-destroy safe**: `CairoDestroyCmd` nulls pointers after free
- **Thread-safety documented**: NOT thread-safe (same model as Tk)

### API Changes

- `tclmcairo create` accepts new `-mode` values: `pdf`, `svg`, `ps`, `eps`
- `tclmcairo create` accepts `-file filename` for file-mode contexts
- `tclmcairo create` accepts `-format argb32|rgb24|a8`
- `tclmcairo create` accepts `-svg_version 1.1|1.2` and `-svg_unit pt|px|...`
- `destroy` auto-calls `surface_finish` for file-mode if not already done

**`gradient_extend`** — repeat/reflect/pad/none:
```tcl
$ctx gradient_linear g 0 0 50 0 {{0 1 0 0 1} {1 0 1 0 1}}
$ctx gradient_extend g repeat   ;# tile the gradient
$ctx rect 0 0 400 300 -fillname g
```

**`gradient_filter`** — interpolation quality:
```tcl
$ctx gradient_filter g best|good|fast|nearest|bilinear
```

**`paint`** — fill entire surface with current source:
```tcl
$ctx set_source -color {0.2 0.5 0.8}
$ctx paint            ;# full opacity
$ctx paint 0.4        ;# with alpha
$ctx set_source -gradient mygrad
$ctx paint
```

**`set_source`** — set source without drawing:
```tcl
$ctx set_source -color {r g b ?a?}
$ctx set_source -gradient name
```


### Build

- `Makefile` / `Makefile.win`: JPEG auto-detected (checks for `jpeglib.h`),
  disable with `JPEG=0`
- `Makefile.win`: PowerShell pkgIndex generation on one line (no `\` continuation)
- `build-win.bat`: pkgIndex generation fixed (single-line PowerShell)
- `PKG_TCL_SOURCES`: now `tclmcairo-0.2.tm`
- `PACKAGE_VERSION`: `0.2`

### Test Results

| Platform | Tcl | Tests |
|----------|-----|-------|
| Linux Debian | 8.6.17 | 97/97 |
| Linux Debian | 9.0.3  | 97/97 |
| Windows MSYS2 MINGW64 | 8.6 | 97/97 |
| Windows BAWT 3.2      | 8.6 | 97/97 |

---

## v0.1 (2026-04-07)

First release. Fully tested on all supported platforms.

### Features

- Shapes: `rect` (with `-radius`), `circle`, `ellipse`, `arc`, `line`, `poly`
- SVG paths: `M L H V C Q Z` fully supported; `A` with basic ellipse approximation
- Text: font parsing (`Sans Bold Italic 14`), anchor, color, alpha
- Font metrics: `font_measure` → `{width height ascent descent}`
- Transforms: translate / scale / rotate / reset
- Gradients: linear + radial with color stops, `-fillname`
- Line options: `-dash`, `-linecap`, `-linejoin`, `-alpha`
- Output: PNG, PDF, SVG, PS, EPS
- Raster mode (ARGB32) + Vector mode (Recording Surface → true vectors)
- 5 demos, each saved in all 5 output formats

### Error Handling

- Unknown options raise `TCL_ERROR`
- Invalid color, out-of-range values, wrong argument counts all raise errors
- All `parse_opts` callers propagate errors cleanly

### Bug Fixes

- Text alpha: `-color {r g b a}` alpha was ignored — fixed
- `line` color alpha: same fix applied
- All `strncpy` calls: explicit null-terminator added
- Gradient name buffer: null-terminator added

**`gradient_extend`** — repeat/reflect/pad/none:
```tcl
$ctx gradient_linear g 0 0 50 0 {{0 1 0 0 1} {1 0 1 0 1}}
$ctx gradient_extend g repeat   ;# tile the gradient
$ctx rect 0 0 400 300 -fillname g
```

**`gradient_filter`** — interpolation quality:
```tcl
$ctx gradient_filter g best|good|fast|nearest|bilinear
```

**`paint`** — fill entire surface with current source:
```tcl
$ctx set_source -color {0.2 0.5 0.8}
$ctx paint            ;# full opacity
$ctx paint 0.4        ;# with alpha
$ctx set_source -gradient mygrad
$ctx paint
```

**`set_source`** — set source without drawing:
```tcl
$ctx set_source -color {r g b ?a?}
$ctx set_source -gradient name
```


### Build

- `Makefile.win`: MSYS2 targets (mingw-ucrt64, mingw64, bawt86, bawt90)
- `build-win.bat`: BAWT build with auto-detect of Cairo from MSYS2 MINGW64
- `test-win.bat`: sets `C:\msys64\mingw64\bin` in PATH for cairo.dll
- `check-bawt.bat`: BAWT installation checker
- TEA: Cairo detection via `pkg-config`, `TCLSH` overridable

### Known Limitations

- Text: Cairo Toy API — no HarfBuzz, no BiDi, no CJK shaping
- Windows: Tcl 8.6 only
- Single-page output only (multi-page added in v0.2)
- No image embedding (added in v0.2)

### Test Results

| Platform | Tcl | Tests |
|----------|-----|-------|
| Linux Debian | 8.6.17 | 41/41 |
| Linux Debian | 9.0.3  | 41/41 |
| Windows MSYS2 UCRT64  | 8.6.17 | 41/41 |
| Windows MSYS2 MINGW64 | 8.6.17 | 41/41 |
| Windows BAWT 3.2      | 8.6    | 41/41 |
