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
