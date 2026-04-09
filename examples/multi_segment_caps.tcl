source [file join [file dirname [file normalize [info script]]] _header.tcl]

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

set col {0 0 0}
$cr set_source_rgb 0 0 0
$cr set_line_width 30.0
$cr set_line_cap round

$cr move_to  50.0  75.0; $cr line_to 200.0  75.0; $cr stroke
$cr move_to  50.0 125.0; $cr line_to 200.0 125.0; $cr stroke
$cr move_to  50.0 175.0; $cr line_to 200.0 175.0; $cr stroke

sample_save $cr multi_segment_caps
