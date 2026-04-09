source [file join [file dirname [file normalize [info script]]] _header.tcl]
set PI 3.14159265358979

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

# Clip to circle using SVG arc path
set r 76.8; set cx 128; set cy 128
$cr push
$cr clip_path "M [expr {$cx+$r}] $cy \
    A $r $r 0 1 0 [expr {$cx-$r}] $cy \
    A $r $r 0 1 0 [expr {$cx+$r}] $cy Z"

# Fill black rectangle
$cr set_source_rgb 0 0 0
$cr move_to 0 0; $cr line_to 256 0
$cr line_to 256 256; $cr line_to 0 256; $cr close_path
$cr fill

# Green diagonals
$cr set_source_rgb 0 1 0
$cr set_line_width 10
$cr move_to 0 0;   $cr line_to 256 256; $cr stroke
$cr move_to 256 0; $cr line_to 0 256;   $cr stroke
$cr pop

sample_save $cr clip
