#!/usr/bin/env tclsh8.6
# tests/test-tclmcairo.tcl -- tclmcairo Tests
#
# Run: make test
# or:  TCLMCAIRO_LIBDIR=. tclsh tests/test-tclmcairo.tcl

# Add tcl/ directory to module search path
# Works for both Tcl 8.6 and 9.0
set _tmdir [file normalize [file join [file dirname [info script]] ../tcl]]
if {$_tmdir ni [tcl::tm::path list]} {
    tcl::tm::path add $_tmdir
}
unset _tmdir

package require tcltest 2.2
namespace import tcltest::*

package require tclmcairo

# ================================================================
# Setup
# ================================================================
set W 200
set H 150

proc mkctx  {}      { return [tclmcairo::new $::W $::H] }
proc mkvctx {}      { return [tclmcairo::new $::W $::H -mode vector] }
proc tmpfile {ext}  { return [file join /tmp "tclmcairo_test.[pid].$ext"] }
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
    set ctx [tclmcairo::new 400 300 -mode vector]
    $ctx clear 0.08 0.10 0.18

    # Background gradient
    $ctx gradient_linear bg 0 0 400 0 \
        {{0 0.08 0.10 0.25 1} {1 0.15 0.10 0.30 1}}
    $ctx rect 0 0 400 300 -fillname bg

    # Title
    $ctx text 200 50 "tclmcairo v0.1" \
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
# v0.2 — push/pop
# ================================================================
test pushpop-1.0 {push/pop restores state} -body {
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx push
    $ctx transform -translate 100 100
    $ctx circle 0 0 30 -fill {1 0 0}
    $ctx pop
    # After pop, transform should be gone — circle at original coords
    $ctx circle 10 10 10 -fill {0 1 0}
    set ok 1
    $ctx destroy; set ok
} -result 1

test pushpop-1.1 {nested push/pop} -body {
    set ctx [mkctx]
    $ctx push
    $ctx push
    $ctx transform -rotate 45
    $ctx pop
    $ctx pop
    set ok 1
    $ctx destroy; set ok
} -result 1

# ================================================================
# v0.2 — clip
# ================================================================
test clip-1.0 {clip_rect clips circle} -body {
    set f [tmpfile png]
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx push
    $ctx clip_rect 0 0 100 75
    $ctx circle 100 75 60 -fill {1 0 0}
    $ctx clip_reset
    $ctx pop
    $ctx save $f
    set ok [expr {[file exists $f] && [file size $f] > 100}]
    $ctx destroy; cleanup $f; set ok
} -result 1

test clip-1.1 {clip_path with SVG path} -body {
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx push
    $ctx clip_path "M 50 0 L 200 50 L 150 150 L 50 100 Z"
    $ctx rect 0 0 200 150 -fill {0 0.5 1}
    $ctx clip_reset
    $ctx pop
    set ok 1
    $ctx destroy; set ok
} -result 1

test clip-1.2 {clip_reset restores full canvas} -body {
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx clip_rect 0 0 10 10
    $ctx clip_reset
    # After reset, can draw anywhere
    $ctx circle 190 140 5 -fill {1 0 0}
    set ok 1
    $ctx destroy; set ok
} -result 1

# ================================================================
# v0.2 — multipage PDF
# ================================================================
test multipage-1.0 {multipage PDF creates file} -body {
    set f [tmpfile pdf]
    set ctx [tclmcairo::new 595 842 -mode pdf -file $f]
    $ctx clear 1 1 1
    $ctx text 100 100 "Page 1" -font "Sans 16" -color {0 0 0}
    $ctx newpage
    $ctx clear 1 1 1
    $ctx text 100 100 "Page 2" -font "Sans 16" -color {0 0 0.8}
    $ctx finish
    $ctx destroy
    set ok [expr {[file exists $f] && [file size $f] > 500}]
    cleanup $f; set ok
} -result 1

test multipage-1.1 {multipage PDF destroy without finish} -body {
    # destroy should auto-finish
    set f [tmpfile pdf]
    set ctx [tclmcairo::new 595 842 -mode pdf -file $f]
    $ctx clear 1 1 1
    $ctx text 100 200 "Auto-finish" -font "Sans 14" -color {0 0 0}
    $ctx destroy
    set ok [expr {[file exists $f] && [file size $f] > 200}]
    cleanup $f; set ok
} -result 1

test multipage-1.2 {multipage error: newpage on raster} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx newpage } err
    $ctx destroy
    string match "*newpage only valid*" $err
} -result 1

test multipage-1.3 {file mode SVG} -body {
    set f [tmpfile svg]
    set ctx [tclmcairo::new 400 300 -mode svg -file $f]
    $ctx clear 0.1 0.1 0.2
    $ctx rect 10 10 380 280 -fill {0.2 0.5 0.9} -radius 8
    $ctx text 200 150 "SVG file-mode" -font "Sans Bold 18" \
        -color {1 1 1} -anchor center
    $ctx finish
    $ctx destroy
    set ok [expr {[file exists $f] && [file size $f] > 100}]
    cleanup $f; set ok
} -result 1

# ================================================================
# v0.2 — image
# ================================================================
test image-1.0 {image PNG load and draw} -body {
    # Create a small PNG first
    set src [tmpfile png]
    set tmp [tclmcairo::new 60 60]
    $tmp clear 1 0.5 0
    $tmp circle 30 30 25 -fill {1 0.8 0.2}
    $tmp save $src
    $tmp destroy

    # Embed in another context
    set f [tmpfile png]
    set ctx [mkctx]
    $ctx clear 0.2 0.2 0.3
    $ctx image $src 10 10
    $ctx save $f
    set ok [expr {[file exists $f] && [file size $f] > 200}]
    $ctx destroy; cleanup $f; cleanup $src; set ok
} -result 1

test image-1.1 {image with -width -height scaling} -body {
    set src [tmpfile png]
    set tmp [tclmcairo::new 100 100]
    $tmp clear 0.8 0.2 0.2
    $tmp circle 50 50 40 -fill {1 0.5 0.5}
    $tmp save $src
    $tmp destroy

    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx image $src 0 0 -width 50 -height 50
    set ok 1
    $ctx destroy; cleanup $src; set ok
} -result 1

test image-1.2 {image with -alpha} -body {
    set src [tmpfile png]
    set tmp [tclmcairo::new 80 80]
    $tmp clear 0 0.5 1
    $tmp save $src
    $tmp destroy

    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx image $src 10 10 -alpha 0.5
    set ok 1
    $ctx destroy; cleanup $src; set ok
} -result 1

test image-1.3 {image bad file -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx image /nonexistent/file.png 0 0 } err
    $ctx destroy
    expr {$err ne ""}
} -result 1



# ================================================================
# select_font_face
# ================================================================
test select_font_face-1.0 {select_font_face sets font family} -body {
    set f [tmpfile png]
    set ctx [tclmcairo::new 300 100]
    $ctx clear 1 1 1
    $ctx select_font_face "Serif" -slant normal -weight bold -size 20
    $ctx text 10 60 "Bold Serif" -color {0 0 0}
    $ctx save $f
    $ctx destroy
    file size $f
} -match glob -result {[0-9]*}

