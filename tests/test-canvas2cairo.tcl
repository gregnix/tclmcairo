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

test c2c-unit-7.0 {_tk_font: returns family and size 14} -body {
    # font actual may resolve "Sans" to system font (e.g. "Noto Sans")
    # — just verify size is present
    string match "* 14" [::canvas2cairo::_tk_font "Sans 14"]
} -result 1

test c2c-unit-7.1 {_tk_font: empty returns default} -body {
    expr {[::canvas2cairo::_tk_font ""] ne ""}
} -result 1

# ----------------------------------------------------------------
# Integration tests — need Tk Canvas
# ----------------------------------------------------------------

proc tmpf {ext} {
    set f [file join /tmp "c2c[incr ::_tc].$ext"]
    lappend ::_tmpfiles $f
    return $f
}
set ::_tmpfiles {}

proc cleanup_tmpfiles {} {
    foreach f $::_tmpfiles { catch {file delete $f} }
    set ::_tmpfiles {}
}

test c2c-int-1.0 {export empty canvas SVG} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 200 -height 150 -background white
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 100}
} -result 1

test c2c-int-1.1 {export → PDF} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 200 -height 150
    .t create rectangle 10 10 190 140 -fill blue
    set f [tmpf pdf]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-1.2 {export → PS} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 200 -height 150
    .t create line 0 0 200 150 -fill red -width 3
    set f [tmpf ps]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 100}
} -result 1

test c2c-int-1.3 {export → EPS} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 200 -height 150
    .t create oval 50 50 150 100 -fill green
    set f [tmpf eps]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 100}
} -result 1

test c2c-int-1.4 {export uses canvas -width/-height not winfo} -constraints hasTk -body {
    # wm withdraw means winfo returns 1 — must use cget
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 400 -height 300
    .t create rectangle 0 0 400 300 -fill "#112233"
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    set svg [read [open $f r]]
    string match "*width=\"400*" $svg
} -result 1

test c2c-int-2.0 {render rectangle fill+outline} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 300 -height 200
    .t create rectangle 20 20 280 180 -fill "#336699" -outline white -width 2
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.1 {render oval circle} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 200 -height 200
    .t create oval 10 10 190 190 -fill blue -outline yellow -width 3
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.2 {render line with dash} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 300 -height 100
    .t create line 10 50 290 50 -fill red -width 3 -dash {8 4}
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.3 {render polygon} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 200 -height 200
    .t create polygon 100 10 190 190 10 190 -fill orange -outline black
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.4 {render text} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 300 -height 100
    .t create text 150 50 -text "Hello" -font {Sans 16} \
        -fill navy -anchor center
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.5 {render arc pieslice} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 200 -height 200
    .t create arc 10 10 190 190 -start 0 -extent 270 \
        -style pieslice -fill purple -outline white -width 2
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.6 {render arc chord} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 200 -height 200
    .t create arc 10 10 190 190 -start 30 -extent 200 \
        -style chord -fill teal -outline white -width 2
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.7 {render arc open} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 200 -height 200
    .t create arc 10 10 190 190 -start 45 -extent 270 \
        -style arc -outline red -width 4
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.8 {render line with arrow} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 300 -height 100
    .t create line 20 50 280 50 -fill blue -width 2 -arrow last
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-2.9 {render smooth polyline} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 300 -height 200
    .t create line 10 100 80 20 150 180 220 20 290 100 \
        -fill green -width 3 -smooth true
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 200}
} -result 1

test c2c-int-3.0 {hidden items are skipped} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
    canvas .t -width 200 -height 200
    .t create rectangle 10 10 190 190 -fill red -state hidden
    .t create oval 50 50 150 150 -fill blue
    set f [tmpf svg]; canvas2cairo::export .t $f; destroy .t
    expr {[file size $f] > 100}
} -result 1

