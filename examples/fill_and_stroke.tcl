source [file join [file dirname [file normalize [info script]]] _header.tcl]
set PI 3.14159265358979

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

$cr move_to 128.0 25.6
$cr line_to 230.4 230.4
$cr rel_line_to -102.4 0.0
$cr curve_to 51.2 230.4 51.2 128.0 128.0 128.0
$cr close_path

$cr move_to 64.0 25.6
$cr rel_line_to 51.2 51.2
$cr rel_line_to -51.2 51.2
$cr rel_line_to -51.2 -51.2
$cr close_path

$cr set_line_width 10.0
$cr set_source_rgb 0 0 1
$cr fill_preserve
$cr set_source_rgb 0 0 0
$cr stroke

sample_save $cr fill_and_stroke
