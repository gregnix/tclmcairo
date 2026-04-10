#!/usr/bin/env wish
# demo-coordinates.tcl
# Interaktives Demo: user_to_device, device_to_user, recording_bbox, path_get
#
# Usage: TCLMCAIRO_LIBDIR=/path/to/tclmcairo wish demo-coordinates.tcl

set dir [file dirname [file normalize [info script]]]
tcl::tm::path add [file join $dir .. tcl]
set env(TCLMCAIRO_LIBDIR) [file join $dir ..]
if {[info exists env(TCLMCAIRO_LIBDIR_OVERRIDE)]} {
    set env(TCLMCAIRO_LIBDIR) $env(TCLMCAIRO_LIBDIR_OVERRIDE)
}
package require Tk
package require tclmcairo

# ================================================================
# Window layout
# ================================================================
wm title . "tclmcairo — Coordinates Demo"
wm resizable . 0 0

ttk::frame .main -padding 8
pack .main -fill both -expand 1

# Notebook: 3 tabs
ttk::notebook .main.nb
pack .main.nb -fill both -expand 1

ttk::frame .main.nb.t1
ttk::frame .main.nb.t2
ttk::frame .main.nb.t3

.main.nb add .main.nb.t1 -text "user_to_device"
.main.nb add .main.nb.t2 -text "recording_bbox"
.main.nb add .main.nb.t3 -text "path_get"

# ================================================================
# TAB 1: user_to_device / device_to_user
# ================================================================
set W 480; set H 320

# Controls
ttk::frame .main.nb.t1.ctrl -padding {4 4}
pack .main.nb.t1.ctrl -fill x

ttk::label .main.nb.t1.ctrl.lt  -text "Translate X:"
ttk::spinbox .main.nb.t1.ctrl.tx -width 5 -from -200 -to 200 \
    -textvariable ::tx -increment 5
ttk::label .main.nb.t1.ctrl.lty -text "Y:"
ttk::spinbox .main.nb.t1.ctrl.ty -width 5 -from -200 -to 200 \
    -textvariable ::ty -increment 5
ttk::label .main.nb.t1.ctrl.lr  -text "  Rotate°:"
ttk::spinbox .main.nb.t1.ctrl.rot -width 5 -from -180 -to 180 \
    -textvariable ::rot -increment 5
ttk::label .main.nb.t1.ctrl.ls  -text "  Scale:"
ttk::spinbox .main.nb.t1.ctrl.sc -width 5 -from 0.1 -to 3.0 \
    -textvariable ::sc -increment 0.1 -format "%.1f"

pack .main.nb.t1.ctrl.lt .main.nb.t1.ctrl.tx \
     .main.nb.t1.ctrl.lty .main.nb.t1.ctrl.ty \
     .main.nb.t1.ctrl.lr .main.nb.t1.ctrl.rot \
     .main.nb.t1.ctrl.ls .main.nb.t1.ctrl.sc \
     -side left -padx 2

set tx 100; set ty 80; set rot 30; set sc 1.0

# Canvas display
canvas .main.nb.t1.c -width $W -height $H \
    -background "#0d1117" -cursor crosshair
pack .main.nb.t1.c -padx 4 -pady 4

# Info label
ttk::label .main.nb.t1.info -text "Klick auf Canvas = device→user Koordinaten" \
    -font "TkSmallCaptionFont"
pack .main.nb.t1.info -pady 2

# Result display
ttk::frame .main.nb.t1.res -padding {4 2}
pack .main.nb.t1.res -fill x
ttk::label .main.nb.t1.res.l1 -text "Klick (device):" -width 20 -anchor w
ttk::label .main.nb.t1.res.v1 -textvariable ::dev_coords \
    -font "TkFixedFont" -width 20
ttk::label .main.nb.t1.res.l2 -text "→ user coords:" -width 20 -anchor w
ttk::label .main.nb.t1.res.v2 -textvariable ::usr_coords \
    -font "TkFixedFont" -foreground "#58a6ff" -width 20
