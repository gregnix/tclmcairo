# canvas2cairo-0.1.tm  (tclmcairo 0.3.2)
# Export a Tk Canvas to SVG, PDF, PS, EPS, or PNG via tclmcairo
# via tclmcairo. Requires: Tk, tclmcairo.
#
# Usage:
#   canvas2cairo::export .c output.svg
#   canvas2cairo::export .c output.pdf
#   canvas2cairo::render .c $ctx    ;# render into existing context
#
# Version: 0.1  License: BSD  Author: gregnix

package require tclmcairo

# Tk is required for integration (Canvas items), but not for unit tests
# of pure-Tcl helpers. Load gracefully.
if {[catch {package require Tk} _c2c_err]} {
    # No Tk available — helpers still usable, export/render will fail
    # if called without a real Canvas
}
unset -nocomplain _c2c_err

namespace eval canvas2cairo {

namespace export export render

# ================================================================
# Public API
# ================================================================

proc export {canvas args} {
    # Usage:
    #   canvas2cairo::export .c filename.pdf ?-scale f? ?-viewport {..}?
    #   canvas2cairo::export .c -chan channel -format fmt ?-scale f? ?-viewport {..}?
    #
    # Detect if first arg is a filename or an option
    set filename ""
    if {[llength $args] > 0 && [string index [lindex $args 0] 0] ne "-"} {
        set filename [lindex $args 0]
        set args [lrange $args 1 end]
    }

    set scale       1.0
    set viewport    ""
    set bg_override ""
    set chan_out    ""
    set chan_fmt    "pdf"
    foreach {k v} $args {
        switch $k {
            -scale      { set scale [expr {double($v)}] }
            -viewport   { set viewport $v }
            -background { set bg_override $v }
            -chan        { set chan_out $v }
            -format     { set chan_fmt $v }
        }
    }

    # -chan mode: write to channel instead of file
    if {$chan_out ne ""} {
        # Security: verify channel is writable + set binary mode
        if {[catch {puts -nonewline $chan_out ""} err]} {
            error "canvas2cairo: channel is not writable: $err"
        }
        if {[catch {fconfigure $chan_out -translation binary} err]} {
            error "canvas2cairo: cannot set binary mode on channel: $err"
        }
        _export_chan $canvas $chan_out $chan_fmt $scale $viewport
        return
    }

    if {$filename eq ""} {
        error "canvas2cairo::export: filename required"
    }

    # Determine canvas size
    set w [$canvas cget -width]
    set h [$canvas cget -height]
    set ww [winfo width  $canvas]
    set wh [winfo height $canvas]
    if {$ww > 1} { set w $ww }
    if {$wh > 1} { set h $wh }

    # Honour scrollregion if set (and no viewport override)
    set sr_ox 0; set sr_oy 0
    if {$viewport eq ""} {
        set sr [$canvas cget -scrollregion]
        if {$sr ne "" && [llength $sr] == 4} {
            set sr_x1 [lindex $sr 0]; set sr_y1 [lindex $sr 1]
            set sr_x2 [lindex $sr 2]; set sr_y2 [lindex $sr 3]
            set sw [expr {int($sr_x2 - $sr_x1)}]
            set sh [expr {int($sr_y2 - $sr_y1)}]
            if {$sw > 0} { set w $sw }
            if {$sh > 0} { set h $sh }
            # Negative origin: shift all items by offset
            if {$sr_x1 < 0} { set sr_ox [expr {int($sr_x1)}] }
            if {$sr_y1 < 0} { set sr_oy [expr {int($sr_y1)}] }
        }
    }

    # Viewport crop: export only a region of the canvas
    set vx 0; set vy 0; set vw $w; set vh $h
    if {$viewport ne "" && [llength $viewport] == 4} {
        lassign $viewport vx vy x2 y2
        set vw [expr {int($x2 - $vx)}]
        set vh [expr {int($y2 - $vy)}]
        if {$vw < 1} { set vw 1 }
        if {$vh < 1} { set vh 1 }
    }

    # Apply scale
    set out_w [expr {int(ceil($vw * $scale))}]
    set out_h [expr {int(ceil($vh * $scale))}]

    # Determine mode from extension
    set ext [string tolower [file extension $filename]]
    switch $ext {
        .svg  { set mode svg }
        .pdf  { set mode pdf }
        .ps   { set mode ps  }
        .eps  { set mode eps }
        .png  { set mode png }
        default { set mode svg }
    }

    # Merge scrollregion offset with viewport
    set rx [expr {$vx + $sr_ox}]
    set ry [expr {$vy + $sr_oy}]

    if {$mode eq "png"} {
        set ctx [tclmcairo::new $out_w $out_h]
        $ctx clear 1 1 1
        _apply_render $canvas $ctx $scale $rx $ry $vw $vh
        $ctx save $filename
        $ctx destroy
        return
    }

    set ctx [tclmcairo::new $out_w $out_h -mode $mode -file $filename]
    _apply_render $canvas $ctx $scale $rx $ry $vw $vh
    $ctx finish
    $ctx destroy
}

# Internal: apply scale/viewport transforms then render
proc _apply_render {canvas ctx scale vx vy {vw 0} {vh 0}} {
    if {$scale != 1.0 || $vx != 0 || $vy != 0} {
        $ctx push
        if {$scale != 1.0} { $ctx transform -scale $scale $scale }
        if {$vx != 0 || $vy != 0} {
            $ctx transform -translate [expr {-double($vx)}] [expr {-double($vy)}]
        }
        # Clip bbox: only render items within the viewport region
        set clip ""
        if {$vw > 0 && $vh > 0} {
            set clip [list $vx $vy [expr {$vx+$vw}] [expr {$vy+$vh}]]
        }
        render $canvas $ctx 0 0 $clip
        $ctx pop
    } else {
        render $canvas $ctx
    }
}

# Internal: export canvas to open channel
proc _export_chan {canvas chan fmt scale viewport} {
    # Determine canvas size
    set w [$canvas cget -width]
    set h [$canvas cget -height]
    set ww [winfo width  $canvas]
    set wh [winfo height $canvas]
    if {$ww > 1} { set w $ww }
    if {$wh > 1} { set h $wh }

    # Scrollregion
    set sr_ox 0; set sr_oy 0
    if {$viewport eq ""} {
        set sr [$canvas cget -scrollregion]
        if {$sr ne "" && [llength $sr] == 4} {
            lassign $sr sr_x1 sr_y1 sr_x2 sr_y2
            set sw [expr {int($sr_x2 - $sr_x1)}]
            set sh [expr {int($sr_y2 - $sr_y1)}]
            if {$sw > 0} { set w $sw }
            if {$sh > 0} { set h $sh }
            if {$sr_x1 < 0} { set sr_ox [expr {int($sr_x1)}] }
            if {$sr_y1 < 0} { set sr_oy [expr {int($sr_y1)}] }
        }
    }

    # Viewport
    set vx 0; set vy 0; set vw $w; set vh $h
    if {$viewport ne "" && [llength $viewport] == 4} {
        lassign $viewport vx vy x2 y2
        set vw [expr {int($x2 - $vx)}]
        set vh [expr {int($y2 - $vy)}]
        if {$vw < 1} { set vw 1 }
        if {$vh < 1} { set vh 1 }
    }

    set out_w [expr {int(ceil($vw * $scale))}]
    set out_h [expr {int(ceil($vh * $scale))}]
    set rx [expr {$vx + $sr_ox}]
    set ry [expr {$vy + $sr_oy}]

    if {$fmt eq "png"} {
        set ctx [tclmcairo::new $out_w $out_h]
        $ctx clear 1 1 1
        _apply_render $canvas $ctx $scale $rx $ry $vw $vh
        $ctx save -chan $chan -format png
        $ctx destroy
        return
    }

    # Vector formats (pdf/svg/ps/eps): tclmcairo::new needs -file for
    # vector mode. Write to tmp file then stream to channel.
    set tmpf [file join /tmp _c2c_chan_[pid]_[clock microseconds].$fmt]
    set ctx [tclmcairo::new $out_w $out_h -mode $fmt -file $tmpf]
    _apply_render $canvas $ctx $scale $rx $ry $vw $vh
    $ctx finish
    $ctx destroy
    # Stream tmp file to channel
    set fh [open $tmpf rb]
    fconfigure $fh -translation binary
    fcopy $fh $chan
    close $fh
    file delete -force $tmpf
}

proc render {canvas ctx {ox 0} {oy 0} {clip_bbox ""}} {
    # ox/oy: canvas origin offset (for scroll position or viewport)
    # clip_bbox: optional {x1 y1 x2 y2} in canvas coords to skip items outside
    #
    # Public API also accepts keyword args:
    #   canvas2cairo::render .c $ctx -clip {x1 y1 x2 y2}
    # In this form ox/oy are derived from scroll position automatically.
    if {$ox eq "-clip"} {
        # called as: render canvas ctx -clip {x1 y1 x2 y2}
        set clip_bbox $oy
        set ox 0; set oy 0
    }
    # Background
    set bg [$canvas cget -background]
    if {$bg ne ""} {
        set c [_tk_color $canvas $bg]
        $ctx clear {*}$c
    } else {
        $ctx clear 1 1 1
    }

    # Account for scroll position: canvasx(0) gives current x-origin
    if {$ox == 0 && $oy == 0} {
        catch {
            set ox [expr {int([$canvas canvasx 0])}]
            set oy [expr {int([$canvas canvasy 0])}]
        }
    }

    if {$ox != 0 || $oy != 0} {
        $ctx push
        $ctx transform -translate [expr {-$ox}] [expr {-$oy}]
    }

    # Render all items in Z-order (bottom to top)
    foreach id [$canvas find all] {
        _render_item $canvas $ctx $id $clip_bbox
    }

    if {$ox != 0 || $oy != 0} {
        $ctx pop
    }
}

# ================================================================
# Item rendering dispatch
# ================================================================

proc _render_item {canvas ctx id {clip_bbox ""}} {
    # Skip hidden items
    if {[catch {set state [$canvas itemcget $id -state]}] == 0} {
        if {$state eq "hidden"} return
    }
    # Skip items with no coords (safety)
    if {[catch {set bbox [$canvas bbox $id]}]} { return }
    if {$bbox eq ""} { return }
    # Skip items completely outside clip bbox (performance optimization)
    if {$clip_bbox ne "" && [llength $bbox] == 4 && [llength $clip_bbox] == 4} {
        if {[_bbox_outside $bbox $clip_bbox]} { return }
    }
    set type [$canvas type $id]
    switch $type {
        rectangle { _render_rect    $canvas $ctx $id }
        oval      { _render_oval    $canvas $ctx $id }
        line      { _render_line    $canvas $ctx $id }
        polygon   { _render_polygon $canvas $ctx $id }
        text      { _render_text    $canvas $ctx $id }
        arc       { _render_arc     $canvas $ctx $id }
        image     { _render_image   $canvas $ctx $id }
        window    -
        bitmap    {
            # window/bitmap items cannot be exported — skip silently
            # Uncomment for debug: puts stderr "canvas2cairo: skipping $type item $id"
        }
        default   { }
    }
}

# ================================================================
# rectangle
# ================================================================

proc _render_rect {canvas ctx id} {
    lassign [$canvas coords $id] x1 y1 x2 y2
    set w [expr {$x2 - $x1}]
    set h [expr {$y2 - $y1}]

    set fill   [_item_opt $canvas $id -fill]
    set stroke [_item_opt $canvas $id -outline]
    set lw     [_item_opt $canvas $id -width]
    set dash   [_item_opt $canvas $id -dash]

    set opts {}
    if {$fill ne "" && $fill ne "none"} {
        lappend opts -fill [_tk_color $canvas $fill]
    }
    if {$stroke ne "" && $stroke ne ""} {
        lappend opts -stroke [_tk_color $canvas $stroke]
        lappend opts -width  [expr {double($lw)}]
    }
    if {$dash ne ""} {
        lappend opts -dash [_tk_dash $dash]
    }

    if {[llength $opts]} {
        $ctx rect $x1 $y1 $w $h {*}$opts
    }
}

# ================================================================
# oval
# ================================================================

# Note on strokes and Cairo pixel-exact rendering:
# Cairo renders stroke outlines at exactly the specified width, centered on the
# path. A 1px stroke on an oval extends 0.5px inside and 0.5px outside.
# In Tk, overlapping fills hide this; in Cairo it is always visible.
# Use -outline "" to avoid strokes that bleed into adjacent canvas items.
proc _render_oval {canvas ctx id} {
    lassign [$canvas coords $id] x1 y1 x2 y2
    set cx [expr {($x1 + $x2) / 2.0}]
    set cy [expr {($y1 + $y2) / 2.0}]
    set rx [expr {($x2 - $x1) / 2.0}]
    set ry [expr {($y2 - $y1) / 2.0}]

    set fill   [_item_opt $canvas $id -fill]
    set stroke [_item_opt $canvas $id -outline]
    set lw     [_item_opt $canvas $id -width]
    set dash   [_item_opt $canvas $id -dash]

    set opts {}
    if {$fill ne ""} {
        lappend opts -fill [_tk_color $canvas $fill]
    }
    if {$stroke ne ""} {
        lappend opts -stroke [_tk_color $canvas $stroke]
        lappend opts -width  [expr {double($lw)}]
    }
    if {$dash ne ""} {
        lappend opts -dash [_tk_dash $dash]
    }

    if {[llength $opts]} {
        if {abs($rx - $ry) < 0.5} {
            $ctx circle $cx $cy $rx {*}$opts
        } else {
            $ctx ellipse $cx $cy $rx $ry {*}$opts
        }
    }
}

# ================================================================
# line
# ================================================================

proc _render_line {canvas ctx id} {
    set coords [$canvas coords $id]
    if {[llength $coords] < 4} return

    set fill   [_item_opt $canvas $id -fill]
    set lw     [_item_opt $canvas $id -width]
    set dash   [_item_opt $canvas $id -dash]
    set cap    [_item_opt $canvas $id -capstyle]
    set join   [_item_opt $canvas $id -joinstyle]
    set smooth [_item_opt $canvas $id -smooth]
    set arrow  [_item_opt $canvas $id -arrow]

    set col {0 0 0}
    if {$fill ne ""} { set col [_tk_color $canvas $fill] }

    # Build SVG path
    set path [_coords_to_path $coords $smooth]

    set opts [list -stroke $col -width [expr {double($lw)}]]
    set dashoffset [_item_opt $canvas $id -dashoffset]
    if {$dash ne ""}  {
        lappend opts -dash [_tk_dash $dash]
        if {$dashoffset ne "" && $dashoffset != 0} {
            lappend opts -dash_offset [expr {double($dashoffset)}]
        }
    }
    if {$cap ne ""}   { lappend opts -linecap  [_cap_style $cap] }
    if {$join ne ""}  { lappend opts -linejoin [_join_style $join] }

    $ctx path $path {*}$opts

    # Arrowheads
    if {$arrow ne "none" && $arrow ne ""} {
        set arrowshape [_item_opt $canvas $id -arrowshape]
        _draw_arrows $ctx $coords $arrow $col $lw $arrowshape
    }
}

# ================================================================
# polygon
# ================================================================

proc _render_polygon {canvas ctx id} {
    set coords [$canvas coords $id]
    if {[llength $coords] < 6} return

    set fill   [_item_opt $canvas $id -fill]
    set stroke [_item_opt $canvas $id -outline]
    set lw     [_item_opt $canvas $id -width]
    set smooth [_item_opt $canvas $id -smooth]
    set dash   [_item_opt $canvas $id -dash]
    set frule  [_item_opt $canvas $id -joinstyle]  ;# not fillrule but reuse

    set path [_coords_to_path $coords $smooth closed]

    set opts {}
    if {$fill ne ""} {
        lappend opts -fill [_tk_color $canvas $fill]
    }
    if {$stroke ne ""} {
        lappend opts -stroke [_tk_color $canvas $stroke]
        lappend opts -width  [expr {double($lw)}]
    }
    if {$dash ne ""} { lappend opts -dash [_tk_dash $dash] }

    if {[llength $opts]} {
        $ctx path $path {*}$opts
    }
}

# ================================================================
# text
# ================================================================

proc _render_text {canvas ctx id} {
    lassign [$canvas coords $id] x y

    set text   [_item_opt $canvas $id -text]
    set fill   [_item_opt $canvas $id -fill]
    set font   [_item_opt $canvas $id -font]
    set anchor [_item_opt $canvas $id -anchor]
    set width  [_item_opt $canvas $id -width]   ;# wrap width (ignore in SVG)
    set angle  [_item_opt $canvas $id -angle]

    if {$text eq ""} return

    set col {0 0 0}
    if {$fill ne ""} { set col [_tk_color $canvas $fill] }

    set cfont [_tk_font $font]
    set canc  [_tk_anchor $anchor]

    set underline [_item_opt $canvas $id -underline]
    set justify  [_item_opt $canvas $id -justify]
    set opts [list -font $cfont -color $col -anchor $canc]

    # Handle -width: manual word-wrap using original Tk font for measurement
    if {$width ne "" && $width > 0 && $text ne ""} {
        set text [_wrap_text $text $font $width]
    }

    # Split on newlines — cairo_show_text does not handle \n
    set lines [split $text "\n"]
    set nlines [llength $lines]
    set fsize  [expr {abs([font actual $font -size])}]
    set line_height [expr {$fsize * 1.3}]

    # Adjust Y start based on anchor and number of lines
    # Tk places the anchor at (x,y) for the whole text block
    set total_h [expr {$nlines * $line_height}]
    switch -glob [string tolower $anchor] {
        center -
        e* -
        w* -
        c   { set y0 [expr {$y - $total_h / 2.0 + $fsize * 0.5}] }
        s*  { set y0 [expr {$y - $total_h + $fsize}] }
        default { set y0 $y }
    }

    if {$angle ne "" && $angle != 0} {
        $ctx push
        $ctx transform -translate $x $y
        $ctx transform -rotate [expr {-double($angle)}]
        set ly [expr {$y0 - $y}]
        foreach line $lines {
            $ctx text 0 $ly $line {*}$opts
            set ly [expr {$ly + $line_height}]
        }
        $ctx pop
    } else {
        set ly $y0
        foreach line $lines {
            # Apply -justify offset using Cairo font_measure for accuracy
            set lx $x
            if {$justify ne "" && $justify ne "left" && [llength $lines] > 1} {
                # Use Cairo metrics for text width — more accurate than Tk font measure
                # because Cairo renders with its own font engine
                set lw 0; set maxw 0
                catch {
                    set lw   [lindex [$ctx font_measure $line $cfont] 0]
                    foreach ln $lines {
                        set w [lindex [$ctx font_measure $ln $cfont] 0]
                        if {$w > $maxw} { set maxw $w }
                    }
                }
                # Fallback to Tk if font_measure failed
                if {$lw == 0} {
                    set lw [font measure $font $line]
                    set maxw 0
                    foreach ln $lines {
                        set w [font measure $font $ln]
                        if {$w > $maxw} { set maxw $w }
                    }
                }
                if {$justify eq "center"} {
                    set lx [expr {$x + ($maxw - $lw) / 2.0}]
                } elseif {$justify eq "right"} {
                    set lx [expr {$x + $maxw - $lw}]
                }
            }
            $ctx text $lx $ly $line {*}$opts
            set ly [expr {$ly + $line_height}]
        }
    }
}

# ================================================================
# arc
# ================================================================

proc _render_arc {canvas ctx id} {
    lassign [$canvas coords $id] x1 y1 x2 y2

    set cx [expr {($x1 + $x2) / 2.0}]
    set cy [expr {($y1 + $y2) / 2.0}]
    set rx [expr {($x2 - $x1) / 2.0}]
    set ry [expr {($y2 - $y1) / 2.0}]
    set r  [expr {($rx + $ry) / 2.0}]   ;# approximate

    set start  [_item_opt $canvas $id -start]
    set extent [_item_opt $canvas $id -extent]
    set style  [_item_opt $canvas $id -style]   ;# pieslice arc chord
    set fill   [_item_opt $canvas $id -fill]
    set stroke [_item_opt $canvas $id -outline]
    set lw     [_item_opt $canvas $id -width]

    set end [expr {$start + $extent}]

    # Tk: angles counter-clockwise from 3-o'clock → Cairo: clockwise from 3
    set cstart [expr {-$start}]
    set cend   [expr {-$end}]

    set opts {}
    if {$fill ne ""}   { lappend opts -fill   [_tk_color $canvas $fill] }
    if {$stroke ne ""} { lappend opts -stroke [_tk_color $canvas $stroke]
                         lappend opts -width  [expr {double($lw)}] }

    if {[llength $opts]} {
        if {$style eq "arc"} {
            # Open arc — stroke only, no fill
            set stroke_col {0 0 0}
            if {$stroke ne ""} { set stroke_col [_tk_color $canvas $stroke] }
            $ctx arc $cx $cy $r $cstart $cend                 -stroke $stroke_col -width [expr {double($lw)}]
        } elseif {$style eq "chord"} {
            # Chord: arc closed with straight line
            set PI 3.14159265358979
            set x1c [expr {$cx + $r*cos($cstart*$PI/180)}]
            set y1c [expr {$cy + $r*sin($cstart*$PI/180)}]
            set x2c [expr {$cx + $r*cos($cend*$PI/180)}]
            set y2c [expr {$cy + $r*sin($cend*$PI/180)}]
            # Build SVG arc path
            set large [expr {abs($extent) > 180 ? 1 : 0}]
            set sweep [expr {$extent > 0 ? 0 : 1}]
            set svgpath "M $x1c $y1c A $r $r 0 $large $sweep $x2c $y2c Z"
            $ctx path $svgpath {*}$opts
        } else {
            # pieslice (default)
            $ctx arc $cx $cy $r $cstart $cend {*}$opts
        }
    }
}

# ================================================================
# image
# ================================================================

proc _render_image {canvas ctx id} {
    lassign [$canvas coords $id] x y

    set img    [_item_opt $canvas $id -image]
    set anchor [_item_opt $canvas $id -anchor]

    if {$img eq ""} return
    if {[image type $img] ne "photo"} return

    # Write image to temp file, read as binary bytearray
    # ($img data -format png) returns base64; binary conversions are unreliable.
    # File I/O is the safest path.
    set tmpf "/tmp/c2c_img_[pid]_$id.png"
    if {[catch {$img write $tmpf -format png} err]} {
        puts stderr "canvas2cairo: image write failed: $err"
        return
    }

    # Read back as raw bytes
    set fh [open $tmpf rb]
    fconfigure $fh -translation binary
    set bindata [read $fh]
    close $fh
    file delete -force $tmpf

    # Adjust for anchor
    set iw [image width  $img]
    set ih [image height $img]
    lassign [_anchor_offset $anchor $iw $ih] ox oy
    set ix [expr {$x + $ox}]
    set iy [expr {$y + $oy}]

    if {[catch {$ctx image_data $bindata $ix $iy} err]} {
        puts stderr "canvas2cairo: image_data failed for item $id: $err"
    }
}

# ================================================================
# Helper: coordinate list → SVG path string
# ================================================================

proc _coords_to_path {coords smooth {closed ""}} {
    set n [expr {[llength $coords] / 2}]
    if {$n < 2} {
        return "M [lindex $coords 0] [lindex $coords 1]"
    }

    # Extract point list
    set pts {}
    foreach {x y} $coords { lappend pts [list $x $y] }

    if {$smooth eq "" || $smooth eq "0" || $smooth eq "false"} {
        # ---- Straight lines ----
        set path "M [lindex [lindex $pts 0] 0] [lindex [lindex $pts 0] 1]"
        foreach p [lrange $pts 1 end] {
            append path " L [lindex $p 0] [lindex $p 1]"
        }
        if {$closed ne ""} { append path " Z" }

    } elseif {$smooth eq "raw"} {
        # ---- -smooth raw: explicit cubic Bezier control points ----
        # Tk raw format: p0 cp1 cp2 p1 cp1 cp2 p2 ...
        # Every 3 points: anchor, cp1, cp2 — then next anchor
        # n must be 1 + 3k points for k segments
        set p0 [lindex $pts 0]
        set path "M [lindex $p0 0] [lindex $p0 1]"
        set i 1
        while {$i + 2 < $n} {
            set cp1 [lindex $pts $i]
            set cp2 [lindex $pts [expr {$i+1}]]
            set p1  [lindex $pts [expr {$i+2}]]
            append path " C [lindex $cp1 0] [lindex $cp1 1]"
            append path " [lindex $cp2 0] [lindex $cp2 1]"
            append path " [lindex $p1 0] [lindex $p1 1]"
            incr i 3
        }
        if {$closed ne ""} { append path " Z" }

    } else {
        # ---- -smooth 1/true: Catmull-Rom spline ----
        # Catmull-Rom: curve passes through all original points.
        # Control points derived from neighboring points (tension=0.5).
        # Mapped to cubic Bezier: cp1 = p_i + (p_{i+1}-p_{i-1})/6
        #                         cp2 = p_{i+1} - (p_{i+2}-p_i)/6

        if {$closed ne ""} {
            # For closed curves, wrap endpoints
            set allpts [concat [list [lindex $pts end]] $pts \
                [list [lindex $pts 0]] [list [lindex $pts 1]]]
        } else {
            # For open curves, duplicate first and last point
            set allpts [concat [list [lindex $pts 0]] $pts [list [lindex $pts end]]]
        }
        set np [llength $allpts]

        if {$closed eq ""} {
            set p0 [lindex $allpts 1]
            set path "M [lindex $p0 0] [lindex $p0 1]"
            set istart 1
            set iend [expr {$np - 3}]
        } else {
            set p0 [lindex $allpts 1]
            set path "M [lindex $p0 0] [lindex $p0 1]"
            set istart 1
            set iend [expr {$np - 3}]
        }

        for {set i $istart} {$i <= $iend} {incr i} {
            set p0 [lindex $allpts [expr {$i-1}]]
            set p1 [lindex $allpts $i]
            set p2 [lindex $allpts [expr {$i+1}]]
            set p3 [lindex $allpts [expr {$i+2}]]

            # Catmull-Rom → cubic Bezier control points (tension 0.5)
            set cp1x [expr {[lindex $p1 0] + ([lindex $p2 0]-[lindex $p0 0])/6.0}]
            set cp1y [expr {[lindex $p1 1] + ([lindex $p2 1]-[lindex $p0 1])/6.0}]
            set cp2x [expr {[lindex $p2 0] - ([lindex $p3 0]-[lindex $p1 0])/6.0}]
            set cp2y [expr {[lindex $p2 1] - ([lindex $p3 1]-[lindex $p1 1])/6.0}]

            append path [format " C %.4f %.4f %.4f %.4f %.4f %.4f" \
                $cp1x $cp1y $cp2x $cp2y [lindex $p2 0] [lindex $p2 1]]
        }

        if {$closed ne ""} { append path " Z" }
    }
    return $path
}

# ================================================================
# Helper: arrowheads
# ================================================================

proc _arrowhead {ctx x0 y0 x1 y1 aw al col} {
        set dx [expr {$x1 - $x0}]
        set dy [expr {$y1 - $y0}]
        set len [expr {sqrt($dx*$dx + $dy*$dy)}]
        if {$len < 0.001} return
        set ux [expr {$dx/$len}]; set uy [expr {$dy/$len}]
        set px [expr {-$uy}];     set py [expr {$ux}]
        set bx [expr {$x1 - $ux*$al}]; set by [expr {$y1 - $uy*$al}]
        set p1x [expr {$bx + $px*$aw/2}]; set p1y [expr {$by + $py*$aw/2}]
        set p2x [expr {$bx - $px*$aw/2}]; set p2y [expr {$by - $py*$aw/2}]
        $ctx poly $x1 $y1 $p1x $p1y $p2x $p2y -fill $col
}

proc _draw_arrows {ctx coords arrow col lw {arrowshape ""}} {
    # arrowshape: {d1 d2 d3} = tip-length wing-length width
    if {$arrowshape ne "" && [llength $arrowshape] == 3} {
        lassign $arrowshape d1 d2 d3
        set al [expr {double($d1)}]
        set aw [expr {double($d3) * 2}]
    } else {
        set aw [expr {$lw * 3 + 6}]   ;# arrow width
        set al [expr {$lw * 4 + 8}]   ;# arrow length
    }

    set n [llength $coords]
    if {$arrow eq "last" || $arrow eq "both"} {
        set x0 [lindex $coords end-3]; set y0 [lindex $coords end-2]
        set x1 [lindex $coords end-1]; set y1 [lindex $coords end]
        _arrowhead $ctx $x0 $y0 $x1 $y1 $aw $al $col
    }
    if {$arrow eq "first" || $arrow eq "both"} {
        set x0 [lindex $coords 2]; set y0 [lindex $coords 3]
        set x1 [lindex $coords 0]; set y1 [lindex $coords 1]
        _arrowhead $ctx $x0 $y0 $x1 $y1 $aw $al $col
    }
}

# ================================================================
# Color conversion
# ================================================================

proc _tk_color {canvas color} {
    if {$color eq "" || $color eq "none"} { return {0 0 0} }
    # Use winfo rgb for accurate conversion
    set w [winfo toplevel $canvas]
    if {[catch {set rgb [winfo rgb $w $color]} err]} {
        return {0 0 0}
    }
    list [expr {[lindex $rgb 0] / 65535.0}] \
         [expr {[lindex $rgb 1] / 65535.0}] \
         [expr {[lindex $rgb 2] / 65535.0}]
}

# ================================================================
# Font conversion: Tk font → Cairo font string
# ================================================================

proc _tk_font {font} {
    if {$font eq ""} { return "Sans 12" }

    if {[catch {
        set family [font actual $font -family]
        set size   [expr {abs([font actual $font -size])}]
        set weight [font actual $font -weight]
        set slant  [font actual $font -slant]
    }]} {
        return $font
    }

    set spec $family
    if {$weight eq "bold"}   { append spec " Bold" }
    if {$slant  eq "italic"} { append spec " Italic" }
    append spec " $size"
    return $spec
}

# ================================================================
# Text wrapping: break text to fit within width pixels
# Uses Tk font measurement — must be called with a valid Tk font spec
# ================================================================

proc _wrap_text {text tk_font max_width} {
    # Use Tk font measurement to wrap text at max_width pixels
    # tk_font: original Tk font (named font, list, or string)
    if {[catch {font measure $tk_font "x"} err]} {
        # Can't measure with this font spec — try as list
        if {[catch {font measure [list {*}$tk_font] "x"} err2]} {
            return $text
        }
        set tk_font [list {*}$tk_font]
    }

    set words [split $text " "]
    set lines {}
    set current ""

    foreach word $words {
        set test [expr {$current eq "" ? $word : "$current $word"}]
        if {[font measure $tk_font $test] <= $max_width} {
            set current $test
        } else {
            if {$current ne ""} { lappend lines $current }
            set current $word
        }
    }
    if {$current ne ""} { lappend lines $current }

    return [join $lines "
"]
}

# ================================================================
# BBox overlap check
# Returns 1 if item_bbox is completely outside clip_bbox
# ================================================================

proc _bbox_outside {item_bbox clip_bbox} {
    lassign $item_bbox ix1 iy1 ix2 iy2
    lassign $clip_bbox cx1 cy1 cx2 cy2
    expr {$ix2 < $cx1 || $iy2 < $cy1 || $ix1 > $cx2 || $iy1 > $cy2}
}

# Testable wrapper used in tests
proc _render_item_would_skip {item_bbox clip_bbox} {
    _bbox_outside $item_bbox $clip_bbox
}

# ================================================================
# Anchor conversion: Tk → Cairo
# ================================================================

proc _tk_anchor {anchor} {
    switch [string tolower $anchor] {
        center  -
        c       { return center }
        nw      { return nw }
        n       { return n  }
        ne      { return ne }
        e       { return e  }
        se      { return se }
        s       { return s  }
        sw      { return sw }
        w       { return w  }
        default { return sw }
    }
}

proc _anchor_offset {anchor w h} {
    switch [string tolower $anchor] {
        center  -
        c       { return [list [expr {-$w/2}] [expr {-$h/2}]] }
        nw      { return {0 0} }
        n       { return [list [expr {-$w/2}] 0] }
        ne      { return [list [expr {-$w}]   0] }
        e       { return [list [expr {-$w}]   [expr {-$h/2}]] }
        se      { return [list [expr {-$w}]   [expr {-$h}]] }
        s       { return [list [expr {-$w/2}] [expr {-$h}]] }
        sw      { return [list 0              [expr {-$h}]] }
        w       { return [list 0              [expr {-$h/2}]] }
        default { return {0 0} }
    }
}

# ================================================================
# Dash conversion
# ================================================================

proc _tk_dash {dash} {
    # Tk dash: "-", ".", ",", etc. or list of numbers
    if {[string is list $dash] && [llength $dash] > 0} {
        # Already a list of numbers
        if {[string is double [lindex $dash 0]]} { return $dash }
    }
    # Tk pattern characters
    set result {}
    foreach ch [split $dash {}] {
        switch $ch {
            "-"     { lappend result 8 4 }
            "."     { lappend result 2 4 }
            ","     { lappend result 4 4 }
            default { }
        }
    }
    if {$result eq ""} { return {4 4} }
    return $result
}

# ================================================================
# Line cap/join style conversion
# ================================================================

proc _cap_style {cap} {
    switch [string tolower $cap] {
        projecting  { return square }
        round       { return round  }
        butt        -
        default     { return butt   }
    }
}

proc _join_style {join} {
    switch [string tolower $join] {
        round   { return round }
        bevel   { return bevel }
        miter   -
        default { return miter }
    }
}

# ================================================================
# Safe item option access
# ================================================================

proc _item_opt {canvas id option} {
    if {[catch {$canvas itemcget $id $option} val]} { return "" }
    return $val
}

} ;# namespace eval canvas2cairo

package provide canvas2cairo 0.1
