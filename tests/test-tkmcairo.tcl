#!/usr/bin/env tclsh8.6
# tests/test-tkmcairo.tcl -- tkmcairo Tests
#
# Run: make test
# or:  TKMCAIRO_LIBDIR=. tclsh tests/test-tkmcairo.tcl

# Add tcl/ directory to module search path
# Works for both Tcl 8.6 and 9.0
set _tmdir [file normalize [file join [file dirname [info script]] ../tcl]]
if {$_tmdir ni [tcl::tm::path list]} {
    tcl::tm::path add $_tmdir
}
unset _tmdir

package require tcltest 2.2
namespace import tcltest::*

package require tkmcairo

# ================================================================
# Setup
# ================================================================
set W 200
set H 150

proc mkctx  {}      { return [tkmcairo::new $::W $::H] }
proc mkvctx {}      { return [tkmcairo::new $::W $::H -mode vector] }
proc tmpfile {ext}  { return [file join /tmp "tkmcairo_test.[pid].$ext"] }
proc cleanup {f}    { catch {file delete $f} }

# ================================================================
# Basic
# ================================================================
test create-1.0 {create context} -body {
    set ctx [mkctx]
    set ok [expr {$ctx ne ""}]
    $ctx destroy; set ok
} -result 1

test create-1.1 {correct size} -body {
    set ctx [mkctx]
    set s [$ctx size]
    $ctx destroy; set s
} -result {200 150}

test create-1.2 {vector mode} -body {
    set ctx [mkvctx]
    set ok [expr {$ctx ne ""}]
    $ctx destroy; set ok
} -result 1

test create-1.3 {multiple contexts} -body {
    set a [mkctx]; set b [mkctx]; set c [mkctx]
    set ok [expr {$a ne $b && $b ne $c}]
    $a destroy; $b destroy; $c destroy; set ok
} -result 1

test destroy-1.0 {destroy no error} -body {
    set ctx [mkctx]
    $ctx destroy; set ok 1
} -result 1

# ================================================================
# clear + todata
# ================================================================
test clear-1.0 {clear no error} -body {
    set ctx [mkctx]
    $ctx clear 0.1 0.2 0.3
    $ctx destroy; set ok 1
} -result 1

test todata-1.0 {todata returns bytes} -body {
    set ctx [mkctx]
    $ctx clear 1 0 0
    set d [$ctx todata]
    set ok [expr {[string length $d] == $::W * $::H * 4}]
    $ctx destroy; set ok
} -result 1

test todata-1.1 {red color in pixel data} -body {
    set ctx [mkctx]
    $ctx clear 1.0 0.0 0.0
    set d [$ctx todata]
    # ARGB32: byte 0=B, 1=G, 2=R, 3=A (little-endian BGRA)
    binary scan $d "cccc" b g r a
    # R>0 G=0 B=0
    set ok [expr {($r & 0xFF) > 0 && ($g & 0xFF) == 0 && ($b & 0xFF) == 0}]
    $ctx destroy; set ok
} -result 1

# ================================================================
# PNG export
# ================================================================
test save-png-1.0 {save PNG} -body {
    set f [tmpfile png]
    set ctx [mkctx]
    $ctx clear 0.1 0.1 0.2
    $ctx rect 10 10 100 50 -fill {1 0.5 0} -stroke {1 1 1} -width 2
    $ctx save $f
    set ok [expr {[file exists $f] && [file size $f] > 100}]
    $ctx destroy; cleanup $f; set ok
} -result 1

test save-png-1.1 {PNG vector mode} -body {
    set f [tmpfile png]
    set ctx [mkvctx]
    $ctx clear 0 0.2 0
    $ctx circle 100 75 50 -fill {1 1 0}
    $ctx save $f
    set ok [expr {[file exists $f] && [file size $f] > 100}]
    $ctx destroy; cleanup $f; set ok
} -result 1

# ================================================================
# PDF/SVG export
# ================================================================
test save-pdf-1.0 {save PDF} -body {
    set f [tmpfile pdf]
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx text 20 80 "Hello PDF" -font "Sans Bold 24" -color {0 0 0}
    $ctx save $f
    set ok [expr {[file exists $f] && [file size $f] > 100}]
    $ctx destroy; cleanup $f; set ok
} -result 1

