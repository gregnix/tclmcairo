# Common setup for all Cairo sample ports
set dir [file dirname [file normalize [info script]]]
set libdir [file dirname $dir]
if {[info exists env(TCLMCAIRO_LIBDIR)]} {
    set libdir $env(TCLMCAIRO_LIBDIR)
}
tcl::tm::path add [file join $libdir tcl]
set env(TCLMCAIRO_LIBDIR) $libdir
package require tclmcairo

proc sample_save {cr name} {
    set out [file join [file dirname [info script]] ${name}.png]
    $cr save $out
    $cr destroy
    puts "  -> $out ([file size $out] bytes)"
}
