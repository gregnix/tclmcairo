# shape_renderer-0.1.tm
# Cairo-based shape renderer for diagram nodes
# Returns PNG bytes for embedding in Tk Canvas as photo images
#
# Shapes: generic, router, switch, server, firewall, cloud,
#         database (cylinder), table (DB entity), workstation
#
# Usage:
#   package require shape_renderer
#   set bytes [shape_renderer::render router 64 64]
#   set img   [image create photo -data $bytes -format png]
#   .c create image $x $y -image $img -anchor nw
#
# Part of tclmcairo — https://github.com/gregnix/tclmcairo
# License: BSD

package require tclmcairo

namespace eval ::shape_renderer {
    # Cache: key = "type:w:h:color" -> PNG bytes
    variable cache
    array set cache {}
}

# ================================================================
# Public API
# ================================================================

# render type w h ?-color {r g b}? ?-label str? ?-zoom z?
# Returns PNG bytearray
proc ::shape_renderer::render {type w h args} {
    variable cache

    set color  {0.3 0.5 0.8}
    set label  ""
    set zoom   1.0

    foreach {k v} $args {
        switch $k {
            -color { set color $v }
            -label { set label $v }
            -zoom  { set zoom  $v }
        }
    }

    set pw [expr {max(1, int($w * $zoom))}]
    set ph [expr {max(1, int($h * $zoom))}]
    set key "$type:$pw:$ph:[join $color -]"

    if {[info exists cache($key)]} {
        return $cache($key)
    }

    set bytes [_render_shape $type $pw $ph $color $label $zoom]
    set cache($key) $bytes
    return $bytes
}

# render_to_file type w h file ?-color {r g b}? ?-zoom z?
# Saves directly via $ctx save — avoids topng + binary write issues
proc ::shape_renderer::render_to_file {type w h file args} {
    set color {0.3 0.5 0.8}
    set zoom  1.0
    foreach {k v} $args {
        switch $k {
            -color { set color $v }
            -zoom  { set zoom  $v }
        }
    }
    set pw [expr {max(1, int($w * $zoom))}]
    set ph [expr {max(1, int($h * $zoom))}]
    set ctx [tclmcairo::new $pw $ph]
    _render_shape_ctx $type $pw $ph $color "" $zoom $ctx
    $ctx save $file
    $ctx destroy
}

# Internal: render into existing context
proc ::shape_renderer::_render_shape_ctx {type w h color label zoom ctx} {
    switch $type {
        router      { _shape_router      $ctx $w $h $color $zoom }
        switch      { _shape_switch      $ctx $w $h $color $zoom }
        server      { _shape_server      $ctx $w $h $color $zoom }
        firewall    { _shape_firewall    $ctx $w $h $color $zoom }
        cloud       { _shape_cloud       $ctx $w $h $color $zoom }
        database    { _shape_database    $ctx $w $h $color $zoom }
        workstation { _shape_workstation $ctx $w $h $color $zoom }
        table       { _shape_table       $ctx $w $h $color $zoom }
        printer     { _shape_printer     $ctx $w $h $color $zoom }
        scanner     { _shape_scanner     $ctx $w $h $color $zoom }
        accesspoint { _shape_accesspoint $ctx $w $h $color $zoom }
        phone       { _shape_phone       $ctx $w $h $color $zoom }
        wifi        { _shape_wifi        $ctx $w $h $color $zoom }
        fiber       { _shape_fiber       $ctx $w $h $color $zoom }
        building    { _shape_building    $ctx $w $h $color $zoom }
        default     { _shape_generic     $ctx $w $h $color $zoom }
    }
    if {$label ne ""} { _draw_label $ctx $w $h $label $zoom }
}

# Clear cache (e.g. after zoom change)
proc ::shape_renderer::clear_cache {} {
    variable cache
    unset -nocomplain cache
    array set cache {}
}

# ================================================================
# Shape dispatcher
# ================================================================

proc ::shape_renderer::_render_shape {type w h color label zoom} {
    set ctx [tclmcairo::new $w $h]
    _render_shape_ctx $type $w $h $color $label $zoom $ctx
    set bytes [$ctx topng]
    $ctx destroy
    return $bytes
}

# ================================================================
# Helpers
# ================================================================

