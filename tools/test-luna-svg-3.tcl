package require tclmcairo
package require svg2cairo

proc cleanOutput {dir} {
    foreach pattern [list "*-luna.png" "*-svg2cairo.png" "error.log"] {
        foreach file [glob -nocomplain -directory $dir $pattern] {
            file delete -force $file
            puts "geloescht: $file"
        }
    }
}

proc createpng {dir {scale 2.0}} {
    cleanOutput $dir

    set files [glob -nocomplain -directory $dir *.svg]

    if {[llength $files] == 0} {
        puts "Keine SVG-Dateien in $dir gefunden"
        return
    }

    set logfile [file join $dir error.log]

    set lf [open $logfile w]
    puts $lf "SVG Render Error Log"
    puts $lf "Directory: $dir"
    puts $lf "Timestamp: [clock format [clock seconds]]"
    puts $lf ""
    close $lf

    foreach file $files {
        puts $file

        if {[catch {
            lassign [svg2cairo::size $file] sw sh

            if {$sw <= 0 || $sh <= 0} {
                error "ungueltige SVG-Groesse: ${sw}x${sh}"
            }

            set width  [expr {int($sw * $scale)}]
            set height [expr {int($sh * $scale)}]
            set base   [file rootname $file]

            set ctx [tclmcairo::new $width $height]
            $ctx svg_file_luna $file 0 0 -width $width -height $height
            $ctx save "${base}-luna.png"
            $ctx destroy
            puts "luna   $file: OK"

            set ctx [tclmcairo::new $width $height]
            svg2cairo::render $ctx $file -scale $scale
            $ctx save "${base}-svg2cairo.png"
            $ctx destroy
            puts "svg2c  $file: OK"

            puts ""
        } msg opts]} {
            puts stderr "FEHLER bei $file: $msg"

            set lf [open $logfile a]
            puts $lf "----------------------------------------"
            puts $lf "Datei: $file"
            puts $lf "Fehler: $msg"
            puts $lf ""
            puts $lf "Stacktrace:"
            puts $lf [dict get $opts -errorinfo]
            puts $lf ""
            close $lf
        }
    }

    puts "Fehlerprotokoll geschrieben: $logfile"
}

#createpng "./demos/decode"
#createpng "./demos/vgs"
#https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/
#createpng "./demos/w3org"
