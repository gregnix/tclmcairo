title    {tclmcairo 0.2 — Cheat Sheet}
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
    {title {Images}  type table  mono 1  content {
        {{image}           {$ctx image file x y ?-width w? ?-height h? ?-alpha a?}}
        {{JPEG in PDF}     {JPEG auto-embedded as MIME data — no re-encoding}  0}
        {{image_data}      {$ctx image_data bytes x y ?-width w? ?-height h?}}
        {{topng roundtrip} {set b [$src topng]  /  $dst image_data $b x y}}
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
    }}
    {title {Notes}  type list  content {
        {No Tk dependency — runs in plain tclsh.}
        {Thread safety: NOT thread-safe (same model as Tk).}
        {JPEG MIME embedding: PDF/SVG ~25% smaller than PNG re-encoded.}
        {clip_rect + push/pop replaces raise/lower in Plotchart-style charts.}
    }}
}