test save-svg-1.0 {save SVG} -body {
    set f [tmpfile svg]
    set ctx [mkvctx]
    $ctx clear 1 1 1
    $ctx rect 10 10 180 130 -fill {0.8 0.9 1}
    $ctx save $f
    set ok [expr {[file exists $f] && [file size $f] > 50}]
    $ctx destroy; cleanup $f; set ok
} -result 1

test save-eps-1.0 {save EPS} -body {
    set f [tmpfile eps]
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx circle 100 75 60 -fill {0.5 0 0.8}
    $ctx save $f
    set ok [expr {[file exists $f] && [file size $f] > 50}]
    $ctx destroy; cleanup $f; set ok
} -result 1

# ================================================================
# Drawing commands
# ================================================================
test rect-1.0 {rect no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx rect 10 10 100 60 -fill {1 0 0}
    $ctx destroy; set ok 1
} -result 1

test rect-1.1 {rect with radius} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx rect 10 10 100 60 -fill {0 1 0} -radius 10
    $ctx destroy; set ok 1
} -result 1

test rect-1.2 {rect fill + stroke} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx rect 10 10 100 60 -fill {0 0 1} -stroke {1 1 1} -width 3
    $ctx destroy; set ok 1
} -result 1

test circle-1.0 {circle no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx circle 100 75 50 -fill {1 1 0}
    $ctx destroy; set ok 1
} -result 1

test ellipse-1.0 {ellipse no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx ellipse 100 75 80 40 -fill {0 1 1} -stroke {1 0 0}
    $ctx destroy; set ok 1
} -result 1

test line-1.0 {line no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx line 0 0 200 150 -color {1 1 1} -width 2
    $ctx destroy; set ok 1
} -result 1

test line-1.1 {line with dash} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx line 0 75 200 75 -color {1 0 0} -width 2 -dash {8 4}
    $ctx destroy; set ok 1
} -result 1

test arc-1.0 {arc no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx arc 100 75 60 0 270 -stroke {1 1 0} -width 3
    $ctx destroy; set ok 1
} -result 1

test poly-1.0 {polygon no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx poly 10 10 100 10 100 100 10 100 -fill {0.8 0.4 0}
    $ctx destroy; set ok 1
} -result 1

test text-1.0 {text no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx text 20 100 "Test" -font "Sans 14" -color {1 1 1}
    $ctx destroy; set ok 1
} -result 1

test text-1.1 {text bold italic} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx text 20 100 "Bold Italic" -font "Sans Bold Italic 16" -color {1 1 0}
    $ctx destroy; set ok 1
} -result 1

test text-1.2 {text anchor center} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx text 100 75 "Mitte" -font "Sans 14" -color {1 1 1} -anchor center
    $ctx destroy; set ok 1
} -result 1

# ================================================================
# SVG paths
# ================================================================
test path-1.0 {M L Z} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx path "M 10 10 L 100 10 L 100 100 Z" -fill {0.5 0.8 0.2}
    $ctx destroy; set ok 1
} -result 1

test path-1.1 {cubic Bezier C} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx path "M 10 75 C 50 10 150 10 190 75" -stroke {1 0.5 0} -width 3
    $ctx destroy; set ok 1
} -result 1

test path-1.2 {quadratic Bezier Q} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx path "M 10 75 Q 100 10 190 75" -stroke {0 1 0.5} -width 2
    $ctx destroy; set ok 1
} -result 1

test path-1.3 {H V relative commands} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx path "M 10 10 H 190 V 140 H 10 Z" -fill {0.2 0.2 0.8}
    $ctx destroy; set ok 1
} -result 1

test path-1.4 {complex SVG path} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx path "M 50 10 L 90 90 L 10 40 L 90 40 L 10 90 Z" \
        -fill {1 0.8 0} -stroke {0 0 0} -width 1
    $ctx destroy; set ok 1
} -result 1

# ================================================================
# Font metrics
# ================================================================
test font_measure-1.0 {returns 4 values} -body {
    set ctx [mkctx]
    set m [$ctx font_measure "Hello World" "Sans 14"]
    set ok [expr {[llength $m] == 4}]
    $ctx destroy; set ok
} -result 1

