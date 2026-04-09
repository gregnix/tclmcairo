source [file join [file dirname [file normalize [info script]]] _header.tcl]

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

# tclmcairo has built-in -radius for rect:
$cr rect 25.6 25.6 204.8 204.8 -radius 20.48 \
    -fill {0.5 0.5 1} -stroke {0.5 0 0 0.5} -width 10.0

sample_save $cr rounded_rectangle
