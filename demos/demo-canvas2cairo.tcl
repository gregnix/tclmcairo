#!/usr/bin/env wish
# demo-canvas2cairo.tcl
# Demonstrates canvas2cairo: Tk Canvas → SVG / PDF via tclmcairo
#
# Usage:
#   wish demo-canvas2cairo.tcl
#   TCLMCAIRO_LIBDIR=/path/to/tclmcairo wish demo-canvas2cairo.tcl

set dir [file dirname [file normalize [info script]]]
tcl::tm::path add [file join $dir ..]
set env(TCLMCAIRO_LIBDIR) [file join $dir .. tclmcairo03]
if {[info exists env(TCLMCAIRO_LIBDIR_OVERRIDE)]} {
    set env(TCLMCAIRO_LIBDIR) $env(TCLMCAIRO_LIBDIR_OVERRIDE)
}

package require Tk
package require canvas2cairo

set outdir [file join $dir out]
file mkdir $outdir

proc save_demo {canvas name} {
    global outdir
    canvas2cairo::export $canvas [file join $outdir ${name}.svg]
    canvas2cairo::export $canvas [file join $outdir ${name}.pdf]
    puts "  -> $outdir/${name}.svg"
    puts "  -> $outdir/${name}.pdf"
}

wm withdraw .
update

# ================================================================
# Demo 1: Shapes — rect, oval, arc, polygon, line
# ================================================================
puts "Demo 1: Shapes..."

canvas .d1 -width 620 -height 360 -background "#0d1117"
.d1 create rectangle 30  30 190 130 \
    -fill "#e94560" -outline "#ff6b6b" -width 2
.d1 create rectangle 210 30 370 130 \
    -fill "" -outline "#58a6ff" -width 3
.d1 create rectangle 390 30 580 130 \
    -fill "#21262d" -outline "#30363d" -width 1

# Ovals
.d1 create oval  30 155 190 255 -fill "#238636" -outline "#2ea043" -width 2
.d1 create oval 210 155 370 255 -fill "" -outline "#f78166" -width 3
.d1 create oval 390 155 580 255 -fill "#533483" -outline "#a371f7" -width 2

# Arc styles
.d1 create arc  30 275 140 355 -start 0 -extent 270 \
    -style pieslice -fill "#e9c46a" -outline "#f4a261" -width 2
.d1 create arc 160 275 280 355 -start 30 -extent 200 \
    -style chord   -fill "#264653" -outline "#2a9d8f" -width 2
.d1 create arc 300 275 420 355 -start 45 -extent 280 \
    -style arc     -outline "#e76f51" -width 3
.d1 create arc 440 275 580 355 -start 0 -extent 360 \
    -style pieslice -fill "#533483" -outline "#a371f7" -width 2

# Labels
foreach {x y txt} {
    110 143 "filled"  290 143 "outline"  485 143 "filled+outline"
    110 260 "oval"    290 260 "oval"     485 260 "oval"
    80  358 "pieslice"  220 358 "chord"  360 358 "arc"  510 358 "full"
} {
    .d1 create text $x $y -text $txt -font "Sans 9" -fill "#8b949e" -anchor center
}

update idletasks
save_demo .d1 demo1-shapes
destroy .d1

# ================================================================
# Demo 2: Lines — dash, capstyle, joinstyle, smooth, arrows
# ================================================================
puts "Demo 2: Lines..."

canvas .d2 -width 620 -height 380 -background "#0d1117"

# Solid lines with different widths
foreach {y w col lbl} {
    40 1 "#58a6ff" "width 1"
    70 2 "#58a6ff" "width 2"
    100 4 "#58a6ff" "width 4"
    130 8 "#58a6ff" "width 8"
} {
    .d2 create line 30 $y 280 $y -fill $col -width $w
    .d2 create text 300 $y -text $lbl -font "Sans 10" -fill "#8b949e" -anchor w
}

