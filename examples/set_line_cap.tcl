source [file join [file dirname [file normalize [info script]]] _header.tcl]

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1
$cr set_source_rgb 0 0 0
$cr set_line_width 30.0

$cr set_line_cap butt
$cr move_to  64.0 50.0; $cr line_to  64.0 200.0; $cr stroke

$cr set_line_cap round
$cr move_to 128.0 50.0; $cr line_to 128.0 200.0; $cr stroke

$cr set_line_cap square
$cr move_to 192.0 50.0; $cr line_to 192.0 200.0; $cr stroke

# helping lines
$cr set_source_rgb 1 0.2 0.2
$cr set_line_width 2.56
$cr move_to  64.0 50.0;  $cr line_to  64.0 200.0
$cr move_to 128.0 50.0;  $cr line_to 128.0 200.0
$cr move_to 192.0 50.0;  $cr line_to 192.0 200.0
$cr stroke

sample_save $cr set_line_cap