proc ::shape_renderer::_darker {color {factor 0.6}} {
    lassign $color r g b
    list [expr {$r * $factor}] [expr {$g * $factor}] [expr {$b * $factor}]
}

proc ::shape_renderer::_lighter {color {factor 1.4}} {
    lassign $color r g b
    list [expr {min(1.0,$r*$factor)}] \
         [expr {min(1.0,$g*$factor)}] \
         [expr {min(1.0,$b*$factor)}]
}

proc ::shape_renderer::_draw_label {ctx w h label zoom} {
    set size [expr {max(8, int(11 * $zoom))}]
    set font "Sans $size"
    set maxw [expr {$w - 6*$zoom}]

    # Measure text — truncate if too wide
    if {[catch {
        set ext [$ctx text_extents [$ctx id] $label -font $font]
        set tw [dict get $ext width]
        if {$tw > $maxw && [string length $label] > 4} {
            # Truncate with ellipsis
            set l $label
            while {$tw > $maxw && [string length $l] > 3} {
                set l [string range $l 0 end-1]
                set ext [$ctx text_extents [$ctx id] "${l}…" -font $font]
                set tw [dict get $ext width]
            }
            set label "${l}…"
        }
    }]} {
        # text_extents not available — use label as-is
    }
    $ctx text [expr {$w/2.0}] [expr {$h - 4*$zoom}] $label \
        -font $font -color {0.1 0.1 0.1} -anchor s
}

# ================================================================
# Router — circle with arrows
# ================================================================
proc ::shape_renderer::_shape_router {ctx w h color zoom} {
    set cx [expr {$w/2.0}]; set cy [expr {$h/2.0}]
    set r  [expr {min($w,$h)/2.0 - 4*$zoom}]
    set lw [expr {max(1.5, $zoom * 1.5)}]

    # Gradient background
    $ctx gradient_radial bg $cx $cy [expr {$r*0.6}] \
        [list [list 0 {*}[_lighter $color] 1] \
              [list 1 {*}$color 1]]
    $ctx circle $cx $cy $r -fillname bg \
        -stroke [_darker $color] -width $lw

    # Arrow cross (routing symbol)
    set a [expr {$r * 0.55}]
    set al [expr {$r * 0.25}]
    set hw [expr {$r * 0.12}]
    set col {1 1 1}

    # Cross lines
    $ctx line [expr {$cx-$a}] $cy [expr {$cx+$a}] $cy \
        -color $col -width $lw -linecap round
    $ctx line $cx [expr {$cy-$a}] $cx [expr {$cy+$a}] \
        -color $col -width $lw -linecap round
    # Arrowhead triangles at ends
    set as [expr {$a*0.25}]
    set aw [expr {$a*0.15}]
    foreach {tx ty dx dy} [list \
        [expr {$cx+$a}] $cy       1 0 \
        [expr {$cx-$a}] $cy      -1 0 \
        $cx [expr {$cy+$a}]       0 1 \
        $cx [expr {$cy-$a}]       0 -1] {
        set px [expr {$tx - $dx*$as}]
        set py [expr {$ty - $dy*$as}]
        set nx [expr {-$dy}]; set ny [expr {$dx}]
        $ctx poly $tx $ty \
            [expr {$px+$nx*$aw}] [expr {$py+$ny*$aw}] \
            [expr {$px-$nx*$aw}] [expr {$py-$ny*$aw}] \
            -fill $col
    }
}

# ================================================================
# Switch — rounded rect with ports
# ================================================================
proc ::shape_renderer::_shape_switch {ctx w h color zoom} {
    set m  [expr {4*$zoom}]
    set lw [expr {max(1.5, $zoom * 1.5)}]
    set r  [expr {6*$zoom}]

    $ctx gradient_linear bg $m $m $m [expr {$h-$m}] \
        [list [list 0 {*}[_lighter $color] 1] \
              [list 1 {*}$color 1]]
    $ctx rect $m $m [expr {$w-2*$m}] [expr {$h-2*$m}] \
        -fillname bg -stroke [_darker $color] -width $lw -radius $r

    # Port dots
    set np 4
    set py [expr {$h/2.0}]
    set spacing [expr {($w - 4*$m) / ($np + 1.0)}]
    for {set i 1} {$i <= $np} {incr i} {
        set px [expr {2*$m + $i * $spacing}]
        $ctx circle $px $py [expr {3*$zoom}] -fill {1 1 1 0.9}
        # Port line up/down
        $ctx line $px [expr {$py-8*$zoom}] $px [expr {$py-3*$zoom}] \
            -color {1 1 1 0.8} -width [expr {max(1,$zoom)}]
    }
}