test font_measure-1.1 {width > 0} -body {
    set ctx [mkctx]
    set m [$ctx font_measure "Hello" "Sans 14"]
    set ok [expr {[lindex $m 0] > 0}]
    $ctx destroy; set ok
} -result 1

test font_measure-1.2 {Bold wider than Normal} -body {
    set ctx [mkctx]
    set wn [lindex [$ctx font_measure "Hello" "Sans 14"] 0]
    set wb [lindex [$ctx font_measure "Hello" "Sans Bold 14"] 0]
    $ctx destroy
    expr {$wb >= $wn}
} -result 1

test font_measure-1.3 {larger font = larger height} -body {
    set ctx [mkctx]
    set h1 [lindex [$ctx font_measure "X" "Sans 12"] 1]
    set h2 [lindex [$ctx font_measure "X" "Sans 24"] 1]
    $ctx destroy
    expr {$h2 > $h1}
} -result 1

# ================================================================
# Transforms
# ================================================================
test transform-1.0 {translate no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx transform -translate 50 50
    $ctx rect 0 0 50 50 -fill {1 0 0}
    $ctx transform -reset
    $ctx destroy; set ok 1
} -result 1

test transform-1.1 {rotate no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx transform -rotate 45
    $ctx rect 50 50 80 30 -fill {0 1 0}
    $ctx transform -reset
    $ctx destroy; set ok 1
} -result 1

test transform-1.2 {scale no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx transform -scale 2.0 2.0
    $ctx circle 50 37 20 -fill {0 0 1}
    $ctx transform -reset
    $ctx destroy; set ok 1
} -result 1

# ================================================================
# Gradients
# ================================================================
test gradient-1.0 {gradient_linear no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx gradient_linear grad1 0 0 200 0 \
        {{0 1 0 0 1} {0.5 1 1 0 1} {1 0 0 1 1}}
    $ctx rect 10 10 180 130 -fillname grad1
    $ctx destroy; set ok 1
} -result 1

test gradient-1.1 {gradient_radial no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx gradient_radial grad2 100 75 80 \
        {{0 1 1 0 1} {0.5 0.5 0 0.5 0.8} {1 0 0 0.2 0}}
    $ctx circle 100 75 80 -fillname grad2
    $ctx destroy; set ok 1
} -result 1

test gradient-1.2 {replace gradient no error} -body {
    set ctx [mkctx]; $ctx clear 0 0 0
    $ctx gradient_linear g1 0 0 200 0 {{0 1 0 0 1} {1 0 1 0 1}}
    $ctx gradient_linear g1 0 0 200 0 {{0 0 1 0 1} {1 0 0 1 1}}
    $ctx rect 0 0 200 150 -fillname g1
    $ctx destroy; set ok 1
} -result 1

# ================================================================
# Combined: demo PNG
# ================================================================
test combined-1.0 {combined demo PNG} -body {
    set f [tmpfile png]
    set ctx [tkmcairo::new 400 300 -mode vector]
    $ctx clear 0.08 0.10 0.18

    # Background gradient
    $ctx gradient_linear bg 0 0 400 0 \
        {{0 0.08 0.10 0.25 1} {1 0.15 0.10 0.30 1}}
    $ctx rect 0 0 400 300 -fillname bg

    # Title
    $ctx text 200 50 "tkmcairo v0.1" \
        -font "Sans Bold 28" -color {1 1 1} -anchor center

    # Shapes
    $ctx circle  80  150 50 -fill {1 0.5 0 0.8} -stroke {1 1 1} -width 2
    $ctx rect   150  120 100 60 -fill {0.2 0.6 1} -radius 10 -stroke {1 1 1}
    $ctx ellipse 330 150 50 30  -fill {0.8 0.2 0.8} -stroke {1 1 1}

    # SVG path (star)
    $ctx path "M 200 260 L 210 240 L 220 260 L 200 248 L 220 248 Z" \
        -fill {1 1 0} -stroke {1 0.8 0}

    $ctx save $f
    set ok [expr {[file exists $f] && [file size $f] > 500}]
    $ctx destroy; cleanup $f; set ok
} -result 1

# ================================================================
cleanupTests
