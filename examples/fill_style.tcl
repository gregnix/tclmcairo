source [file join [file dirname [file normalize [info script]]] _header.tcl]
set PI 3.14159265358979

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

$cr set_line_width 6
# Top: even-odd
$cr rect 12 12 232 70 -stroke {0 0 0} -width 6
$cr new_sub_path; $cr arc 64  47 40 0 360
$cr new_sub_path; $cr arc_negative 192 47 40 0 -360

$cr set_fill_rule evenodd
$cr set_source_rgb 0 0.7 0
$cr fill_preserve
$cr set_source_rgb 0 0 0; $cr stroke

# Bottom: winding
$cr transform -translate 0 128
$cr rect 12 12 232 70 -stroke {0 0 0} -width 6
$cr new_sub_path; $cr arc 64  47 40 0 360
$cr new_sub_path; $cr arc_negative 192 47 40 0 -360

$cr set_fill_rule winding
$cr set_source_rgb 0 0 0.9
$cr fill_preserve
$cr set_source_rgb 0 0 0; $cr stroke

sample_save $cr fill_style