# ================================================================
# Server — 3D box effect
# ================================================================
proc ::shape_renderer::_shape_server {ctx w h color zoom} {
    set m   [expr {4*$zoom}]
    set lw  [expr {max(1.5, $zoom*1.5)}]
    set top [expr {8*$zoom}]    ;# 3D top height
    set sid [expr {6*$zoom}]    ;# 3D side width

    # Front face
    $ctx gradient_linear bg $m [expr {$m+$top}] $m [expr {$h-$m}] \
        [list [list 0 {*}[_lighter $color] 1] \
              [list 1 {*}$color 1]]
    $ctx rect $m [expr {$m+$top}] [expr {$w-$m-$sid}] [expr {$h-$m-$top}] \
        -fillname bg -stroke [_darker $color] -width $lw

    # Top face
    $ctx poly $m [expr {$m+$top}] \
               [expr {$m+$sid}] $m \
               [expr {$w-$m}] $m \
               [expr {$w-$m-$sid}] [expr {$m+$top}] \
        -fill [_lighter $color 1.6] -stroke [_darker $color] -width $lw

    # Right face
    $ctx poly [expr {$w-$m-$sid}] [expr {$m+$top}] \
               [expr {$w-$m}] $m \
               [expr {$w-$m}] [expr {$h-$m-$top}] \
               [expr {$w-$m-$sid}] [expr {$h-$m}] \
        -fill [_darker $color 0.75] -stroke [_darker $color] -width $lw

    # LED lights
    for {set i 0} {$i < 3} {incr i} {
        set lx [expr {$m + 8*$zoom + $i * 10*$zoom}]
        set ly [expr {$m + $top + 8*$zoom}]
        set lcol [expr {$i == 0 ? {0.2 0.9 0.2} : {0.2 0.5 0.9}}]
        $ctx circle $lx $ly [expr {2.5*$zoom}] -fill $lcol
    }
}

# ================================================================
# Firewall — brick/shield shape
# ================================================================
proc ::shape_renderer::_shape_firewall {ctx w h color zoom} {
    set m  [expr {4*$zoom}]
    set lw [expr {max(1.5, $zoom*1.5)}]

    # Shield shape via path
    set cx [expr {$w/2.0}]
    set r  [expr {min($w,$h)/2.0 - $m}]

    # Gradient: red/orange for firewall
    set fc {0.85 0.25 0.1}
    $ctx gradient_linear bg $cx $m $cx [expr {$h-$m}] \
        [list [list 0 0.95 0.5 0.1 1] \
              [list 1 0.7  0.1 0.0 1]]

    # Shield path (pentagon-like)
    set pts [list \
        [expr {$cx}]       [expr {$m}] \
        [expr {$w-$m}]     [expr {$m + $r*0.4}] \
        [expr {$w-$m}]     [expr {$m + $r*0.9}] \
        [expr {$cx}]       [expr {$h-$m}] \
        [expr {$m}]        [expr {$m + $r*0.9}] \
        [expr {$m}]        [expr {$m + $r*0.4}] \
    ]
    $ctx poly {*}$pts -fillname bg -stroke {0.5 0.1 0.0} -width $lw

    # Flame lines
    set fy [expr {$h*0.45}]
    foreach {dx col} {
        -0.2 {1.0 0.9 0.1 0.9}
         0.0 {1.0 0.7 0.0 0.9}
         0.2 {1.0 0.9 0.1 0.9}
    } {
        set fx [expr {$cx + $dx*$r}]
        $ctx path "M $fx $fy C [expr {$fx-8*$zoom}] [expr {$fy-15*$zoom}] \
            [expr {$fx+8*$zoom}] [expr {$fy-25*$zoom}] \
            $fx [expr {$fy-30*$zoom}]" \
            -stroke $col -width [expr {2.5*$zoom}] -linecap round
    }
}

