title    {tclmcairo 0.3.6 — Cheat Sheet}
subtitle {Cairo 2D graphics for Tcl — github.com/gregnix/tclmcairo}
sections {
    {title {Setup}  type code  content {
        {tcl::tm::path add /path/to/tclmcairo/tcl}
        {set env(TCLMCAIRO_LIBDIR) /path/to/tclmcairo}
        {package require tclmcairo}
        {set ctx [tclmcairo::new 400 300]}
        {# ... draw ...}
        {$ctx save output.png   ;# or .pdf .svg .ps .eps}
        {$ctx destroy}
    }}
    {title {hasFeature (0.3.6)}  type code  content {
        {tclmcairo hasFeature             ;# -> list of all enabled features}
        {tclmcairo hasFeature lunasvg     ;# -> 1 if HAVE_LUNASVG, else 0}
        {tclmcairo hasFeature jpeg        ;# -> 1 if HAVE_LIBJPEG, else 0}
        {tclmcairo hasFeature image_load  ;# -> 1 (>=0.3.5)}
        {tclmcairo::hasFeature toppm      ;# OO-style helper, same result}
        {# Unknown name -> 0 (forwards-compatible probing)}
    }}
    {title {Create Context}  type table  mono 1  content {
        {{raster (default)} {tclmcairo::new w h ?-format argb32|rgb24|a8?}}
        {{vector}          {tclmcairo::new w h -mode vector}}
        {{PDF file}        {tclmcairo::new w h -mode pdf -file out.pdf}}
        {{SVG file}        {tclmcairo::new w h -mode svg -file out.svg -svg_unit mm}}
        {{PS / EPS}        {tclmcairo::new w h -mode ps|eps -file out.ps}}
        {{Multi-page}      {$ctx newpage  ;# pdf|svg|ps|eps}}
        {{Finish file}     {$ctx finish   ;# flush + close}}
    }}
    {title {Basic Operations}  type table  mono 1  content {
        {{clear}           {$ctx clear r g b ?a?   ;# 0.0–1.0}}
        {{size}            {$ctx size  -> {w h}}}
        {{save}            {$ctx save filename   ;# .png .pdf .svg .ps .eps}}
        {{topng}           {$ctx topng  -> PNG bytearray (no file)}}
        {{toppm (0.3.5)}   {$ctx toppm  -> PPM bytearray (~10× faster, no zlib)}}
        {{todata}          {$ctx todata  -> raw ARGB32 bytes (Tk photo)}}
    }}
    {title {Shapes}  type table  mono 1  content {
        {{rect}            {$ctx rect x y w h ?-fill c? ?-stroke c? ?-radius r?}}
        {{circle}          {$ctx circle cx cy r ?opts?}}
        {{ellipse}         {$ctx ellipse cx cy rx ry ?opts?}}
        {{arc}             {$ctx arc cx cy r start end ?opts?}}
        {{line}            {$ctx line x1 y1 x2 y2 ?-color c? ?-width w? ?-dash {on off}?}}
        {{poly}            {$ctx poly x1 y1 x2 y2 x3 y3 ... ?opts?}}
        {{path}            {$ctx path "M x y L x y C ... Z" ?opts?}}
    }}
    {title {Common Draw Options}  type table  mono 0  content {
        {{-fill {r g b ?a?}} {fill color, alpha optional}}
        {{-fillname name}  {fill with named gradient}}
        {{-stroke {r g b ?a?}} {outline color}}
        {{-width n}        {line/outline width}}
        {{-alpha a}        {overall opacity 0.0–1.0}}
        {{-dash {on off}}  {dash pattern in points}}
        {{-linecap}        {butt | round | square}}
        {{-linejoin}       {miter | round | bevel}}
        {{-fillrule}       {winding | evenodd}}
        {{-radius r}       {rounded corners (rect)}}
    }}
    {title {Text}  type table  mono 1  content {
        {{text}            {$ctx text x y str -font "Sans Bold 14" -color {r g b}}}
        {{-anchor}         {center nw n ne e se s sw w}  0}
        {{-outline 1}      {text as path — enables -fillname (gradient), -stroke}  0}
        {{text_path}       {$ctx text_path x y str ?opts?  ;# always path}}
        {{font_measure}    {$ctx font_measure str font -> {w h ascent descent}}}
        {{select_font_face (0.3.4)} {$ctx select_font_face family ?-slant s? ?-weight w? ?-size n?}}
        {{text_extents (0.3.4)} {$ctx text_extents str -> dict (9 keys: w h x_bearing y_bearing ascent descent line_height x_advance y_advance)}}
    }}
    {title {Gradients}  type code  content {
        {# Linear: name x1 y1 x2 y2 stops}
        {$ctx gradient_linear g 0 0 400 0     {{0 1 0 0 1} {0.5 1 1 0 1} {1 0 0 1 1}}}
        {# stop: {offset r g b a}}
        ""
        {# Radial: name cx cy radius stops}
        {$ctx gradient_radial g2 200 150 100 {{0 1 0.9 0.2 1} {1 0 0 0.5 0}}}
        ""
        {$ctx rect 0 0 400 300 -fillname g}
        {$ctx circle 200 150 80 -fillname g2}
    }}
    {title {Clip Regions}  type code  content {
        {# Always wrap clips in push/pop:}
        {$ctx push}
        {$ctx clip_rect x y w h        ;# rectangular clip}
        {# ... draw clipped content ...}
        {$ctx clip_reset}
        {$ctx pop   ;# clip + state restored}
        ""
        {# Arbitrary shape:}
        {$ctx push}
        {$ctx clip_path "M 100 10 L 190 190 L 10 190 Z"}
        {$ctx rect 0 0 200 200 -fillname mygrad}
        {$ctx pop}
    }}
    {title {State Stack & Transforms}  type table  mono 1  content {
        {{push / pop}      {$ctx push  /  $ctx pop   (cairo_save/restore)}}
        {{-translate}      {$ctx transform -translate dx dy}}
        {{-rotate}         {$ctx transform -rotate degrees}}
        {{-scale}          {$ctx transform -scale sx sy}}
        {{-matrix}         {$ctx transform -matrix xx yx xy yy x0 y0}}
        {{-get}            {$ctx transform -get  -> {xx yx xy yy x0 y0}}}
        {{-reset}          {$ctx transform -reset}}
    }}
    {title {Images (file)}  type table  mono 1  content {
        {{image}           {$ctx image file x y ?-width w? ?-height h? ?-alpha a?}}
        {{JPEG in PDF}     {JPEG auto-embedded as MIME data — no re-encoding}  0}
        {{image_data}      {$ctx image_data bytes x y ?-width w? ?-height h?}}
        {{image_size (0.3.4)} {$ctx image_size id filename -> {w h}}}
    }}
    {title {Image Buffer Pool (0.3.5)}  type table  mono 1  content {
        {{image_load}      {set id [$ctx image_load filename]   ;# load to RAM (PNG/JPEG)}}
        {{image_info}      {lassign [$ctx image_info $id] w h}}
        {{image_blit}      {$ctx image_blit $id x y ?-width w? ?-height h? ?-alpha a?}}
        {{image_scale}     {set id2 [$ctx image_scale $id w h]  ;# bilinear, new id}}
        {{image_free}      {$ctx image_free $id}}
        {{image_load_surface} {set id [$ctx image_load_surface $other_ctx]  ;# no PNG roundtrip}}
        {{Pool}            {max 64 simultaneous images; ids global across contexts}  0}
    }}
    {title {Tk photo bridge (0.3.6)}  type code  content {
        {# Cairo -> Tk photo (already in 0.3.5):}
        {$tkphoto put [$ctx toppm] -format ppm}
        ""
        {# Tk photo -> Cairo (NEW in 0.3.6):}
        {set ppm [$tkphoto data -format ppm]}
        {$ctx image_from_ppm $ppm 0 0 ?-width w? ?-height h? ?-alpha a?}
        ""
        {# Round-trip for SVG/canvas exporters — no tempfile, no PNG re-encoding}
    }}
    {title {SVG Rendering}  type table  mono 1  content {
        {{svg_file (0.3.4)} {$ctx svg_file id filename x y ?opts?   ;# nanosvg, embedded}}
        {{svg_data (0.3.4)} {$ctx svg_data id svgstring x y ?opts?  ;# nanosvg from string}}
        {{svg_file_luna}   {$ctx svg_file_luna id filename x y ?opts?  ;# lunasvg, HAVE_LUNASVG}}
        {{svg_data_luna}   {$ctx svg_data_luna id svgstring x y ?opts?}}
        {{svg_size_luna}   {$ctx svg_size_luna id filename -> {w h}}}
        {{svg2cairo-0.1.tm} {tDOM postprocessor — CSS classes, <text>, <tspan>, <textPath> fallback}}
    }}
    {title {svg2cairo helpers}  type code  content {
        {package require svg2cairo}
        {svg2cairo::render      $ctx file.svg ?-x x? ?-y y? ?-width w? ?-height h? ?-scale s?}
        {svg2cairo::render_data $ctx $svgstring ?-x x? ...}
        ""
        {# Read dimensions without rendering}
        {lassign [svg2cairo::size      file.svg]   w h}
        {lassign [svg2cairo::size_data $svgstring] w h     ;# 0.3.6}
        ""
        {# Fit-to-box with min/max scale clamp (0.3.6)}
        {lassign [svg2cairo::sizeForFit file.svg 400 300] tw th scale}
        {lassign [svg2cairo::sizeForFit file.svg $maxW $maxH -min 0.5 -max 4.0] tw th scale}
    }}
    {title {Blit / Layer Compositing}  type code  content {
        {set bg  [tclmcairo::new 600 400]}
        {set fg  [tclmcairo::new 600 400]  ;# transparent}
        {# draw on each layer separately ...}
        {$bg blit $fg 0 0}
        {$bg blit $overlay 0 0 -alpha 0.7}
        {$bg save composite.png}
        {$bg destroy; $fg destroy}
    }}
    {title {Pan/Zoom with Image Pool (0.3.5)}  type code  content {
        {# Load once, blit many times — no disk I/O on redraw}
        {set img [$ctx image_load "photo.jpg"]}
        {lassign [$ctx image_info $img] iw ih}
        {# On each pan/zoom event:}
        {$ctx clear 1 1 1}
        {$ctx image_blit $img $panX $panY -width [expr {int($iw*$zoom)}]}
        {$tkphoto put [$ctx toppm] -format ppm}
        {# end of session:  $ctx image_free $img}
    }}
    {title {Plotchart-style (clip_rect)}  type code  content {
        {# Data->pixel mapping}
        {proc px x {expr {$lm + ($x-$xmin)/($xmax-$xmin)*$pw}}}
        {proc py y {expr {$H-$bm - ($y-$ymin)/($ymax-$ymin)*$ph}}}
        ""
        {# Clip to plot area — curves stay inside}
        {$ctx push}
        {$ctx clip_rect $lm $tm $pw $ph}
        "foreach {x y} $data {"
        {    # ... append to path ...}
        "}"
        {$ctx path $path -stroke {0.2 0.4 0.9} -width 2}
        {$ctx pop   ;# clip released}
        ""
        {# Axes drawn outside — no raise/lower needed}
        {$ctx line $lm [expr {$H-$bm}] [expr {$lm+$pw}] [expr {$H-$bm}]     -color {0.2 0.2 0.3} -width 1.5}
    }}
    {title {SVG Options}  type table  mono 0  content {
        {{-svg_version}    {1.1 | 1.2 (default)  — limits Cairo features}}
        {{-svg_unit}       {pt (default) px mm cm in em ex pc}}
        {{example mm}      {tclmcairo::new 210 297 -mode svg -file a4.svg -svg_unit mm}  1}
    }}
    {title {Build}  type code  content {
        {# Linux (TEA)}
        {autoconf && ./configure --with-tcl=/usr/lib/tcl8.6}
        {make && make test}
        ""
        {# Windows MSYS2}
        {make -f Makefile.win TARGET=mingw64}
        {make -f Makefile.win TARGET=mingw64 test}
        ""
        {# JPEG optional (default: auto-detect)}
        {make JPEG=0   ;# disable}
        ""
        {# lunasvg optional (0.3.4+) — see nogit/lunasvg-build.md}
        {make CFLAGS="... -DHAVE_LUNASVG -I${LUNADIR}/include ..."}
    }}
    {title {canvas2cairo (companion module)}  type code  content {
        {# Tk Canvas -> PDF/SVG/PS/EPS/PNG via tclmcairo}
        {package require canvas2cairo}
        {canvas2cairo::export $canvas filename.pdf}
        {canvas2cairo::export $canvas filename.png -scale 2.0}
        {canvas2cairo::export $canvas -chan $ch -format pdf}
        ""
        {# Skip UI items (selection markers, grid, rubber-band) — 0.3.6}
        {canvas2cairo::export $canvas out.pdf -exclude-tags {selMarker gridLine}}
        ""
        {# Capability check (0.3.6)}
        {if {![canvas2cairo::ready]} { ... }}
        {array set d [canvas2cairo::probe]   ;# status tclmcairo tk features ...}
        ""
        {# High-level: drop SVG onto canvas (0.3.6)}
        {set id [canvas2cairo::svgItem $canvas $x $y file.svg -size {200 150}]}
        {canvas2cairo::svgResize $canvas $id -size {400 300}}
    }}
    {title {tclmcairo::locate (0.3.6)}  type code  content {
        {tclmcairo::locate                   ;# -> install dir of tclmcairo}
        {tclmcairo::locate canvas2cairo      ;# -> path to .tm or ""}
        {tclmcairo::locate svg2cairo         ;# -> path to .tm or ""}
        {array set p [tclmcairo::locate -all]}
        {# Returns "" (not error) when not found — soft fallback}
    }}
    {title {Notes}  type list  content {
        {No Tk dependency — runs in plain tclsh.}
        {Thread safety: NOT thread-safe (same model as Tk).}
        {JPEG MIME embedding: PDF/SVG ~25% smaller than PNG re-encoded.}
        {clip_rect + push/pop replaces raise/lower in Plotchart-style charts.}
        {Image pool (0.3.5): for repeated draws of the same image (pan/zoom) — image_load + image_blit avoids disk I/O.}
        {toppm (0.3.5): ~10× faster than topng — use for Tk photo updates during animation.}
        {SVG rendering: nanosvg embedded (always); lunasvg optional (HAVE_LUNASVG).}
    }}
}
