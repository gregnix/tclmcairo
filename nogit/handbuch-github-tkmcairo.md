# tclmcairo -- Handbuch: Einrichtung, GitHub, Workflow

Stand: 2026-04-08
Version: 0.2

---

## Inhaltsverzeichnis

1. [Was ist was -- Ueberblick](#1-was-ist-was)
2. [Lokale Einrichtung](#2-lokale-einrichtung)
3. [GitHub -- Einrichtung und Konfiguration](#3-github)
4. [Taegliger Entwicklungsworkflow](#4-workflow)
5. [Fehlerbehandlung](#5-fehler)
6. [Kurzreferenz -- wichtige Befehle](#6-kurzreferenz)
7. [API-Ueberblick 0.2](#7-api)
8. [SVG-Features](#8-svg)

---

## 1. Was ist was

### Die zwei Orte des Codes

```
GitHub (public)                    Lokal (dein Rechner)
gregnix/tclmcairo                   ~/src/tclmcairo-0.1/tclmcairo/
        |                                    |
        |   clone (einmalig)                 |
        +------------------------------------>+
        |                                    |
        |   push (regelmaessig)              |
        +<------------------------------------+
```

### Was in welchem Verzeichnis liegt

```
tclmcairo/                   Repo-Root (= git-Root)
  src/
    libtclmcairo.c           C-Extension (~1900 Zeilen)
  tcl/
    tclmcairo-0.2.tm         TclOO-Wrapper + Loader
  tests/
    test-tclmcairo.tcl       97 Tests
  demos/
    demo-tclmcairo.tcl       12 Demos
  docs/
    api-reference.md        API-Dokumentation
  nogit/                    NICHT im Repo (siehe .gitignore)
    uebergabe-*.md          Session-Uebergaben (deutsch)
    handbuch-github-tclmcairo.md   dieses Dokument
  configure.in              TEA Build-Definition
  Makefile.in               TEA Makefile-Template
  Makefile                  Fallback ohne autoconf
  Makefile.win              Windows Build (MSYS2 + BAWT)
  build-win.bat             Windows BAWT Build
  test-win.bat              Windows BAWT Test
  check-bawt.bat            BAWT-Installation pruefen
  pkgIndex.tcl.in           Package-Index-Template
  aclocal.m4                Bindet tclconfig/tcl.m4
  tclconfig/                TEA-Skripte (git submodule)
  README.md
  CHANGELOG.md
  LICENSE
  .gitignore
```

### nogit/ -- privates Verzeichnis

`nogit/` liegt im Repo-Verzeichnis, ist aber in `.gitignore` und wird nie
committed:

- `uebergabe-*.md` -- Session-Uebergaben (deutsch)
- `handbuch-github-tclmcairo.md` -- dieses Handbuch
- `ideen/` -- Planungsdokumente, Notizen

```bash
mkdir -p ~/src/tclmcairo-0.1/tclmcairo/nogit
```

### .gitignore

```gitignore
libtclmcairo.so
libtclmcairo.dll
libtclmcairo.o
lib/*.o
src/*.o
configure
autom4te.cache/
config.cache
config.log
config.status
Makefile
pkgIndex.tcl
demos/*.png
demos/*.pdf
demos/*.svg
demos/*.eps
demos/*.ps
demos/*.jpg
/tmp/tclmcairo_test.*
*.bak
*~
.#*
\#*#
tclconfig/
nogit/
```

---

## 2. Lokale Einrichtung

### Abhaengigkeiten (Linux)

```bash
sudo apt install libcairo2-dev libjpeg-dev tcl8.6-dev tcl9.0-dev \
                 build-essential autoconf
```

JPEG ist optional (`make JPEG=0` zum Deaktivieren).

### Build (Linux)

```bash
cd ~/src/tclmcairo-0.1/tclmcairo

autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make && make test

# Tcl 9:
make clean
./configure --with-tcl=/usr/lib/tcl9.0
make && make test TCLSH=tclsh9.0

# Demos:
make demo
make demo TCLSH=tclsh9.0
```

### Build (Windows BAWT)

```cmd
check-bawt.bat
build-win.bat 86         # Tcl 8.6, JPEG auto-detect
build-win.bat 86 nojpeg  # ohne JPEG
test-win.bat 86
```

### tclmcairo verfuegbar machen

```tcl
tcl::tm::path add /pfad/zu/tclmcairo/tcl
set env(TCLMCAIRO_LIBDIR) /pfad/zu/tclmcairo
package require tclmcairo
# Seit 0.2: .so wird sofort beim package require geladen.
# Fehler erscheinen damit frueh, nicht erst beim ersten new.
```

---

## 3. GitHub -- Einrichtung und Konfiguration

### SSH-Zugang pruefen

```bash
ssh -T git@github.com
# -> Hi gregnix! You've successfully authenticated...
```

### Ersten Push (einmalig, fuer v0.1 bereits erledigt)

```bash
cd ~/src/tclmcairo-0.1/tclmcairo
mkdir -p nogit
git init
git submodule add https://github.com/tcltk/tclconfig tclconfig
git remote add origin git@github.com:gregnix/tclmcairo.git
git add -A
git commit -m "Initial commit: tclmcairo 0.1"
git branch -M main
git push -u origin main
git tag -a v0.1 -m "tclmcairo 0.1"
git push origin v0.1
```

### v0.2 Release-Push

```bash
cd ~/src/tclmcairo-0.1/tclmcairo

git add -A
git commit -m "release: tclmcairo 0.2

New features:
- newpage/finish (multi-page PDF/PS/SVG)
- image PNG+JPEG, image_data bytes
- clip_rect/clip_path/clip_reset
- push/pop (cairo_save/restore)
- text_path + -outline option
- -fillrule evenodd
- blit (layer compositing)
- topng (PNG as bytearray)
- -format argb32/rgb24/a8
- -svg_version 1.1|1.2, -svg_unit pt|px|mm|cm|in|em|ex|pc
- JPEG auto MIME embedding in PDF/SVG (25% smaller)

Hardening:
- early load at package require
- cairo_status checks after create
- Tcl_CallWhenDeleted cleanup on interp delete
- double-destroy safe

Tests: 97/97 (Tcl 8.6 + 9.0)"

git push
git tag -a v0.2 -m "tclmcairo 0.2"
git push origin v0.2
```

Dann GitHub: **Releases -> Draft a new release -> Tag v0.2** -> ZIP hochladen.

### Repository-Uebersicht

```
gregnix/tclmcairo
  main      Hauptlinie
  Tags:
    v0.1    Grundfunktionen (2026-04)
    v0.2    Bilder, Clip, blit, SVG-Optionen (2026-04)
    v0.3    geplant: HarfBuzz, tkcairo
```

### Versionsschema

- `0.1` -- Shapes, Text, Gradienten, Transforms, PNG/PDF/SVG/PS/EPS
- `0.2` -- Bilder, Mehrseiten, Clip, text_path, blit, topng, SVG-Optionen
- `0.3` -- HarfBuzz-Text, tkcairo (Tk-Widget-Integration), geplant
- `1.0` -- Erste stabile Version (API eingefroren)

---

## 4. Taegliger Entwicklungsworkflow

### Normaler Aenderungsablauf

```bash
cd ~/src/tclmcairo-0.1/tclmcairo

nano src/libtclmcairo.c          # oder tcl/tclmcairo-0.2.tm
make
make test
make test TCLSH=tclsh9.0
make demo                        # bei groesseren Aenderungen
git add -A
git commit -m "bereich: beschreibung"
git push
```

### Commit-Nachrichten

```
<bereich>: <beschreibung>

bereich: core | opts | text | path | gradient | transform | save |
         image | clip | blit | svg | build | test | demo | docs | windows
```

Beispiele:
```
core: add clip_rect command
image: auto-embed JPEG as MIME data in PDF
svg: add -svg_version and -svg_unit options
text: add text_path with -outline option
hardening: add Tcl_CallWhenDeleted for interp cleanup
```

### Versionsbump (Vorlage fuer 0.3)

```bash
# 1. Versionen aendern in:
#    src/libtclmcairo.c     PACKAGE_VERSION "0.2" -> "0.3"
#    tcl/tclmcairo-0.2.tm   package provide tclmcairo 0.2 -> 0.3
#    configure.in          AC_INIT([tclmcairo], [0.2]) -> [0.3]
#    CHANGELOG.md          neue Sektion

# 2. .tm umbenennen:
mv tcl/tclmcairo-0.2.tm tcl/tclmcairo-0.3.tm
# pkgIndex.tcl.in anpassen

# 3. git + Tag
git add -A
git commit -m "bump: version 0.2 -> 0.3"
git tag -a v0.3 -m "tclmcairo 0.3"
git push && git push origin v0.3
```

---

## 5. Fehlerbehandlung

### F: `package require tclmcairo` schlaegt fehl

```bash
TCLMCAIRO_LIBDIR=. tclsh8.6 << 'EOF'
tcl::tm::path add ./tcl
package require tclmcairo
puts "OK: [package version tclmcairo]"
EOF
```

### F: libtclmcairo.so nicht gefunden

```bash
ls ~/src/tclmcairo-0.1/tclmcairo/libtclmcairo.so
# Falls nicht vorhanden:
make clean
autoconf && ./configure --with-tcl=/usr/lib/tcl8.6
make
```

### F: JPEG-Support fehlt

```bash
sudo apt install libjpeg-dev
make clean && autoconf
./configure --with-tcl=/usr/lib/tcl8.6
make
```

### F: Windows -- cairo.dll nicht gefunden

```bash
export PATH=/c/msys64/mingw64/bin:$PATH
```

### F: tclconfig Submodule leer nach clone

```bash
git submodule update --init
```

### F: Falsche Version wird geladen

```tcl
package require tclmcairo
puts [package version tclmcairo]   ;# muss 0.2 sein
puts [info loaded]                 ;# zeigt Pfad der .so
```

---

## 6. Kurzreferenz -- wichtige Befehle

```bash
# Build
autoconf && ./configure --with-tcl=/usr/lib/tcl8.6
make
make test
make test TCLSH=tclsh9.0
make demo
make -f Makefile.win TARGET=mingw64     # Windows MSYS2

# Schnelltest:
TCLMCAIRO_LIBDIR=. tclsh8.6 tests/test-tclmcairo.tcl

# git
git status
git add -A && git commit -m "..."
git push
git tag -a v0.2 -m "..." && git push origin v0.2

# Submodule
git submodule update --init
```

---

## 7. API-Ueberblick 0.2

### Kontext erzeugen

```tcl
# Raster
set ctx [tclmcairo::new 400 300]
set ctx [tclmcairo::new 400 300 -format argb32|rgb24|a8]

# Vektor (fuer PDF/SVG-Ausgabe optimal)
set ctx [tclmcairo::new 400 300 -mode vector]

# Direkt in Datei (mehrseiten-faehig)
set ctx [tclmcairo::new 595 842 -mode pdf -file output.pdf]
set ctx [tclmcairo::new 595 842 -mode svg -file output.svg \
    -svg_version 1.1|1.2 \
    -svg_unit pt|px|mm|cm|in|em|ex|pc]
set ctx [tclmcairo::new 595 842 -mode ps|eps -file output.ps]
```

### Zeichenbefehle

```tcl
$ctx clear  r g b ?a?
$ctx rect   x y w h  ?-fill {r g b a}? ?-stroke? ?-radius r?
$ctx circle cx cy r  ?opts?
$ctx ellipse cx cy rx ry  ?opts?
$ctx arc    cx cy r start end  ?opts?
$ctx line   x1 y1 x2 y2  ?-color? ?-width? ?-dash?
$ctx poly   x1 y1 x2 y2 ...  ?opts?
$ctx path   "M x y L x y C ... Z"  ?opts?
$ctx text   x y string  ?-font "Sans Bold 14"? ?-anchor center?
             ?-fillname grad? ?-outline 1? ?-color {r g b}?
$ctx text_path x y string  ?opts?   ;# Text als Pfad
```

### Gemeinsame Optionen

```
-fill {r g b ?a?}           Fuellung
-fillname name              Fuellung mit Gradient
-stroke {r g b ?a?}         Kontur
-width n                    Linienbreite
-radius r                   Eckenradius
-alpha a                    Gesamt-Transparenz 0..1
-dash {on off}              Strichmuster
-linecap butt|round|square
-linejoin miter|round|bevel
-fillrule winding|evenodd
-outline 0|1                Text-Stroke (bei text/text_path)
-anchor center|nw|n|ne|e|se|s|sw|w
```

### Gradienten

```tcl
$ctx gradient_linear name x1 y1 x2 y2 {{offset r g b a} ...}
$ctx gradient_radial  name cx cy r     {{offset r g b a} ...}
$ctx rect 0 0 400 300 -fillname name
```

### Bilder

```tcl
# Datei laden (PNG oder JPEG)
# JPEG wird automatisch als MIME-Data eingebettet (kein Re-encoding)
$ctx image filename x y ?-width w? ?-height h? ?-alpha a?

# PNG aus Bytearray zeichnen
$ctx image_data bytes x y ?-width w? ?-height h? ?-alpha a?
```

### Clips und Ebenen

```tcl
$ctx push                       # cairo_save
$ctx pop                        # cairo_restore
$ctx clip_rect  x y w h
$ctx clip_path  "M ... Z"
$ctx clip_reset
$ctx blit src_ctx x y ?-alpha a? ?-width w? ?-height h?
```

### Transforms

```tcl
$ctx transform -translate dx dy
$ctx transform -scale sx sy
$ctx transform -rotate deg
$ctx transform -matrix a b c d tx ty
$ctx transform -reset
```

### Ausgabe

```tcl
$ctx save filename      # .png .pdf .svg .ps .eps
$ctx todata             # ARGB32-Pixelbytes (fuer Tk photo)
$ctx topng              # PNG-Bytes im Speicher (kein Dateiname)
$ctx newpage            # naechste Seite (file-mode)
$ctx finish             # Datei schliessen (file-mode)
$ctx destroy            # Kontext freigeben
set s [$ctx size]       # {width height}
set m [$ctx font_measure string font]  # {width height ascent descent}
```

---

## 8. SVG-Features

### Was Cairo's SVG-Backend ausgibt

| Cairo-Operation | SVG-Element |
|---|---|
| Linien, Kurven, Boegen | `<path d="...">` |
| Rechtecke | `<path>` oder `<rect>` |
| Gradienten | `<linearGradient>`, `<radialGradient>` |
| Clipping | `<clipPath>` |
| Transparenz / Alpha | `opacity`, `fill-opacity` |
| Transforms | `transform="matrix(...)"` |
| push/pop | `<g>` |
| Text | **Glyph-Pfade** (kein `<text>`) |

### MIME-Data in SVG (anders als PDF!)

| MIME-Type | SVG-Output |
|---|---|
| JPEG (auto) | `<image href="data:image/jpeg;base64,...">` |
| PNG (auto)  | `<image href="data:image/png;base64,...">` |
| URI         | `<image href="https://...">` |

Wichtig: Im SVG-Backend werden sowohl JPEG als auch PNG als MIME-Data
eingebettet. Das PDF-Backend unterstuetzt nur JPEG-MIME (PNG wird immer
als Pixel-Daten re-enkodiert).

### SVG-Versionen

```tcl
# SVG 1.1: aeltere Viewer, schraenkt Cairo-Features ein
tclmcairo::new 595 842 -mode svg -file out.svg -svg_version 1.1

# SVG 1.2: Standard (default in Cairo)
# Noetig fuer mehrseitige SVG via newpage
tclmcairo::new 595 842 -mode svg -file out.svg -svg_version 1.2
```

Hinweis: `-svg_version` schreibt die Version nicht als SVG-Attribut in
den Header -- es steuert nur intern welche Cairo-Features genutzt werden.

### SVG-Einheiten

```tcl
# Einheit erscheint im SVG-Header als width/height-Einheit
tclmcairo::new 210 297 -mode svg -file a4.svg -svg_unit mm
# -> <svg width="210mm" height="297mm" viewBox="0 0 210 297">

tclmcairo::new 800 600 -mode svg -file screen.svg -svg_unit px
# -> <svg width="800px" height="600px" viewBox="0 0 800 600">

# Verfuegbare Einheiten: pt (default) px mm cm in em ex pc
```

### Was Cairo SVG nicht kann

- Kein `<text>`-Element -- Text ist immer als Glyph-Pfade (nicht durchsuchbar)
- Keine Animationen, kein JavaScript, kein DOM
- Keine SVG-Fonts
- Kein `<symbol>` / `<use>` im Output
- Keine Filter (feGaussianBlur etc.)

---

*Stand: 2026-04-08 | Version 0.2 | gregnix/tclmcairo*
