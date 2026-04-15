# tclmcairo Changelog

## v0.3.4 (2026-04-15)

### svg2cairo-0.1.tm — Bugfixes

7 Fehler behoben (nach Praxistest mit decode/, vgs/, w3org/ SVG-Suites):

- **SV-1:** Frühes `return` bei fehlendem CSS-Match — bei `hasStyle=1`
  wurden Shapes ohne CSS-Klasse/ID nicht gerendert (fehlende Shapes).
  SVG-Default `fill=black` eingeführt.

- **SV-2:** `<defs>` von nanosvg als Shape gerendert — Marker-Paths aus
  `<defs>` erschienen als falsch positionierte Linien.
  Fix: `<defs>…</defs>` vor nanosvg-Pass via `string first/replace` entfernen.

- **SV-3:** `[$node asText]` liefert rekursiv Kinder-Inhalte — Text wurde
  doppelt gerendert (an (0,0) + via textPath-Fallback).
  Fix: nur direkte `TEXT_NODE`-Kinder iterieren.

- **SV-4:** `NOT_AN_ELEMENT`-Fehler bei Textknoten in `childNodes` —
  tDOM liefert auch Text- und Kommentarknoten.
  Fix: `nodeType eq "ELEMENT_NODE"` Check in `_renderNode`.

- **SV-5:** CSS nicht an `<g>`-Kinder vererbt — `#group1 { stroke:red }`
  auf `<g>` hatte keinen Effekt auf Kinder-Shapes.
  Fix: `_cssForNode` in `_renderNode` für alle Nodes auswerten.

- **SV-6:** `path` ohne Transform-Skalierung — SVG-Pfade ignorierten
  sx/sy/ox/oy und erschienen bei scale>1 falsch positioniert.
  Fix: Cairo-Transform-Matrix vor/nach `path`-Aufruf setzen/wiederherstellen.

- **SV-7:** `stroke-width` / `stroke-opacity` nicht als direkte Attribute
  gelesen — `_nodeStyle` ignorierte diese XML-Attribute.

### Build-Fixes

- `build-win.bat`: Klammern in `echo`-Zeilen innerhalb `if`-Blöcken
  mit `^` escaped (CMD-Bug — `)` schloss `if`-Block vorzeitig →
  DLL wurde ohne lunasvg gebaut)
- `pkgIndex.tcl.in`: `svg2cairo 0.1` Eintrag ergänzt,
  `@PACKAGE_VERSION@` durchgängig (kein Hardcode mehr)

### Dokumentation

- `docs/svg2cairo.md` — neu: vollständige API-Referenz
- `docs/api-reference.md` — SVG-Abschnitt (nanosvg/lunasvg/svg2cairo),
  `image_size`, `select_font_face`, `text_extents`
- `docs/manual.md` — SVG-Rendering-Abschnitt, Demo 20+21
- `nogit/TODO-0.4.md` — svg2cairo Known Issues (SV-KI-1 bis SV-KI-7)

---

## v0.3.4 (2026-04-13)

**nanosvg eingebaut — SVG direkt auf Cairo-Context rendern**

Neue Befehle:
```tcl
$ctx svg_file  filename x y ?-width w? ?-height h? ?-scale s?
$ctx svg_data  svgstring x y ?-width w? ?-height h? ?-scale s?
```

- nanosvg.h + nanosvgrast.h (Mikko Mononen, zlib/libpng-Lizenz) direkt eingebettet
- Kein librsvg, keine GLib, keine zusätzlichen DLLs auf Windows
- RGBA→ARGB Premultiplied-Alpha Konversion korrekt
- Tk 8.6 + Tk 9.0 kompatibel (unabhängig von tksvg)
- THIRD-PARTY-LICENSES.txt aktualisiert

**svg2cairo-0.1.tm** — neues Tcl-Modul (tDOM SVG-Postprocessor):
- CSS `<style>` (tag, .class, #id), 50 W3C-Farbnamen
- `<text>`, `<tspan>`, `<textPath>` Fallback
- DOCTYPE-Strip vor tDOM-Parse

**lunasvg optional** (C++ Wrapper, HAVE_LUNASVG):
```tcl
$ctx svg_file_luna filename x y ?-width w? ?-height h? ?-scale s?
$ctx svg_data_luna svgstring x y ?opts?
$ctx svg_size_luna filename -> {width height}
```

**193/193 Tests: Tcl 8.6 + Tcl 9.0 ✔**

## v0.3.3 (2026-04-12)

**`image_size`** — read PNG/JPEG dimensions without drawing:
```tcl
lassign [$ctx image_size $file] w h
```

**`select_font_face`** — direct font family/slant/weight control:
```tcl
$ctx select_font_face "Serif" -slant italic -weight bold -size 18
```
Complements `-font` string parsing — avoids re-parsing overhead in
draw loops where the font doesn't change.

**`text_extents` — full dict** (9 keys):
`width height x_bearing y_bearing x_advance y_advance ascent descent line_height`

**193/193 tests: Tcl 8.6 + Tcl 9.0**

## v0.3.3 (2026-04-11) [base]

**Windows: DLL loading fully resolved**

`pkgIndex.tcl` pre-loads all Cairo dependency DLLs with absolute paths
before loading `tclmcairo.dll`. No PATH modification, no admin rights,
works with BAWT Tcl and any other Tcl installation.

`build-win.bat` copies all 19 required MSYS2 DLLs into `dist\tclmcairo0.3.3\`
automatically.

**Windows test result: 187/187 ✔**

**`save -chan`**: write-mode check + auto binary translation

**`canvas2cairo::export -chan`**: export directly to a Tcl channel

**`make test/demo`**: auto-detect tclsh from configured prefix

## v0.3.2 (2026-04-11)

**`save -chan channel`** — write output to an open Tcl channel.

**`cairo_new_path()` before every shape command** — critical fix.

**canvas2cairo-0.1.tm** — 19 improvements including `-smooth 1` Catmull-Rom,
`render -clip`, `text_extents` for justify, `-underline`, `-arrowshape`,
HiDPI `-scale`, region export `-viewport`.

**shape_renderer-0.1.tm** — 7 new shapes (total 15).

Tests: 181/181 tclmcairo ✔  42/42 canvas2cairo ✔

## v0.3.1 (2026-04-10)

canvas2cairo-0.1.tm initial release. demos/nodeeditor.tcl (new).

## v0.3 (2026-04-09)

29 compositing operators, `-dash_offset`, `arc_negative`,
`user_to_device` / `device_to_user`, `recording_bbox`,
`gradient_extend`, `gradient_filter`, `paint`, `set_source`,
`font_options`, `path_get`, `surface_copy`, `transform -matrix/-get`,
low-level path API, 15 Cairo C sample ports in `examples/`.

Tests: 181/181 Linux · 170/170 Windows

## v0.2 (2026-04-08)

`transform -matrix`, `write -chan`, ISO B/C paper formats.
Tests: 105/105

## v0.1 (2026-03-30)

Initial release. Core Cairo binding for Tcl.
Tests: 41/41