test select_font_face-1.1 {select_font_face italic} -body {
    set f [tmpfile png]
    set ctx [tclmcairo::new 300 100]
    $ctx clear 1 1 1
    $ctx select_font_face "Sans" -slant italic -weight normal -size 16
    $ctx text 10 60 "Italic Sans" -color {0 0 0}
    $ctx save $f
    $ctx destroy
    file size $f
} -match glob -result {[0-9]*}

# ================================================================
# text_extents — full dict
# ================================================================
test text_extents-2.0 {text_extents returns full dict} -body {
    set ctx [tclmcairo::new 10 10]
    set d [$ctx text_extents "Hello" -font "Sans 14"]
    $ctx destroy
    lsort [dict keys $d]
} -result {ascent descent height line_height width x_advance x_bearing y_advance y_bearing}

test text_extents-2.1 {text_extents values are numeric} -body {
    set ctx [tclmcairo::new 10 10]
    set d [$ctx text_extents "Test" -font "Sans 12"]
    $ctx destroy
    expr {[dict get $d width] > 0 && [dict get $d ascent] > 0}
} -result 1

# ================================================================
# image_size
# ================================================================
test image_size-1.0 {image_size returns width height for PNG} -body {
    # Use one of the demo PNGs as test image
    set testimg [file normalize [file join [file dirname [info script]] ../demos/demo-blit-icons.png]]
    if {![file exists $testimg]} {
        return "skip"
    }
    set ctx [tclmcairo::new 10 10]
    set result [$ctx image_size $testimg]
    $ctx destroy
    expr {[llength $result] == 2 && [lindex $result 0] > 0 && [lindex $result 1] > 0}
} -result 1

test image_size-1.1 {image_size bad file -> error} -body {
    set ctx [tclmcairo::new 10 10]
    set err ""
    catch { $ctx image_size /nonexistent/file.png } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

# ================================================================
# v0.2 — text_path
# ================================================================
test textpath-1.0 {text_path with fill} -body {
    set f [tmpfile png]
    set ctx [tclmcairo::new 400 150]
    $ctx clear 0.1 0.1 0.2
    $ctx text_path 200 100 "TCLMCAIRO" \
        -font "Sans Bold 36" -fill {1 0.8 0.2} \
        -stroke {1 1 1} -width 1 -anchor center
    $ctx save $f
    set ok [expr {[file exists $f] && [file size $f] > 200}]
    $ctx destroy; cleanup $f; set ok
} -result 1

test textpath-1.1 {text_path with gradient fill} -body {
    set ctx [tclmcairo::new 400 150 -mode vector]
    $ctx clear 0.05 0.05 0.1
    $ctx gradient_linear gr 0 0 400 0 \
        {{0 1 0.3 0 1} {0.5 1 1 0 1} {1 0 0.3 1 1}}
    $ctx text_path 200 100 "GRADIENT" \
        -font "Sans Bold 40" -fillname gr -anchor center
    set ok 1
    $ctx destroy; set ok
} -result 1

# ================================================================
# v0.2 — fillrule
# ================================================================
test fillrule-1.0 {fillrule evenodd accepted} -body {
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx path "M 100 10 L 120 70 L 175 70 L 130 100 L 145 160 L 100 125 L 55 160 L 70 100 L 25 70 L 80 70 Z" \
        -fill {0.2 0.4 0.9} -fillrule evenodd
    set ok 1
    $ctx destroy; set ok
} -result 1

test fillrule-1.1 {fillrule winding accepted} -body {
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx path "M 100 10 L 120 70 L 175 70 L 130 100 Z" \
        -fill {0.8 0.3 0.1} -fillrule winding
    set ok 1
    $ctx destroy; set ok
} -result 1

test fillrule-1.2 {fillrule invalid -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx path "M 10 10 L 100 10 L 50 80 Z" \
        -fill {1 0 0} -fillrule nonsense } err
    $ctx destroy
    string match "*invalid -fillrule*" $err
} -result 1

# ================================================================


# ================================================================
# v0.2 — text -outline
# ================================================================
test text-outline-1.0 {text -outline 0 default} -body {
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx text 100 75 "Hello" -font "Sans 14" -color {0 0 0} -outline 0
    set ok 1; $ctx destroy; set ok
} -result 1

test text-outline-1.1 {text -outline 1 with fill+stroke} -body {
    set ctx [mkctx]
    $ctx clear 0.1 0.1 0.2
    $ctx text 100 75 "Hello" -font "Sans Bold 18" \
        -fill {1 0.8 0.2} -stroke {0.8 0.3 0} -width 1.5 -outline 1
    set ok 1; $ctx destroy; set ok
} -result 1

test text-outline-1.2 {text -outline 1 with gradient} -body {
    set ctx [mkctx]
    $ctx clear 0.05 0.05 0.1
    $ctx gradient_linear g 0 0 200 0 {{0 1 0 0 1} {1 0 0 1 1}}
    $ctx text 100 75 "GRAD" -font "Sans Bold 22" \
        -fillname g -outline 1
    set ok 1; $ctx destroy; set ok
} -result 1

test text-outline-1.3 {text -outline 1 with anchor center} -body {
    set f [tmpfile png]
    set ctx [mkctx]
    $ctx clear 0.1 0.1 0.2
    $ctx text 100 75 "Centered" -font "Sans Bold 16" \
        -fill {1 1 1} -outline 1 -anchor center
    $ctx save $f
    set ok [expr {[file exists $f] && [file size $f] > 100}]
    $ctx destroy; cleanup $f; set ok
} -result 1

test text-outline-1.4 {text -outline invalid -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx text 10 50 "test" -font "Sans 14" -outline notabool } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

# ================================================================


# ================================================================
# v0.2 — blit
# ================================================================
test blit-1.0 {blit raster onto raster} -body {
    set dst [mkctx]
    $dst clear 0.9 0.9 0.9
    set src [mkctx]
    $src circle 100 75 50 -fill {1 0.5 0}
    $dst blit $src 0 0
    set ok 1
    $dst destroy; $src destroy; set ok
} -result 1

test blit-1.1 {blit with -alpha} -body {
    set dst [mkctx]
    $dst clear 1 1 1
    set src [mkctx]
    $src circle 100 75 50 -fill {0 0.5 1}
    $dst blit $src 0 0 -alpha 0.5
    set ok 1
    $dst destroy; $src destroy; set ok
} -result 1

test blit-1.2 {blit with -width -height scaling} -body {
    set dst [mkctx]
    $dst clear 1 1 1
    set src [tclmcairo::new 200 200]
    $src circle 100 100 90 -fill {0.8 0.3 0.1}
    $dst blit $src 10 10 -width 80 -height 80
    set ok 1
    $dst destroy; $src destroy; set ok
} -result 1

