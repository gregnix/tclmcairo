# tkmcairo Changelog

## v0.1 (2026-04-07)

First release. Fully tested on all supported platforms.

### Test Results

| Platform | Tcl | Tests |
|----------|-----|-------|
| Linux Debian | 8.6.17 | 41/41 |
| Linux Debian | 9.0.3  | 41/41 |
| Windows MSYS2 UCRT64  | 8.6.17 | 41/41 |
| Windows MSYS2 MINGW64 | 8.6.17 | 41/41 |
| Windows BAWT 3.2      | 8.6    | 41/41 |

### Features

- Shapes: `rect` (with `-radius`), `circle`, `ellipse`, `arc`, `line`, `poly`
- SVG paths: `M L H V C Q Z` fully supported; `A` with basic ellipse approximation
- Text: font parsing (`Sans Bold Italic 14`), anchor, color, alpha
- Font metrics: `font_measure` → {width height ascent descent}
- Transforms: translate / scale / rotate / reset
- Gradients: linear + radial with color stops, `-fillname`
- Line options: `-dash`, `-linecap`, `-linejoin`, `-alpha`
- Output: PNG, PDF, SVG, PS, EPS
- Raster mode (ARGB32) + Vector mode (Recording Surface → true vectors)
- 5 demos, each saved in all 5 output formats

### Error Handling (strict Tcl-style API)

- Unknown options raise `TCL_ERROR`: `unknown option "-flll"`
- Odd option list raises error: `option without value`
- Invalid color raises error: `color must be {r g b} or {r g b a}`
- `-alpha` validated: `-alpha must be 0.0..1.0`
- `-linecap` validated: `invalid -linecap: X (butt|round|square)`
- `-linejoin` validated: `invalid -linejoin: X (miter|round|bevel)`
- `poly` requires minimum 3 coordinate pairs (6 values)
- All `parse_opts` callers propagate errors via `if (!parse_opts(...)) return TCL_ERROR`

### Bug Fixes

- Text alpha: `-color {r g b a}` alpha was ignored, `o.alpha` used instead of `color_a`
- `line` color alpha: same fix applied to line command
- All `strncpy` calls: explicit null-terminator added after buffer fill
- Gradient name buffer: null-terminator added

### Build System

- `Makefile.win`: MSYS2 targets (mingw-ucrt64, mingw64, bawt86, bawt90)
- `build-win.bat`: BAWT build with auto-detect of Cairo in MSYS2 MINGW64
- `test-win.bat`: BAWT test with `C:\msys64\mingw64\bin` in PATH for cairo.dll
- `check-bawt.bat`: BAWT installation checker
- `pkgIndex.tcl`: sources `.tm` only — loader finds `.so`/`.dll` itself

### Known Limitations

- Text: Cairo Toy API — no HarfBuzz, no BiDi, no CJK
- Windows: Tcl 8.6 only (Tcl 9 not in MSYS2 MINGW64/UCRT64)
- Cairo not included in BAWT — taken from MSYS2 MINGW64
- Single-page output only (multi-page PDF planned for v0.2)
- No image embedding (planned for v0.2)

### Tcl 8.6 / 9.0 Compatibility

- `Tcl_Size` shim for Tcl 8.6
- `Tcl_InitStubs` version: `"9.0"` for Tcl 9, `"8.6"` for Tcl 8
- Windows DLL: `tkmcairo.dll` (no `lib` prefix, per Windows convention)
- Loader searches `tkmcairo.dll` before `libtkmcairo.dll`

### TEA Build Notes

- TEA under Tcl 9 names output `libtcl9tkmcairo` → fixed to `libtkmcairo.so`
- Cairo detection via `pkg-config` shell call (no `PKG_CHECK_MODULES`)
- `TCLSH` hardcoded, override: `make TCLSH=tclsh9.0 test`
