#!/usr/bin/env tclsh8.6
# demos/demo-tclmcairo.tcl -- tclmcairo Demonstration
#
# Run: make demo
# or:  TCLMCAIRO_LIBDIR=. tclsh demos/demo-tclmcairo.tcl

set _tmdir [file normalize [file join [file dirname [info script]] ../tcl]]
if {$_tmdir ni [tcl::tm::path list]} { tcl::tm::path add $_tmdir }
unset _tmdir
package require tclmcairo

set outdir [file dirname [info script]]

# Helper: save all 5 formats
proc save_all {ctx outdir base} {
    foreach ext {png pdf svg ps eps} {
        set f [file join $outdir ${base}.${ext}]
        $ctx save $f
        puts "  -> $f"
    }
}

# ================================================================
# Demo 1: Shapes and colors
# ================================================================
puts "Demo 1: Shapes..."
set ctx [tclmcairo::new 600 400 -mode vector]
$ctx clear 0.08 0.10 0.20

$ctx gradient_linear bg 0 0 600 0 \
    {{0 0.08 0.10 0.25 1} {1 0.15 0.08 0.30 1}}
$ctx rect 0 0 600 400 -fillname bg

$ctx text 300 45 "tclmcairo v0.2 - Shapes" \
    -font "Sans Bold 22" -color {1 1 1} -anchor center

$ctx rect  30  80 120 80 -fill {1 0.4 0.1} -stroke {1 1 1} -width 1.5
$ctx rect 170  80 120 80 -fill {0.2 0.7 0.3} -radius 12
$ctx rect 310  80 120 80 -fill {0.2 0.4 1.0} -stroke {1 1 0} -width 2 -radius 6
$ctx rect 450  80 120 80 -fill {0.8 0.2 0.8} -alpha 0.7

foreach {x label} {90 "rect" 230 "radius" 370 "stroke" 510 "alpha"} {
    $ctx text $x 185 $label -font "Sans 11" -color {0.7 0.8 1} -anchor center
}

$ctx circle   80 270 55 -fill {1 0.8 0.1 0.9} -stroke {1 1 1} -width 1.5
$ctx circle  200 270 55 -fill {0.3 0.9 0.5}
$ctx ellipse 340 270 90 45 -fill {1 0.3 0.5 0.8}
$ctx ellipse 490 270 55 30 -stroke {0.5 1 1} -width 3

foreach {x label} {80 "circle" 200 "circle" 340 "ellipse" 490 "ellipse"} {
    $ctx text $x 340 $label -font "Sans 11" -color {0.7 0.8 1} -anchor center
}

$ctx line  30 370 170 370 -color {1 1 1} -width 3
$ctx line 190 370 330 370 -color {1 0.8 0} -width 3 -dash {12 4}
$ctx line 350 370 490 370 -color {0.5 1 0.5} -width 3 -dash {4 4} -linecap round
$ctx line 510 370 570 370 -color {1 0.4 1} -width 5 -linecap round

save_all $ctx $outdir demo-shapes
$ctx destroy

# ================================================================
# Demo 2: SVG paths
# ================================================================
puts "Demo 2: SVG paths..."
set ctx [tclmcairo::new 600 400 -mode vector]
$ctx clear 0.05 0.07 0.15

$ctx text 300 35 "tclmcairo v0.2 - SVG Paths" \
    -font "Sans Bold 20" -color {1 1 1} -anchor center

$ctx path "M 100 60 L 116 110 L 68 78 L 132 78 L 84 110 Z" \
    -fill {1 0.9 0} -stroke {1 0.6 0} -width 2

$ctx path "M 250 100 C 250 80 220 65 200 80 C 180 65 150 80 150 100 C 150 130 200 160 200 170 C 200 160 250 130 250 100 Z" \
    -fill {1 0.2 0.3} -stroke {0.8 0 0.1} -width 1.5

$ctx path "M 380 120 C 420 80 460 100 450 140 C 440 180 390 190 370 160 C 350 130 370 100 400 100 C 430 100 440 130 430 150" \
    -stroke {0.4 0.9 1} -width 3

$ctx path "M 480 80 L 560 120 L 480 160 L 500 120 Z" \
    -fill {0.8 0.5 1} -stroke {0.6 0.3 0.9} -width 2

$ctx path "M 50 250 L 100 200 L 150 250 L 200 200 L 250 250 L 300 200 L 350 250" \
    -stroke {0.3 1 0.5} -width 2.5 -linecap round -linejoin round

$ctx path "M 400 200 L 500 200 L 550 280 L 450 320 L 380 270 Z" \
    -fill {0.2 0.4 0.9 0.7} -stroke {0.5 0.8 1} -width 2

# fillrule evenodd — Stern mit Loch (NEU 0.2)
$ctx path "M 520 200 L 535 245 L 580 245 L 545 270 L 558 315 L 520 290 L 482 315 L 495 270 L 460 245 L 505 245 Z" \
    -fill {1 0.8 0} -fillrule evenodd -stroke {1 0.5 0} -width 1.5

foreach {x y label} {
    100 180 "Star"
    200 185 "Heart"
    415 195 "Spiral"
    520 180 "Arrow"
    200 340 "Wave line"
    465 345 "Polygon"
    520 340 "evenodd"
} {
    $ctx text $x $y $label -font "Sans 11" -color {0.6 0.7 0.9} -anchor center
}

save_all $ctx $outdir demo-paths
$ctx destroy

# ================================================================
# Demo 3: Gradients + transparency
# ================================================================
puts "Demo 3: Gradients..."
set ctx [tclmcairo::new 600 400 -mode vector]
$ctx clear 0.05 0.05 0.10

$ctx text 300 35 "tclmcairo v0.2 - Gradients" \
    -font "Sans Bold 20" -color {1 1 1} -anchor center

$ctx gradient_linear grad_h 30 0 270 0 \
    {{0 1 0 0 1} {0.33 1 1 0 1} {0.66 0 1 0 1} {1 0 0 1 1}}
$ctx rect 30 60 240 80 -fillname grad_h -radius 8

$ctx gradient_linear grad_v 0 160 0 280 \
    {{0 0.2 0.4 1 1} {0.5 0.8 0.9 1 0.9} {1 0.1 0.2 0.6 1}}
$ctx rect 30 160 240 120 -fillname grad_v -radius 8

$ctx gradient_radial grad_r 450 150 100 \
    {{0 1 1 1 1} {0.4 0.5 0.8 1 0.9} {0.7 0.1 0.3 0.8 0.6} {1 0 0 0.3 0}}
$ctx circle 450 150 100 -fillname grad_r

$ctx gradient_radial grad_light 450 300 80 \
    {{0 1 0.9 0.5 0.9} {0.3 0.9 0.7 0.2 0.7} {1 0.3 0.1 0 0}}
$ctx circle 450 300 80 -fillname grad_light -stroke {1 0.7 0.3} -width 2

$ctx text 150 155 "Linear horizontal" -font "Sans 12" -color {0.8 0.9 1} -anchor center
$ctx text 150 295 "Linear vertical"   -font "Sans 12" -color {0.8 0.9 1} -anchor center
$ctx text 450 265 "Radial"            -font "Sans 12" -color {0.8 0.9 1} -anchor center
$ctx text 450 395 "Radial (light)"    -font "Sans 12" -color {0.8 0.9 1} -anchor center

save_all $ctx $outdir demo-gradients
$ctx destroy

# ================================================================
# Demo 4: Text + font metrics
# ================================================================
puts "Demo 4: Text..."
set ctx [tclmcairo::new 600 450 -mode vector]
$ctx clear 0.06 0.08 0.16

$ctx text 300 40 "tclmcairo v0.2 - Text" \
    -font "Sans Bold 22" -color {1 1 1} -anchor center

set y 90
foreach {font label} {
    "Sans 14"             "Sans 14"
    "Sans Bold 14"        "Sans Bold 14"
    "Sans Italic 14"      "Sans Italic 14"
    "Sans Bold Italic 14" "Sans Bold Italic 14"
    "Sans 18"             "Sans 18"
    "Sans Bold 24"        "Sans Bold 24"
} {
    set m [$ctx font_measure $label $font]
    set w [format "%.0f" [lindex $m 0]]
    $ctx text 30  $y $label    -font $font      -color {0.9 0.95 1}
    $ctx text 570 $y "w=${w}px" -font "Sans 11" -color {0.5 0.6 0.8} -anchor e
    incr y 45
}

foreach {ax label} {150 "nw" 300 "center" 450 "se"} {
    set ay 400
    $ctx line [expr {$ax-5}] $ay [expr {$ax+5}] $ay -color {1 0.3 0.3} -width 1.5
    $ctx line $ax [expr {$ay-5}] $ax [expr {$ay+5}] -color {1 0.3 0.3} -width 1.5
    $ctx text $ax $ay $label -font "Sans 11" -color {1 0.8 0.4} -anchor $label
}

save_all $ctx $outdir demo-text
$ctx destroy

# ================================================================
# Demo 5: PDF vector export (A4)
# ================================================================
puts "Demo 5: PDF vector..."
set ctx [tclmcairo::new 595 842 -mode vector]
$ctx clear 1 1 1

$ctx gradient_linear hdr 0 0 595 0 \
    {{0 0.1 0.3 0.7 1} {1 0.2 0.5 0.9 1}}
$ctx rect 0 0 595 80 -fillname hdr

$ctx text 297 50 "tclmcairo v0.2 - PDF Export" \
    -font "Sans Bold 28" -color {1 1 1} -anchor center

$ctx text 50 120 "Vector graphics direct to PDF:" \
    -font "Sans Bold 16" -color {0.1 0.2 0.5}

$ctx circle 100 220 60  -fill {1 0.5 0.1 0.8} -stroke {0.8 0.3 0} -width 2
$ctx rect   200 165 160 110 -fill {0.2 0.6 0.9 0.7} -radius 15 \
    -stroke {0.1 0.4 0.7} -width 2
$ctx ellipse 460 220 80 55 -fill {0.7 0.2 0.8 0.7} -stroke {0.5 0 0.6} -width 2

$ctx path "M 50 350 L 150 300 L 250 350 L 350 300 L 450 350 L 545 300" \
    -stroke {0.2 0.6 0.3} -width 3 -linecap round -linejoin round

$ctx gradient_radial r1 200 480 120 \
    {{0 1 0.9 0 1} {0.5 0.8 0.5 0 0.7} {1 0.3 0.1 0 0}}
$ctx circle 200 480 120 -fillname r1

$ctx text 50 650 "Scalable without quality loss." \
    -font "Sans 14" -color {0.3 0.3 0.3}