pack .main.nb.t1.res.l1 .main.nb.t1.res.v1 \
     .main.nb.t1.res.l2 .main.nb.t1.res.v2 \
     -side left -padx 4

set dev_coords "—"
set usr_coords "—"

proc redraw_t1 {} {
    global W H tx ty rot sc dev_coords usr_coords

    set ctx [tclmcairo::new $W $H]
    $ctx clear 0.05 0.05 0.1

    # Apply transform
    $ctx transform -translate $tx $ty
    $ctx transform -rotate    $rot
    $ctx transform -scale     $sc $sc

    # Draw grid in user space
    for {set x -200} {$x <= 200} {incr x 40} {
        $ctx line $x -200 $x 200 -color {0.2 0.2 0.3} -width 0.5
    }
    for {set y -200} {$y <= 200} {incr y 40} {
        $ctx line -200 $y 200 $y -color {0.2 0.2 0.3} -width 0.5
    }
    # Axes
    $ctx line -200 0 200 0 -color {0.4 0.4 0.6} -width 1
    $ctx line 0 -200 0 200 -color {0.4 0.4 0.6} -width 1

    # Shape at user-space origin
    $ctx rect -60 -30 120 60 -fill {0.2 0.4 0.7 0.5} \
        -stroke {0.4 0.6 1} -width 1.5
    $ctx circle 0 0 8 -fill {1 0.5 0.2}
    $ctx text 0 -40 "User (0,0)" -font "Sans 10" \
        -color {1 0.8 0.4} -anchor center

    # Show user_to_device of origin
    set d [$ctx user_to_device 0 0]
    set dx [format "%.0f" [lindex $d 0]]
    set dy [format "%.0f" [lindex $d 1]]

    # Cross at device position
    $ctx transform -reset
    $ctx line [expr {$dx-12}] $dy [expr {$dx+12}] $dy \
        -color {1 0.3 0.3} -width 2
    $ctx line $dx [expr {$dy-12}] $dx [expr {$dy+12}] \
        -color {1 0.3 0.3} -width 2
    $ctx circle $dx $dy 5 -fill {1 0.3 0.3 0.8}
    $ctx text [expr {$dx+10}] [expr {$dy-10}] \
        "device($dx,$dy)" -font "Sans 9" -color {1 0.5 0.5}

    # Render to canvas
    .main.nb.t1.c delete all
    set bytes [$ctx topng]
    $ctx destroy
    set img [image create photo -data $bytes -format png]
    .main.nb.t1.c create image 0 0 -image $img -anchor nw
}

# Mouse click handler
proc on_canvas_click {W H cx cy} {
    global tx ty rot sc dev_coords usr_coords
    set ctx [tclmcairo::new $W $H]
    $ctx transform -translate $tx $ty
    $ctx transform -rotate    $rot
    $ctx transform -scale     $sc $sc
    set u [$ctx device_to_user $cx $cy]
    $ctx destroy
    set dev_coords "($cx, $cy)"
    set usr_coords "([format %.1f [lindex $u 0]], [format %.1f [lindex $u 1]])"
    redraw_t1
    # Show click dot on top of rendered image
    .main.nb.t1.c create oval \
        [expr {$cx-6}] [expr {$cy-6}] \
        [expr {$cx+6}] [expr {$cy+6}] \
        -fill "#ff6b6b" -outline white -width 1.5
    .main.nb.t1.c create text [expr {$cx+10}] [expr {$cy-10}] \
        -text "($cx,$cy)" -fill "#ff6b6b" -font "TkSmallCaptionFont" -anchor w
}

bind .main.nb.t1.c <Button-1> \
    "on_canvas_click $W $H %x %y"

# Redraw on spinbox change
foreach w {.main.nb.t1.ctrl.tx .main.nb.t1.ctrl.ty
           .main.nb.t1.ctrl.rot .main.nb.t1.ctrl.sc} {
    bind $w <Return>   { redraw_t1 }
    bind $w <<Decrement>> { after 50 redraw_t1 }
    bind $w <<Increment>> { after 50 redraw_t1 }
}

