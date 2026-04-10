# canvas2cairo-0.1.tm
# Export a Tk Canvas to SVG (or any tclmcairo output format)
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

proc export {canvas filename args} {
    # Prefer configured -width/-height over winfo (works before window is shown)
    set w [$canvas cget -width]
    set h [$canvas cget -height]

    # winfo width/height is more accurate after rendering, but may return 1
    # if window was never shown — use it only if larger
    set ww [winfo width  $canvas]
    set wh [winfo height $canvas]
    if {$ww > 1} { set w $ww }
    if {$wh > 1} { set h $wh }

    # Honour scrollregion if set
    set sr [$canvas cget -scrollregion]
    if {$sr ne ""} {
        set sw [expr {int([lindex $sr 2] - [lindex $sr 0])}]
        set sh [expr {int([lindex $sr 3] - [lindex $sr 1])}]
        if {$sw > 0} { set w $sw }
        if {$sh > 0} { set h $sh }
    }

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

    if {$mode eq "png"} {
        # PNG: raster context, use save not finish
        set ctx [tclmcairo::new $w $h]
        $ctx clear 1 1 1
        render $canvas $ctx
        $ctx save $filename
        $ctx destroy
        return
    }

    set ctx [tclmcairo::new $w $h -mode $mode -file $filename]
    render $canvas $ctx
    $ctx finish
    $ctx destroy
}

proc render {canvas ctx} {
    # Background
    set bg [$canvas cget -background]
    if {$bg ne "" && $bg ne "white"} {
        set c [_tk_color $canvas $bg]
        $ctx clear {*}$c
    } else {
        $ctx clear 1 1 1
    }

    # Render all items in Z-order (bottom to top)
    foreach id [$canvas find all] {
        _render_item $canvas $ctx $id
    }
}

# ================================================================
# Item rendering dispatch
# ================================================================

proc _render_item {canvas ctx id} {
    # Skip hidden items
    if {[catch {set state [$canvas itemcget $id -state]}] == 0} {
        if {$state eq "hidden"} return
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
        _draw_arrows $ctx $coords $arrow $col $lw
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
            $ctx text $x $ly $line {*}$opts
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
    if {$smooth eq "" || $smooth eq "0" || $smooth eq "false"} {
        # Straight lines
        set path "M [lindex $coords 0] [lindex $coords 1]"
        foreach {x y} [lrange $coords 2 end] {
            append path " L $x $y"
        }
        if {$closed ne ""} { append path " Z" }
    } else {
        # Bezier smooth: Tk uses cubic spline through points
        # Approximate with Cairo curve_to between midpoints
        set n [expr {[llength $coords] / 2}]
        if {$n < 2} {
            return "M [lindex $coords 0] [lindex $coords 1]"
        }

        # Extract points
        set pts {}
        foreach {x y} $coords { lappend pts [list $x $y] }

        # Start at first point
        set path "M [lindex [lindex $pts 0] 0] [lindex [lindex $pts 0] 1]"

        for {set i 1} {$i < $n} {incr i} {
            set p0 [lindex $pts [expr {$i-1}]]
            set p1 [lindex $pts $i]
            # Control points: tangent at midpoint
            set mx [expr {([lindex $p0 0] + [lindex $p1 0]) / 2.0}]
            set my [expr {([lindex $p0 1] + [lindex $p1 1]) / 2.0}]
            append path " Q [lindex $p0 0] [lindex $p0 1] $mx $my"
        }
        set last [lindex $pts end]
        append path " L [lindex $last 0] [lindex $last 1]"
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

proc _draw_arrows {ctx coords arrow col lw} {
    set aw [expr {$lw * 3 + 6}]   ;# arrow width
    set al [expr {$lw * 4 + 8}]   ;# arrow length


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