$ctx text 50 680 "PDF/SVG/EPS directly from tclsh - no Tk required." \
    -font "Sans 14" -color {0.3 0.3 0.3}

$ctx rect 0 800 595 42 -fill {0.15 0.15 0.15}
$ctx text 297 826 "tclmcairo 0.2 - BSD License - https://github.com/gregnix/tclmcairo" \
    -font "Sans 11" -color {0.7 0.7 0.7} -anchor center

save_all $ctx $outdir demo-output
$ctx destroy

# ================================================================
# Demo 6: Multipage PDF (NEU 0.2)
# ================================================================
puts "Demo 6: Multipage PDF..."
set f [file join $outdir demo-multipage.pdf]
set ctx [tclmcairo::new 595 842 -mode pdf -file $f]

foreach {page_num bg_r bg_g bg_b title shapes} {
    1  0.98 0.98 1.0  "Page 1 — Shapes"     circle
    2  0.98 1.0  0.98 "Page 2 — Gradients"  gradient
    3  1.0  0.98 0.96 "Page 3 — Text"       text
} {
    $ctx clear $bg_r $bg_g $bg_b

    # Header
    $ctx gradient_linear hdr 0 0 595 0 \
        {{0 0.15 0.25 0.5 1} {1 0.3 0.5 0.8 1}}
    $ctx rect 0 0 595 60 -fillname hdr
    $ctx text 297 38 $title -font "Sans Bold 20" -color {1 1 1} -anchor center

    # Page number
    $ctx text 297 820 "— $page_num —" \
        -font "Sans 12" -color {0.5 0.5 0.5} -anchor center

    # Content per page
    switch $shapes {
        circle {
            foreach {cx cy r col} {
                150 420 80 {0.2 0.5 1 0.8}
                297 380 60 {1 0.5 0.1 0.8}
                440 420 70 {0.3 0.8 0.4 0.8}
            } {
                $ctx circle $cx $cy $r -fill $col -stroke {1 1 1} -width 2
            }
            $ctx text 297 550 "cairo_show_page → new page" \
                -font "Sans Italic 13" -color {0.4 0.4 0.6} -anchor center
        }
        gradient {
            $ctx gradient_linear g1 50 0 545 0 \
                {{0 1 0 0 1} {0.5 1 1 0 1} {1 0 0 1 1}}
            $ctx rect 50 120 495 100 -fillname g1 -radius 10
            $ctx gradient_radial g2 297 480 150 \
                {{0 1 0.9 0.2 1} {0.6 0.4 0.2 0.8 0.7} {1 0.1 0.05 0.2 0}}
            $ctx circle 297 480 150 -fillname g2
        }
        text {
            # text_path mit Gradient (NEU 0.2)
            $ctx gradient_linear tg 50 0 545 0 \
                {{0 0.2 0.5 1 1} {0.5 0.8 0.9 1 1} {1 0.1 0.3 0.8 1}}
            $ctx text_path 297 320 "tclmcairo" \
                -font "Sans Bold 72" -fillname tg \
                -stroke {0.1 0.2 0.4} -width 2 -anchor center
            $ctx text_path 297 420 "v0.2" \
                -font "Sans Bold 48" \
                -fill {0.3 0.3 0.3} -stroke {0.6 0.6 0.8} -width 1 \
                -anchor center
            $ctx text 297 520 "text_path with gradient fill" \
                -font "Sans Italic 14" -color {0.4 0.4 0.6} -anchor center
        }
    }

    if {$page_num < 3} { $ctx newpage }
}
$ctx finish
$ctx destroy
puts "  -> $f"

# ================================================================
# Demo 7: Clip regions (NEU 0.2)
# ================================================================
puts "Demo 7: Clip regions..."
set ctx [tclmcairo::new 600 400 -mode vector]
$ctx clear 0.08 0.08 0.14

$ctx text 300 35 "tclmcairo v0.2 - Clip Regions" \
    -font "Sans Bold 20" -color {1 1 1} -anchor center

# Panel 1: clip_rect — Kreis auf Rechteck begrenzt
$ctx push
$ctx clip_rect 30 70 160 200
$ctx gradient_radial gr1 110 170 120 \
    {{0 1 0.8 0.1 1} {0.5 0.8 0.4 0 0.8} {1 0 0 0.3 0}}
$ctx circle 110 170 120 -fillname gr1
$ctx clip_reset
$ctx pop
$ctx rect 30 70 160 200 -stroke {0.6 0.6 0.8} -width 1.5
$ctx text 110 290 "clip_rect" -font "Sans 12" -color {0.7 0.8 1} -anchor center

# Panel 2: clip_path — Ellipse als Clip-Maske
$ctx push
$ctx clip_path "M 370 170 C 370 100 430 70 490 70 C 550 70 610 100 610 170 C 610 240 550 270 490 270 C 430 270 370 240 370 170 Z"
$ctx gradient_linear gr2 370 0 610 0 \
    {{0 0.2 0.7 1 1} {0.5 0.9 0.5 0.1 1} {1 0.8 0.1 0.5 1}}
$ctx rect 370 70 240 200 -fillname gr2
$ctx path "M 390 90 L 610 270 M 610 90 L 390 270" \
    -stroke {1 1 1} -width 2 -alpha 0.3
$ctx clip_reset
$ctx pop
$ctx path "M 370 170 C 370 100 430 70 490 70 C 550 70 610 100 610 170 C 610 240 550 270 490 270 C 430 270 370 240 370 170 Z" \
    -stroke {0.6 0.6 0.8} -width 1.5
$ctx text 490 290 "clip_path" -font "Sans 12" -color {0.7 0.8 1} -anchor center

# Panel 3: Abgerundetes Thumbnail via clip_path (push/pop)
$ctx push
set rx 30; set ry 8
set tx 100; set ty 320; set tw 200; set th 70
$ctx clip_path "M [expr {$tx+$rx}] $ty L [expr {$tx+$tw-$rx}] $ty \
    C [expr {$tx+$tw}] $ty [expr {$tx+$tw}] [expr {$ty+$ry}] [expr {$tx+$tw}] [expr {$ty+$ry}] \
    L [expr {$tx+$tw}] [expr {$ty+$th-$ry}] \
    C [expr {$tx+$tw}] [expr {$ty+$th}] [expr {$tx+$tw-$rx}] [expr {$ty+$th}] [expr {$tx+$tw-$rx}] [expr {$ty+$th}] \
    L [expr {$tx+$rx}] [expr {$ty+$th}] \
    C $tx [expr {$ty+$th}] $tx [expr {$ty+$th-$ry}] $tx [expr {$ty+$th-$ry}] \
    L $tx [expr {$ty+$ry}] C $tx $ty [expr {$tx+$rx}] $ty [expr {$tx+$rx}] $ty Z"
$ctx gradient_linear gr3 $tx 0 [expr {$tx+$tw}] 0 \
    {{0 0.1 0.5 0.3 1} {0.4 0.5 0.9 0.5 1} {1 0.2 0.7 0.9 1}}
$ctx rect $tx $ty $tw $th -fillname gr3
$ctx text [expr {$tx+$tw/2}] [expr {$ty+$th/2+6}] "Rounded clip" \
    -font "Sans Bold 14" -color {1 1 1} -anchor center
$ctx clip_reset
$ctx pop
$ctx text [expr {$tx+$tw/2}] [expr {$ty+$th+20}] "push/pop" \
    -font "Sans 12" -color {0.7 0.8 1} -anchor center

save_all $ctx $outdir demo-clip
$ctx destroy

# ================================================================
# Demo 8: text_path (NEU 0.2)
# ================================================================
puts "Demo 8: text_path..."
set ctx [tclmcairo::new 600 400 -mode vector]
$ctx clear 0.05 0.05 0.12

$ctx text 300 35 "tclmcairo v0.2 - Text Path" \
    -font "Sans Bold 20" -color {1 1 1} -anchor center

# Gradient-Titel
$ctx gradient_linear tg1 0 0 600 0 \
    {{0 1 0.3 0 1} {0.3 1 1 0 1} {0.7 0.2 0.5 1 1} {1 1 0.8 0 1}}
$ctx text_path 300 115 "GRADIENT" \
    -font "Sans Bold 64" -fillname tg1 \
    -stroke {0.3 0.3 0.3} -width 0.8 -anchor center

# Outline-Text
$ctx text_path 300 200 "OUTLINE" \
    -font "Sans Bold 52" \
    -stroke {0.4 0.9 1} -width 2 -anchor center

# Gefüllter Text mit Schatten-Effekt (push/pop)
$ctx push
$ctx transform -translate 3 3
$ctx text_path 300 290 "SHADOW" \
    -font "Sans Bold 48" \
    -fill {0 0 0} -alpha 0.5 -anchor center
$ctx pop
$ctx text_path 300 290 "SHADOW" \
    -font "Sans Bold 48" \
    -fill {1 0.9 0.3} -stroke {0.8 0.6 0} -width 1 -anchor center

# Clip + text_path Kombination
$ctx push
$ctx clip_rect 0 310 600 90
$ctx text_path 300 380 "CLIPPED" \
    -font "Sans Bold 56" \
    -fill {0.8 0.3 0.9} -stroke {1 0.5 1} -width 1.5 -anchor center
$ctx clip_reset
$ctx pop
$ctx line 0 310 600 310 -color {0.4 0.4 0.6} -width 1 -dash {4 4}

save_all $ctx $outdir demo-textpath
$ctx destroy


# ================================================================
# Demo 9: PNG Transparency (NEU 0.2)
# ================================================================
puts "Demo 9: PNG Transparency..."

# Panel A: kein clear -> transparenter Hintergrund
set ctx [tclmcairo::new 300 300]
# Kein $ctx clear -> Hintergrund alpha=0
$ctx circle 150 150 120 -fill {0.2 0.5 1 0.8}
$ctx circle 150 150  80 -fill {0.9 0.7 0.1 0.9}
$ctx circle 150 150  40 -fill {1 1 1}
$ctx text 150 280 "no clear -> transparent BG" \
    -font "Sans 11" -color {0.3 0.3 0.3} -anchor center
$ctx save [file join $outdir demo-transparent-rings.png]
puts "  -> [file join $outdir demo-transparent-rings.png]"
$ctx destroy

# Panel B: clear 0 0 0 0 -> explizit transparent
set ctx [tclmcairo::new 300 120]
$ctx clear 0 0 0 0
$ctx gradient_linear g 0 0 300 0 {{0 0.2 0.6 1 1} {1 0.8 0.2 0.9 1}}
$ctx rect 20 20 260 80 -fillname g -radius 16
$ctx text 150 65 "Transparent BG" \
    -font "Sans Bold 18" -color {1 1 1} -anchor center
