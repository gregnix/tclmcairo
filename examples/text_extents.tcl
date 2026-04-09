source [file join [file dirname [file normalize [info script]]] _header.tcl]
set PI 3.14159265358979

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

set utf8 "cairo"
set m [$cr font_measure $utf8 "Sans 100"]
set mw [lindex $m 0]; set mh [lindex $m 1]
set asc [lindex $m 2]

set x 25.0; set y 150.0

$cr set_source_rgb 0 0 0
$cr text $x $y $utf8 -font "Sans 100" -color {0 0 0} -anchor sw

# bounding box
$cr set_source_rgba 1 0.2 0.2 0.6
$cr set_line_width 6.0
$cr arc $x $y 10.0 0 360; $cr fill

$cr move_to $x $y
$cr rel_line_to 0 [expr {-$mh}]
$cr rel_line_to $mw 0
$cr rel_line_to 0 $mh
$cr set_line_width 3
$cr stroke

# baseline dot
$cr arc $x $y 4 0 360; $cr fill

sample_save $cr text_extents