# Dash patterns
foreach {y dash lbl} {
    170 {8 4}     "{8 4}"
    200 {4 4}     "{4 4}"
    230 {12 4 2 4} "{12 4 2 4}"
    260 {2 2}     "{2 2}"
} {
    .d2 create line 30 $y 280 $y -fill "#e9c46a" -width 2 -dash $dash
    .d2 create text 300 $y -text "dash $lbl" -font "Sans 10" -fill "#8b949e" -anchor w
}

# Cap styles
foreach {x cap col} {
    390 butt      "#e94560"
    460 projecting "#f4a261"
    530 round     "#2ea043"
} {
    .d2 create line $x 40 $x 130 -fill $col -width 20 -capstyle $cap
    .d2 create line $x 40 $x 130 -fill "#ffffff" -width 1  ;# guide
    .d2 create text $x 148 -text $cap -font "Sans 9" -fill "#8b949e" -anchor center
}

# Join styles
foreach {ox join col} {
    0 miter "#e94560"
    70 round "#f4a261"
    140 bevel "#2ea043"
} {
    set bx [expr {390+$ox}]
    .d2 create line [expr {$bx}] 210 [expr {$bx+30}] 170 [expr {$bx+60}] 210 \
        -fill $col -width 12 -joinstyle $join
    .d2 create text [expr {$bx+30}] 228 -text $join \
        -font "Sans 9" -fill "#8b949e" -anchor center
}

# Arrows
.d2 create line 30 290 280 290 -fill "#a371f7" -width 2 -arrow last
.d2 create line 30 320 280 320 -fill "#a371f7" -width 2 -arrow first
.d2 create line 30 350 280 350 -fill "#a371f7" -width 2 -arrow both
.d2 create text 300 290 -text "arrow last"  -font "Sans 10" -fill "#8b949e" -anchor w
.d2 create text 300 320 -text "arrow first" -font "Sans 10" -fill "#8b949e" -anchor w
.d2 create text 300 350 -text "arrow both"  -font "Sans 10" -fill "#8b949e" -anchor w

# Smooth polyline
.d2 create line 390 270 430 310 470 270 510 330 560 280 \
    -fill "#58a6ff" -width 2 -smooth true
.d2 create text 475 350 -text "smooth" -font "Sans 10" -fill "#8b949e" -anchor center

update idletasks
save_demo .d2 demo2-lines
destroy .d2

# ================================================================
# Demo 3: Text — fonts, anchors, rotation
# ================================================================
puts "Demo 3: Text..."

canvas .d3 -width 620 -height 400 -background "#0d1117"

# Font variations
set y 35
foreach {font lbl} {
    "Sans 10"          "Sans 10"
    "Sans 14"          "Sans 14"
    {Sans 18 bold}     "Sans 18 bold"
    {Sans 14 italic}   "Sans 14 italic"
    "Serif 16"         "Serif 16"
    "Monospace 12"     "Monospace 12"
} {
    .d3 create text 200 $y -text "The quick brown fox" \
        -font $font -fill "#c9d1d9" -anchor w
    .d3 create text 195 $y -text $lbl \
        -font "Sans 9" -fill "#8b949e" -anchor e
    incr y 38
}

# Anchor positions
set cx 500; set cy 190
.d3 create oval [expr {$cx-3}] [expr {$cy-3}] [expr {$cx+3}] [expr {$cy+3}] \
    -fill "#e94560"
foreach {anchor dx dy} {
    nw  -70 -50    n   0 -50    ne  70 -50
    w   -70   0   center 0  0   e  70   0
    sw  -70  50    s   0  50   se  70  50
} {
    .d3 create text [expr {$cx+$dx}] [expr {$cy+$dy}] \
        -text $anchor -font "Sans 10" \
        -fill "#58a6ff" -anchor $anchor
}
.d3 create text $cx 280 -text "anchor positions" \
    -font "Sans 9" -fill "#8b949e" -anchor center