$ctx save [file join $outdir demo-transparent-badge.png]
puts "  -> [file join $outdir demo-transparent-badge.png]"
$ctx destroy

# Panel C: Schatten-Effekt mit alpha
set ctx [tclmcairo::new 400 200]
# kein clear -> transparent
foreach {dx dy} {8 8  4 4} {
    $ctx rect [expr {60+$dx}] [expr {40+$dy}] 280 120 \
        -fill {0 0 0 0.3} -radius 12
}
$ctx rect 60 40 280 120 -fill {0.15 0.15 0.2} -radius 12
$ctx rect 60 40 280 2   -fill {1 1 1 0.15} -radius 2
$ctx text 200 95 "Shadow Card" \
    -font "Sans Bold 20" -color {1 1 1} -anchor center
$ctx text 200 122 "alpha=0.3 shadow on transparent" \
    -font "Sans 11" -color {0.6 0.6 0.7} -anchor center
$ctx save [file join $outdir demo-transparent-card.png]
puts "  -> [file join $outdir demo-transparent-card.png]"
$ctx destroy

# Panel D: Gradient-Fade-out (alpha 1->0)
set ctx [tclmcairo::new 400 150]
# kein clear -> transparent
$ctx gradient_linear fade 0 0 400 0 \
    {{0 0.2 0.5 0.9 1} {0.7 0.2 0.5 0.9 1} {1 0.2 0.5 0.9 0}}
$ctx rect 0 0 400 150 -fillname fade
$ctx text 160 85 "Fade to transparent" \
    -font "Sans Bold 16" -color {1 1 1} -anchor center
$ctx save [file join $outdir demo-transparent-fade.png]
puts "  -> [file join $outdir demo-transparent-fade.png]"
$ctx destroy

# ================================================================
# Demo 10: Blit / Layer Compositing (NEU 0.2)
# ================================================================
puts "Demo 10: Blit / Layers..."

# Hintergrund-Layer
set bg [tclmcairo::new 600 400]
$bg gradient_linear sky 0 0 0 400 \
    {{0 0.4 0.6 0.9 1} {0.6 0.6 0.75 0.9 1} {1 0.85 0.8 0.7 1}}
$bg rect 0 0 600 400 -fillname sky
# Boden
$bg gradient_linear ground 0 280 0 400 \
    {{0 0.3 0.5 0.2 1} {1 0.2 0.35 0.15 1}}
$bg rect 0 280 600 120 -fillname ground

# Layer: Berge (transparent, vector)
set mountains [tclmcairo::new 600 400]
$mountains path "M 0 300 L 80 180 L 160 260 L 240 140 L 340 230 \
    L 420 120 L 520 220 L 600 160 L 600 400 L 0 400 Z" \
    -fill {0.45 0.55 0.45 0.9}
$mountains path "M 0 320 L 60 220 L 120 280 L 200 190 L 280 260 \
    L 360 200 L 450 270 L 540 210 L 600 250 L 600 400 L 0 400 Z" \
    -fill {0.35 0.45 0.35 0.95}

# Layer: Sonne (transparent)
set sun [tclmcairo::new 120 120]
$sun gradient_radial sg 60 60 55 \
    {{0 1 1 0.8 1} {0.5 1 0.85 0.1 0.9} {1 1 0.6 0 0}}
$sun circle 60 60 55 -fillname sg

# Layer: Wolken (transparent)
set clouds [tclmcairo::new 600 200]
foreach {cx cy r a} {
    120 80 45 0.85   150 65 35 0.85   95 75 30 0.85
    380 60 50 0.80   415 48 38 0.80   350 70 32 0.80
    540 90 40 0.75   570 75 30 0.75
} {
    $clouds circle $cx $cy $r -fill [list 1 1 1 $a]
}

# Layer: Text-Banner (transparent)
set banner [tclmcairo::new 400 80]
$banner rect 0 0 400 80 -fill {0 0 0 0.5} -radius 12
$banner gradient_linear tg 0 0 400 0 \
    {{0 1 0.9 0.3 1} {0.5 1 1 0.6 1} {1 0.4 0.9 1 1}}
$banner text 200 50 "blit compositing" \
    -font "Sans Bold 24" -fillname tg -outline 1 -anchor center

# Zusammensetzen (Reihenfolge = Tiefe)
$bg blit $mountains 0   0
$bg blit $sun       460 20  -alpha 0.9
$bg blit $clouds    0   0   -alpha 0.85
$bg blit $banner    100 310

$bg save [file join $outdir demo-blit.png]
$bg save [file join $outdir demo-blit.pdf]
puts "  -> [file join $outdir demo-blit.png]"
puts "  -> [file join $outdir demo-blit.pdf]"

$bg destroy; $mountains destroy; $sun destroy
$clouds destroy; $banner destroy

# ----
# Zweites Beispiel: Icon-Sheet aus Einzel-Icons zusammensetzen
set sheet [tclmcairo::new 280 80]
$sheet clear 0.12 0.12 0.18

foreach {ix label col} {
    0  "Rect"   {0.2 0.5 1}
    1  "Circle" {1 0.5 0.1}
    2  "Star"   {0.9 0.8 0.1}
    3  "Text"   {0.4 0.9 0.5}
} {
    set icon [tclmcairo::new 60 60]
    switch $ix {
        0 { $icon rect 10 10 40 40 -fill $col -radius 6 }
        1 { $icon circle 30 30 25 -fill $col }
        2 { $icon path "M 30 5 L 36 22 L 54 22 L 40 33 L 45 50 \
                L 30 40 L 15 50 L 20 33 L 6 22 L 24 22 Z" \
                -fill $col -fillrule evenodd }
        3 { $icon text 30 38 "A" -font "Sans Bold 36" \
                -color $col -anchor center }
    }
    set px [expr {$ix * 70 + 5}]
    $sheet blit $icon $px 5 -width 60 -height 60
    $sheet text [expr {$px + 30}] 77 $label \
        -font "Sans 9" -color {0.7 0.7 0.8} -anchor center
    $icon destroy
}

$sheet save [file join $outdir demo-blit-icons.png]
puts "  -> [file join $outdir demo-blit-icons.png]"
$sheet destroy

# ================================================================
# Demo 11: PNG formats, topng, image_data (NEU 0.2)
# ================================================================
puts "Demo 11: PNG Formats + topng + image_data..."

# Teil A: -format Vergleich argb32 vs rgb24 vs a8
set f [file join $outdir demo-png-formats.png]
set canvas [tclmcairo::new 620 310]
$canvas clear 0.1 0.1 0.16

$canvas text 310 28 "PNG Pixel Formats" \
    -font "Sans Bold 18" -color {1 1 1} -anchor center

# ---- Panel 1: ARGB32 ----
# zeigt transparenten Hintergrund (Schachbrett-Hint) + Alpha-Kreis
set ctx [tclmcairo::new 170 160]
# Schachbrett-Muster als BG-Hint (kein clear -> transparent)
foreach {rx ry} {0 0  20 20  40 0  60 20  80 0  100 20  120 0  140 20
                  0 20  20 0   40 20  60 0   80 20  100 0   120 20  140 0
                  0 40  20 60  40 40  60 60  80 40  100 60  120 40  140 60
                  0 60  20 40  40 60  60 40  80 60  100 40  120 60  140 40
                  0 80  20 100 40 80  60 100 80 80  100 100 120 80  140 100
                  0 100 20 80  40 100 60 80  80 100 100 80  120 100 140 80
                  0 120 20 140 40 120 60 140 80 120 100 140 120 120 140 140
                  0 140 20 120 40 140 60 120 80 140 100 120 120 140 140 120} {
    $ctx rect $rx $ry 20 20 -fill {0.3 0.3 0.35}
}
$ctx circle 85 80 60 -fill {0.2 0.5 1 0.9}
$ctx circle 85 80 35 -fill {0.2 0.5 1 0.35}
$ctx circle 85 80 12 -fill {1 1 1 0.7}
set bytes_a32 [$ctx topng]
$ctx destroy
$canvas image_data $bytes_a32 15 45
$canvas text  100 218 "ARGB32" -font "Sans Bold 12" -color {0.9 0.9 1} -anchor center
$canvas text  100 233 "32-bit + Alpha" -font "Sans 10" -color {0.6 0.6 0.7} -anchor center
$canvas text  100 248 "transparent BG" -font "Sans 9" -color {0.4 0.7 0.4} -anchor center
$canvas text  100 262 "[string length $bytes_a32]B" -font "Sans 9" -color {0.5 0.6 0.5} -anchor center

# ---- Panel 2: RGB24 ----
# zeigt: kein Alpha möglich, BG immer solid
set ctx [tclmcairo::new 170 160 -format rgb24]
$ctx clear 0.15 0.15 0.2   ;# BG muss explizit gesetzt werden
$ctx circle 85 80 60 -fill {0.3 0.8 0.4}
$ctx circle 85 80 35 -fill {0.2 0.6 0.3}
$ctx circle 85 80 12 -fill {1 1 1}
$ctx text 85 84 "RGB" -font "Sans Bold 16" -color {0.15 0.15 0.2} -anchor center
set bytes_r24 [$ctx topng]
$ctx destroy
$canvas image_data $bytes_r24 215 45
$canvas text  300 218 "RGB24" -font "Sans Bold 12" -color {0.9 0.9 1} -anchor center
$canvas text  300 233 "24-bit, no alpha" -font "Sans 10" -color {0.6 0.6 0.7} -anchor center
$canvas text  300 248 "solid BG always" -font "Sans 9" -color {0.8 0.5 0.4} -anchor center
$canvas text  300 262 "[string length $bytes_r24]B" -font "Sans 9" -color {0.5 0.6 0.5} -anchor center

# ---- Panel 3: A8 als Maske in Aktion ----
# A8-Oberfläche: definiert NUR den Alpha-Kanal
set mask [tclmcairo::new 170 160 -format a8]
# Weiss = opak, Schwarz = transparent
# Kreis-Ring + Buchstaben-Form
$mask circle 85 80 65 -fill {1 1 1}           ;# äusserer Ring opak
$mask circle 85 80 42 -fill {0 0 0}           ;# Loch
$mask circle 85 80 20 -fill {1 1 1}           ;# innerer Punkt
# Vier Nasen
foreach {mx my} {85 18  85 142  18 80  152 80} {
    $mask circle $mx $my 12 -fill {1 1 1}
}
set mask_bytes [$mask topng]
$mask destroy

