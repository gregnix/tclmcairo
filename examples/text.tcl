source [file join [file dirname [file normalize [info script]]] _header.tcl]
set PI 3.14159265358979

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

$cr set_source_rgb 0 0 0
$cr text 10 135 "Hello" -font "Sans Bold 90" -color {0 0 0}

# "void" as outlined text
$cr text 70 165 "void" -font "Sans Bold 90" \
    -fill {0.5 0.5 1} -stroke {0 0 0} -width 2.56 -outline 1

# helping lines: anchor points
$cr set_source_rgba 1 0.2 0.2 0.6
$cr arc 10 135 5 0 360; $cr fill
$cr arc 70 165 5 0 360; $cr fill

sample_save $cr text
