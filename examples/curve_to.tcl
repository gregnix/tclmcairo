source [file join [file dirname [file normalize [info script]]] _header.tcl]

set x  25.6;  set y  128.0
set x1 102.4; set y1 230.4
set x2 153.6; set y2  25.6
set x3 230.4; set y3 128.0

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

$cr move_to  $x  $y
$cr curve_to $x1 $y1 $x2 $y2 $x3 $y3
$cr set_source_rgb 0 0 0
$cr set_line_width 10.0
$cr stroke

# Control lines
set hcol {1 0.2 0.2 0.6}
$cr line $x $y $x1 $y1 -color $hcol -width 6
$cr line $x2 $y2 $x3 $y3 -color $hcol -width 6

# Control points
foreach {px py} [list $x $y $x1 $y1 $x2 $y2 $x3 $y3] {
    $cr circle $px $py 5 -fill $hcol
}

sample_save $cr curve_to