# Maske auf Gradient anwenden: Gradient-BG + clip_path simuliert A8-Effekt
# Echte A8-Maske: Gradient dort sichtbar wo A8=weiß
set a8demo [tclmcairo::new 170 160]
# Gradient-Hintergrund
$a8demo gradient_linear g1 0 0 170 160 \
    {{0 1 0.3 0 1} {0.4 0.9 0.8 0.1 1} {0.8 0.2 0.5 1 1} {1 0.8 0.2 0.9 1}}
$a8demo rect 0 0 170 160 -fillname g1

# A8-Maske anwenden: clip auf äusseren Ring
$a8demo push
$a8demo clip_path "M 85 15 A 65 65 0 1 1 84.99 15 Z  \
    M 85 38 A 42 42 0 1 0 84.99 38 Z"
$a8demo gradient_linear g2 0 0 170 0 \
    {{0 1 1 1 0.8} {1 1 1 1 0.8}}
$a8demo rect 0 0 170 160 -fillname g2
$a8demo clip_reset
$a8demo pop

# Innerer Punkt
$a8demo push
$a8demo clip_path "M 85 60 A 20 20 0 1 1 84.99 60 Z"
$a8demo rect 0 0 170 160 -fillname g1
$a8demo clip_reset
$a8demo pop

# Vier Nasen
foreach {mx my} {85 18  85 142  18 80  152 80} {
    $a8demo push
    $a8demo clip_path "M $mx [expr {$my-12}] A 12 12 0 1 1 [expr {$mx-0.01}] [expr {$my-12}] Z"
    $a8demo rect 0 0 170 160 -fillname g1
    $a8demo clip_reset
    $a8demo pop
}

set bytes_a8 [$a8demo topng]
$a8demo destroy

$canvas image_data $bytes_a8 415 45
$canvas text  500 218 "A8 as Mask" -font "Sans Bold 12" -color {0.9 0.9 1} -anchor center
$canvas text  500 233 "alpha channel only" -font "Sans 10" -color {0.6 0.6 0.7} -anchor center
$canvas text  500 248 "gradient through mask" -font "Sans 9" -color {0.4 0.7 0.4} -anchor center
$canvas text  500 262 "[string length $bytes_a8]B" -font "Sans 9" -color {0.5 0.6 0.5} -anchor center

# Trennlinien
$canvas line 208 45 208 215 -color {0.3 0.3 0.4} -width 1 -dash {4 4}
$canvas line 408 45 408 215 -color {0.3 0.3 0.4} -width 1 -dash {4 4}

# Format-Erklärung unten
$canvas rect 15 270 590 30 -fill {0.15 0.15 0.22} -radius 6
$canvas text 310 289 \
    "ARGB32: transparent possible  ·  RGB24: solid only  ·  A8: mask for clipping/compositing" \
    -font "Sans 10" -color {0.6 0.7 0.8} -anchor center

$canvas save $f
$canvas destroy
puts "  -> $f"

# Teil B: topng Roundtrip-Kette
set f [file join $outdir demo-topng-chain.png]
set out [tclmcairo::new 580 180]
$out clear 0.08 0.08 0.14
$out text 290 25 "topng → image_data → topng (Roundtrip Chain)" \
    -font "Sans Bold 14" -color {1 1 1} -anchor center

# Original erzeugen
set orig [tclmcairo::new 100 120]
$orig clear 0 0 0 0
$orig gradient_radial gr 50 60 45 \
    {{0 1 0.9 0.2 1} {0.6 0.5 0.8 1 0.8} {1 0 0 0.5 0}}
$orig circle 50 60 45 -fillname gr -stroke {1 1 1} -width 1.5

set bytes [$orig topng]
$orig destroy

# 4 Generationen
set x 20
set gen 0
foreach alpha {1.0 0.85 0.7 0.55 0.4} label {"Original" "Gen 1" "Gen 2" "Gen 3" "Gen 4"} {
    # PNG-Bytes → zeichnen
    $out image_data $bytes $x 40 -width 90 -height 110 -alpha $alpha
    $out text [expr {$x+45}] 162 $label \
        -font "Sans 10" -color {0.6 0.7 0.8} -anchor center

    # Nächste Generation: neu zeichnen + topng
    if {$gen < 4} {
        set tmp [tclmcairo::new 100 120]
        $tmp clear 0 0 0 0
        $tmp image_data $bytes 0 0
        set bytes [$tmp topng]
        $tmp destroy
    }
    incr x 110
    incr gen
}

# Pfeil zwischen Generationen
for {set ax 113} {$ax < 470} {incr ax 110} {
    $out line $ax 95 [expr {$ax+17}] 95 \
        -color {0.4 0.6 0.8} -width 1.5 -linecap round
    $out path "M [expr {$ax+17}] 89 L [expr {$ax+24}] 95 L [expr {$ax+17}] 101 Z" \
        -fill {0.4 0.6 0.8}
}

$out save $f
$out destroy
puts "  -> $f"

# Teil C: topng für In-Memory-Workflow
set f [file join $outdir demo-topng-inmemory.png]
set sheet [tclmcairo::new 580 200]
$sheet clear 0.1 0.1 0.18
$sheet text 290 22 "topng: In-Memory PNG Workflow" \
    -font "Sans Bold 14" -color {1 1 1} -anchor center

# Mehrere Icons in-memory erzeugen und kombinieren
set icons {}
foreach {shape col label} {
    circle  {0.2 0.6 1.0}   "Network"
    rect    {0.3 0.8 0.4}   "Storage"
    path    {1.0 0.6 0.2}   "Process"
    ellipse {0.8 0.3 0.9}   "Display"
    poly    {1.0 0.8 0.2}   "Config"
} {
    set ic [tclmcairo::new 80 80]
    switch $shape {
        circle  { $ic circle  40 40 32 -fill $col }
        rect    { $ic rect    12 12 56 56 -fill $col -radius 10 }
        path    { $ic path "M 40 10 L 52 30 L 70 30 L 56 46 L 62 66 L 40 54 L 18 66 L 24 46 L 10 30 L 28 30 Z" \
                    -fill $col -fillrule evenodd }
        ellipse { $ic ellipse 40 40 35 22 -fill $col }
        poly    { $ic poly 40 12 62 30 54 56 26 56 18 30 \
                    -fill $col }
    }
    lappend icons [$ic topng]
    $ic destroy
}

# Icons aus Bytes auf Sheet zeichnen — kein Disk-Zugriff!
set x 30
foreach bytes $icons label {Network Storage Process Display Config} {
    $sheet image_data $bytes $x 40 -width 80 -height 80
    $sheet text [expr {$x+40}] 135 $label \
        -font "Sans 11" -color {0.8 0.8 0.9} -anchor center

    # Byte-Größe anzeigen
    $sheet text [expr {$x+40}] 150 "[string length $bytes]B" \
        -font "Sans 9" -color {0.5 0.6 0.5} -anchor center
    incr x 108
}

# Workflow-Label unten
$sheet text 290 180 \
    "Icons created in memory — no temp files — direct compose" \
    -font "Sans Italic 11" -color {0.5 0.6 0.7} -anchor center

$sheet save $f
$sheet destroy
puts "  -> $f"


# ================================================================
puts "Demo 12: MIME Data Embedding..."

# ----------------------------------------------------------------
# Was Cairo MIME macht:
#   JPEG: load_jpeg() setzt CAIRO_MIME_TYPE_JPEG automatisch
#         → Cairo PDF/SVG bettet Original-JPEG 1:1 ein
#         → kein Re-encoding, kein Qualitätsverlust, kleines PDF
#   PNG:  Cairo PDF/SVG re-enkodiert immer als Pixel-Daten
#         → CAIRO_MIME_TYPE_PNG wird von aktuellen Backends ignoriert
# ----------------------------------------------------------------

# ---- JPEG-Datei erzeugen (via libjpeg) ----
# tclmcairo hat keinen JPEG-Output → via Tcl/exec erstellen
set jpg_file [file join $outdir demo-mime-source.jpg]
set png_tmp  [file join $outdir demo-mime-source-tmp.png]

# PNG erzeugen und zu JPEG konvertieren
set src [tclmcairo::new 300 200]
$src clear 0.15 0.15 0.22
for {set i 0} {$i < 80} {incr i} {
    $src circle \
        [expr {int(rand()*290)+5}] [expr {int(rand()*190)+5}] \
        [expr {int(rand()*18)+4}] \
        -fill [list [expr {rand()}] [expr {rand()}] [expr {rand()}] 1.0]
}
$src text 150 185 "JPEG source image" \
    -font "Sans Bold 13" -color {1 1 1 0.8} -anchor center
$src save $png_tmp
$src destroy

# Plattform-native Pfade (wichtig fuer Windows)
set png_tmp_native [file nativename $png_tmp]
set jpg_file_native [file nativename $jpg_file]

# PNG -> JPEG: magick (ImageMagick 7) > convert (IM6/Linux) > cjpeg
# Hinweis: auf Windows existiert ein System-convert.exe (Disk-Tool) --
# deshalb immer zuerst 'magick' versuchen.
set jpeg_ok 0
foreach {cmd args} [list \
    magick  [list $png_tmp_native -quality 85 $jpg_file_native] \
    convert [list $png_tmp_native -quality 85 $jpg_file_native] \
    cjpeg   [list -quality 85 -outfile $jpg_file_native $png_tmp_native] \
] {
    if {!$jpeg_ok && ![catch {exec {*}[concat $cmd $args]} err]} {
        if {[file exists $jpg_file]} { set jpeg_ok 1 }
    }
}
if {!$jpeg_ok} {
    puts "  (JPEG conversion not available — using PNG for Demo 12)"
    puts "  (Install ImageMagick or libjpeg-turbo for JPEG comparison)"
    set jpg_file $png_tmp
}
# png_tmp deleted at end

set jpg_sz [file size $jpg_file]
set is_jpeg [expr {[string match *.jpg $jpg_file]}]

# ---- Zwei PDFs: JPEG vs PNG gleiche Bildgröße ----
set pdf_jpeg [file join $outdir demo-mime-jpeg.pdf]
set pdf_png  [file join $outdir demo-mime-png.pdf]

# PDF mit JPEG (MIME auto-embedded)
set ctx [tclmcairo::new 500 240 -mode pdf -file $pdf_jpeg]
$ctx clear 0.97 0.97 1.0
$ctx gradient_linear hdr 0 0 500 0 {{0 0.1 0.4 0.7 1} {1 0.2 0.6 0.9 1}}
$ctx rect 0 0 500 40 -fillname hdr
$ctx text 250 26 "JPEG: MIME auto-embedded (CAIRO_MIME_TYPE_JPEG)" \
    -font "Sans Bold 13" -color {1 1 1} -anchor center
