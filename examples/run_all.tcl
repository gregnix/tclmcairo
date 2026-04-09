#!/usr/bin/env tclsh
# Run all Cairo sample ports and report results
set dir [file dirname [file normalize [info script]]]

set samples {
    arc arc_negative clip curve_to dash
    fill_and_stroke fill_style gradient
    multi_segment_caps rounded_rectangle
    set_line_cap set_line_join
    text text_align_center text_extents
}

set ok 0; set fail 0
foreach s $samples {
    set f [file join $dir ${s}.tcl]
    if {[catch {exec [info nameofexecutable] $f} err]} {
        puts "FAIL $s: $err"
        incr fail
    } else {
        puts "OK   $s"
        incr ok
    }
}
puts "\n$ok OK, $fail FAILED"
