# test-canvas2cairo.tcl
# Tests for canvas2cairo-0.1.tm
#
# Unit tests run headless (no Tk needed).
# Integration tests require Tk — run with wish or tclsh+Tk.
#
# Run: TCLMCAIRO_LIBDIR=.. tclsh8.6 test-canvas2cairo.tcl

package require tcltest 2.2
namespace import ::tcltest::*

set dir [file dirname [file normalize [info script]]]
tcl::tm::path add [file join $dir .. tcl]
set env(TCLMCAIRO_LIBDIR) [file join $dir ..]

# ----------------------------------------------------------------
# Load module — with or without Tk
# ----------------------------------------------------------------
set have_tk 0
if {![catch {package require Tk} err]} {
    set have_tk 1
    wm withdraw .
    update
}

# Load canvas2cairo helpers directly into namespace
# (works even without Tk for pure-Tcl helper tests)
namespace eval ::canvas2cairo {}
source [file join $dir .. tcl canvas2cairo-0.1.tm]

if {!$have_tk} {
    puts "NOTE: Tk not available — integration tests skipped"
}

tcltest::testConstraint hasTk $have_tk

# ----------------------------------------------------------------
# Unit tests: pure Tcl helpers — no Canvas, no Tk
# ----------------------------------------------------------------

test c2c-unit-1.0 {_tk_anchor: center} -body {
    ::canvas2cairo::_tk_anchor center
} -result center

test c2c-unit-1.1 {_tk_anchor: nw} -body {
    ::canvas2cairo::_tk_anchor nw
} -result nw

test c2c-unit-1.2 {_tk_anchor: se} -body {
    ::canvas2cairo::_tk_anchor se
} -result se

test c2c-unit-1.3 {_tk_anchor: unknown defaults to sw} -body {
    ::canvas2cairo::_tk_anchor bogus
} -result sw

test c2c-unit-2.0 {_anchor_offset: center 100x60} -body {
    ::canvas2cairo::_anchor_offset center 100 60
} -result {-50 -30}

test c2c-unit-2.1 {_anchor_offset: nw = 0 0} -body {
    ::canvas2cairo::_anchor_offset nw 100 60
} -result {0 0}

test c2c-unit-2.2 {_anchor_offset: se = -w -h} -body {
    ::canvas2cairo::_anchor_offset se 100 60
} -result {-100 -60}

test c2c-unit-2.3 {_anchor_offset: n = -w/2 0} -body {
    ::canvas2cairo::_anchor_offset n 100 60
} -result {-50 0}

test c2c-unit-3.0 {_tk_dash: numeric list pass-through} -body {
    ::canvas2cairo::_tk_dash {8 4}
} -result {8 4}

test c2c-unit-3.1 {_tk_dash: dash char returns 2 values} -body {
    llength [::canvas2cairo::_tk_dash "-"]
} -result 2

test c2c-unit-3.2 {_tk_dash: dot char returns 2 values} -body {
    llength [::canvas2cairo::_tk_dash "."]
} -result 2

test c2c-unit-3.3 {_tk_dash: empty string} -body {
    set r [::canvas2cairo::_tk_dash ""]
    expr {[llength $r] >= 2}
} -result 1

test c2c-unit-4.0 {_cap_style: butt} -body {
    ::canvas2cairo::_cap_style butt
} -result butt

test c2c-unit-4.1 {_cap_style: projecting -> square} -body {
    ::canvas2cairo::_cap_style projecting
} -result square

test c2c-unit-4.2 {_cap_style: round} -body {
    ::canvas2cairo::_cap_style round
} -result round

test c2c-unit-5.0 {_join_style: miter} -body {
    ::canvas2cairo::_join_style miter
} -result miter

test c2c-unit-5.1 {_join_style: bevel} -body {
    ::canvas2cairo::_join_style bevel
} -result bevel

test c2c-unit-5.2 {_join_style: round} -body {
    ::canvas2cairo::_join_style round
} -result round

test c2c-unit-6.0 {_coords_to_path: two-point line} -body {
    ::canvas2cairo::_coords_to_path {10 20 100 50} {}
} -result "M 10 20 L 100 50"

test c2c-unit-6.1 {_coords_to_path: triangle closed} -body {
    ::canvas2cairo::_coords_to_path {10 10 100 10 55 80} {} closed
} -result "M 10 10 L 100 10 L 55 80 Z"

test c2c-unit-6.2 {_coords_to_path: four points starts with M} -body {
    set p [::canvas2cairo::_coords_to_path {0 0 50 50 100 0 150 50} {}]
    string match "M 0 0 L*" $p
} -result 1

test c2c-unit-6.3 {_coords_to_path: smooth does not crash} -body {
    set p [::canvas2cairo::_coords_to_path {10 50 80 20 150 80} true]
    expr {[string length $p] > 5}
} -result 1

test c2c-unit-7.0 {_tk_font: passthrough single-word} -body {
    ::canvas2cairo::_tk_font "Sans 14"
} -result "Sans 14"