foreach {ix iy iw ih} {10 50 220 180  240 50 120 100  370 50 120 100  240 160 250 70} {
    $ctx image $jpg_file $ix $iy -width $iw -height $ih
}
$ctx text 250 228 "Original JPEG bytes embedded 1:1 — no re-encoding" \
    -font "Sans Italic 11" -color {0.3 0.5 0.3} -anchor center
$ctx finish
$ctx destroy

# PDF mit PNG (re-encoded)
set ctx [tclmcairo::new 500 240 -mode pdf -file $pdf_png]
$ctx clear 0.97 0.97 1.0
$ctx gradient_linear hdr2 0 0 500 0 {{0 0.5 0.2 0.1 1} {1 0.7 0.4 0.2 1}}
$ctx rect 0 0 500 40 -fillname hdr2
$ctx text 250 26 "PNG: re-encoded as pixel data" \
    -font "Sans Bold 13" -color {1 1 1} -anchor center
foreach {ix iy iw ih} {10 50 220 180  240 50 120 100  370 50 120 100  240 160 250 70} {
    $ctx image $png_tmp $ix $iy -width $iw -height $ih
}

# Fallback: falls png_tmp schon gelöscht
if {![file exists $png_tmp]} {
    set src2 [tclmcairo::new 300 200]
    $src2 clear 0.3 0.3 0.4
    $src2 text 150 100 "PNG source" -font "Sans Bold 20" \
        -color {1 1 1} -anchor center
    $src2 save $png_tmp
    $src2 destroy
    foreach {ix iy iw ih} {10 50 220 180  240 50 120 100  370 50 120 100  240 160 250 70} {
        $ctx image $png_tmp $ix $iy -width $iw -height $ih
    }
}
$ctx text 250 228 "PNG decoded to BGRA pixels, re-compressed in PDF" \
    -font "Sans Italic 11" -color {0.5 0.3 0.2} -anchor center
$ctx finish
$ctx destroy

set sz_jpeg [file size $pdf_jpeg]
set sz_png  [file size $pdf_png]
set saving  [expr {$sz_png - $sz_jpeg}]
set pct     [format "%.1f" [expr {$sz_png>0 ? 100.0*$saving/$sz_png : 0}]]

# ---- Übersichts-PNG: Architektur + Größenvergleich ----
set overview [file join $outdir demo-mime-compare.png]
set canvas [tclmcairo::new 620 300]
$canvas clear 0.1 0.1 0.18

$canvas text 310 26 "MIME Data Embedding in Cairo" \
    -font "Sans Bold 17" -color {1 1 1} -anchor center

# JPEG Pipeline
$canvas rect 15 48 590 66 -fill {0.10 0.18 0.12} -radius 6
$canvas text 310 60 "JPEG: CAIRO_MIME_TYPE_JPEG — auto-embedded (load_jpeg)" \
    -font "Sans 11" -color {0.4 0.9 0.5} -anchor center
foreach {px lbl col} {
    18  "JPEG\nfile"      {0.2 0.4 0.7}
    165 "MIME\nattach"    {0.2 0.6 0.3}
    315 "PDF 1:1\nembed"  {0.2 0.7 0.3}
    470 "small\nPDF ✔"   {0.2 0.8 0.3}
} {
    $canvas rect $px 68 128 34 -fill $col -radius 5
    $canvas text [expr {$px+64}] 89 $lbl \
        -font "Sans Bold 10" -color {1 1 1} -anchor center
}
foreach ax {149 299 449} {
    $canvas line $ax 85 [expr {$ax+13}] 85 -color {0.3 0.7 0.4} -width 2
    $canvas path "M [expr {$ax+13}] 79 L [expr {$ax+20}] 85 L [expr {$ax+13}] 91 Z" \
        -fill {0.3 0.7 0.4}
}

# PNG Pipeline
$canvas rect 15 128 590 66 -fill {0.18 0.12 0.10} -radius 6
$canvas text 310 140 "PNG: no MIME support in Cairo PDF/SVG backends" \
    -font "Sans 11" -color {0.9 0.5 0.4} -anchor center
foreach {px lbl col} {
    18  "PNG\nfile"        {0.3 0.4 0.7}
    165 "decode\nBGRA"     {0.6 0.3 0.2}
    315 "deflate\ncompress" {0.5 0.3 0.2}
    470 "larger\nPDF ✗"   {0.7 0.3 0.2}
} {
    $canvas rect $px 148 128 34 -fill $col -radius 5
    $canvas text [expr {$px+64}] 169 $lbl \
        -font "Sans Bold 10" -color {1 1 1} -anchor center
}
foreach ax {149 299 449} {
    $canvas line $ax 165 [expr {$ax+13}] 165 -color {0.6 0.4 0.3} -width 2
    $canvas path "M [expr {$ax+13}] 159 L [expr {$ax+20}] 165 L [expr {$ax+13}] 171 Z" \
        -fill {0.6 0.4 0.3}
}

# Größenvergleich
$canvas rect 15 208 590 42 -fill {0.14 0.14 0.20} -radius 6
set bar_w 460
set bx 75

set b_jpeg [expr {$sz_jpeg>0 && $sz_png>0 ? int($bar_w * $sz_jpeg / $sz_png) : 0}]
$canvas text $bx 223 "JPEG" -font "Sans 10" -color {0.4 0.8 0.5} -anchor e
$canvas rect $bx 216 $b_jpeg 10 -fill {0.2 0.6 0.3} -radius 2
$canvas text [expr {$bx+$b_jpeg+4}] 224 "[expr {$sz_jpeg/1024}]KB" \
    -font "Sans 9" -color {0.5 0.8 0.5}

$canvas text $bx 238 "PNG" -font "Sans 10" -color {0.8 0.5 0.4} -anchor e
$canvas rect $bx 231 $bar_w 10 -fill {0.6 0.3 0.2} -radius 2
$canvas text [expr {$bx+$bar_w+4}] 239 "[expr {$sz_png/1024}]KB" \
    -font "Sans 9" -color {0.8 0.5 0.4}

set sc [expr {$saving >= 0 ? {0.3 0.9 0.4} : {0.9 0.5 0.3}}]
if {$is_jpeg} {
    set savings_label "Saved with JPEG MIME: ${saving}B (${pct}%)  ·  Source: ${jpg_sz}B JPEG"
} else {
    set savings_label "No JPEG available — install ImageMagick for JPEG comparison"
    set sc {0.6 0.6 0.4}
}
$canvas text 310 256 $savings_label \
    -font "Sans Bold 11" -color $sc -anchor center

$canvas text 310 278 \
    "JPEG is always auto-embedded  ·  PNG: re-encoded as pixels (Cairo limitation)" \
    -font "Sans 10" -color {0.5 0.6 0.7} -anchor center

$canvas save $overview
$canvas destroy

puts "  -> $pdf_jpeg ([file size $pdf_jpeg] Bytes, JPEG MIME)"
puts "  -> $pdf_png  ([file size $pdf_png] Bytes, PNG re-encoded)"
puts "  -> $overview"
puts "     Saved: ${saving}B (${pct}%)"

# png_tmp deleted at end

# ================================================================

# Demo 13: Plotchart-style — axes outside, data clipped
# ================================================================
puts "Demo 13: Plotchart-style chart..."

set f [file join $outdir demo-plotchart.png]

# Chart geometry
set W 600; set H 400
set lm 70; set rm 20; set tm 20; set bm 50
set pw [expr {$W - $lm - $rm}]   ;# plot width
set ph [expr {$H - $tm - $bm}]   ;# plot height

# Data ranges
set xmin 0.0; set xmax 10.0
set ymin -1.2; set ymax 1.2

# Map data -> pixels
proc px {x} {
    global lm pw xmin xmax
    expr {$lm + ($x - $xmin) / ($xmax - $xmin) * $pw}
}
proc py {y} {
    global tm ph ymin ymax H bm
    expr {$H - $bm - ($y - $ymin) / ($ymax - $ymin) * $ph}
}

set ctx [tclmcairo::new $W $H]
$ctx clear 0.97 0.97 0.99

# ---- Plot area background ----
$ctx rect $lm $tm $pw $ph -fill {1 1 1} -stroke {0.7 0.7 0.7} -width 1

# ---- Grid lines (inside plot area, clipped) ----
$ctx push
$ctx clip_rect $lm $tm $pw $ph

$ctx gradient_linear gbg $lm 0 [expr {$lm+$pw}] 0 \
    {{0 0.95 0.97 1.0 1} {1 0.97 0.97 1.0 1}}
$ctx rect $lm $tm $pw $ph -fillname gbg

foreach y {-1.0 -0.5 0.0 0.5 1.0} {
    set ypx [py $y]
    if {$y == 0.0} {
        $ctx line $lm $ypx [expr {$lm+$pw}] $ypx \
            -color {0.5 0.5 0.7} -width 1.5
    } else {
        $ctx line $lm $ypx [expr {$lm+$pw}] $ypx \
            -color {0.8 0.8 0.9} -width 0.8 -dash {4 4}
    }
}
foreach x {2 4 6 8} {
    set xpx [px $x]
    $ctx line $xpx $tm $xpx [expr {$tm+$ph}] \
        -color {0.8 0.8 0.9} -width 0.8 -dash {4 4}
}

# ---- Data lines (clipped to plot area) ----
# sin(x)
set pts {}
for {set i 0} {$i <= 100} {incr i} {
    set x [expr {$xmin + $i * ($xmax-$xmin) / 100.0}]
    set y [expr {sin($x)}]
    lappend pts [px $x] [py $y]
}
set path "M [lindex $pts 0] [lindex $pts 1]"
for {set i 2} {$i < [llength $pts]} {incr i 2} {
    append path " L [lindex $pts $i] [lindex $pts [expr {$i+1}]]"
}
$ctx path $path -stroke {0.2 0.4 0.9} -width 2.5

# cos(x)
set pts {}
for {set i 0} {$i <= 100} {incr i} {
    set x [expr {$xmin + $i * ($xmax-$xmin) / 100.0}]
    set y [expr {cos($x)}]
    lappend pts [px $x] [py $y]
}
set path "M [lindex $pts 0] [lindex $pts 1]"
for {set i 2} {$i < [llength $pts]} {incr i 2} {
    append path " L [lindex $pts $i] [lindex $pts [expr {$i+1}]]"
}
$ctx path $path -stroke {0.9 0.3 0.2} -width 2.5

# sin(x)*cos(x/2) — third curve
set pts {}
for {set i 0} {$i <= 100} {incr i} {
    set x [expr {$xmin + $i * ($xmax-$xmin) / 100.0}]
    set y [expr {sin($x) * cos($x/2.0)}]
    lappend pts [px $x] [py $y]
}
set path "M [lindex $pts 0] [lindex $pts 1]"
for {set i 2} {$i < [llength $pts]} {incr i 2} {
    append path " L [lindex $pts $i] [lindex $pts [expr {$i+1}]]"
}
$ctx path $path -stroke {0.2 0.7 0.3} -width 2 -dash {6 3}