# ================================================================
# Cloud — Bezier blob
# ================================================================
proc ::shape_renderer::_shape_cloud {ctx w h color zoom} {
    set cx [expr {$w/2.0}]; set cy [expr {$h/2.0}]
    set rx [expr {$w/2.0 - 4*$zoom}]
    set ry [expr {$h/2.0 - 8*$zoom}]
    set lw [expr {max(1.5, $zoom*1.5)}]

    $ctx gradient_linear bg 0 0 $w $h \
        [list [list 0 0.85 0.92 1.0 1] \
              [list 1 0.65 0.78 0.95 1]]

    # Cloud via multiple overlapping circles
    set bumps {
        {0.0  0.1  0.38}
        {0.3 -0.15 0.30}
        {0.6 -0.1  0.32}
        {-0.3 -0.1 0.28}
        {-0.55 0.1 0.25}
        {0.0  0.2  0.42}
    }
    foreach b $bumps {
        lassign $b bx by br
        $ctx circle \
            [expr {$cx + $bx*$rx}] \
            [expr {$cy + $by*$ry}] \
            [expr {$br*min($w,$h)}] \
            -fillname bg
    }
    # Outline the whole cloud area
    $ctx circle $cx [expr {$cy+0.1*$ry}] [expr {0.42*min($w,$h)}] \
        -stroke [_darker {0.65 0.78 0.95} 0.8] -width $lw
}

# ================================================================
# Database — cylinder
# ================================================================
proc ::shape_renderer::_shape_database {ctx w h color zoom} {
    set m   [expr {4*$zoom}]
    set lw  [expr {max(1.5, $zoom*1.5)}]
    set ew  [expr {($w-2*$m)/2.0}]   ;# ellipse x radius
    set eh  [expr {8*$zoom}]           ;# ellipse y radius
    set cx  [expr {$w/2.0}]
    set top [expr {$m + $eh}]
    set bot [expr {$h - $m - $eh}]

    $ctx gradient_linear bg $m $top $m $bot \
        [list [list 0 {*}[_lighter $color] 1] \
              [list 1 {*}$color 1]]

    # Body rectangle
    $ctx rect $m $top [expr {$w-2*$m}] [expr {$bot-$top}] \
        -fillname bg
    # Side strokes
    $ctx line $m $top $m $bot -color [_darker $color] -width $lw
    $ctx line [expr {$w-$m}] $top [expr {$w-$m}] $bot \
        -color [_darker $color] -width $lw

    # Bottom ellipse
    $ctx ellipse $cx $bot $ew $eh \
        -fill $color -stroke [_darker $color] -width $lw

    # Top ellipse (highlight)
    $ctx ellipse $cx $top $ew $eh \
        -fill [_lighter $color 1.5] -stroke [_darker $color] -width $lw

    # Horizontal lines (data layers) — ellipse arcs via path
    foreach dy {0.3 0.55} {
        set y [expr {$top + ($bot-$top)*$dy}]
        # Top half of ellipse as SVG arc path
        set x1 [expr {$cx - $ew}]
        set x2 [expr {$cx + $ew}]
        $ctx path "M $x1 $y A $ew $eh 0 0 1 $x2 $y" \
            -stroke [_darker $color] -width [expr {max(1,$zoom)}]
    }
}

# ================================================================
# Workstation — monitor + base
# ================================================================
proc ::shape_renderer::_shape_workstation {ctx w h color zoom} {
    set m   [expr {4*$zoom}]
    set lw  [expr {max(1.5, $zoom*1.5)}]
    set mh  [expr {$h * 0.62}]   ;# monitor height
    set bw  [expr {$w * 0.25}]   ;# base width
    set bh  [expr {$h * 0.12}]   ;# base height
    set cx  [expr {$w/2.0}]

    # Monitor
    $ctx gradient_linear bg $m $m $m $mh \
        [list [list 0 {*}[_lighter $color 1.3] 1] \
              [list 1 {*}$color 1]]
    $ctx rect $m $m [expr {$w-2*$m}] [expr {$mh-$m}] \
        -fillname bg -stroke [_darker $color] -width $lw -radius [expr {3*$zoom}]

    # Screen (inner)
    set sp [expr {5*$zoom}]
    $ctx rect [expr {$m+$sp}] [expr {$m+$sp}] \
        [expr {$w-2*$m-2*$sp}] [expr {$mh-$m-2*$sp}] \
        -fill {0.05 0.1 0.2} \
        -radius [expr {2*$zoom}]

    # Screen glow (alpha via separate clear rect)
    $ctx rect [expr {$m+$sp+2*$zoom}] [expr {$m+$sp+2*$zoom}] \
        [expr {$w-2*$m-2*$sp-4*$zoom}] [expr {($mh-$m-2*$sp-4*$zoom)*0.4}] \
        -fill {0.2 0.4 0.7 0.4}

    # Stand neck
    $ctx line $cx $mh $cx [expr {$h-$m-$bh}] \
        -color [_darker $color] -width [expr {4*$zoom}] -linecap round

    # Base
    $ctx rect [expr {$cx-$bw}] [expr {$h-$m-$bh}] \
        [expr {2*$bw}] $bh \
        -fill [_darker $color 0.85] -stroke [_darker $color] \
        -width $lw -radius [expr {2*$zoom}]
}