test c2c-unit-7.1 {_tk_font: empty returns default} -body {
    expr {[::canvas2cairo::_tk_font ""] ne ""}
} -result 1

# ----------------------------------------------------------------
# Integration tests — need Tk Canvas
# ----------------------------------------------------------------

proc tmpf {ext} { file join [::tcltest::temporaryDirectory] "c2c[incr ::_tc].$ext" }

test c2c-int-1.0 {export empty canvas SVG} -constraints hasTk -body {
    canvas .t -width 200 -height 150 -background white
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 100}
} -result 1

test c2c-int-1.1 {export → PDF} -constraints hasTk -body {
    canvas .t -width 200 -height 150
    .t create rectangle 10 10 190 140 -fill blue
    set f [tmpf pdf]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-1.2 {export → PS} -constraints hasTk -body {
    canvas .t -width 200 -height 150
    .t create line 0 0 200 150 -fill red -width 3
    set f [tmpf ps]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 100}
} -result 1

test c2c-int-1.3 {export → EPS} -constraints hasTk -body {
    canvas .t -width 200 -height 150
    .t create oval 50 50 150 100 -fill green
    set f [tmpf eps]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 100}
} -result 1

test c2c-int-1.4 {export uses canvas -width/-height not winfo} -constraints hasTk -body {
    # wm withdraw means winfo returns 1 — must use cget
    canvas .t -width 400 -height 300
    .t create rectangle 0 0 400 300 -fill "#112233"
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    set svg [read [open $f r]]
    string match "*width=\"400*" $svg
} -result 1

test c2c-int-2.0 {render rectangle fill+outline} -constraints hasTk -body {
    canvas .t -width 300 -height 200
    .t create rectangle 20 20 280 180 -fill "#336699" -outline white -width 2
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.1 {render oval circle} -constraints hasTk -body {
    canvas .t -width 200 -height 200
    .t create oval 10 10 190 190 -fill blue -outline yellow -width 3
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.2 {render line with dash} -constraints hasTk -body {
    canvas .t -width 300 -height 100
    .t create line 10 50 290 50 -fill red -width 3 -dash {8 4}
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.3 {render polygon} -constraints hasTk -body {
    canvas .t -width 200 -height 200
    .t create polygon 100 10 190 190 10 190 -fill orange -outline black
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.4 {render text} -constraints hasTk -body {
    canvas .t -width 300 -height 100
    .t create text 150 50 -text "Hello" -font {Sans 16} \
        -fill navy -anchor center
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.5 {render arc pieslice} -constraints hasTk -body {
    canvas .t -width 200 -height 200
    .t create arc 10 10 190 190 -start 0 -extent 270 \
        -style pieslice -fill purple -outline white -width 2
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.6 {render arc chord} -constraints hasTk -body {
    canvas .t -width 200 -height 200
    .t create arc 10 10 190 190 -start 30 -extent 200 \
        -style chord -fill teal -outline white -width 2
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.7 {render arc open} -constraints hasTk -body {
    canvas .t -width 200 -height 200
    .t create arc 10 10 190 190 -start 45 -extent 270 \
        -style arc -outline red -width 4
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.8 {render line with arrow} -constraints hasTk -body {
    canvas .t -width 300 -height 100
    .t create line 20 50 280 50 -fill blue -width 2 -arrow last
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.9 {render smooth polyline} -constraints hasTk -body {
    canvas .t -width 300 -height 200
    .t create line 10 100 80 20 150 180 220 20 290 100 \
        -fill green -width 3 -smooth true
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-3.0 {hidden items are skipped} -constraints hasTk -body {
    canvas .t -width 200 -height 200
    .t create rectangle 10 10 190 190 -fill red -state hidden
    .t create oval 50 50 150 150 -fill blue
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 100}
} -result 1

test c2c-int-4.0 {render into existing context} -constraints hasTk -body {
    canvas .t -width 300 -height 200
    .t create rectangle 20 20 280 180 -fill "#336699"
    .t create text 150 100 -text "Embedded" -font {Sans 14} \
        -fill white -anchor center
    set f [tmpf pdf]
    set ctx [tclmcairo::new 300 200 -mode pdf -file $f]
    canvas2cairo::render .t $ctx
    $ctx finish; $ctx destroy; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-4.1 {two canvas side by side on one PDF} -constraints hasTk -body {
    canvas .t1 -width 200 -height 150
    canvas .t2 -width 200 -height 150
    .t1 create rectangle 10 10 190 140 -fill red
    .t2 create oval      10 10 190 140 -fill blue
    set f [tmpf pdf]
    set ctx [tclmcairo::new 420 160 -mode pdf -file $f]
    canvas2cairo::render .t1 $ctx
    $ctx push
    $ctx transform -translate 210 0
    canvas2cairo::render .t2 $ctx
    $ctx pop
    $ctx finish; $ctx destroy
    destroy .t1; destroy .t2
    expr {[file size $f] > 200}
} -result 1

cleanupTests