# ================================================================
# TAB 2: recording_bbox
# ================================================================
ttk::frame .main.nb.t2.ctrl -padding {4 4}
pack .main.nb.t2.ctrl -fill x

ttk::label  .main.nb.t2.ctrl.l -text "Zeichnen:"
ttk::button .main.nb.t2.ctrl.b1 -text "Text" \
    -command {set bbox_content text; redraw_t2}
ttk::button .main.nb.t2.ctrl.b2 -text "Kreis" \
    -command {set bbox_content circle; redraw_t2}
ttk::button .main.nb.t2.ctrl.b3 -text "Pfade" \
    -command {set bbox_content paths; redraw_t2}
ttk::button .main.nb.t2.ctrl.b4 -text "Alles" \
    -command {set bbox_content all; redraw_t2}
pack .main.nb.t2.ctrl.l \
     .main.nb.t2.ctrl.b1 .main.nb.t2.ctrl.b2 \
     .main.nb.t2.ctrl.b3 .main.nb.t2.ctrl.b4 \
     -side left -padx 4

canvas .main.nb.t2.c -width $W -height $H \
    -background "#0d1117"
pack .main.nb.t2.c -padx 4 -pady 4

ttk::frame .main.nb.t2.res -padding {4 2}
pack .main.nb.t2.res -fill x
ttk::label .main.nb.t2.res.l -text "recording_bbox:" -width 18 -anchor w
ttk::label .main.nb.t2.res.v -textvariable ::bbox_result \
    -font "TkFixedFont" -foreground "#2ea043"
pack .main.nb.t2.res.l .main.nb.t2.res.v -side left -padx 4

set bbox_content all
set bbox_result "—"

proc redraw_t2 {} {
    global W H bbox_content bbox_result

    # Draw into vector context
    set ctx [tclmcairo::new $W $H -mode vector]

    if {$bbox_content eq "text" || $bbox_content eq "all"} {
        $ctx text 80 100 "tclmcairo" \
            -font "Sans Bold 48" -color {0.4 0.7 1} -anchor w
    }
    if {$bbox_content eq "circle" || $bbox_content eq "all"} {
        $ctx circle 320 200 70 -fill {0.8 0.3 0.1 0.8} \
            -stroke {1 0.5 0.2} -width 3
    }
    if {$bbox_content eq "paths" || $bbox_content eq "all"} {
        $ctx path "M 50 260 C 100 200 200 300 300 240 L 420 260" \
            -stroke {0.3 0.9 0.4} -width 4
    }

    # Get bounding box
    set bb [$ctx recording_bbox]
    set bx [lindex $bb 0]; set by [lindex $bb 1]
    set bw [lindex $bb 2]; set bh [lindex $bb 3]
    set bbox_result \
        "x=[format %.0f $bx]  y=[format %.0f $by]  w=[format %.0f $bw]  h=[format %.0f $bh]"

    # Render to raster for display
    set raster [tclmcairo::new $W $H]
    $raster clear 0.05 0.05 0.1
    $raster blit $ctx 0 0

    # Draw the bounding box highlight
    $raster rect $bx $by $bw $bh \
        -stroke {1 0.8 0.2} -width 2
    # Corner markers
    foreach {cx cy} [list \
        $bx $by \
        [expr {$bx+$bw}] $by \
        [expr {$bx+$bw}] [expr {$by+$bh}] \
        $bx [expr {$by+$bh}]] {
        $raster circle $cx $cy 4 -fill {1 0.8 0.2}
    }
    # Label
    $raster text [expr {$bx+4}] [expr {$by-6}] \
        "bbox: ${bx}×${by} / ${bw}×${bh}" \
        -font "Sans 9" -color {1 0.8 0.2}

    .main.nb.t2.c delete all
    set bytes [$raster topng]
    $ctx destroy; $raster destroy
    set img [image create photo -data $bytes -format png]
    .main.nb.t2.c create image 0 0 -image $img -anchor nw
}

