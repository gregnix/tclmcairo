source [file join [file dirname [file normalize [info script]]] _header.tcl]
set PI 3.14159265358979

set cr [tclmcairo::new 256 256]
$cr clear 1 1 1

$cr set_source_rgb 0 0 0
$cr set_line_width 10.0
$cr move_to 128.0 25.6
$cr line_to 230.4 230.4
$cr rel_line_to -102.4 0.0
$cr curve_to 51.2 230.4 51.2 128.0 128.0 128.0
$cr set_line_width 10.0

# Dash: 50 ink, 10 skip, 10 ink, 10 skip — offset -50
# tclmcairo: -dash {50 10 10 10} -dash_offset -50
# But we use low-level stroke here:
tclmcairo set_source_rgb [$cr id] 0 0 0
# Apply dash via path options on a helper proc
set id [$cr id]
tclmcairo move_to  $id 128.0 25.6
tclmcairo line_to  $id 230.4 230.4
tclmcairo rel_line_to $id -102.4 0.0
tclmcairo curve_to $id 51.2 230.4 51.2 128.0 128.0 128.0

# Use $cr path for dash support:
$cr new_path
$cr path "M 128 25.6 L 230.4 230.4 l -102.4 0 C 51.2 230.4 51.2 128 128 128" \
    -stroke {0 0 0} -width 10 -dash {50 10 10 10} -dash_offset -50

sample_save $cr dash
