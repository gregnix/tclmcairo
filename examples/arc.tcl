source [file join [file dirname [file normalize [info script]]] _header.tcl]
set PI 3.14159265358979

set xc 128.0; set yc 128.0; set radius 100.0
set a1 45.0;  set a2 180.0

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

# Main arc
$cr arc $xc $yc $radius $a1 $a2 -stroke {0 0 0} -width 10

# Center dot (helping)
$cr circle $xc $yc 10 -fill {1 0.2 0.2 0.6}

# Radii (helping)
set hcol {1 0.2 0.2 0.6}
$cr line $xc $yc \
    [expr {$xc + $radius*cos($a1*$PI/180)}] \
    [expr {$yc + $radius*sin($a1*$PI/180)}] \
    -color $hcol -width 6

$cr line $xc $yc \
    [expr {$xc + $radius*cos($a2*$PI/180)}] \
    [expr {$yc + $radius*sin($a2*$PI/180)}] \
    -color $hcol -width 6

sample_save $cr arc