# ================================================================
# DB Table (Entity) — header + columns
# ================================================================
proc ::shape_renderer::_shape_table {ctx w h color args} {
    # color is the header color
    set lw 1.5
    set hr [expr {$h * 0.28}]   ;# header height ratio

    # Header
    $ctx gradient_linear bg 0 0 0 $hr \
        [list [list 0 {*}[_lighter $color] 1] \
              [list 1 {*}$color 1]]
    $ctx rect 0 0 $w $hr -fillname bg

    # Body
    $ctx rect 0 $hr $w [expr {$h-$hr}] \
        -fill {0.98 0.98 0.98}

    # Border
    $ctx rect 1 1 [expr {$w-2}] [expr {$h-2}] \
        -stroke [_darker $color] -width 1.5

    # Header line
    $ctx line 0 $hr $w $hr -color [_darker $color] -width 1.5

    # Column separators (visual hint)
    foreach y {0.52 0.67 0.82} {
        set ly [expr {$h * $y}]
        $ctx line 2 $ly [expr {$w-2}] $ly \
            -color {0.85 0.85 0.85} -width 1
    }

    # Key icon in header
    $ctx circle [expr {$w*0.12}] [expr {$hr*0.5}] [expr {$hr*0.25}] \
        -stroke {1 1 1} -width 1.5 -fill {1 1 1 0.2}
    $ctx line [expr {$w*0.18}] [expr {$hr*0.5}] \
               [expr {$w*0.28}] [expr {$hr*0.5}] \
        -color {1 1 1 0.8} -width 1.5
}

# ================================================================
# Generic — rounded rect with gradient
# ================================================================
proc ::shape_renderer::_shape_generic {ctx w h color zoom} {
    set m  [expr {3*$zoom}]
    set lw [expr {max(1.5, $zoom*1.5)}]
    set r  [expr {6*$zoom}]

    $ctx gradient_linear bg $m $m $m [expr {$h-$m}] \
        [list [list 0 {*}[_lighter $color] 1] \
              [list 1 {*}$color 1]]
    $ctx rect $m $m [expr {$w-2*$m}] [expr {$h-2*$m}] \
        -fillname bg -stroke [_darker $color] -width $lw -radius $r
}

package provide shape_renderer 0.1