$ctx pop   ;# clip released — axes drawn outside from here

# ---- Axes (outside clip, clean) ----
# X axis
$ctx line $lm [expr {$H-$bm}] [expr {$lm+$pw}] [expr {$H-$bm}] \
    -color {0.2 0.2 0.3} -width 1.5
# Y axis
$ctx line $lm $tm $lm [expr {$H-$bm}] \
    -color {0.2 0.2 0.3} -width 1.5

# Tick marks + labels X
foreach x {0 2 4 6 8 10} {
    set xpx [px $x]
    set ypx [expr {$H-$bm}]
    $ctx line $xpx $ypx $xpx [expr {$ypx+5}] -color {0.3 0.3 0.4} -width 1
    $ctx text $xpx [expr {$ypx+18}] $x \
        -font "Sans 11" -color {0.3 0.3 0.4} -anchor center
}

# Tick marks + labels Y
foreach y {-1.0 -0.5 0.0 0.5 1.0} {
    set ypx [py $y]
    $ctx line [expr {$lm-5}] $ypx $lm $ypx -color {0.3 0.3 0.4} -width 1
    $ctx text [expr {$lm-10}] $ypx \
        [format "%.1f" $y] \
        -font "Sans 11" -color {0.3 0.3 0.4} -anchor e
}

# Title + axis labels
$ctx text [expr {$lm + $pw/2}] 12 \
    "tclmcairo — Plotchart-style (clip_rect + push/pop)" \
    -font "Sans Bold 13" -color {0.2 0.2 0.4} -anchor center

$ctx text [expr {$lm + $pw/2}] [expr {$H-6}] \
    "x" -font "Sans Italic 12" -color {0.4 0.4 0.5} -anchor center

$ctx text 14 [expr {$tm + $ph/2}] \
    "y" -font "Sans Italic 12" -color {0.4 0.4 0.5} -anchor center

# Legend
set lx [expr {$lm + $pw - 160}]
set ly [expr {$tm + 12}]
$ctx rect $lx $ly 155 62 -fill {1 1 1 0.85} -stroke {0.7 0.7 0.8} -width 1 -radius 4
foreach {label col dash} {
    "sin(x)"          {0.2 0.4 0.9}  {}
    "cos(x)"          {0.9 0.3 0.2}  {}
    "sin(x)·cos(x/2)" {0.2 0.7 0.3}  {6 3}
} {
    incr ly 18
    set args [list -color $col -width 2]
    if {$dash ne {}} { lappend args -dash $dash }
    $ctx line [expr {$lx+8}] $ly [expr {$lx+35}] $ly {*}$args
    $ctx text [expr {$lx+42}] [expr {$ly+4}] $label \
        -font "Sans 10" -color {0.3 0.3 0.4}
}

$ctx save $f
$ctx destroy
puts "  -> $f"

# Demo 14: Transform -matrix / -get
# ================================================================
puts "Demo 14: Transform matrix..."

set f [file join $outdir demo-matrix.png]
set W 620; set H 440
set canvas [tclmcairo::new $W $H]
$canvas clear 0.1 0.1 0.18

$canvas text [expr {$W/2}] 24 "tclmcairo — transform -matrix / -get" \
    -font "Sans Bold 16" -color {1 1 1} -anchor center

# Helper: draw a small "stamp" shape (arrow + label)
proc stamp {ctx label col} {
    $ctx rect 0 -20 80 40 -fill $col -radius 6
    $ctx path "M 80 0 L 100 -15 L 100 15 Z" -fill $col
    $ctx text 40 4 $label -font "Sans Bold 11" \
        -color {1 1 1} -anchor center
}

# ---- Panel 1: pure -translate via -matrix ----
$canvas push
$canvas clip_rect 10 42 180 185
$canvas rect 10 42 180 185 -fill {0.14 0.14 0.22} -radius 4
$canvas text 100 60 "-translate" -font "Sans Bold 12" \
    -color {0.7 0.7 0.9} -anchor center
foreach {dx dy col lbl} {
    60 90  {0.9 0.3 0.2} "origin"
    100 120 {0.3 0.7 0.9} "+40+30"
    140 150 {0.2 0.8 0.4} "+80+60"
} {
    $canvas push
    $canvas transform -matrix 1 0 0 1 $dx $dy
    stamp $canvas $lbl $col
    $canvas pop
}
$canvas pop

# ---- Panel 2: -rotate via -matrix ----
$canvas push
$canvas clip_rect 200 42 180 185
$canvas rect 200 42 180 185 -fill {0.14 0.14 0.22} -radius 4
$canvas text 290 60 "-rotate (matrix)" -font "Sans Bold 12" \
    -color {0.7 0.7 0.9} -anchor center
set cx 290; set cy 145
$canvas circle $cx $cy 3 -fill {0.5 0.5 0.6}
foreach {deg col} {0 {0.9 0.3 0.2}  45 {0.3 0.7 0.9}  90 {0.2 0.8 0.4}  135 {1 0.7 0.2}} {
    set r [expr {$deg * 3.14159 / 180.0}]
    set c2 [expr {cos($r)}]; set s2 [expr {sin($r)}]
    $canvas push
    $canvas transform -matrix $c2 $s2 [expr {-$s2}] $c2 $cx $cy
    stamp $canvas "${deg}°" $col
    $canvas pop
}
$canvas pop

# ---- Panel 3: -scale via -matrix ----
$canvas push
$canvas clip_rect 390 42 220 185
$canvas rect 390 42 220 185 -fill {0.14 0.14 0.22} -radius 4
$canvas text 500 60 "-scale (matrix)" -font "Sans Bold 12" \
    -color {0.7 0.7 0.9} -anchor center
foreach {sx sy tx ty col lbl} {
    0.5 0.5 420 95  {0.9 0.3 0.2} "0.5×"
    0.8 0.8 420 135 {0.3 0.7 0.9} "0.8×"
    1.2 1.2 420 175 {0.2 0.8 0.4} "1.2×"
} {
    $canvas push
    $canvas transform -matrix $sx 0 0 $sy $tx $ty
    stamp $canvas $lbl $col
    $canvas pop
}
$canvas pop

# ---- Panel 4: combined matrix (shear + scale) ----
set py2 240
$canvas rect 10 $py2 180 185 -fill {0.14 0.14 0.22} -radius 4
$canvas text 100 [expr {$py2+18}] "shear + scale" -font "Sans Bold 12" \
    -color {0.7 0.7 0.9} -anchor center
set row14 0
foreach {xx yx xy yy tx ty col lbl} [list \
    1.0 0.3 0.0 1.0  30 [expr {$py2+60}]  {0.9 0.5 0.2} "shear-x" \
    1.0 0.0 0.3 1.0  30 [expr {$py2+110}] {0.3 0.7 0.9} "shear-y" \
    1.2 0.2 0.1 0.9  30 [expr {$py2+160}] {0.8 0.3 0.8} "combined" \
] {
    $canvas push
    $canvas transform -matrix $xx $yx $xy $yy $tx $ty
    stamp $canvas $lbl $col
    $canvas pop
    incr row14
}

# ---- Panel 5: -get demonstration ----
set px5 200; set py5 $py2
$canvas rect $px5 $py5 390 185 -fill {0.12 0.18 0.14} -radius 4
$canvas text [expr {$px5+195}] [expr {$py5+18}] \
    "transform -get — read current CTM" \
    -font "Sans Bold 12" -color {0.5 0.9 0.6} -anchor center

# Show CTM values for various transforms
set row 0
foreach {op label} {
    {-reset}            "identity"
    {-translate 30 20}  "translate 30 20"
    {-rotate 30}        "rotate 30°"
    {-scale 1.5 0.8}    "scale 1.5 0.8"
} {
    set tmp [tclmcairo::new 10 10]
    $tmp transform {*}$op
    set m [$tmp transform -get]
    $tmp destroy

    set y [expr {$py5 + 45 + $row*33}]
    $canvas rect [expr {$px5+8}] [expr {$y-12}] 374 28 \
        -fill {0.15 0.22 0.18} -radius 3
    $canvas text [expr {$px5+16}] $y $label \
        -font "Sans Bold 10" -color {0.6 0.9 0.7}
    # Format matrix values
    set vals {}
    foreach v $m { lappend vals [format "%.3f" $v] }
    $canvas text [expr {$px5+130}] $y \
        "{[join $vals {  }]}" \
        -font "Courier 9" -color {0.8 0.9 0.8}
    incr row
}

$canvas text [expr {$W/2}] [expr {$H-16}] \
    "-matrix xx yx xy yy x0 y0  ·  -get returns current CTM  ·  push/pop scopes transforms" \
    -font "Sans 10" -color {0.5 0.6 0.7} -anchor center

$canvas save $f
$canvas destroy
puts "  -> $f"


# ================================================================
# Demo 15: Compositing Operators
# ================================================================
puts "Demo 15: Compositing Operators..."

set f [file join $outdir demo-operators.png]
set W 620; set H 460
set canvas [tclmcairo::new $W $H]
$canvas clear 0.1 0.1 0.18

$canvas text [expr {$W/2}] 22 "tclmcairo — Compositing Operators" \
    -font "Sans Bold 16" -color {1 1 1} -anchor center

# Each cell: two overlapping circles with different operators
set operators {
    OVER      MULTIPLY  SCREEN    OVERLAY
    DARKEN    LIGHTEN   DIFFERENCE XOR
    COLOR_DODGE COLOR_BURN HARD_LIGHT SOFT_LIGHT
    ADD       SATURATE  EXCLUSION  SOURCE
}
set cols 4; set rows 4
set cw [expr {$W / $cols}]
set ch [expr {($H - 40) / $rows}]