test blit-1.3 {blit vector onto raster} -body {
    set dst [mkctx]
    $dst clear 0.1 0.1 0.2
    set src [mkvctx]
    $src circle 100 75 50 -fill {0.9 0.7 0.1 0.8}
    $dst blit $src 0 0
    set ok 1
    $dst destroy; $src destroy; set ok
} -result 1

test blit-1.4 {blit saves PNG correctly} -body {
    set f [tmpfile png]
    set dst [mkctx]
    $dst clear 0.2 0.2 0.3
    set src [tclmcairo::new 80 80]
    $src circle 40 40 35 -fill {1 0.8 0.2}
    $dst blit $src 60 35
    $dst save $f
    set ok [expr {[file exists $f] && [file size $f] > 200}]
    $dst destroy; $src destroy; cleanup $f; set ok
} -result 1

test blit-1.5 {blit same id -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { tclmcairo blit [$ctx id] [$ctx id] 0 0 } err
    $ctx destroy
    string match *different* $err
} -result 1

test blit-1.6 {blit invalid src -> error} -body {
    set dst [mkctx]
    set err ""
    catch { tclmcairo blit [$dst id] 9999 0 0 } err
    $dst destroy
    expr {$err ne ""}
} -result 1

# ================================================================


# ================================================================
# v0.2 — -format rgb24 / a8
# ================================================================
test format-1.0 {-format rgb24 creates valid PNG} -body {
    set ctx [tclmcairo::new 200 100 -format rgb24]
    $ctx clear 0.2 0.4 0.8
    $ctx circle 100 50 40 -fill {1 0.8 0.2}
    set f [tmpfile png]
    $ctx save $f
    $ctx destroy
    set ok [expr {[file exists $f] && [file size $f] > 100}]
    cleanup $f; set ok
} -result 1

test format-1.1 {-format invalid -> error} -body {
    set err ""
    catch { tclmcairo::new 100 100 -format bogus } err
    string match *invalid* $err
} -result 1

test format-1.2 {-format a8 creates context} -body {
    set ctx [tclmcairo::new 100 100 -format a8]
    set ok [expr {$ctx ne ""}]
    $ctx destroy; set ok
} -result 1

# ================================================================
# v0.2 — topng
# ================================================================
test topng-1.0 {topng returns PNG bytes} -body {
    set ctx [mkctx]
    $ctx clear 0.2 0.5 0.8
    $ctx circle 100 75 50 -fill {1 0.8 0.2}
    set bytes [$ctx topng]
    $ctx destroy
    # PNG magic bytes: 89 50 4E 47
    set ok [expr {[string length $bytes] > 100 &&
        [string index $bytes 1] eq "P"}]
    set ok
} -result 1

test topng-1.1 {topng from vector mode} -body {
    set ctx [mkvctx]
    $ctx clear 0.1 0.1 0.2
    $ctx rect 10 10 180 130 -fill {0.3 0.6 0.9} -radius 8
    set bytes [$ctx topng]
    $ctx destroy
    expr {[string length $bytes] > 100}
} -result 1

test topng-1.2 {topng bytes == save file} -body {
    set ctx [mkctx]
    $ctx clear 0 0 0 0
    $ctx circle 100 75 60 -fill {1 0.5 0 0.8}
    set bytes [$ctx topng]
    set f [tmpfile png]
    $ctx save $f
    $ctx destroy
    set sz [file size $f]
    cleanup $f
    expr {[string length $bytes] == $sz}
} -result 1

# ================================================================
# v0.2 — image_data
# ================================================================
test image_data-1.0 {image_data draws PNG bytes} -body {
    # Quell-PNG erzeugen
    set src [tclmcairo::new 60 60]
    $src circle 30 30 25 -fill {1 0.5 0}
    set bytes [$src topng]
    $src destroy
    # Auf Target zeichnen
    set ctx [mkctx]
    $ctx clear 0.1 0.1 0.2
    $ctx image_data $bytes 20 20
    set ok 1
    $ctx destroy; set ok
} -result 1

test image_data-1.1 {image_data with -width -height} -body {
    set src [tclmcairo::new 80 80]
    $src circle 40 40 35 -fill {0.2 0.7 0.4}
    set bytes [$src topng]
    $src destroy
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx image_data $bytes 10 10 -width 50 -height 50
    set ok 1
    $ctx destroy; set ok
} -result 1

test image_data-1.2 {image_data with -alpha} -body {
    set src [tclmcairo::new 80 80]
    $src clear 0 0.5 1
    set bytes [$src topng]
    $src destroy
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx image_data $bytes 10 10 -alpha 0.5
    set ok 1
    $ctx destroy; set ok
} -result 1

test image_data-1.3 {image_data invalid bytes -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx image_data [binary format H* "DEADBEEF"] 0 0 } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

test image_data-1.4 {topng roundtrip: bytes -> image_data} -body {
    # Zeichnen, topng, image_data, nochmal topng -> gleiche Größe
    set src [mkctx]
    $src clear 0 0 0 0
    $src gradient_linear g 0 0 200 0 {{0 1 0 0 1} {1 0 0 1 1}}
    $src rect 10 10 180 130 -fillname g -radius 12
    set bytes1 [$src topng]
    $src destroy

    set dst [mkctx]
    $dst clear 0 0 0 0
    $dst image_data $bytes1 0 0
    set bytes2 [$dst topng]
    $dst destroy

    # Beide müssen gültige PNG-Bytes sein
    expr {[string length $bytes1] > 100 && [string length $bytes2] > 100}
} -result 1

# ================================================================




# ================================================================
# Robustheit / Edge Cases (Review 4.3)
# ================================================================
test robust-1.0 {double destroy is safe} -body {
    set ctx [mkctx]
    $ctx destroy
    catch { $ctx destroy }   ;# zweites destroy — kein crash
    set ok 1
} -result 1

test robust-1.1 {destroy then method -> error} -body {
    set ctx [mkctx]
    $ctx destroy
    set err ""
    catch { $ctx clear 1 1 1 } err
    expr {$err ne ""}
} -result 1

test robust-1.2 {zero-size context} -body {
    # Cairo erlaubt das, kein crash erwartet
    set err ""
    catch { tclmcairo::new 0 0 } err
    # Entweder ok oder klarer Fehler — kein Segfault
    set ok 1
} -result 1

test robust-1.3 {very large context} -body {
    # Sollte Fehler geben oder korrekt erstellen
    set err ""
    set ok [catch { tclmcairo::new 32767 32767 } ctx]
    if {!$ok} { catch { $ctx destroy } }
    set ok 1   ;# kein Crash ist das Ziel
} -result 1

test robust-1.4 {negative dimensions -> error or safe} -body {
    set err ""
    set ok [catch { tclmcairo::new -10 100 } err]
    # Entweder Fehler oder sichere Behandlung
    set ok 1
} -result 1

test robust-1.5 {package require loads .so immediately} -body {
    # Nach package require muss tclmcairo command existieren
    expr {[llength [info commands tclmcairo]] > 0}
} -result 1

