#!/usr/bin/env tclsh8.6
# demos/demo-tkmcairo.tcl -- tkmcairo Demonstration
#
# Run: make demo
# or:  TKMCAIRO_LIBDIR=. tclsh demos/demo-tkmcairo.tcl

set _tmdir [file normalize [file join [file dirname [info script]] ../tcl]]
if {$_tmdir ni [tcl::tm::path list]} { tcl::tm::path add $_tmdir }
unset _tmdir
package require tkmcairo

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
set ctx [tkmcairo::new 600 400 -mode vector]
$ctx clear 0.08 0.10 0.20

$ctx gradient_linear bg 0 0 600 0 \
    {{0 0.08 0.10 0.25 1} {1 0.15 0.08 0.30 1}}
$ctx rect 0 0 600 400 -fillname bg

$ctx text 300 45 "tkmcairo v0.1 - Shapes" \
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
set ctx [tkmcairo::new 600 400 -mode vector]
$ctx clear 0.05 0.07 0.15

$ctx text 300 35 "tkmcairo v0.1 - SVG Paths" \
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

foreach {x y label} {
    100 180 "Star"
    200 185 "Heart"
    415 195 "Spiral"
    520 180 "Arrow"
    200 340 "Wave line"
    465 345 "Polygon"
} {
    $ctx text $x $y $label -font "Sans 11" -color {0.6 0.7 0.9} -anchor center
}

save_all $ctx $outdir demo-paths
$ctx destroy

# ================================================================
# Demo 3: Gradients + transparency
# ================================================================
puts "Demo 3: Gradients..."
set ctx [tkmcairo::new 600 400 -mode vector]
$ctx clear 0.05 0.05 0.10

$ctx text 300 35 "tkmcairo v0.1 - Gradients" \
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
set ctx [tkmcairo::new 600 450 -mode vector]
$ctx clear 0.06 0.08 0.16

$ctx text 300 40 "tkmcairo v0.1 - Text" \
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
set ctx [tkmcairo::new 595 842 -mode vector]
$ctx clear 1 1 1

$ctx gradient_linear hdr 0 0 595 0 \
    {{0 0.1 0.3 0.7 1} {1 0.2 0.5 0.9 1}}
$ctx rect 0 0 595 80 -fillname hdr

$ctx text 297 50 "tkmcairo v0.1 - PDF Export" \
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
$ctx text 297 826 "tkmcairo 0.1 - BSD License - https://github.com/gregnix/tkmcairo" \
    -font "Sans 11" -color {0.7 0.7 0.7} -anchor center

save_all $ctx $outdir demo-output
$ctx destroy

puts "\nAll demos complete."
puts "Output files in directory: $outdir"