# ================================================================
# Printer — box with paper tray and output slot
# ================================================================
proc ::shape_renderer::_shape_printer {ctx w h color zoom} {
    set m  [expr {4*$zoom}]
    set lw [expr {max(1.5, $zoom*1.5)}]
    set bh [expr {$h * 0.55}]   ;# body height
    set ty [expr {$m + $h*0.08}] ;# top paper tray y
    set th [expr {$h * 0.18}]   ;# tray height

    # Paper tray (top input)
    $ctx gradient_linear tray $m $ty $m [expr {$ty+$th}] \
        [list [list 0 {*}[_lighter $color 1.6] 1] \
              [list 1 {*}[_lighter $color 1.2] 1]]
    $ctx rect [expr {$w*0.2}] $ty [expr {$w*0.6}] $th \
        -fillname tray -stroke [_darker $color] -width $lw \
        -radius [expr {2*$zoom}]
    # Paper sheets in tray
    for {set i 0} {$i < 3} {incr i} {
        set py [expr {$ty + 3*$zoom + $i*2*$zoom}]
        $ctx line [expr {$w*0.22}] $py [expr {$w*0.78}] $py \
            -color {1 1 1 0.8} -width [expr {max(0.5,$zoom*0.5)}]
    }

    # Main body
    set by [expr {$ty + $th - 2*$zoom}]
    $ctx gradient_linear bg $m $by $m [expr {$by+$bh}] \
        [list [list 0 {*}[_lighter $color] 1] \
              [list 1 {*}$color 1]]
    $ctx rect $m $by [expr {$w-2*$m}] $bh \
        -fillname bg -stroke [_darker $color] -width $lw \
        -radius [expr {4*$zoom}]

    # Output slot
    set oy [expr {$by + $bh*0.45}]
    $ctx rect [expr {$m+4*$zoom}] $oy [expr {$w-4*$m}] [expr {4*$zoom}] \
        -fill [_darker $color 0.5] -radius [expr {1*$zoom}]

    # Output paper
    $ctx rect [expr {$w*0.2}] [expr {$oy - 2*$zoom}] \
        [expr {$w*0.6}] [expr {$bh*0.3}] \
        -fill {1 1 1 0.95} -stroke [_darker $color 0.7] \
        -width [expr {max(0.5,$zoom*0.5)}]

    # Control LEDs
    foreach {lx lcol} [list \
        [expr {$w-$m-12*$zoom}] {0.2 0.9 0.2} \
        [expr {$w-$m-22*$zoom}] {0.9 0.5 0.1}] {
        $ctx circle $lx [expr {$by + 8*$zoom}] [expr {2.5*$zoom}] \
            -fill $lcol
    }
}

# ================================================================
# Scanner — flat bed with scanning light
# ================================================================
proc ::shape_renderer::_shape_scanner {ctx w h color zoom} {
    set m  [expr {4*$zoom}]
    set lw [expr {max(1.5, $zoom*1.5)}]
    set bh [expr {$h * 0.45}]   ;# body height
    set by [expr {$h * 0.3}]    ;# body y (flat, lower half)

    # Lid (top, slightly open)
    $ctx gradient_linear lid $m $m $m [expr {$by*0.9}] \
        [list [list 0 {*}[_lighter $color 1.5] 1] \
              [list 1 {*}[_lighter $color 1.1] 1]]
    $ctx rect $m $m [expr {$w-2*$m}] [expr {$by*0.85}] \
        -fillname lid -stroke [_darker $color] -width $lw \
        -radius [expr {3*$zoom}]

    # Glass surface (inside lid bottom)
    $ctx rect [expr {$m+4*$zoom}] [expr {$by*0.5}] \
        [expr {$w-4*$m}] [expr {$by*0.3}] \
        -fill {0.85 0.92 1.0 0.8}

    # Body base
    $ctx gradient_linear base $m $by $m [expr {$by+$bh}] \
        [list [list 0 {*}$color 1] \
              [list 1 {*}[_darker $color] 1]]
    $ctx rect $m $by [expr {$w-2*$m}] $bh \
        -fillname base -stroke [_darker $color] -width $lw \
        -radius [expr {3*$zoom}]

    # Scan line (light beam)
    set sx [expr {$w * 0.35}]
    $ctx gradient_linear beam $sx $by $sx [expr {$by+$bh*0.6}] \
        [list [list 0 0.4 0.8 1.0 0.9] \
              [list 1 0.4 0.8 1.0 0.0]]
    $ctx rect $sx [expr {$by+2*$zoom}] [expr {3*$zoom}] [expr {$bh*0.6}] \
        -fillname beam

    # Button row
    foreach {bx bcol} [list \
        [expr {$m+8*$zoom}]  {0.2 0.7 0.2} \
        [expr {$m+18*$zoom}] {0.2 0.4 0.9} \
        [expr {$m+28*$zoom}] {0.9 0.5 0.1}] {
        $ctx rect $bx [expr {$by+$bh*0.7}] [expr {7*$zoom}] [expr {5*$zoom}] \
            -fill $bcol -radius [expr {1.5*$zoom}]
    }
}