test robust-1.6 {missing file for image -> clear error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx image /nonexistent/path/foto.png 0 0 } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

test robust-1.7 {file mode requires -file} -body {
    set err ""
    catch { tclmcairo::new 400 300 -mode pdf } err
    string match *-file* $err
} -result 1

test robust-1.8 {multiple contexts independent} -body {
    set a [tclmcairo::new 100 100]
    set b [tclmcairo::new 200 150]
    $a clear 1 0 0
    $b clear 0 1 0
    set sa [$a size]
    set sb [$b size]
    $a destroy
    $b destroy
    expr {$sa eq {100 100} && $sb eq {200 150}}
} -result 1

# ================================================================


# ================================================================
# v0.2 — -svg_version / -svg_unit
# ================================================================
test svg-opts-1.0 {-svg_version 1.1: creates valid SVG} -body {
    set f [tmpfile svg]
    set ctx [tclmcairo::new 100 80 -mode svg -file $f -svg_version 1.1]
    $ctx clear 0.5 0.5 0.5
    $ctx finish; $ctx destroy
    set ok [expr {[file size $f] > 100}]
    cleanup $f; set ok
} -result 1

test svg-opts-1.1 {-svg_version 1.2: creates valid SVG} -body {
    set f [tmpfile svg]
    set ctx [tclmcairo::new 100 80 -mode svg -file $f -svg_version 1.2]
    $ctx clear 0.5 0.5 0.5
    $ctx finish; $ctx destroy
    set ok [expr {[file size $f] > 100}]
    cleanup $f; set ok
} -result 1

test svg-opts-1.2 {-svg_version invalid -> error} -body {
    set err ""
    catch { tclmcairo::new 100 100 -mode svg -file /tmp/x.svg \
        -svg_version 2.0 } err
    string match *invalid* $err
} -result 1

test svg-opts-1.3 {-svg_unit px: width attribute contains px} -body {
    set f [tmpfile svg]
    set ctx [tclmcairo::new 200 100 -mode svg -file $f -svg_unit px]
    $ctx rect 10 10 180 80 -fill {0.5 0.5 1}
    $ctx finish; $ctx destroy
    set fd [open $f r]; set c [read $fd]; close $fd
    cleanup $f
    string match *width="200px"* $c
} -result 1

test svg-opts-1.4 {-svg_unit mm: width attribute contains mm} -body {
    set f [tmpfile svg]
    set ctx [tclmcairo::new 200 100 -mode svg -file $f -svg_unit mm]
    $ctx rect 10 10 180 80 -fill {0.5 1 0.5}
    $ctx finish; $ctx destroy
    set fd [open $f r]; set c [read $fd]; close $fd
    cleanup $f
    string match *width="200mm"* $c
} -result 1

test svg-opts-1.5 {-svg_unit invalid -> error} -body {
    set err ""
    catch { tclmcairo::new 100 100 -mode svg -file /tmp/x.svg \
        -svg_unit furlong } err
    string match *invalid* $err
} -result 1

# ================================================================


# ================================================================
# Plotchart-style: clip_rect + push/pop + path (line charts)
# ================================================================
test plotchart-1.0 {plotchart: clip_rect scopes data to plot area} -body {
    set ctx [tclmcairo::new 400 300]
    $ctx clear 1 1 1

    # Draw outside plot area first (should be visible)
    $ctx circle 5 5 10 -fill {1 0 0}

    # Clip to plot area
    $ctx push
    $ctx clip_rect 50 30 300 220

    # This circle is partially outside — only inner part visible
    $ctx circle 50 30 40 -fill {0.2 0.5 1}

    # Path inside clip
    $ctx path "M 50 150 L 200 80 L 350 150" -stroke {0.9 0.3 0.2} -width 2
    $ctx pop   ;# clip released

    # Draw outside again (should be visible)
    $ctx circle 395 295 10 -fill {0 0.8 0}

    set f [tmpfile png]
    $ctx save $f
    $ctx destroy
    set ok [expr {[file size $f] > 100}]
    cleanup $f; set ok
} -result 1

test plotchart-1.1 {plotchart: nested push/pop restores state} -body {
    set ctx [tclmcairo::new 300 200]
    $ctx clear 1 1 1

    $ctx push
    $ctx clip_rect 10 10 280 180
    $ctx rect 0 0 300 200 -fill {0.9 0.9 1}

    # Nested push/pop
    $ctx push
    $ctx transform -translate 50 50
    $ctx circle 0 0 30 -fill {1 0.5 0}
    $ctx pop

    # State restored — circle at absolute position
    $ctx circle 250 150 20 -fill {0.2 0.8 0.4}
    $ctx pop

    set f [tmpfile png]
    $ctx save $f
    $ctx destroy
    set ok [expr {[file size $f] > 100}]
    cleanup $f; set ok
} -result 1

test plotchart-1.2 {plotchart: multiple curves with data mapping} -body {
    # Simulate data->pixel mapping as in Demo 13
    set W 300; set H 200
    set lm 40; set tm 20
    set pw [expr {$W - $lm - 20}]
    set ph [expr {$H - $tm - 30}]
    set xmin 0.0; set xmax 6.28
    set ymin -1.2; set ymax 1.2

    proc _px {x} {
        global lm pw xmin xmax
        expr {$lm + ($x-$xmin)/($xmax-$xmin)*$pw}
    }
    proc _py {y} {
        global tm ph ymin ymax H
        expr {$H - 30 - ($y-$ymin)/($ymax-$ymin)*$ph}
    }

    set ctx [tclmcairo::new $W $H]
    $ctx clear 0.95 0.95 1.0

    $ctx push
    $ctx clip_rect $lm $tm $pw $ph

    # sin curve
    set path "M [_px 0] [_py [expr {sin(0)}]]"
    for {set i 1} {$i <= 50} {incr i} {
        set x [expr {$xmin + $i*($xmax-$xmin)/50.0}]
        append path " L [_px $x] [_py [expr {sin($x)}]]"
    }
    $ctx path $path -stroke {0.2 0.4 0.9} -width 2

    # cos curve
    set path "M [_px 0] [_py [expr {cos(0)}]]"
    for {set i 1} {$i <= 50} {incr i} {
        set x [expr {$xmin + $i*($xmax-$xmin)/50.0}]
        append path " L [_px $x] [_py [expr {cos($x)}]]"
    }
    $ctx path $path -stroke {0.9 0.3 0.2} -width 2

    $ctx pop   ;# axes drawn outside clip

    # X axis (outside clip)
    $ctx line $lm [expr {$H-30}] [expr {$lm+$pw}] [expr {$H-30}] \
        -color {0.2 0.2 0.3} -width 1.5
    # Y axis
    $ctx line $lm $tm $lm [expr {$H-30}] \
        -color {0.2 0.2 0.3} -width 1.5

    set f [tmpfile png]
    $ctx save $f
    $ctx destroy
    set ok [expr {[file size $f] > 200}]
    cleanup $f
    rename _px {}; rename _py {}
    set ok
} -result 1

