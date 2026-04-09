source [file join [file dirname [file normalize [info script]]] _header.tcl]
set PI 3.14159265358979

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

# Linear gradient: white top to black bottom
$cr gradient_linear lin 0 0 0 256 {{0 1 1 1 1} {1 0 0 0 1}}
$cr set_source -gradient lin
$cr move_to 0 0; $cr line_to 256 0
$cr line_to 256 256; $cr line_to 0 256; $cr close_path
$cr fill

# Radial gradient (tclmcairo: cx cy r — no separate focal point)
$cr gradient_radial rad 128 128 76.8 {{0 1 1 1 1} {1 0 0 0 1}}
$cr set_source -gradient rad
$cr arc 128 128 76.8 0 360
$cr fill

sample_save $cr gradient
