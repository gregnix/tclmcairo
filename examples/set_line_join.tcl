source [file join [file dirname [file normalize [info script]]] _header.tcl]

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1
$cr set_source_rgb 0 0 0

# miter (top)
$cr set_line_width 40.96
$cr set_line_join miter
$cr move_to  76.8  84.48
$cr rel_line_to  51.2 -51.2
$cr rel_line_to  51.2  51.2
$cr stroke

# bevel (middle)
$cr set_line_join bevel
$cr move_to  76.8 161.28
$cr rel_line_to  51.2 -51.2
$cr rel_line_to  51.2  51.2
$cr stroke

# round (bottom)
$cr set_line_join round
$cr move_to  76.8 238.08
$cr rel_line_to  51.2 -51.2
$cr rel_line_to  51.2  51.2
$cr stroke

sample_save $cr set_line_join