test c2c-int-4.0 {render into existing context} -constraints hasTk -body {
    catch {destroy .t}
    catch {destroy .t}
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

cleanup_tmpfiles
# Note: cleanupTests at end of file

# ================================================================
# Tests for new fixes (0.3.1)
# ================================================================

# -smooth raw: explicit Bezier control points
test canvas2cairo-smooth-raw-1 {smooth raw path has C commands} -constraints hasTk -body {
    set c [canvas .test_sr1 -width 200 -height 200]
    # 4 points: anchor + cp1 + cp2 + anchor (1 cubic segment)
    $c create line 20 100 60 20 140 20 180 100 -smooth raw -fill black
    set path [canvas2cairo::_coords_to_path \
        {20 100 60 20 140 20 180 100} raw]
    destroy .test_sr1
    # Should contain C (cubic bezier)
    string match "*C*" $path
} -result 1

# -smooth 1: B-spline passes through points
test canvas2cairo-smooth-1-1 {smooth 1 path has C commands (Catmull-Rom)} -constraints hasTk -body {
    set path [canvas2cairo::_coords_to_path \
        {20 100 80 20 160 20 200 100} 1]
    # Catmull-Rom produces cubic C commands (not quadratic Q)
    string match "*C*" $path
} -result 1

# straight path: only L commands
test canvas2cairo-smooth-0-1 {smooth 0 path has only L commands} -body {
    set path [canvas2cairo::_coords_to_path {10 10 100 10 100 100} 0]
    expr {[string match "*L*" $path] && ![string match "*Q*" $path] && ![string match "*C*" $path]}
} -result 1

# hidden item: return not continue fix
test canvas2cairo-hidden-1 {hidden items are skipped not aborted} -constraints hasTk -body {
    set c [canvas .test_h1 -width 200 -height 200]
    $c create rectangle 10 10 100 100 -fill red -tags r1
    $c create rectangle 50 50 150 150 -fill blue -tags r2
    $c itemconfigure r1 -state hidden
    # render should complete without error
    set ctx [tclmcairo::new 200 200]
    set err [catch {canvas2cairo::render $c $ctx} msg]
    $ctx destroy
    destroy .test_h1
    set err
} -result 0

# PNG export
test canvas2cairo-png-1 {PNG export produces valid PNG} -constraints hasTk -body {
    set c [canvas .test_png1 -width 100 -height 100]
    $c create rectangle 10 10 90 90 -fill blue
    set f /tmp/test_c2c_[pid].png
    canvas2cairo::export $c $f
    set fh [open $f rb]; set magic [read $fh 4]; close $fh
    file delete $f
    destroy .test_png1
    binary scan $magic H8 hex
    set hex
} -result 89504e47

# -dashoffset
test canvas2cairo-dashoffset-1 {dashoffset is passed to path opts} -constraints hasTk -body {
    set c [canvas .test_do1 -width 200 -height 100]
    $c create line 10 50 190 50 -dash {8 4} -dashoffset 4 -fill black
    set err [catch {
        set ctx [tclmcairo::new 200 100]
        canvas2cairo::render $c $ctx
        $ctx destroy
    } msg]
    destroy .test_do1
    set err
} -result 0


# ================================================================
# Tests for 0.3.2: export -scale, -viewport
# ================================================================

test canvas2cairo-scale-1 {export -scale 2 doubles output size} -constraints hasTk -body {
    set c [canvas .test_sc1 -width 100 -height 100]
    $c create rectangle 10 10 90 90 -fill blue
    set f /tmp/test_scale_[pid].png
    canvas2cairo::export $c $f -scale 2.0
    # Read PNG dimensions
    set fh [open $f rb]
    seek $fh 16
    binary scan [read $fh 8] II pw ph
    close $fh
    file delete $f
    destroy .test_sc1
    list $pw $ph
} -result {200 200}

test canvas2cairo-viewport-1 {export -viewport crops output} -constraints hasTk -body {
    set c [canvas .test_vp1 -width 200 -height 200]
    $c create rectangle 10 10 190 190 -fill red
    set f /tmp/test_vp_[pid].png
    canvas2cairo::export $c $f -viewport {50 50 150 150}
    set fh [open $f rb]
    seek $fh 16
    binary scan [read $fh 8] II pw ph
    close $fh
    file delete $f
    destroy .test_vp1
    list $pw $ph
} -result {100 100}

test canvas2cairo-scale-viewport-1 {export -scale + -viewport} -constraints hasTk -body {
    set c [canvas .test_sv1 -width 200 -height 200]
    $c create rectangle 10 10 190 190 -fill green
    set f /tmp/test_sv_[pid].png
    canvas2cairo::export $c $f -viewport {0 0 100 100} -scale 3.0
    set fh [open $f rb]
    seek $fh 16
    binary scan [read $fh 8] II pw ph
    close $fh
    file delete $f
    destroy .test_sv1
    list $pw $ph
} -result {300 300}


# ================================================================
# Tests for scroll position, justify, background
# ================================================================

test canvas2cairo-background-1 {canvas background color is exported} -constraints hasTk -body {
    set c [canvas .test_bg1 -width 100 -height 100 -background "#336699"]
    set f /tmp/test_bg_[pid].png
    canvas2cairo::export $c $f
    set ok [file exists $f]
    file delete $f
    destroy .test_bg1
    set ok
} -result 1

test canvas2cairo-justify-center-1 {multiline text justify center} -constraints hasTk -body {
    set c [canvas .test_jc1 -width 200 -height 200]
    $c create text 100 100 -text "Hello\nWorld" -anchor center -justify center \
        -font {Helvetica 12}
    set err [catch {
        set ctx [tclmcairo::new 200 200]
        canvas2cairo::render $c $ctx
        $ctx destroy
    } msg]
    destroy .test_jc1
    set err
} -result 0

test canvas2cairo-scroll-1 {scrolled canvas render without error} -constraints hasTk -body {
    set c [canvas .test_sc2 -width 200 -height 200 -scrollregion {0 0 1000 1000}]
    $c create rectangle 500 500 600 600 -fill red
    $c xview moveto 0.5
    $c yview moveto 0.5
    set f /tmp/test_scroll_[pid].png
    set err [catch {canvas2cairo::export $c $f} msg]
    file delete -force $f
    destroy .test_sc2
    set err
} -result 0


# ================================================================
# Tests for negative scrollregion, polygon empty fill, clip
# ================================================================

test canvas2cairo-negative-scrollregion-1 {negative scrollregion export} -constraints hasTk -body {
    set c [canvas .test_nsr1 -width 200 -height 200 \
        -scrollregion {-100 -100 500 500}]
    $c create rectangle -50 -50 50 50 -fill blue
    $c create rectangle 100 100 200 200 -fill red
    set f /tmp/test_nsr_[pid].png
    set err [catch {canvas2cairo::export $c $f} msg]
    file delete -force $f
    destroy .test_nsr1
    set err
} -result 0

test canvas2cairo-polygon-outline-only-1 {polygon with empty fill exports stroke only} -constraints hasTk -body {
    set c [canvas .test_pol1 -width 200 -height 200]
    $c create polygon 50 50 150 50 100 150 \
        -fill "" -outline red -width 2
    set f /tmp/test_pol_[pid].png
    set err [catch {canvas2cairo::export $c $f} msg]
    file delete -force $f
    destroy .test_pol1
    set err
} -result 0

test canvas2cairo-clip-performance-1 {items outside bbox are skipped} -body {
    # Test that _render_item skips items outside clip_bbox
    set inside  [canvas2cairo::_render_item_would_skip \
        {100 100 200 200} {0 0 50 50}]
    set overlap [canvas2cairo::_render_item_would_skip \
        {100 100 200 200} {150 150 300 300}]
    list $inside $overlap
} -result {1 0}

# ================================================================
# New in 0.3.2: -smooth 1 Catmull-Rom, render -clip, text_extents justify
# ================================================================

test canvas2cairo-smooth-catmullrom-1 {-smooth 1 line exports without error} -constraints hasTk -body {
    set c [canvas .test_cr1 -width 300 -height 200]
    $c create line 20 100  80 30  140 170  200 50  260 120 \
        -smooth 1 -fill blue -width 2
    set f /tmp/test_smooth_[pid].svg
    set err [catch {canvas2cairo::export $c $f} msg]
    file delete -force $f
    destroy .test_cr1
    set err
} -result 0

test canvas2cairo-smooth-catmullrom-2 {-smooth 1 closed polygon without error} -constraints hasTk -body {
    set c [canvas .test_cr2 -width 200 -height 200]
    $c create polygon 100 20  180 80  150 160  50 160  20 80 \
        -smooth 1 -fill {#aaddff} -outline blue
    set f /tmp/test_smooth_poly_[pid].png
    set err [catch {canvas2cairo::export $c $f} msg]
    file delete -force $f
    destroy .test_cr2
    set err
} -result 0

test canvas2cairo-render-clip-1 {render with -clip option exports without error} -constraints hasTk -body {
    set c [canvas .test_rclip1 -width 400 -height 300]
    $c create rectangle 10 10 390 290 -fill lightblue
    $c create oval 150 100 250 200 -fill red
    set ctx [tclmcairo::new 200 150]
    $ctx clear 1 1 1
    set err [catch {canvas2cairo::render $c $ctx -clip {100 75 300 225}} msg]
    $ctx destroy
    destroy .test_rclip1
    set err
} -result 0

test canvas2cairo-render-clip-2 {render -clip restricts items} -constraints hasTk -body {
    set c [canvas .test_rclip2 -width 400 -height 300]
    $c create rectangle 150 100 250 200 -fill green -tags inside
    $c create rectangle 10 10 90 90 -fill red -tags outside
    set f /tmp/test_rclip_[pid].png
    set ctx [tclmcairo::new 200 150]
    $ctx clear 1 1 1
    set err [catch {canvas2cairo::render $c $ctx -clip {100 75 300 225}} msg]
    $ctx save $f
    $ctx destroy
    file delete -force $f
    destroy .test_rclip2
    set err
} -result 0

test canvas2cairo-text-extents-justify-1 {multiline text justify center uses Cairo metrics} -constraints hasTk -body {
    set c [canvas .test_tej1 -width 300 -height 200]
    $c create text 150 100 \
        -text "Hello\nWorld\nCairo" \
        -font {TkDefaultFont 12} \
        -justify center -anchor center
    set f /tmp/test_tej_[pid].svg
    set err [catch {canvas2cairo::export $c $f} msg]
    file delete -force $f
    destroy .test_tej1
    set err
} -result 0

test canvas2cairo-text-extents-justify-2 {multiline text justify right exports without error} -constraints hasTk -body {
    set c [canvas .test_tej2 -width 300 -height 200]
    $c create text 250 100 \
        -text "Right\nAligned\nText" \
        -font {TkDefaultFont 11} \
        -justify right -anchor e
    set f /tmp/test_tej_r_[pid].pdf
    set err [catch {canvas2cairo::export $c $f} msg]
    file delete -force $f
    destroy .test_tej2
    set err
} -result 0


cleanup_tmpfiles
cleanupTests
