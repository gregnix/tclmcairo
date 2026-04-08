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

puts "\nAll demos complete."
puts "Output files in directory: $outdir"
