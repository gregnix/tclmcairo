source [file join [file dirname [file normalize [info script]]] _header.tcl]
set PI 3.14159265358979

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

set utf8 "cairo"
set m [$cr font_measure $utf8 "Sans 52"]
set mw [lindex $m 0]; set mh [lindex $m 1]

set x [expr {128.0 - $mw/2.0}]
set y [expr {128.0 + $mh/2.0}]

$cr set_source_rgb 0 0 0
$cr text $x $y $utf8 -font "Sans 52" -color {0 0 0} -anchor sw

# helping lines
$cr set_source_rgba 1 0.2 0.2 0.6
$cr set_line_width 6.0
$cr arc $x $y 10.0 0 360; $cr fill
$cr move_to 128 0;   $cr rel_line_to 0 256
$cr move_to 0 128.0; $cr rel_line_to 256 0
$cr set_line_width 2
$cr stroke

sample_save $cr text_align_center