test plotchart-1.3 {plotchart: clip_path with triangle mask} -body {
    set ctx [tclmcairo::new 200 200]
    $ctx clear 1 1 1
    $ctx push
    $ctx clip_path "M 100 10 L 190 190 L 10 190 Z"
    $ctx gradient_linear g 0 0 200 0 {{0 0.2 0.5 1 1} {1 0.9 0.3 0.1 1}}
    $ctx rect 0 0 200 200 -fillname g
    $ctx pop
    set f [tmpfile png]
    $ctx save $f
    $ctx destroy
    set ok [expr {[file size $f] > 100}]
    cleanup $f; set ok
} -result 1

# ================================================================


# ================================================================
# transform -matrix / -get
# ================================================================
test transform-matrix-1.0 {-matrix applies affine transform} -body {
    set ctx [mkctx]
    $ctx transform -matrix 1 0 0 1 50 50   ;# pure translate via matrix
    set m [$ctx transform -get]
    $ctx destroy
    lindex $m 4   ;# x0 should be 50
} -result 50.0

test transform-matrix-1.1 {-get returns identity after reset} -body {
    set ctx [mkctx]
    $ctx transform -translate 100 200
    $ctx transform -reset
    set m [$ctx transform -get]
    $ctx destroy
    set m
} -result {1.0 0.0 0.0 1.0 0.0 0.0}

test transform-matrix-1.2 {-get after translate} -body {
    set ctx [mkctx]
    $ctx transform -translate 30 70
    set m [$ctx transform -get]
    $ctx destroy
    list [lindex $m 4] [lindex $m 5]   ;# x0 y0
} -result {30.0 70.0}

test transform-matrix-1.3 {-matrix invalid -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx transform -matrix 1 0 0 } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

# ================================================================


# ================================================================
# v0.3 — operator
# ================================================================
test operator-1.0 {operator OVER is default} -body {
    set ctx [mkctx]
    $ctx operator OVER
    set ok 1; $ctx destroy; set ok
} -result 1

