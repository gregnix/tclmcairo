# tkmcairo -- Cairo 2D graphics for Tcl
# TclOO wrapper around libtkmcairo.so
#
# Usage:
#   package require tkmcairo
#
#   set ctx [tkmcairo::context new 400 300]
#   set ctx [tkmcairo::context new 400 300 -mode vector]
#
#   $ctx clear 0.1 0.2 0.3
#   $ctx rect   10 10 200 100 -fill {1 0.3 0.1} -stroke {1 1 1} -radius 8
#   $ctx circle 200 150 60   -fill {0.2 0.5 1 0.8}
#   $ctx ellipse 100 100 80 40 -stroke {1 1 0}
#   $ctx line   0 0 400 300  -color {0.5 0.5 0.5} -width 2 -dash {8 4}
#   $ctx arc    200 150 50 0 270 -stroke {1 1 1}
#   $ctx poly   10 10 50 50 90 10 -fill {0.8 0.4 0}
#   $ctx path   "M 10 10 L 100 100 C 50 50 80 80 200 200 Z" \
#               -fill {0 0.8 0.4} -stroke {1 1 1}
#   $ctx text   50 50 "Hello World" -font "Sans Bold 18" \
#               -color {1 1 1} -anchor center
#
#   # Gradients
#   $ctx gradient_linear grad1 0 0 400 0 {{0 1 0 0 1} {1 0 0 1 1}}
#   $ctx rect 10 10 380 100 -fillname grad1
#
#   # Font metrics
#   set m [$ctx font_measure "Hello" "Sans Bold 16"]
#   ;# -> {width height ascent descent}
#
#   # Transforms
#   $ctx transform -translate 50 50
#   $ctx transform -rotate 45
#   $ctx transform -scale 2.0 2.0
#   $ctx transform -reset
#
#   # Output
#   $ctx save "output.png"    ;# PNG
#   $ctx save "output.pdf"    ;# PDF (vector if -mode vector)
#   $ctx save "output.svg"    ;# SVG
#   $ctx save "output.eps"    ;# EPS
#
#   # Raw pixel data for Tk photo
#   set data [$ctx todata]    ;# bytearray ARGB32
#
#   $ctx destroy

package provide tkmcairo 0.1

namespace eval ::tkmcairo {
    variable _libloaded 0
    variable _tmdir [file dirname [file normalize [info script]]]

    proc _load {} {
        variable _libloaded
        if {$_libloaded} return

        # Already loaded via manual 'load' command?
        if {[llength [info commands tkmcairo]] > 0} {
            set _libloaded 1
            return
        }

        variable _tmdir

        # Search directories: LIBDIR env > tmdir-relative > cwd-relative
        set dirs [list \
            [file join $_tmdir .. lib] \
            [file join $_tmdir lib] \
            [file join $_tmdir] \
            [file join $_tmdir ..] \
            [pwd] \
            [file join [pwd] lib] \
        ]
        if {[info exists ::env(TKMCAIRO_LIBDIR)]} {
            set dirs [linsert $dirs 0 $::env(TKMCAIRO_LIBDIR)]
        }

        # Always try libtkmcairo.so — this is the canonical name.
        # Tcl rule: libNAME.so → NAME_Init() = Tkmcairo_Init
        # Also try .dylib (macOS) and .dll (Windows).
        # Windows note: gcc/MSYS2 builds WITHOUT lib-prefix → tkmcairo.dll
        #   load tkmcairo.dll → Tkmcairo_Init  (correct)
        #   load libtkmcairo.dll → Libtkmcairo_Init  (wrong, would fail)
        set names [list libtkmcairo.so libtkmcairo.dylib tkmcairo.dll libtkmcairo.dll]

        foreach d $dirs {
            foreach name $names {
                set p [file normalize [file join $d $name]]
                if {[file isfile $p]} {
                    if {[catch {load $p} err] == 0} {
                        set _libloaded 1
                        return
                    }
                }
            }
        }

        # Collect what was found for diagnostics
        set found {}
        foreach d $dirs {
            foreach p [glob -nocomplain -directory $d {libtkmcairo*}] {
                if {[file isfile $p]} { lappend found [file normalize $p] }
            }
        }
        set msg "libtkmcairo.so not found (searched: [join $dirs {, }])"
        if {[llength $found]} {
            append msg "\nFiles found but not loadable: [join $found {, }]"
        }
        append msg "\nSet TKMCAIRO_LIBDIR or run 'make' first"
        error $msg
    }
}

# ================================================================
# tkmcairo::context -- TclOO object
# ================================================================
oo::class create tkmcairo::context {
    variable _id

    constructor {width height args} {
        ::tkmcairo::_load
        set _id [tkmcairo create $width $height {*}$args]
    }

    destructor {
        catch {tkmcairo destroy $_id}
    }

    method destroy {} {
        tkmcairo destroy $_id
        next
    }

    # -- Basic operations --
    method clear   {r g b {a 1.0}}             { tkmcairo clear   $_id $r $g $b $a }
    method size    {}                           { tkmcairo size    $_id }
    method save    {filename}                   { tkmcairo save    $_id $filename }
    method todata  {}                           { tkmcairo todata  $_id }

    # -- Drawing commands --
    method rect    {x y w h args}              { tkmcairo rect    $_id $x $y $w $h {*}$args }
    method line    {x1 y1 x2 y2 args}          { tkmcairo line    $_id $x1 $y1 $x2 $y2 {*}$args }
    method circle  {cx cy r args}              { tkmcairo circle  $_id $cx $cy $r {*}$args }
    method ellipse {cx cy rx ry args}          { tkmcairo ellipse $_id $cx $cy $rx $ry {*}$args }
    method arc     {cx cy r start end args}    { tkmcairo arc     $_id $cx $cy $r $start $end {*}$args }
    method poly    {args}                      { tkmcairo poly    $_id {*}$args }
    method path    {svgdata args}              { tkmcairo path    $_id $svgdata {*}$args }
    method text    {x y string args}           { tkmcairo text    $_id $x $y $string {*}$args }

    # -- Metrics --
    method font_measure {string font}          { tkmcairo font_measure $_id $string $font }

    # -- Transforms --
    method transform {args}                    { tkmcairo transform $_id {*}$args }

    # -- Gradients --
    method gradient_linear {name x1 y1 x2 y2 stops} {
        tkmcairo gradient_linear $_id $name $x1 $y1 $x2 $y2 $stops
    }
    method gradient_radial {name cx cy r stops} {
        tkmcairo gradient_radial $_id $name $cx $cy $r $stops
    }

    # -- Direct access for advanced use --
    method id {} { return $_id }
}

# ================================================================
# Short-form constructor
# ================================================================
proc ::tkmcairo::new {width height args} {
    return [::tkmcairo::context new $width $height {*}$args]
}