# Rotation
set rx 130; set ry 320
foreach {angle col} {0 "#e94560"  30 "#f4a261"  60 "#e9c46a"
                     90 "#2ea043" 120 "#58a6ff" 150 "#a371f7"} {
    .d3 create text $rx $ry -text "Rotation" \
        -font {Sans 12 bold} -fill $col -anchor center -angle $angle
}
.d3 create text $rx 390 -text "-angle" \
    -font "Sans 9" -fill "#8b949e" -anchor center

update idletasks
save_demo .d3 demo3-text
destroy .d3

# ================================================================
# Demo 4: Mixed — realistic chart-like canvas
# ================================================================
puts "Demo 4: Chart..."

canvas .d4 -width 620 -height 420 -background "#161b22"

# Frame
.d4 create rectangle 0 0 620 420 -fill "#161b22" -outline "#30363d" -width 1

# Title
.d4 create text 310 28 -text "tclmcairo canvas2cairo — Demo Chart" \
    -font {Sans 16 bold} -fill "#c9d1d9" -anchor center

# Plot area background
.d4 create rectangle 60 55 580 350 -fill "#0d1117" -outline "#30363d" -width 1

# Grid lines
foreach y {350 305 260 215 170 125} {
    .d4 create line 60 $y 580 $y -fill "#21262d" -width 1 -dash {4 4}
}
foreach x {60 164 268 372 476 580} {
    .d4 create line $x 55 $x 350 -fill "#21262d" -width 1 -dash {4 4}
}

# Data: sin + cos curves (50 points each)
set PI 3.14159265358979
set lm 60; set pw [expr {580-60}]; set ph [expr {350-55}]
set xmin 0; set xmax 6.28; set ymin -1.2; set ymax 1.2

proc px x { global lm pw xmin xmax
    expr {$lm + ($x-$xmin)/($xmax-$xmin)*$pw} }
proc py y { global ph ymin ymax
    expr {350 - ($y-$ymin)/($ymax-$ymin)*$ph} }

# sin curve
set sin_coords {}
for {set i 0} {$i <= 60} {incr i} {
    set x [expr {$xmin + $i*($xmax-$xmin)/60.0}]
    lappend sin_coords [px $x] [py [expr {sin($x)}]]
}
.d4 create line {*}$sin_coords -fill "#58a6ff" -width 2.5 -smooth false

# cos curve
set cos_coords {}
for {set i 0} {$i <= 60} {incr i} {
    set x [expr {$xmin + $i*($xmax-$xmin)/60.0}]
    lappend cos_coords [px $x] [py [expr {cos($x)}]]
}
.d4 create line {*}$cos_coords -fill "#e94560" -width 2.5

# product curve
set prod_coords {}
for {set i 0} {$i <= 60} {incr i} {
    set x [expr {$xmin + $i*($xmax-$xmin)/60.0}]
    lappend prod_coords [px $x] [py [expr {sin($x)*cos($x/2)}]]
}
.d4 create line {*}$prod_coords -fill "#2ea043" -width 2 -dash {8 3}

# Axes
.d4 create line 60 350 580 350 -fill "#8b949e" -width 1.5
.d4 create line 60  55  60 350 -fill "#8b949e" -width 1.5

# Y-axis labels
foreach {y val} {350 -1.2  305 -0.6  260 0  215 0.6  170 1.2} {
    .d4 create text 52 $y -text $val -font "Monospace 9" \
        -fill "#8b949e" -anchor e
}
# X-axis labels
foreach {x val} {60 0  164 π/2  268 π  372 3π/2  476 2π  580 5π/2} {
    .d4 create text $x 362 -text $val -font "Sans 9" \
        -fill "#8b949e" -anchor center
}

