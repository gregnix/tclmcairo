# test-svg2cairo.tcl
# Tests for svg2cairo-0.1.tm
#
# Run: TCLMCAIRO_LIBDIR=.. tclsh8.6 test-svg2cairo.tcl

package require tcltest 2.2
namespace import ::tcltest::*

set dir [file dirname [file normalize [info script]]]

# Put OUR copy of svg2cairo (and the rest of tcl/) at the FRONT of the
# tm-path list. We can't fully reset the path because tdom etc. need to
# stay reachable. tcl::tm::path add appends at the front but is a no-op
# if the path is already in the list — so we use the lower-level remove
# + add to guarantee priority.
set _tcldir [file join $dir .. tcl]
catch {tcl::tm::path remove $_tcldir}
tcl::tm::path add $_tcldir

# Also forget any previously cached package-ifneeded for svg2cairo,
# in case a system install registered one already.
catch {package forget svg2cairo}

set env(TCLMCAIRO_LIBDIR) [file join $dir ..]

# tdom is the hard requirement for svg2cairo.
if {[catch {package require tdom} err]} {
    puts "NOTE: tdom not available — svg2cairo tests skipped"
    puts "test-svg2cairo.tcl:\tTotal\t0\tPassed\t0\tSkipped\t0\tFailed\t0"
    exit 0
}

package require tclmcairo
package require svg2cairo

# ----------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------

proc tmpfile {ext} {
    set base [expr {
        [info exists ::env(TEMP)] ? $::env(TEMP) :
        [info exists ::env(TMPDIR)] ? $::env(TMPDIR) : "/tmp"
    }]
    return [file join $base "tcst_[pid]_[clock microseconds].$ext"]
}

proc cleanup {f} { catch {file delete -force $f} }

# Write a small SVG to disk and return the path
proc svg_with_size {w h} {
    set f [tmpfile svg]
    set fh [open $f w]
    puts $fh "<?xml version=\"1.0\"?>"
    puts $fh "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$w\" height=\"$h\">"
    puts $fh "  <rect x=\"0\" y=\"0\" width=\"$w\" height=\"$h\" fill=\"red\"/>"
    puts $fh "</svg>"
    close $fh
    return $f
}

proc svg_with_viewbox {vbW vbH} {
    set f [tmpfile svg]
    set fh [open $f w]
    puts $fh "<?xml version=\"1.0\"?>"
    puts $fh "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 $vbW $vbH\">"
    puts $fh "  <rect x=\"0\" y=\"0\" width=\"$vbW\" height=\"$vbH\" fill=\"blue\"/>"
    puts $fh "</svg>"
    close $fh
    return $f
}

# ================================================================
# size — read SVG dimensions from a file
# ================================================================

test svg2cairo-size-1.0 {size returns w h for explicit width/height} -body {
    set f [svg_with_size 200 150]
    set sz [svg2cairo::size $f]
    cleanup $f
    set sz
} -result {200 150}

test svg2cairo-size-1.1 {size falls back to viewBox when no width/height} -body {
    set f [svg_with_viewbox 320 240]
    set sz [svg2cairo::size $f]
    cleanup $f
    set sz
} -result {320 240}

test svg2cairo-size-1.2 {size returns 0 0 for non-existent file} -body {
    svg2cairo::size /no/such/file.svg
} -result {0 0}

test svg2cairo-size-1.3 {size returns w h pair} -body {
    set f [svg_with_size 64 32]
    set sz [svg2cairo::size $f]
    cleanup $f
    expr {[llength $sz] == 2}
} -result 1

# ================================================================
# size_data — same as size but for a string
# ================================================================

test svg2cairo-size_data-1.0 {size_data returns w h for explicit width/height} -body {
    set svg "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"42\" height=\"17\"><rect x=\"0\" y=\"0\" width=\"42\" height=\"17\" fill=\"red\"/></svg>"
    svg2cairo::size_data $svg
} -result {42 17}

test svg2cairo-size_data-1.1 {size_data via viewBox} -body {
    set svg "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 200\"></svg>"
    svg2cairo::size_data $svg
} -result {100 200}

test svg2cairo-size_data-1.2 {size_data with garbage falls back} -body {
    set svg "not actually svg"
    set sz [svg2cairo::size_data $svg]
    expr {[llength $sz] == 2}
} -result 1

# ================================================================
# sizeForFit — clamp scale to avoid degenerate fits
# ================================================================

test svg2cairo-fit-1.0 {sizeForFit returns 3-element list} -body {
    set f [svg_with_size 100 100]
    set r [svg2cairo::sizeForFit $f 200 200]
    cleanup $f
    expr {[llength $r] == 3}
} -result 1

test svg2cairo-fit-1.1 {sizeForFit clamps small SVG to -max} -body {
    # 10x10 SVG into 1000x1000 box -> scale would be 100x, clamped to 2.0
    set f [svg_with_size 10 10]
    lassign [svg2cairo::sizeForFit $f 1000 1000] tw th s
    cleanup $f
    list $tw $th $s
} -result {20 20 2.0}

test svg2cairo-fit-1.2 {sizeForFit clamps huge SVG to -min} -body {
    # 1000x1000 SVG into 10x10 box -> scale would be 0.01, clamped to 0.5
    set f [svg_with_size 1000 1000]
    lassign [svg2cairo::sizeForFit $f 10 10] tw th s
    cleanup $f
    list $tw $th $s
} -result {500 500 0.5}

test svg2cairo-fit-1.3 {sizeForFit fits when scale within range} -body {
    # 100x100 into 150x150 -> 1.5x scale, no clamping
    set f [svg_with_size 100 100]
    lassign [svg2cairo::sizeForFit $f 150 150] tw th s
    cleanup $f
    list $tw $th [format %.2f $s]
} -result {150 150 1.50}

test svg2cairo-fit-1.4 {sizeForFit -min/-max overrides defaults} -body {
    set f [svg_with_size 10 10]
    lassign [svg2cairo::sizeForFit $f 1000 1000 -max 5.0] tw th s
    cleanup $f
    list $tw $th $s
} -result {50 50 5.0}

test svg2cairo-fit-1.5 {sizeForFit chooses min(scaleX, scaleY)} -body {
    # 100x100 SVG into 200x50 box -> scaleX=2, scaleY=0.5, picks 0.5
    set f [svg_with_size 100 100]
    lassign [svg2cairo::sizeForFit $f 200 50] tw th s
    cleanup $f
    list $tw $th $s
} -result {50 50 0.5}

test svg2cairo-fit-1.6 {sizeForFit on missing file falls back to 100x100} -body {
    # File missing -> size returns {0 0} -> falls back to 100x100.
    # 100x100 into 50x50 -> scale = min(50/100,50/100) = 0.5 (= -min)
    # -> targets = 100*0.5 = 50, 50
    lassign [svg2cairo::sizeForFit /no/such/file.svg 50 50] tw th s
    list $tw $th $s
} -result {50 50 0.5}

# ================================================================
# has_text helper (existing)
# ================================================================

test svg2cairo-has_text-1.0 {has_text true if SVG contains <text>} -body {
    set f [tmpfile svg]
    set fh [open $f w]
    puts $fh "<svg xmlns=\"http://www.w3.org/2000/svg\"><text x=\"0\" y=\"10\">Hi</text></svg>"
    close $fh
    set r [svg2cairo::has_text $f]
    cleanup $f
    set r
} -result 1

test svg2cairo-has_text-1.1 {has_text false on shapes-only SVG} -body {
    set f [svg_with_size 50 50]
    set r [svg2cairo::has_text $f]
    cleanup $f
    set r
} -result 0

cleanupTests