# ================================================================
# TAB 3: path_get
# ================================================================
ttk::frame .main.nb.t3.ctrl -padding {4 4}
pack .main.nb.t3.ctrl -fill x

ttk::label  .main.nb.t3.ctrl.l -text "Pfad:"
ttk::button .main.nb.t3.ctrl.b1 -text "Linie" \
    -command {set path_content line; redraw_t3}
ttk::button .main.nb.t3.ctrl.b2 -text "Bezier" \
    -command {set path_content bezier; redraw_t3}
ttk::button .main.nb.t3.ctrl.b3 -text "Polygon" \
    -command {set path_content polygon; redraw_t3}
pack .main.nb.t3.ctrl.l \
     .main.nb.t3.ctrl.b1 .main.nb.t3.ctrl.b2 \
     .main.nb.t3.ctrl.b3 \
     -side left -padx 4

canvas .main.nb.t3.c -width $W -height 220 \
    -background "#0d1117"
pack .main.nb.t3.c -padx 4 -pady 4

ttk::label .main.nb.t3.lbl -text "path_get → SVG string:" \
    -font "TkSmallCaptionFont"
pack .main.nb.t3.lbl -anchor w -padx 6

text .main.nb.t3.txt -width 60 -height 5 \
    -font "TkFixedFont" -background "#161b22" -foreground "#58a6ff" \
    -relief flat -wrap word
pack .main.nb.t3.txt -fill x -padx 6 -pady 4

set path_content bezier

proc redraw_t3 {} {
    global W path_content

    set ctx [tclmcairo::new $W 220]
    $ctx clear 0.05 0.05 0.1

    # Build path with low-level API
    switch $path_content {
        line {
            $ctx move_to  30 110
            $ctx line_to 200 60
            $ctx line_to 350 140
            $ctx line_to 450 80
        }
        bezier {
            $ctx move_to   30 150
            $ctx curve_to  80  40 180 200 280 110
            $ctx curve_to 360  30 420 180 450  80
        }
        polygon {
            # Star
            set PI 3.14159265358979
            set cx 240; set cy 110
            $ctx move_to [expr {$cx + 90*cos(-$PI/2)}] \
                         [expr {$cy + 90*sin(-$PI/2)}]
            for {set i 1} {$i <= 10} {incr i} {
                set r [expr {$i % 2 == 0 ? 90 : 38}]
                set a [expr {$PI * $i / 5 - $PI/2}]
                $ctx line_to [expr {$cx + $r*cos($a)}] \
                             [expr {$cy + $r*sin($a)}]
            }
            $ctx close_path
        }
    }

    # Get path BEFORE drawing
    set svg [$ctx path_get]

    # Draw the path
    $ctx set_source_rgb 0.4 0.7 1.0
    $ctx set_line_width 3
    $ctx stroke

    # Show control points for bezier
    if {$path_content eq "bezier"} {
        foreach {px py} {30 150  80 40  180 200  280 110
                         280 110  360 30  420 180  450 80} {
            $ctx circle $px $py 4 -fill {1 0.6 0.2 0.8}
        }
    }

    .main.nb.t3.c delete all
    set bytes [$ctx topng]
    $ctx destroy
    set img [image create photo -data $bytes -format png]
    .main.nb.t3.c create image 0 0 -image $img -anchor nw

    # Show SVG string
    .main.nb.t3.txt delete 1.0 end
    # Format nicely: break at each command letter
    set formatted [regsub -all { ([MLCQAZT])} $svg "\n\\1"]
    .main.nb.t3.txt insert end [string trim $formatted]
}

# ================================================================
# Init
# ================================================================
after 100 {
    redraw_t1
    redraw_t2
    redraw_t3
}

# Status bar
ttk::label .main.status \
    -text "Tab 1: Klick auf Canvas • Tab 2: Buttons • Tab 3: Buttons" \
    -font "TkSmallCaptionFont" -foreground "#8b949e"
pack .main.status -pady 4