# Legend
foreach {lx col lbl} {100 "#58a6ff" "sin(x)"  230 "#e94560" "cos(x)"
                      360 "#2ea043" "sin·cos"} {
    .d4 create line [expr {$lx-25}] 392 [expr {$lx+5}] 392 \
        -fill $col -width 2.5
    .d4 create text [expr {$lx+10}] 392 -text $lbl \
        -font "Sans 11" -fill $col -anchor w
}

update idletasks
save_demo .d4 demo4-chart
destroy .d4

# ================================================================
# Demo 5: All item types on one canvas
# ================================================================
puts "Demo 5: Full showcase..."

canvas .d5 -width 620 -height 460 -background "#0d1117"

# Title bar
.d5 create rectangle 0 0 620 45 -fill "#161b22" -outline "#30363d" -width 1
.d5 create text 310 23 -text "canvas2cairo 0.1 — All Item Types" \
    -font {Sans 14 bold} -fill "#c9d1d9" -anchor center

# Section: Shapes
.d5 create text 20 60 -text "Shapes" -font {Sans 11 bold} \
    -fill "#8b949e" -anchor w
.d5 create rectangle  20  75 140 155 -fill "#e94560" -outline "" -width 0
.d5 create rectangle 155  75 265 155 -fill "" -outline "#58a6ff" -width 3
.d5 create oval      280  75 380 155 -fill "#533483" -outline "#a371f7" -width 2

# Star polygon
proc star {cx cy r1 r2 n} {
    set PI 3.14159265358979
    set c {}
    for {set i 0} {$i < $n*2} {incr i} {
        set a [expr {$i*$PI/$n - $PI/2}]
        set r [expr {$i%2==0 ? $r1 : $r2}]
        lappend c [expr {$cx+$r*cos($a)}] [expr {$cy+$r*sin($a)}]
    }
    return $c
}
.d5 create polygon {*}[star 460 115 50 22 6] \
    -fill "#e9c46a" -outline "#f4a261" -width 2

# Section: Lines & Paths
.d5 create text 20 175 -text "Lines" -font {Sans 11 bold} \
    -fill "#8b949e" -anchor w
.d5 create line  20 195 580 195 -fill "#58a6ff" -width 1
.d5 create line  20 215 580 215 -fill "#e9c46a" -width 3 -dash {10 4}
.d5 create line  20 240 150 270 280 240 410 270 540 240 \
    -fill "#e94560" -width 2 -smooth true
.d5 create line  20 290 580 290 -fill "#2ea043" -width 2 \
    -arrow last -capstyle round

# Section: Arc styles
.d5 create text 20 315 -text "Arcs" -font {Sans 11 bold} \
    -fill "#8b949e" -anchor w
foreach {x style fill out} {
     50 pieslice "#533483" "#a371f7"
    160 chord   "#264653" "#2a9d8f"
    270 arc     ""        "#e76f51"
} {
    .d5 create arc [expr {$x-45}] 330 [expr {$x+45}] 420 \
        -start 30 -extent 220 -style $style \
        -fill $fill -outline $out -width 2
    .d5 create text $x 425 -text $style \
        -font "Sans 9" -fill "#8b949e" -anchor center
}

# Section: Text styles
.d5 create text 380 315 -text "Text" -font {Sans 11 bold} \
    -fill "#8b949e" -anchor w
.d5 create text 380 345 -text "Regular" \
    -font "Sans 13" -fill "#c9d1d9" -anchor w
.d5 create text 380 370 -text "Bold Italic" \
    -font {Sans 13 bold italic} -fill "#58a6ff" -anchor w
.d5 create text 380 395 -text "Monospace" \
    -font "Monospace 12" -fill "#2ea043" -anchor w
.d5 create text 590 380 -text "45°" \
    -font {Sans 14 bold} -fill "#e9c46a" -anchor center -angle 45

update idletasks
save_demo .d5 demo5-showcase
destroy .d5

puts "\nAll demos complete."
puts "Output in: $outdir"
