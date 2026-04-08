# pkgIndex.tcl.in -- wird durch ./configure zu pkgIndex.tcl
#
# Release layout (all files in same directory):
#   pkgIndex.tcl
#   tclmcairo-0.2.tm    TclOO wrapper + loader
#   libtclmcairo.so                   Linux
#   libtclmcairo.dylib                macOS
#   tclmcairo.dll                     Windows

if {![package vsatisfies [package provide Tcl] 8.6-]} { return }

package ifneeded tclmcairo 0.2 \
    [list source [file join $dir tcl tclmcairo-0.2.tm]]