set idx 0
foreach op $operators {
    set col [expr {$idx % $cols}]
    set row [expr {$idx / $cols}]
    set cx [expr {$col * $cw + $cw/2}]
    set cy [expr {40 + $row * $ch + $ch/2 - 10}]
    set r  [expr {min($cw,$ch)/3}]

    # Cell background
    $canvas rect [expr {$col*$cw+2}] [expr {40+$row*$ch+2}] \
        [expr {$cw-4}] [expr {$ch-4}] \
        -fill {0.15 0.15 0.22} -radius 4

    # Draw: orange circle, then blue circle with operator
    $canvas push
    $canvas clip_rect [expr {$col*$cw+4}] [expr {40+$row*$ch+4}] \
        [expr {$cw-8}] [expr {$ch-26}]

    # Background gradient
    $canvas gradient_linear "opbg$idx" \
        [expr {$col*$cw}] 0 [expr {($col+1)*$cw}] 0 \
        {{0 0.2 0.2 0.3 1} {1 0.25 0.25 0.35 1}}
    $canvas rect [expr {$col*$cw+4}] [expr {40+$row*$ch+4}] \
        [expr {$cw-8}] [expr {$ch-26}] -fillname "opbg$idx"

    # Circle A (orange)
    $canvas operator OVER
    $canvas circle [expr {$cx - $r/3}] $cy $r -fill {1 0.55 0.1 0.85}

    # Circle B with the operator
    $canvas operator $op
    $canvas circle [expr {$cx + $r/3}] $cy $r -fill {0.2 0.5 0.9 0.85}

    $canvas operator OVER
    $canvas pop

    # Label
    $canvas text $cx [expr {40 + ($row+1)*$ch - 12}] $op \
        -font "Sans Bold 9" -color {0.8 0.8 0.9} -anchor center

    incr idx
}

$canvas save $f
$canvas destroy
puts "  -> $f"

# ================================================================
# Demo 16: user_to_device / device_to_user + arc_negative + dash_offset
# ================================================================
puts "Demo 16: Coordinates, arc_negative, dash_offset..."

set f [file join $outdir demo-coords.png]
set W 620; set H 320
set canvas [tclmcairo::new $W $H]
$canvas clear 0.1 0.1 0.18

$canvas text [expr {$W/2}] 22 \
    "user_to_device · arc_negative · -dash_offset" \
    -font "Sans Bold 15" -color {1 1 1} -anchor center

# Panel 1: user_to_device — show coordinate mapping under transforms
set px1 10; set py1 40; set pw1 190; set ph1 260
$canvas rect $px1 $py1 $pw1 $ph1 -fill {0.14 0.14 0.22} -radius 6
$canvas text [expr {$px1+$pw1/2}] [expr {$py1+16}] "user_to_device" \
    -font "Sans Bold 11" -color {0.7 0.7 0.9} -anchor center

# Draw a rotated grid and show mapped coordinates
set orig_x [expr {$px1 + $pw1/2}]
set orig_y [expr {$py1 + $ph1/2 + 10}]

foreach {ux uy col} {
    0   0  {1 1 1}
    40  0  {1 0.5 0.2}
    0  40  {0.3 0.8 0.4}
    40 40  {0.2 0.6 1}
} {
    # Show user point
    $canvas push
    $canvas transform -translate $orig_x $orig_y
    $canvas transform -rotate 30
    $canvas circle $ux $uy 5 -fill $col
    set mapped [$canvas user_to_device $ux $uy]
    $canvas pop

    # Show device point (where it actually lands on screen)
    set dx [lindex $mapped 0]
    set dy [lindex $mapped 1]
    $canvas circle $dx $dy 3 -fill $col -stroke {1 1 1} -width 0.5
    $canvas line [expr {$dx+4}] $dy [expr {$dx+20}] $dy \
        -color $col -width 0.5 -dash {2 2}
    $canvas text [expr {$dx+22}] [expr {$dy+4}] \
        "($ux,$uy)" -font "Courier 8" -color $col
}
# Rotated grid lines
$canvas push
$canvas transform -translate $orig_x $orig_y
$canvas transform -rotate 30
foreach v {-40 0 40} {
    $canvas line $v -50 $v 50 -color {0.4 0.4 0.5} -width 0.5 -dash {3 3}
    $canvas line -50 $v 50 $v -color {0.4 0.4 0.5} -width 0.5 -dash {3 3}
}
$canvas pop
$canvas text [expr {$px1+$pw1/2}] [expr {$py1+$ph1-8}] \
    "30° rotate" -font "Sans 9" -color {0.5 0.6 0.7} -anchor center

# Panel 2: arc_negative — comparison
set px2 [expr {$px1+$pw1+10}]; set pw2 190
$canvas rect $px2 $py1 $pw2 $ph1 -fill {0.14 0.14 0.22} -radius 6
$canvas text [expr {$px2+$pw2/2}] [expr {$py1+16}] "arc vs arc_negative" \
    -font "Sans Bold 11" -color {0.7 0.7 0.9} -anchor center

set acx [expr {$px2+$pw2/2}]
# arc (clockwise): blue
$canvas arc $acx [expr {$py1+90}] 50 -30 210 \
    -stroke {0.2 0.5 1} -width 3
$canvas text $acx [expr {$py1+148}] "arc (clockwise)" \
    -font "Sans 9" -color {0.2 0.5 1} -anchor center
# arc_negative (counter-clockwise): orange
$canvas arc_negative $acx [expr {$py1+230}] 50 -30 210 \
    -stroke {1 0.55 0.2} -width 3
$canvas text $acx [expr {$py1+288}] "arc_negative" \
    -font "Sans 9" -color {1 0.55 0.2} -anchor center

# Direction arrows
$canvas path "M [expr {$acx+50}] [expr {$py1+90}] \
    L [expr {$acx+58}] [expr {$py1+83}] \
    L [expr {$acx+58}] [expr {$py1+97}] Z" -fill {0.2 0.5 1}
$canvas path "M [expr {$acx+50}] [expr {$py1+230}] \
    L [expr {$acx+58}] [expr {$py1+237}] \
    L [expr {$acx+58}] [expr {$py1+223}] Z" -fill {1 0.55 0.2}

# Panel 3: dash_offset — animation effect
set px3 [expr {$px2+$pw2+10}]; set pw3 200
$canvas rect $px3 $py1 $pw3 $ph1 -fill {0.14 0.14 0.22} -radius 6
$canvas text [expr {$px3+$pw3/2}] [expr {$py1+16}] "-dash_offset" \
    -font "Sans Bold 11" -color {0.7 0.7 0.9} -anchor center

# Same dash pattern with different offsets → "animation frames"
set y0 [expr {$py1+45}]
foreach {offset col lbl} {
    0   {0.9 0.3 0.2} "offset=0"
    4   {1.0 0.6 0.2} "offset=4"
    8   {0.8 0.9 0.2} "offset=8"
    12  {0.2 0.8 0.4} "offset=12"
    16  {0.2 0.6 1.0} "offset=16"
    20  {0.6 0.2 0.9} "offset=20"
} {
    $canvas line [expr {$px3+15}] $y0 [expr {$px3+$pw3-15}] $y0 \
        -color $col -width 3 -dash {12 6} -dash_offset $offset
    $canvas text [expr {$px3+$pw3-12}] [expr {$y0+4}] $lbl \
        -font "Courier 9" -color $col -anchor e
    incr y0 35
}
$canvas text [expr {$px3+$pw3/2}] [expr {$py1+$ph1-8}] \
    "same -dash, varying offset" \
    -font "Sans 9" -color {0.5 0.6 0.7} -anchor center

$canvas save $f
$canvas destroy
puts "  -> $f"

# ================================================================
# Demo 17: gradient_extend + gradient_filter + paint + set_source
# ================================================================
puts "Demo 17: Gradient extend, filter, paint, set_source..."

set f [file join $outdir demo-gradient-ops.png]
set W 620; set H 400
set canvas [tclmcairo::new $W $H]
$canvas clear 0.1 0.1 0.18

$canvas text [expr {$W/2}] 22 \
    "gradient_extend · gradient_filter · paint · set_source" \
    -font "Sans Bold 15" -color {1 1 1} -anchor center

# Panel 1: gradient_extend modes
set px 10; set py 40; set pw 140; set ph 170
$canvas text [expr {$px+$pw*2}] [expr {$py-8}] "gradient_extend" \
    -font "Sans Bold 12" -color {0.7 0.7 0.9} -anchor center

foreach {ext col_top lbl} {
    none    {0.2 0.3 0.6} "none"
    pad     {0.2 0.5 0.3} "pad"
    repeat  {0.6 0.3 0.2} "repeat"
    reflect {0.5 0.2 0.6} "reflect"
} {
    set bx $px; set by $py
    $canvas rect $bx $by $pw $ph -fill {0.15 0.15 0.22} -radius 4

    # Small gradient in center — extend mode fills the rest
    $canvas gradient_linear "ext_$ext" \
        [expr {$bx+40}] 0 [expr {$bx+100}] 0 \
        {{0 1 0.8 0 1} {1 0.1 0.3 0.9 1}}
    $canvas gradient_extend "ext_$ext" $ext
    $canvas push
    $canvas clip_rect [expr {$bx+4}] [expr {$by+20}] [expr {$pw-8}] [expr {$ph-30}]
    $canvas rect [expr {$bx+4}] [expr {$by+20}] [expr {$pw-8}] [expr {$ph-30}] \
        -fillname "ext_$ext"
    # Show the "defined" region
    $canvas line [expr {$bx+40}] [expr {$by+20}] \
                 [expr {$bx+40}] [expr {$by+$ph-10}] \
        -color {1 1 1 0.4} -width 1 -dash {3 3}
    $canvas line [expr {$bx+100}] [expr {$by+20}] \
                 [expr {$bx+100}] [expr {$by+$ph-10}] \
        -color {1 1 1 0.4} -width 1 -dash {3 3}
    $canvas pop

    $canvas text [expr {$bx+$pw/2}] [expr {$by+$ph-8}] $lbl \
        -font "Sans Bold 10" -color {0.9 0.9 1} -anchor center
    incr px [expr {$pw+5}]
}

# Panel 2: paint + set_source
set px2 10; set py2 [expr {$py+$ph+20}]; set ph2 140
$canvas text [expr {$px2 + 290}] [expr {$py2-8}] "paint + set_source" \
    -font "Sans Bold 12" -color {0.7 0.7 0.9} -anchor center

# paint with solid color + alpha
foreach {alpha col lbl bx} {
    1.0   {0.9 0.3 0.2}  "paint 1.0"    10
    0.7   {0.2 0.6 0.9}  "paint 0.7"   155
    0.4   {0.3 0.8 0.3}  "paint 0.4"   300
} {
    $canvas rect $bx $py2 135 $ph2 -fill {0.15 0.15 0.22} -radius 4
    # Checkerboard to show alpha
    foreach {rx ry} {0 0 20 20 40 0 60 20 80 0 100 20 120 0
                     0 20 20 0 40 20 60 0 80 20 100 0 120 20
                     0 40 20 60 40 40 60 60 80 40 100 60 120 40
                     0 60 20 40 40 60 60 40 80 60 100 40 120 60
                     0 80 20 100 40 80 60 100 80 80 100 100 120 80
                     0 100 20 80 40 100 60 80 80 100 100 80 120 100} {
        $canvas rect [expr {$bx+4+$rx}] [expr {$py2+20+$ry}] 20 20 \
            -fill {0.25 0.25 0.3}
    }
    $canvas push
    $canvas clip_rect [expr {$bx+4}] [expr {$py2+20}] 127 [expr {$ph2-30}]
    $canvas set_source -color $col
    $canvas paint $alpha
    $canvas pop
    $canvas text [expr {$bx+68}] [expr {$py2+$ph2-8}] $lbl \
        -font "Sans Bold 10" -color {0.9 0.9 1} -anchor center
}