test operator-1.1 {operator MULTIPLY} -body {
    set ctx [mkctx]
    $ctx operator MULTIPLY
    $ctx circle 100 75 60 -fill {1 0.5 0}
    set f [tmpfile png]; $ctx save $f; $ctx destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

test operator-1.2 {operator XOR} -body {
    set ctx [mkctx]
    $ctx operator XOR
    $ctx rect 20 20 160 110 -fill {0.8 0.2 0.4}
    set f [tmpfile png]; $ctx save $f; $ctx destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

test operator-1.3 {operator DIFFERENCE} -body {
    set ctx [mkctx]
    $ctx operator DIFFERENCE
    $ctx circle 100 75 50 -fill {0.5 0.9 0.2}
    set ok 1; $ctx destroy; set ok
} -result 1

test operator-1.4 {invalid operator -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx operator BOGUS } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

test operator-1.5 {case insensitive operator} -body {
    set ctx [mkctx]
    $ctx operator multiply
    set ok 1; $ctx destroy; set ok
} -result 1

# ================================================================
# v0.3 — -dash_offset
# ================================================================
test dash-offset-1.0 {-dash_offset accepted} -body {
    set ctx [mkctx]
    $ctx line 0 75 200 75 -color {1 1 1} -width 2 \
        -dash {10 5} -dash_offset 3
    set ok 1; $ctx destroy; set ok
} -result 1

test dash-offset-1.1 {-dash_offset 0 = default} -body {
    set ctx [mkctx]
    $ctx line 0 75 200 75 -color {1 1 1} -width 2 \
        -dash {8 4} -dash_offset 0
    set ok 1; $ctx destroy; set ok
} -result 1

test dash-offset-1.2 {-dash_offset on path} -body {
    set ctx [mkctx]
    $ctx path "M 10 75 L 190 75" -stroke {1 0.5 0} \
        -width 2 -dash {6 3} -dash_offset 5
    set ok 1; $ctx destroy; set ok
} -result 1

# ================================================================
# v0.3 — arc_negative
# ================================================================
test arc-neg-1.0 {arc_negative draws} -body {
    set ctx [mkctx]
    $ctx arc_negative 100 75 50 0 270 -stroke {0.2 0.8 1} -width 2
    set f [tmpfile png]; $ctx save $f; $ctx destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

test arc-neg-1.1 {arc_negative produces valid image} -body {
    set ctx [mkctx]
    $ctx clear 0 0 0 0
    $ctx arc_negative 100 75 50 0 270 -stroke {0 0 1} -width 3
    set f [tmpfile png]; $ctx save $f; $ctx destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

# ================================================================
# v0.3 — user_to_device / device_to_user
# ================================================================
test coords-1.0 {user_to_device identity = same} -body {
    set ctx [mkctx]
    set d [$ctx user_to_device 50 80]
    $ctx destroy
    set d
} -result {50.0 80.0}

test coords-1.1 {user_to_device after translate} -body {
    set ctx [mkctx]
    $ctx transform -translate 30 40
    set d [$ctx user_to_device 10 20]
    $ctx destroy
    set d
} -result {40.0 60.0}

test coords-1.2 {device_to_user inverse of user_to_device} -body {
    set ctx [mkctx]
    $ctx transform -translate 100 50
    $ctx transform -scale 2.0 2.0
    set d [$ctx user_to_device 10 20]
    set u [$ctx device_to_user {*}$d]
    $ctx destroy
    list [format %.1f [lindex $u 0]] [format %.1f [lindex $u 1]]
} -result {10.0 20.0}

test coords-1.3 {user_to_device after rotate} -body {
    set ctx [mkctx]
    $ctx transform -rotate 90
    set d [$ctx user_to_device 10 0]
    $ctx destroy
    # 90° rotation: (10,0) -> (0,10) approximately
    expr {abs([lindex $d 0] - 0) < 0.01 && abs([lindex $d 1] - 10) < 0.01}
} -result 1

# ================================================================
# v0.3 — recording_bbox
# ================================================================
test recbbox-1.0 {recording_bbox on vector context} -body {
    set ctx [tclmcairo::new 300 200 -mode vector]
    $ctx circle 150 100 50 -fill {0.5 0.8 0.2}
    set bb [$ctx recording_bbox]
    $ctx destroy
    expr {[llength $bb] == 4}
} -result 1

test recbbox-1.1 {recording_bbox x y w h positive} -body {
    set ctx [tclmcairo::new 400 300 -mode vector]
    $ctx rect 20 30 100 60 -fill {1 0 0}
    set bb [$ctx recording_bbox]
    $ctx destroy
    # w and h should be > 0
    expr {[lindex $bb 2] > 0 && [lindex $bb 3] > 0}
} -result 1

test recbbox-1.2 {recording_bbox on raster -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx recording_bbox } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

# ================================================================


# ================================================================
# v0.3 — gradient_extend
# ================================================================
test gext-1.0 {gradient_extend repeat} -body {
    set ctx [mkctx]
    $ctx gradient_linear g 0 0 50 0 {{0 1 0 0 1} {1 0 0 1 1}}
    $ctx gradient_extend g repeat
    $ctx rect 0 0 200 150 -fillname g
    set f [tmpfile png]; $ctx save $f; $ctx destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

test gext-1.1 {gradient_extend reflect} -body {
    set ctx [mkctx]
    $ctx gradient_linear g 0 0 60 0 {{0 0 0.5 1 1} {1 1 0.8 0 1}}
    $ctx gradient_extend g reflect
    $ctx rect 0 0 200 150 -fillname g
    set ok 1; $ctx destroy; set ok
} -result 1

test gext-1.2 {gradient_extend pad (default)} -body {
    set ctx [mkctx]
    $ctx gradient_linear g 50 0 150 0 {{0 0.2 0.5 1 1} {1 1 0.8 0 1}}
    $ctx gradient_extend g pad
    $ctx rect 0 0 200 150 -fillname g
    set ok 1; $ctx destroy; set ok
} -result 1

test gext-1.3 {gradient_extend none} -body {
    set ctx [mkctx]
    $ctx gradient_linear g 50 0 150 0 {{0 1 0 0 1} {1 0 1 0 1}}
    $ctx gradient_extend g none
    $ctx rect 0 0 200 150 -fillname g
    set ok 1; $ctx destroy; set ok
} -result 1

test gext-1.4 {gradient_extend invalid -> error} -body {
    set ctx [mkctx]
    $ctx gradient_linear g 0 0 200 0 {{0 1 0 0 1} {1 0 1 0 1}}
    set err ""
    catch { $ctx gradient_extend g BOGUS } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

test gext-1.5 {gradient_extend unknown name -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx gradient_extend nosuchgrad repeat } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

# ================================================================
# v0.3 — gradient_filter
# ================================================================
test gflt-1.0 {gradient_filter best} -body {
    set ctx [mkctx]
    $ctx gradient_linear g 0 0 200 0 {{0 0.2 0.5 1 1} {1 0.9 0.3 0 1}}
    $ctx gradient_filter g best
    $ctx rect 0 0 200 150 -fillname g
    set ok 1; $ctx destroy; set ok
} -result 1

test gflt-1.1 {gradient_filter nearest} -body {
    set ctx [mkctx]
    $ctx gradient_radial g 100 75 60 {{0 1 0.8 0 1} {1 0 0.2 0.8 0}}
    $ctx gradient_filter g nearest
    $ctx circle 100 75 80 -fillname g
    set ok 1; $ctx destroy; set ok
} -result 1

test gflt-1.2 {gradient_filter invalid -> error} -body {
    set ctx [mkctx]
    $ctx gradient_linear g 0 0 200 0 {{0 1 0 0 1} {1 0 1 0 1}}
    set err ""
    catch { $ctx gradient_filter g BOGUS } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

# ================================================================
# v0.3 — paint / set_source
# ================================================================
test paint-1.0 {paint fills entire surface} -body {
    set ctx [mkctx]
    $ctx set_source -color {0.8 0.2 0.4}
    $ctx paint
    set f [tmpfile png]; $ctx save $f; $ctx destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

test paint-1.1 {paint with alpha} -body {
    set ctx [mkctx]
    $ctx clear 1 1 1
    $ctx set_source -color {0 0.5 1}
    $ctx paint 0.5
    set ok 1; $ctx destroy; set ok
} -result 1

test paint-1.2 {paint with gradient source} -body {
    set ctx [mkctx]
    $ctx gradient_linear g 0 0 200 0 {{0 1 0 0 1} {1 0 0 1 1}}
    $ctx set_source -gradient g
    $ctx paint
    set ok 1; $ctx destroy; set ok
} -result 1

test paint-1.3 {set_source -color invalid -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx set_source -color {1 0} } err
    $ctx destroy
    string match *needs* $err
} -result 1

test paint-1.4 {set_source -gradient unknown -> error} -body {
    set ctx [mkctx]
    set err ""
    catch { $ctx set_source -gradient nosuch } err
    $ctx destroy
    expr {$err ne ""}
} -result 1

# ================================================================


# ================================================================
# v0.3 — font_options
# ================================================================
test fontopts-1.0 {font_options get returns list of 6} -body {
    set ctx [mkctx]
    set fo [$ctx font_options]
    $ctx destroy
    llength $fo
} -result 6

test fontopts-1.1 {font_options set antialias gray} -body {
    set ctx [mkctx]
    $ctx font_options -antialias gray
    set fo [$ctx font_options]
    $ctx destroy
    lindex $fo 1
} -result gray

test fontopts-1.2 {font_options set hint_style full} -body {
    set ctx [mkctx]
    $ctx font_options -hint_style full
    set fo [$ctx font_options]
    $ctx destroy
    lindex $fo 3
} -result full

test fontopts-1.3 {font_options set hint_metrics on} -body {
    set ctx [mkctx]
    $ctx font_options -hint_metrics on
    set fo [$ctx font_options]
    $ctx destroy
    lindex $fo 5
} -result on

test fontopts-1.4 {font_options set hint_metrics off} -body {
    set ctx [mkctx]
    $ctx font_options -hint_metrics off
    set fo [$ctx font_options]
    $ctx destroy
    lindex $fo 5
} -result off

test fontopts-1.5 {font_options invalid antialias -> error} -body {
    set ctx [mkctx]; set err ""
    catch { $ctx font_options -antialias BOGUS } err
    $ctx destroy
    string match *invalid* $err
} -result 1

test fontopts-1.6 {font_options invalid hint_style -> error} -body {
    set ctx [mkctx]; set err ""
    catch { $ctx font_options -hint_style BOGUS } err
    $ctx destroy
    string match *invalid* $err
} -result 1

test fontopts-1.7 {font_options affects text rendering} -body {
    set ctx [mkctx]
    $ctx font_options -antialias none -hint_style none
    $ctx text 100 75 "Test" -font "Sans 14" -color {1 1 1}
    set f [tmpfile png]; $ctx save $f; $ctx destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

# ================================================================
# v0.3 — path_get
# ================================================================
test pathget-1.0 {path_get on empty path returns empty string} -body {
    set ctx [mkctx]
    set p [$ctx path_get]
    $ctx destroy
    set p
} -result {}

test pathget-1.1 {path_get returns string} -body {
    set ctx [mkctx]
    set p [$ctx path_get]
    $ctx destroy
    expr {[string length $p] >= 0}
} -result 1

test pathget-1.2 {path_get after stroke is empty (Cairo clears path)} -body {
    set ctx [mkctx]
    $ctx line 10 10 100 100 -color {1 1 1} -width 2
    set p [$ctx path_get]
    $ctx destroy
    # Cairo clears path after stroke — correct behavior
    set p
} -result {}

# ================================================================
# v0.3 — surface_copy
# ================================================================
test surfc-1.0 {surface_copy creates new context same size} -body {
    set ctx [tclmcairo::new 200 150]
    set cid [$ctx surface_copy]
    set sz [tclmcairo size $cid]
    $ctx destroy; tclmcairo destroy $cid
    set sz
} -result {200 150}

test surfc-1.1 {surface_copy with custom size} -body {
    set ctx [tclmcairo::new 200 150]
    set cid [$ctx surface_copy 80 60]
    set sz [tclmcairo size $cid]
    $ctx destroy; tclmcairo destroy $cid
    set sz
} -result {80 60}

test surfc-1.2 {surface_copy is independent — draw on copy does not affect original} -body {
    set ctx [tclmcairo::new 200 150]
    $ctx clear 0.5 0.5 0.5
    set cid [$ctx surface_copy]
    tclmcairo clear $cid 1 0 0
    set bytes_orig [$ctx topng]
    set bytes_copy [tclmcairo topng $cid]
    $ctx destroy; tclmcairo destroy $cid
    # Different content → different PNG bytes
    expr {$bytes_orig ne $bytes_copy}
} -result 1

test surfc-1.3 {surface_copy from vector context} -body {
    set ctx [tclmcairo::new 200 150 -mode vector]
    $ctx circle 100 75 50 -fill {0.5 0.8 0.2}
    set cid [$ctx surface_copy]
    set sz [tclmcairo size $cid]
    $ctx destroy; tclmcairo destroy $cid
    set sz
} -result {200 150}

test surfc-1.4 {surface_copy result can be saved as PNG} -body {
    set ctx [tclmcairo::new 200 150]
    $ctx clear 0.2 0.4 0.8
    $ctx circle 100 75 60 -fill {1 0.8 0.2}
    set cid [$ctx surface_copy]
    set f [tmpfile png]
    tclmcairo save $cid $f
    $ctx destroy; tclmcairo destroy $cid
    set ok [expr {[file size $f] > 200}]; cleanup $f; set ok
} -result 1

# ================================================================


# ================================================================
# Low-level path commands
# ================================================================
test lowlevel-1.0 {move_to + line_to + stroke} -body {
    set cr [tclmcairo::new 256 256]
    $cr set_source_rgb 0 0 0
    $cr set_line_width 5
    $cr move_to 10 10
    $cr line_to 246 246
    $cr stroke
    set f [tmpfile png]; $cr save $f; $cr destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

test lowlevel-1.1 {rel_line_to + close_path} -body {
    set cr [tclmcairo::new 256 256]
    $cr set_source_rgb 0.5 0 1
    $cr set_line_width 3
    $cr move_to 50 50
    $cr rel_line_to 150 0
    $cr rel_line_to 0 150
    $cr close_path
    $cr stroke
    set ok 1; $cr destroy; set ok
} -result 1

test lowlevel-1.2 {curve_to draws bezier} -body {
    set cr [tclmcairo::new 256 256]
    $cr set_source_rgb 0 0 1
    $cr set_line_width 10
    $cr move_to 25.6 128
    $cr curve_to 102.4 230.4 153.6 25.6 230.4 128
    $cr stroke
    set f [tmpfile png]; $cr save $f; $cr destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

test lowlevel-1.3 {rel_curve_to} -body {
    set cr [tclmcairo::new 256 256]
    $cr set_source_rgb 0 0.5 1
    $cr set_line_width 5
    $cr move_to 50 128
    $cr rel_curve_to 30 60 80 -60 120 0
    $cr stroke
    set ok 1; $cr destroy; set ok
} -result 1

test lowlevel-1.4 {fill_preserve keeps path for stroke} -body {
    set cr [tclmcairo::new 256 256]
    $cr set_source_rgb 0 0 1
    $cr move_to 50 50
    $cr line_to 200 50
    $cr line_to 200 200
    $cr close_path
    $cr fill_preserve
    $cr set_source_rgb 1 0 0
    $cr set_line_width 4
    $cr stroke
    set f [tmpfile png]; $cr save $f; $cr destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

test lowlevel-1.5 {stroke_preserve keeps path} -body {
    set cr [tclmcairo::new 256 256]
    $cr set_source_rgb 0.5 0.5 1
    $cr set_line_width 8
    $cr move_to 20 128; $cr line_to 236 128
    $cr stroke_preserve
    $cr set_source_rgba 1 0 0 0.5
    $cr set_line_width 2
    $cr stroke
    set ok 1; $cr destroy; set ok
} -result 1

test lowlevel-1.6 {new_sub_path + fill_rule evenodd} -body {
    set cr [tclmcairo::new 256 256]
    $cr set_line_width 6
    $cr move_to 12 12; $cr line_to 244 12
    $cr line_to 244 82; $cr line_to 12 82; $cr close_path
    $cr new_sub_path
    $cr arc 64 47 40 0 [expr {2*3.14159}]
    $cr set_fill_rule evenodd
    $cr set_source_rgb 0 0.7 0
    $cr fill_preserve
    $cr set_source_rgb 0 0 0
    $cr stroke
    set f [tmpfile png]; $cr save $f; $cr destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

test lowlevel-1.7 {new_path clears current path} -body {
    set cr [tclmcairo::new 256 256]
    $cr move_to 0 0; $cr line_to 256 256
    $cr new_path
    set p [$cr path_get]
    $cr destroy
    set p
} -result {}

test lowlevel-1.8 {set_line_cap butt|round|square} -body {
    set cr [tclmcairo::new 256 256]
    foreach cap {butt round square} {
        $cr set_line_cap $cap
    }
    set ok 1; $cr destroy; set ok
} -result 1

test lowlevel-1.9 {set_line_join miter|round|bevel} -body {
    set cr [tclmcairo::new 256 256]
    foreach join {miter round bevel} {
        $cr set_line_join $join
    }
    set ok 1; $cr destroy; set ok
} -result 1

test lowlevel-1.10 {set_source_rgba + fill} -body {
    set cr [tclmcairo::new 256 256]
    $cr set_source_rgba 1 0.5 0 0.8
    $cr arc 128 128 80 0 [expr {2*3.14159}]
    $cr fill
    set f [tmpfile png]; $cr save $f; $cr destroy
    set ok [expr {[file size $f] > 100}]; cleanup $f; set ok
} -result 1

test lowlevel-1.11 {set_source_rgb + stroke} -body {
    set cr [tclmcairo::new 256 256]
    $cr set_source_rgb 0.2 0.6 0.9
    $cr set_line_width 12
    $cr move_to 30 128; $cr line_to 226 128
    $cr stroke
    set ok 1; $cr destroy; set ok
} -result 1

test lowlevel-1.12 {set_fill_rule winding} -body {
    set cr [tclmcairo::new 256 256]
    $cr set_fill_rule winding
    $cr move_to 128 10
    $cr line_to 246 246
    $cr line_to 10 246
    $cr close_path
    $cr set_source_rgb 0.2 0.5 0.9
    $cr fill
    set ok 1; $cr destroy; set ok
} -result 1

test lowlevel-1.13 {set_line_cap invalid -> error} -body {
    set cr [tclmcairo::new 256 256]; set err ""
    catch { $cr set_line_cap bogus } err
    $cr destroy
    string match *invalid* $err
} -result 1

test lowlevel-1.14 {set_line_join invalid -> error} -body {
    set cr [tclmcairo::new 256 256]; set err ""
    catch { $cr set_line_join bogus } err
    $cr destroy
    string match *invalid* $err
} -result 1

test lowlevel-1.15 {set_fill_rule invalid -> error} -body {
    set cr [tclmcairo::new 256 256]; set err ""
    catch { $cr set_fill_rule bogus } err
    $cr destroy
    string match *invalid* $err
} -result 1

test lowlevel-1.16 {rel_move_to moves current point} -body {
    set cr [tclmcairo::new 256 256]
    $cr move_to 50 50
    $cr rel_move_to 30 40
    $cr line_to 200 200
    $cr set_source_rgb 0 0 0
    $cr set_line_width 2
    $cr stroke
    set ok 1; $cr destroy; set ok
} -result 1

# ================================================================


# ================================================================
# Robustness / validation fixes (from code review)
# ================================================================

# Fix 1: package version consistency
test robustness-1.0 {package version is 0.3.3} -body {
    package present tclmcairo
} -result 0.3.3

# Fix 5: low-level commands check argument count
test robustness-1.1 {move_to requires x y} -body {
    set ctx [tclmcairo::new 100 100]
    set err ""
    catch { tclmcairo move_to [$ctx id] } err
    $ctx destroy
    string match *args* $err
} -result 1

test robustness-1.2 {line_to requires x y} -body {
    set ctx [tclmcairo::new 100 100]
    set err ""
    catch { tclmcairo line_to [$ctx id] 10 } err
    $ctx destroy
    string match *args* $err
} -result 1

test robustness-1.3 {close_path requires id only} -body {
    set ctx [tclmcairo::new 100 100]
    $ctx move_to 10 10; $ctx line_to 50 50
    $ctx close_path
    set ok 1; $ctx destroy; set ok
} -result 1

# Fix 6: create validates options
test robustness-2.0 {create rejects unknown option} -body {
    set err ""
    catch { tclmcairo::new 100 100 -bogus val } err
    expr {$err ne ""}
} -result 1

test robustness-2.1 {create rejects odd option list} -body {
    set err ""
    catch { tclmcairo::new 100 100 -mode } err
    string match *value* $err
} -result 1

test robustness-2.2 {create rejects invalid -mode} -body {
    set err ""
    catch { tclmcairo::new 100 100 -mode foobar } err
    string match *invalid* $err
} -result 1

test robustness-2.3 {create rejects invalid -format} -body {
    set err ""
    catch { tclmcairo::new 100 100 -format foobar } err
    string match *invalid* $err
} -result 1

# Fix 7: SVG path parser does not crash on bad input
test robustness-3.0 {path with invalid number does not crash} -body {
    set ctx [tclmcairo::new 100 100]
    catch { $ctx path "M abc Z" -stroke {1 0 0} -width 1 }
    set ok 1; $ctx destroy; set ok
} -result 1

test robustness-3.1 {path with empty string does not crash} -body {
    set ctx [tclmcairo::new 100 100]
    catch { $ctx path "" -stroke {1 0 0} -width 1 }
    set ok 1; $ctx destroy; set ok
} -result 1

test robustness-3.2 {path with truncated data does not crash} -body {
    set ctx [tclmcairo::new 100 100]
    catch { $ctx path "M 10 10 L 50" -stroke {1 0 0} -width 1 }
    set ok 1; $ctx destroy; set ok
} -result 1

# ================================================================
# save -chan (new in 0.3.2)
# ================================================================

test save-chan-1 {save -chan -format png writes PNG bytes} -body {
    set ctx [tclmcairo::new 100 100]
    $ctx clear 0.2 0.4 0.8
    $ctx circle 50 50 30 -fill {1 0.5 0}
    set f [file join /tmp test_chan_[pid].png]
    set ch [open $f wb]
    $ctx save -chan $ch -format png
    close $ch
    $ctx destroy
    set sz [file size $f]
    file delete -force $f
    expr {$sz > 100}
} -result 1

test save-chan-2 {save -chan -format pdf writes PDF bytes} -body {
    set ctx [tclmcairo::new 200 200]
    $ctx clear 1 1 1
    $ctx rect 20 20 160 160 -fill {0.8 0.2 0.2}
    set f [file join /tmp test_chan_[pid].pdf]
    set ch [open $f wb]
    $ctx save -chan $ch -format pdf
    close $ch
    $ctx destroy
    set hdr [read [set fh [open $f rb]] 5]; close $fh
    file delete -force $f
    string match "%PDF*" $hdr
} -result 1

test save-chan-3 {save -chan -format svg writes SVG bytes} -body {
    set ctx [tclmcairo::new 100 100]
    $ctx clear 1 1 1
    $ctx circle 50 50 40 -stroke {0 0 1} -width 2
    set f [file join /tmp test_chan_[pid].svg]
    set ch [open $f wb]
    $ctx save -chan $ch -format svg
    close $ch
    $ctx destroy
    set hdr [read [set fh [open $f r]] 20]; close $fh
    file delete -force $f
    expr {[string match "*xml*" $hdr] || [string match "*svg*" $hdr] || [string length $hdr] > 5}
} -result 1

test save-chan-4 {save -chan -format png from vector context} -body {
    set ctx [tclmcairo::new 100 100 -mode vector]
    $ctx rect 10 10 80 80 -fill {0.5 0.8 0.3}
    set f [file join /tmp test_chan_vec_[pid].png]
    set ch [open $f wb]
    $ctx save -chan $ch -format png
    close $ch
    $ctx destroy
    set sz [file size $f]
    file delete -force $f
    expr {$sz > 100}
} -result 1

test save-chan-6 {save -chan read-only channel gives error} -body {
    set ctx [tclmcairo::new 100 100]
    $ctx clear 0.5 0.5 0.5
    set f [file join /tmp test_chan_ro_[pid].pdf]
    # Create file first, then open read-only
    close [open $f w]
    set ch [open $f rb]
    set err ""
    catch { $ctx save -chan $ch -format pdf } err
    close $ch
    $ctx destroy
    file delete -force $f
    string match "*not writable*" $err
} -result 1

test save-chan-7 {save -chan text-mode channel produces valid PDF} -body {
    set ctx [tclmcairo::new 100 100]
    $ctx clear 1 1 1
    $ctx circle 50 50 30 -fill {0.2 0.5 1}
    set f [file join /tmp test_chan_txt_[pid].pdf]
    set ch [open $f w]   ;# text mode — should be auto-fixed to binary
    $ctx save -chan $ch -format pdf
    close $ch
    $ctx destroy
    # Valid PDF starts with %PDF
    set hdr [read [set fh [open $f rb]] 5]; close $fh
    file delete -force $f
    string match "%PDF*" $hdr
} -result 1

# ================================================================
cleanupTests
