#!/usr/bin/env tclsh
# gen_samples_md.tcl
# Generates examples/SAMPLES.md with embedded source code + images.
# Usage: tclsh gen_samples_md.tcl examples/

set dir [lindex $argv 0]
if {$dir eq ""} { set dir [file join [file dirname [info script]] .. examples] }
set dir [file normalize $dir]

array set desc {
    arc               "Arc with helping lines showing start/end angles and radii."
    arc_negative      "Counter-clockwise arc (`arc_negative`) with helping lines."
    clip              "Circular clip region: fill + diagonals clipped to a circle."
    curve_to          "Cubic Bézier curve with control point lines."
    dash              "Dashed path using `-dash` and `-dash_offset`."
    fill_and_stroke   "`fill_preserve` keeps the path for subsequent stroke."
    fill_style        "`evenodd` vs `winding` fill rule with `new_sub_path`."
    gradient          "Linear gradient (top→bottom) + radial gradient."
    multi_segment_caps "Three parallel lines with `round` line cap."
    rounded_rectangle "Rectangle with rounded corners via `-radius`."
    set_line_cap      "Comparison of `butt`, `round`, `square` line caps."
    set_line_join     "Comparison of `miter`, `bevel`, `round` line joins."
    text              "`show_text` + `text_path` (gradient fill, stroke outline)."
    text_align_center "Text centered using `font_measure` metrics."
    text_extents      "Bounding box from `font_measure` drawn around text."
}

array set cairo {
    arc               "`cairo_arc()` · `cairo_fill()`"
    arc_negative      "`cairo_arc_negative()`"
    clip              "`cairo_clip()` · `cairo_new_path()`"
    curve_to          "`cairo_curve_to()`"
    dash              "`cairo_set_dash()` · `cairo_rel_line_to()`"
    fill_and_stroke   "`cairo_fill_preserve()` · `cairo_stroke()`"
    fill_style        "`cairo_set_fill_rule()` · `cairo_new_sub_path()`"
    gradient          "`cairo_pattern_create_linear/radial()`"
    multi_segment_caps "`cairo_set_line_cap(ROUND)`"
    rounded_rectangle "`cairo_arc()` for corners (tclmcairo: `-radius`)"
    set_line_cap      "`cairo_set_line_cap()` — butt · round · square"
    set_line_join     "`cairo_set_line_join()` — miter · bevel · round"
    text              "`cairo_show_text()` · `cairo_text_path()`"
    text_align_center "`cairo_text_extents()`"
    text_extents      "`cairo_text_extents()` — bounding box"
}

proc read_source {path} {
    set f [open $path r]
    set lines [split [read $f] \n]
    close $f
    set result {}
    foreach l $lines {
        if {[string match "source *" $l]} continue
        if {[string match "sample_save *" $l]} continue
        lappend result $l
    }
    # trim leading/trailing blank lines
    while {[llength $result] && [string trim [lindex $result 0]] eq ""} {
        set result [lrange $result 1 end]
    }
    while {[llength $result] && [string trim [lindex $result end]] eq ""} {
        set result [lrange $result 0 end-1]
    }
    return [join $result \n]
}

# Header
puts "# tclmcairo — Cairo Samples"
puts ""
puts "Tcl ports of the official \[Cairo samples\](https://cairographics.org/samples/)."
puts "Original C code by Øyvind Kolås — **public domain**."
puts ""
puts "```bash"
puts "# Run all samples:"
puts "cd examples"
puts "TCLMCAIRO_LIBDIR=.. tclsh8.6 run_all.tcl"
puts ""
puts "# Single sample:"
puts "TCLMCAIRO_LIBDIR=.. tclsh8.6 arc.tcl   # -> arc.png"
puts "```"
puts ""
puts "---"
puts ""

# One section per sample
foreach name [lsort [array names desc]] {
    set tcl_file [file join $dir ${name}.tcl]
    set png_file ${name}.png
    if {![file exists $tcl_file]} continue

    set title [string map {_ " "} $name]
    set code  [read_source $tcl_file]

    puts "## $title"
    puts ""
    puts "!\[$name\]($png_file)"
    puts ""
    puts "$desc($name)"
    puts ""
    puts "*Cairo API: $cairo($name)*"
    puts ""
    puts "```tcl"
    puts $code
    puts "```"
    puts ""
    puts "---"
    puts ""
}