# paint with gradient source
set gx 445
$canvas rect $gx $py2 165 $ph2 -fill {0.15 0.15 0.22} -radius 4
$canvas gradient_radial "pg" \
    [expr {$gx+82}] [expr {$py2+65}] 60 \
    {{0 1 0.9 0.2 1} {0.5 0.5 0.3 0.8 0.9} {1 0 0 0.5 0}}
$canvas push
$canvas clip_rect [expr {$gx+4}] [expr {$py2+20}] 157 [expr {$ph2-30}]
$canvas set_source -gradient pg
$canvas paint
$canvas pop
$canvas text [expr {$gx+82}] [expr {$py2+$ph2-8}] "set_source -gradient" \
    -font "Sans Bold 10" -color {0.9 0.9 1} -anchor center

$canvas save $f
$canvas destroy
puts "  -> $f"


# ================================================================
# Demo 18: font_options + path_get + surface_copy
# ================================================================
puts "Demo 18: font_options, path_get, surface_copy..."

set f [file join $outdir demo-prio3.png]
set W 620; set H 440
set canvas [tclmcairo::new $W $H]
$canvas clear 0.1 0.1 0.18

$canvas text [expr {$W/2}] 22 \
    "tclmcairo 0.3 — font_options · path_get · surface_copy" \
    -font "Sans Bold 15" -color {1 1 1} -anchor center

# ---- Panel 1: font_options antialias comparison ----
set px 10; set py 40; set pw 185; set ph 185
$canvas rect $px $py $pw $ph -fill {0.14 0.14 0.22} -radius 6
$canvas text [expr {$px+$pw/2}] [expr {$py+16}] "font_options" \
    -font "Sans Bold 11" -color {0.7 0.7 0.9} -anchor center

set ty [expr {$py+38}]
foreach {aa lbl col} {
    default "default"   {0.9 0.9 1.0}
    none    "none"      {1.0 0.6 0.4}
    gray    "gray"      {0.4 0.9 0.5}
    best    "best"      {0.4 0.7 1.0}
} {
    set tmp [tclmcairo::new 165 30]
    $tmp clear 0.14 0.14 0.22
    $tmp font_options -antialias $aa
    $tmp text 4 22 "Gg Aa Xyz 1234  ($lbl)" \
        -font "Sans 13" -color $col
    set bytes [$tmp topng]
    $tmp destroy
    $canvas image_data $bytes [expr {$px+10}] $ty
    incr ty 34
}

# hint_style comparison
set ty [expr {$py+172}]
$canvas text [expr {$px+$pw/2}] $ty "-hint_style" \
    -font "Sans 9" -color {0.5 0.6 0.7} -anchor center

# ---- Panel 2: path_get — show what paths look like ----
set px2 [expr {$px+$pw+10}]; set pw2 185
$canvas rect $px2 $py $pw2 $ph -fill {0.14 0.14 0.22} -radius 6
$canvas text [expr {$px2+$pw2/2}] [expr {$py+16}] "path_get" \
    -font "Sans Bold 11" -color {0.7 0.7 0.9} -anchor center

# Draw shapes and show their SVG path representation
set shapes {
    {circle  "circle" {100 75 40}}
    {rect    "rect"   {20 10 120 50}}
}

# Build paths manually and read them back via path_get
# We need to draw without consuming — use a temporary surface trick
# Build path, clip_path reads it, path_get reads current path

# Demonstrate path_get with clip_path:
# clip_path uses the path but doesn't consume current path context
# Actually: show the path string for known shapes

set demo_paths {
    "M 10 10 L 100 10 L 100 60 L 10 60 Z"   "rect"
    "M 100 10 C 130 10 150 30 150 60 C 150 90 130 110 100 110 C 70 110 50 90 50 60 C 50 30 70 10 100 10 Z"  "bezier"
    "M 10 60 L 55 10 L 100 60 Z"             "triangle"
}

set ty2 [expr {$py+35}]
foreach {svgpath label} $demo_paths {
    # Draw the path shape
    set tmp [tclmcairo::new 165 55]
    $tmp clear 0.14 0.14 0.22
    # Draw shape
    $tmp push
    $tmp transform -translate 10 5
    $tmp transform -scale 0.55 0.4
    $tmp path $svgpath -fill {0.3 0.6 0.9 0.7} -stroke {0.6 0.8 1} -width 1.5
    $tmp pop
    # Show truncated path string
    set short [string range $svgpath 0 28]
    if {[string length $svgpath] > 28} { append short "..." }
    $tmp text 83 44 $short -font "Courier 8" -color {0.6 0.7 0.8} -anchor center
    set bytes [$tmp topng]
    $tmp destroy
    $canvas image_data $bytes $px2 $ty2
    incr ty2 58
}

$canvas text [expr {$px2+$pw2/2}] [expr {$py+$ph-8}] \
    "path_get → SVG string" \
    -font "Sans 9" -color {0.5 0.6 0.7} -anchor center

# ---- Panel 3: surface_copy — layer operations ----
set px3 [expr {$px2+$pw2+10}]; set pw3 200
$canvas rect $px3 $py $pw3 $ph -fill {0.14 0.14 0.22} -radius 6
$canvas text [expr {$px3+$pw3/2}] [expr {$py+16}] "surface_copy" \
    -font "Sans Bold 11" -color {0.7 0.7 0.9} -anchor center

# Original
set orig [tclmcairo::new 180 60]
$orig clear 0.2 0.3 0.5
$orig gradient_linear bg 0 0 180 0 {{0 0.2 0.5 0.9 1} {1 0.8 0.2 0.1 1}}
$orig rect 0 0 180 60 -fillname bg
$orig circle 90 30 25 -fill {1 1 1 0.8}
$orig text 90 34 "original" -font "Sans Bold 11" -color {0.1 0.1 0.2} -anchor center
set orig_bytes [$orig topng]

# Copy 1: same content, draw on top
set copy1_id [$orig surface_copy]
tclmcairo circle $copy1_id 30 30 20 -fill {1 0.5 0 0.9}
tclmcairo circle $copy1_id 150 30 20 -fill {0.5 0 1 0.9}
set copy1_bytes [tclmcairo topng $copy1_id]
tclmcairo destroy $copy1_id

# Copy 2: different size (thumbnail)
set copy2_id [$orig surface_copy 90 30]
set copy2_bytes [tclmcairo topng $copy2_id]
tclmcairo destroy $copy2_id

$orig destroy

# Display
set ty3 [expr {$py+35}]
$canvas image_data $orig_bytes $px3 $ty3
$canvas text [expr {$px3+$pw3/2}] [expr {$ty3+65}] \
    "original (180×60)" -font "Sans 9" -color {0.6 0.7 0.8} -anchor center

incr ty3 78
$canvas image_data $copy1_bytes $px3 $ty3
$canvas text [expr {$px3+$pw3/2}] [expr {$ty3+65}] \
    "surface_copy + draw on top" -font "Sans 9" -color {0.4 0.8 0.5} -anchor center

incr ty3 78
$canvas image_data $copy2_bytes $px3 [expr {$ty3+8}] -width 90 -height 30
$canvas text [expr {$px3+$pw3/2}] [expr {$ty3+45}] \
    "surface_copy 90×30 (resize)" -font "Sans 9" -color {0.4 0.6 0.9} -anchor center

# ---- Bottom row: font_options hint_style comparison ----
set py4 [expr {$py+$ph+15}]; set ph4 110
$canvas rect 10 $py4 600 $ph4 -fill {0.14 0.14 0.22} -radius 6
$canvas text 310 [expr {$py4+14}] \
    "font_options -hint_style: none  slight  medium  full" \
    -font "Sans Bold 11" -color {0.7 0.7 0.9} -anchor center

set tx 15
foreach {hs col} {none {0.9 0.5 0.4}  slight {0.9 0.8 0.3}  medium {0.4 0.9 0.5}  full {0.4 0.7 1.0}} {
    set tmp [tclmcairo::new 148 78]
    $tmp clear 0.14 0.14 0.22
    $tmp font_options -hint_style $hs -antialias gray
    $tmp text 74 22 $hs -font "Sans Bold 12" -color $col -anchor center
    $tmp text 74 44 "Handgloves" -font "Serif 14" -color {0.9 0.9 1} -anchor center
    $tmp text 74 62 "1234567890" -font "Monospace 12" -color {0.7 0.7 0.8} -anchor center
    set bytes [$tmp topng]
    $tmp destroy
    $canvas image_data $bytes $tx [expr {$py4+24}]
    incr tx 152
}

$canvas save $f
$canvas destroy
puts "  -> $f"

# ============================================================
puts "Demo 19: save -chan (channel output)..."

# Draw a simple badge
set d19 [tclmcairo::new 300 200]
$d19 clear 0.08 0.08 0.15

$d19 gradient_linear bg 0 0 300 0 \
    {{0 0.2 0.5 0.9 1} {0.5 0.1 0.3 0.7 1} {1 0.05 0.15 0.4 1}}
$d19 rect 0 0 300 200 -fillname bg

$d19 gradient_radial glow 150 100 90 \
    {{0 1.0 0.9 0.3 0.6} {1 0 0 0 0}}
$d19 circle 150 100 80 -fillname glow

$d19 text 150 90 "save" -font "Sans Bold 28" \
    -color {1 1 1} -anchor center
$d19 text 150 118 "-chan" -font "Monospace Bold 20" \
    -color {0.8 0.9 1} -anchor center

# PNG via channel
set f19png [file join $outdir demo-chan.png]
set ch [open $f19png wb]
$d19 save -chan $ch -format png
close $ch
puts "  -> $f19png (PNG via channel)"

# PDF via channel
set f19pdf [file join $outdir demo-chan.pdf]
set ch [open $f19pdf wb]
$d19 save -chan $ch -format pdf
close $ch
puts "  -> $f19pdf (PDF via channel, [file size $f19pdf] bytes)"

# SVG via channel
set f19svg [file join $outdir demo-chan.svg]
set ch [open $f19svg wb]
$d19 save -chan $ch -format svg
close $ch
puts "  -> $f19svg (SVG via channel)"

$d19 destroy

puts "\nAll demos complete."
puts "Output files in directory: $outdir"