# ================================================================
# Access Point — dome with signal rings
# ================================================================
proc ::shape_renderer::_shape_accesspoint {ctx w h color zoom} {
    set cx [expr {$w/2.0}]
    set lw [expr {max(1.5, $zoom*1.5)}]

    # Signal arcs (background, wide)
    lassign [_lighter $color 1.4] ar ag ab
    foreach {r alpha} {0.45 0.15  0.35 0.25  0.25 0.4} {
        set rad [expr {min($w,$h) * $r}]
        $ctx arc $cx [expr {$h*0.62}] $rad 200 140 \
            -stroke [list $ar $ag $ab $alpha] \
            -width [expr {$lw * 2.5}]
    }

    # Dome body
    set dw [expr {$w * 0.55}]
    set dh [expr {$h * 0.35}]
    set dy [expr {$h * 0.38}]
    $ctx gradient_radial dome $cx [expr {$dy+$dh*0.3}] [expr {$dw*0.4}] \
        [list [list 0 {*}[_lighter $color 1.6] 1] \
              [list 1 {*}$color 1]]
    $ctx ellipse $cx [expr {$dy+$dh/2.0}] [expr {$dw/2.0}] [expr {$dh/2.0}] \
        -fillname dome -stroke [_darker $color] -width $lw

    # Base plate
    $ctx rect [expr {$cx - $dw*0.4}] [expr {$dy+$dh*0.85}] \
        [expr {$dw*0.8}] [expr {$h*0.08}] \
        -fill [_darker $color 0.8] \
        -radius [expr {2*$zoom}]

    # Signal dot (active LED)
    $ctx circle $cx [expr {$dy + $dh*0.45}] [expr {3*$zoom}] \
        -fill {0.2 1.0 0.4 0.9}
}

# ================================================================
# Phone — handset shape via path
# ================================================================
proc ::shape_renderer::_shape_phone {ctx w h color zoom} {
    set cx [expr {$w/2.0}]
    set cy [expr {$h/2.0}]
    set lw [expr {max(2.0, $zoom*2.0)}]
    set s  [expr {min($w,$h) * 0.38}]

    $ctx gradient_linear bg $cx [expr {$cy-$s}] $cx [expr {$cy+$s}] \
        [list [list 0 {*}[_lighter $color] 1] \
              [list 1 {*}$color 1]]

    # Handset as thick bezier path
    set x1 [expr {$cx - $s*0.55}]
    set y1 [expr {$cy - $s*0.85}]
    set x2 [expr {$cx + $s*0.55}]
    set y2 [expr {$cy + $s*0.85}]

    # Earpiece
    $ctx circle [expr {$cx - $s*0.25}] [expr {$cy - $s*0.6}] \
        [expr {$s*0.32}] -fillname bg -stroke [_darker $color] -width $lw

    # Mouthpiece
    $ctx circle [expr {$cx + $s*0.25}] [expr {$cy + $s*0.6}] \
        [expr {$s*0.32}] -fillname bg -stroke [_darker $color] -width $lw

    # Handle connecting them
    $ctx path "M [expr {$cx-$s*0.42}] [expr {$cy-$s*0.35}] \
        C [expr {$cx-$s*0.8}] [expr {$cy+$s*0.0}] \
          [expr {$cx+$s*0.8}] [expr {$cy+$s*0.0}] \
          [expr {$cx+$s*0.42}] [expr {$cy+$s*0.35}]" \
        -stroke [_darker $color] -width [expr {$lw*2.5}]
    $ctx path "M [expr {$cx-$s*0.42}] [expr {$cy-$s*0.35}] \
        C [expr {$cx-$s*0.8}] [expr {$cy+$s*0.0}] \
          [expr {$cx+$s*0.8}] [expr {$cy+$s*0.0}] \
          [expr {$cx+$s*0.42}] [expr {$cy+$s*0.35}]" \
        -stroke [_lighter $color 1.4] -width [expr {$lw*1.2}]
}

# ================================================================
# WiFi — concentric arcs (WiFi symbol)
# ================================================================
proc ::shape_renderer::_shape_wifi {ctx w h color zoom} {
    set cx  [expr {$w/2.0}]
    set cy  [expr {$h*0.62}]
    set lw  [expr {max(2.5, $zoom*2.5)}]
    lassign $color cr cg cb

    # Three arcs, decreasing size
    foreach {r alpha} {
        0.42 1.0
        0.28 0.85
        0.14 0.7
    } {
        set rad [expr {min($w,$h) * $r}]
        $ctx arc $cx $cy $rad 210 120 \
            -stroke [list $cr $cg $cb $alpha] -width $lw
    }

    # Center dot
    $ctx circle $cx $cy [expr {4*$zoom}] -fill $col
}

# ================================================================
# Fiber — bundle of light-carrying fibers
# ================================================================
proc ::shape_renderer::_shape_fiber {ctx w h color zoom} {
    set cx  [expr {$w/2.0}]
    set lw  [expr {max(1.5, $zoom*1.5)}]
    set m   [expr {8*$zoom}]

    # Cable sheath (outer)
    $ctx gradient_linear sheath $m [expr {$h*0.4}] \
        [expr {$w-$m}] [expr {$h*0.6}] \
        [list [list 0 {*}[_darker $color 0.7] 1] \
              [list 1 {*}$color 1]]
    $ctx rect $m [expr {$h*0.38}] [expr {$w-2*$m}] [expr {$h*0.24}] \
        -fillname sheath -stroke [_darker $color] -width $lw \
        -radius [expr {5*$zoom}]

    # Individual fiber strands with glow
    set fibers {
        {0.25 {0.3 0.7 1.0}}
        {0.38 {0.2 0.9 0.5}}
        {0.50 {1.0 0.9 0.2}}
        {0.62 {1.0 0.4 0.2}}
        {0.75 {0.8 0.3 1.0}}
    }
    foreach fib $fibers {
        lassign $fib fx fcol
        set x [expr {$m + ($w-2*$m)*$fx}]
        # Glow
        $ctx line $x [expr {$h*0.39}] $x [expr {$h*0.61}] \
            -color [list {*}$fcol 0.3] -width [expr {4*$zoom}]
        # Core
        $ctx line $x [expr {$h*0.39}] $x [expr {$h*0.61}] \
            -color [list {*}$fcol 1.0] -width [expr {max(1,$zoom)}]
    }

    # Connector ends
    foreach ex [list $m [expr {$w-$m}]] {
        $ctx rect [expr {$ex - 4*$zoom}] [expr {$h*0.33}] \
            [expr {8*$zoom}] [expr {$h*0.34}] \
            -fill [_darker $color 0.6] -stroke [_darker $color] -width $lw \
            -radius [expr {2*$zoom}]
    }
}

# ================================================================
# Building — outline with roof and windows
# ================================================================
proc ::shape_renderer::_shape_building {ctx w h color zoom} {
    set m  [expr {4*$zoom}]
    set lw [expr {max(1.5, $zoom*1.5)}]
    set rh [expr {$h * 0.2}]    ;# roof height
    set bh [expr {$h * 0.68}]   ;# body height
    set by [expr {$m + $rh}]    ;# body y

    # Roof (triangle)
    set cx [expr {$w/2.0}]
    $ctx poly $cx $m \
               [expr {$w-$m}] [expr {$m+$rh}] \
               $m             [expr {$m+$rh}] \
        -fill [_darker $color 0.85] \
        -stroke [_darker $color] -width $lw

    # Body
    $ctx gradient_linear body $m $by $m [expr {$by+$bh}] \
        [list [list 0 {*}[_lighter $color 1.2] 1] \
              [list 1 {*}$color 1]]
    $ctx rect $m $by [expr {$w-2*$m}] $bh \
        -fillname body -stroke [_darker $color] -width $lw

    # Windows (2 rows x 3 cols)
    set ww [expr {($w-2*$m) / 4.5}]
    set wh [expr {$bh / 5.5}]
    for {set row 0} {$row < 2} {incr row} {
        for {set col 0} {$col < 3} {incr col} {
            set wx [expr {$m + ($col+0.4) * ($w-2*$m)/3.5}]
            set wy [expr {$by + ($row+0.3) * $bh/3.0}]
            $ctx rect $wx $wy $ww $wh \
                -fill {0.85 0.92 1.0 0.9} \
                -stroke [_darker $color 0.7] \
                -width [expr {max(0.5,$zoom*0.5)}]
        }
    }

    # Door
    set dw [expr {$ww * 0.9}]
    set dh [expr {$bh * 0.28}]
    $ctx rect [expr {$cx - $dw/2.0}] [expr {$by + $bh - $dh}] \
        $dw $dh \
        -fill [_darker $color 0.6] \
        -stroke [_darker $color] -width $lw \
        -radius [expr {$dw*0.15}]
}
