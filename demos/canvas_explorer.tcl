#!/usr/bin/env wish
# canvas_explorer.tcl — Interaktiver Canvas/Cairo-Explorer
#
# Zeigt alle Tk-Canvas-Item-Typen mit:
#   - Live-Optionen
#   - Tk-Canvas-Vorschau (links)
#   - canvas2cairo PNG-Export-Vorschau (rechts)
#   - Generierter Tcl-Code (unten)
#   - Status: OK / ANDERS / FEHLT

package require Tk 8.6

set _dir [file dirname [file normalize [info script]]]
set _tcl [file join $_dir .. tcl]
tcl::tm::path add $_tcl
if {[info exists env(TCLMCAIRO_LIBDIR)]} {
    lappend auto_path $env(TCLMCAIRO_LIBDIR)
    tcl::tm::path add $env(TCLMCAIRO_LIBDIR)
}
unset _dir _tcl
package require tclmcairo
package require canvas2cairo

# ================================================================
# Status
# ================================================================
namespace eval ::ce {
    variable canvas_left  ""
    variable canvas_right ""
    variable current_item ""
    variable option_vars
    array set option_vars {}
    variable preview_size 220
    variable export_img   ""
}

array set ::ce::status_color {
    ok "#006600"  partial "#cc8800"  different "#cc5500"  missing "#cc0000"
}
array set ::ce::status_label {
    ok "✔ OK"  partial "~ Teilweise"  different "! Anders"  missing "✗ Fehlt"
}
array set ::ce::status_bg {
    ok "#e8ffe8"  partial "#fff8e0"  different "#fff0e0"  missing "#ffe8e8"
}

# ================================================================
# Draw procs — each item type has a named proc
# ================================================================

proc ::ce::draw_rectangle {c w h fill outline width dash radius} {
    set d [expr {$dash eq "none" ? {} : $dash}]
    if {$d ne {}} {
        $c create rectangle 20 20 [expr {$w-20}] [expr {$h-20}] \
            -fill $fill -outline $outline -width $width -dash $d
    } else {
        $c create rectangle 20 20 [expr {$w-20}] [expr {$h-20}] \
            -fill $fill -outline $outline -width $width
    }
}
proc ::ce::code_rectangle {fill outline width dash radius} {
    set d [expr {$dash eq "none" ? {} : $dash}]
    if {$d ne {}} {
        return ".c create rectangle 20 20 200 200 \\\n    -fill $fill -outline $outline -width $width -dash {$d}"
    } else {
        return ".c create rectangle 20 20 200 200 \\\n    -fill $fill -outline $outline -width $width"
    }
}

proc ::ce::draw_oval {c w h fill outline width} {
    set cx [expr {$w/2}]; set cy [expr {$h/2}]
    $c create oval [expr {$cx-80}] [expr {$cy-60}] \
                   [expr {$cx+80}] [expr {$cy+60}] \
        -fill $fill -outline $outline -width $width
}
proc ::ce::code_oval {fill outline width} {
    return ".c create oval 30 50 190 170 \\\n    -fill $fill -outline $outline -width $width"
}

proc ::ce::draw_line {c w h fill width smooth arrow capstyle dash} {
    set pts [list 20 [expr {$h*0.7}] \
                 [expr {$w*0.3}] [expr {$h*0.2}] \
                 [expr {$w*0.6}] [expr {$h*0.7}] \
                 [expr {$w-20}]  [expr {$h*0.3}]]
    set d [expr {$dash eq "none" ? {} : $dash}]
    set opts [list -fill $fill -width $width -capstyle $capstyle]
    if {$smooth} { lappend opts -smooth 1 }
    if {$arrow ne "none"} { lappend opts -arrow $arrow }
    if {$d ne {}} { lappend opts -dash $d }
    $c create line {*}$pts {*}$opts
}
proc ::ce::code_line {fill width smooth arrow capstyle dash} {
    set d [expr {$dash eq "none" ? {} : $dash}]
    set s "-fill $fill -width $width -capstyle $capstyle"
    if {$smooth} { append s " -smooth 1" }
    if {$arrow ne "none"} { append s " -arrow $arrow" }
    if {$d ne {}} { append s " -dash {$d}" }
    return ".c create line 20 140 80 40 160 140 210 60 \\\n    $s"
}

proc ::ce::draw_polygon {c w h fill outline width smooth} {
    set cx [expr {$w/2}]; set cy [expr {$h/2}]
    set pts {}
    for {set i 0} {$i < 6} {incr i} {
        set a [expr {$i * 3.14159 / 3.0 - 3.14159/2}]
        lappend pts [expr {$cx + 80*cos($a)}] [expr {$cy + 70*sin($a)}]
    }
    set opts [list -fill $fill -outline $outline -width $width]
    if {$smooth} { lappend opts -smooth 1 }
    $c create polygon {*}$pts {*}$opts
}
proc ::ce::code_polygon {fill outline width smooth} {
    set s "-fill $fill -outline $outline -width $width"
    if {$smooth} { append s " -smooth 1" }
    return ".c create polygon 110 20 190 70 190 150 110 200 30 150 30 70 \\\n    $s"
}

proc ::ce::draw_arc {c w h fill outline width start extent style} {
    set cx [expr {$w/2}]; set cy [expr {$h/2}]
    $c create arc [expr {$cx-80}] [expr {$cy-70}] \
                  [expr {$cx+80}] [expr {$cy+70}] \
        -start $start -extent $extent -style $style \
        -fill $fill -outline $outline -width $width
}
proc ::ce::code_arc {fill outline width start extent style} {
    return ".c create arc 30 40 190 180 \\\n    -start $start -extent $extent -style $style \\\n    -fill $fill -outline $outline -width $width"
}

proc ::ce::draw_text {c w h text fill size bold italic angle anchor} {
    set f "Helvetica $size"
    if {$bold}   { append f " bold" }
    if {$italic} { append f " italic" }
    $c create text [expr {$w/2}] [expr {$h/2}] \
        -text $text -fill $fill -font $f -angle $angle -anchor $anchor
}
proc ::ce::code_text {text fill size bold italic angle anchor} {
    set f "Helvetica $size"
    if {$bold}   { append f " bold" }
    if {$italic} { append f " italic" }
    return ".c create text 110 110 \\\n    -text \"$text\" -fill $fill \\\n    -font {$f} -angle $angle -anchor $anchor"
}

proc ::ce::draw_line_smooth {c w h width smooth} {
    set pts [list 20 [expr {$h-30}] \
                 [expr {$w*0.25}] 30 \
                 [expr {$w*0.5}]  [expr {$h-30}] \
                 [expr {$w*0.75}] 30 \
                 [expr {$w-20}]   [expr {$h-30}]]
    $c create line {*}$pts -fill "#cc3300" -width $width -smooth $smooth
    $c create line {*}$pts -fill "#0055aa" -width 1 -smooth 0
    $c create text 10 12 -text "Rot: Smooth" -fill "#cc3300" -anchor nw -font "Helvetica 8"
    $c create text 10 24 -text "Blau: Gerade" -fill "#0055aa" -anchor nw -font "Helvetica 8"
}
proc ::ce::code_line_smooth {width smooth} {
    return ".c create line 20 190 60 30 110 190 160 30 210 190 \\\n    -fill #cc3300 -width $width -smooth $smooth"
}

proc ::ce::draw_dash_styles {c w h width style} {
    set y 20
    if {$style eq "shorthand"} {
        foreach {pat lbl col} {
            .    "."   "#0055aa"
            -    "-"   "#006600"
            -.   "-."  "#cc3300"
            -..  "-.." "#880088"
        } {
            $c create line 10 $y [expr {$w-50}] $y \
                -fill $col -width $width -dash $pat
            $c create text [expr {$w-45}] $y -text $lbl \
                -font "Courier 9" -fill $col -anchor w
            incr y 40
        }
        $c create text 10 [expr {$h-12}] \
            -text "Kurznotation" -font "Helvetica 8 italic" -fill "#888" -anchor w
    } else {
        foreach {pat lbl col} {
            {4 2}     "{4 2}"     "#0055aa"
            {8 3}     "{8 3}"     "#006600"
            {8 3 2 3} "{8 3 2 3}" "#cc3300"
            {4 2 1 2} "{4 2 1 2}" "#880088"
        } {
            $c create line 10 $y [expr {$w-65}] $y \
                -fill $col -width $width -dash $pat
            $c create text [expr {$w-63}] $y -text $lbl \
                -font "Courier 8" -fill $col -anchor w
            incr y 40
        }
    }
}
proc ::ce::code_dash_styles {width style} {
    if {$style eq "shorthand"} {
        return ".c create line 10 20 160 20 -fill #0055aa -width $width -dash ."
    } else {
        return ".c create line 10 20 160 20 -fill #0055aa -width $width -dash {4 2}"
    }
}

proc ::ce::draw_active_states {c w h state} {
    set hw [expr {$w/2-10}]
    $c create rectangle 20 30 $hw [expr {$h-30}] \
        -fill "#b3d1f0" -outline "#0055aa" \
        -activefill "#ffee88" -activeoutline "#cc8800" \
        -width 2 -state $state
    $c create text [expr {$hw/2+10}] [expr {$h/2}] \
        -text "Normal:\n#b3d1f0\nActive:\n#ffee88" \
        -font "Helvetica 8" -anchor center
    $c create rectangle [expr {$w/2+10}] 30 [expr {$w-20}] [expr {$h-30}] \
        -fill "#cccccc" -outline "#888888" \
        -disabledfill "#eeeeee" -disabledoutline "#aaaaaa" \
        -width 1 -state disabled
    $c create text [expr {$w*0.75+5}] [expr {$h/2}] \
        -text "disabled" -font "Helvetica 9" -fill "#888" -anchor center
    $c create text [expr {$w/2}] [expr {$h-12}] \
        -text "Cairo: immer 'normal' Zustand" \
        -font "Helvetica 8 italic" -fill "#cc3300" -anchor center
}
proc ::ce::code_active_states {state} {
    return ".c create rectangle 20 30 100 190 \\\n    -fill #b3d1f0 -activefill #ffee88 \\\n    -state $state"
}

proc ::ce::draw_image_item {c w h size anchor} {
    if {![info exists ::ce_testimg($size)]} {
        set img [image create photo -width $size -height $size]
        for {set row 0} {$row < $size} {incr row} {
            for {set col 0} {$col < $size} {incr col} {
                set r [expr {int(255*$col/$size.0)}]
                set g [expr {int(255*$row/$size.0)}]
                set b [expr {int(200 - 100*($col+$row)/(2.0*$size))}]
                $img put [format "#%02x%02x%02x" $r $g $b] -to $col $row
            }
        }
        set ::ce_testimg($size) $img
    }
    $c create image [expr {$w/2}] [expr {$h/2}] \
        -image $::ce_testimg($size) -anchor $anchor
}
proc ::ce::code_image_item {size anchor} {
    return "set img \[image create photo -file bild.png\]\n.c create image 110 110 \\\n    -image \$img -anchor $anchor"
}

proc ::ce::draw_stipple {c w h stipple fill} {
    $c create rectangle 20 20 [expr {$w/2-10}] [expr {$h-20}] \
        -fill $fill -stipple $stipple -outline "#003399"
    $c create text [expr {$w/4+5}] [expr {$h/2}] \
        -text "Stipple:\n$stipple" -font "Helvetica 9" \
        -fill white -anchor center
    $c create rectangle [expr {$w/2+10}] 20 [expr {$w-20}] [expr {$h-20}] \
        -fill $fill -outline "#003399"
    $c create text [expr {$w*0.75+5}] [expr {$h/2}] \
        -text "Solid\n(Cairo)" -font "Helvetica 9" \
        -fill white -anchor center
}
proc ::ce::code_stipple {stipple fill} {
    return ".c create rectangle 20 20 100 190 \\\n    -fill $fill -stipple $stipple"
}

proc ::ce::draw_window_item {c w h} {
    catch {destroy $c.b}
    button $c.b -text "Tk Button" -relief raised \
        -bg "#e0e8ff" -pady 4 -padx 12
    $c create window [expr {$w/2}] [expr {$h/2-20}] \
        -window $c.b -anchor center
    $c create text [expr {$w/2}] [expr {$h/2+30}] \
        -text "Tk-Widget — im Export übersprungen" \
        -font "Helvetica 9 italic" -fill "#cc3300" -anchor center
}
proc ::ce::code_window_item {} {
    return ".c create window 110 100 \\\n    -window \$button_widget"
}

proc ::ce::draw_z_order {c w h order} {
    if {$order eq "normal"} {
        $c create rectangle 20 20 120 120 -fill "#cc3300" -outline ""
        $c create rectangle 60 60 160 160 -fill "#0055aa" -outline ""
        $c create rectangle 100 100 200 200 -fill "#006600" -outline ""
        $c create text [expr {$w/2}] [expr {$h-12}] \
            -text "Rot → Blau → Grün (normal)" \
            -font "Helvetica 8" -fill "#333" -anchor center
    } else {
        $c create rectangle 20 20 120 120 -fill "#cc3300" -outline ""
        set b [$c create rectangle 60 60 160 160 -fill "#0055aa" -outline ""]
        $c create rectangle 100 100 200 200 -fill "#006600" -outline ""
        $c lower $b
        $c create text [expr {$w/2}] [expr {$h-12}] \
            -text "Blau unter Rot (nach lower)" \
            -font "Helvetica 8" -fill "#333" -anchor center
    }
}
proc ::ce::code_z_order {order} {
    return ".c create rectangle 20 20 120 120 -fill #cc3300\n.c create rectangle 60 60 160 160 -fill #0055aa\n# raise/lower wirkt auf Cairo-Export!"
}

# ================================================================
# Item-Definitionen — nur Metadaten, draw/code als proc-Namen
# ================================================================
set ::ce::items {
    rectangle {
        label "Rectangle" status ok
        note "Vollständig unterstützt. -dash, -width, -outline, -fill korrekt."
        options {
            fill    {color  "#b3d1f0"  "Füllfarbe"}
            outline {color  "#0055aa"  "Rahmenfarbe"}
            width   {scale  2  1 8    "Rahmenstärke"}
            dash    {choice "none"  {none . - -. {4 2} {8 3 2 3}}  "Strichmuster"}
            radius  {scale  0  0 30   "Eckenradius (info)"}
        }
        draw_opts {fill outline width dash radius}
    }
    oval {
        label "Oval / Circle" status ok
        note "Korrekt. Tk verwendet Bounding-Box, Cairo zeichnet Ellipse."
        options {
            fill    {color  "#ffcccc"  "Füllfarbe"}
            outline {color  "#cc0000"  "Rahmenfarbe"}
            width   {scale  2  1 8    "Rahmenstärke"}
        }
        draw_opts {fill outline width}
    }
    line {
        label "Line" status ok
        note "Einfache Linien OK. -smooth wird als gerade Segmente exportiert. -arrow OK."
        options {
            fill     {color  "#0055aa"  "Farbe"}
            width    {scale  2  1 12   "Breite"}
            smooth   {check  0          "Smooth (Bezier)"}
            arrow    {choice "none" {none first last both} "Pfeilspitzen"}
            capstyle {choice "butt" {butt round projecting} "Linienende"}
            dash     {choice "none"  {none . - -. {4 2} {8 3 2 3}}  "Strichmuster"}
        }
        draw_opts {fill width smooth arrow capstyle dash}
    }
    polygon {
        label "Polygon" status ok
        note "Korrekt. -smooth raw wird exportiert."
        options {
            fill    {color  "#ddeeff"  "Füllfarbe"}
            outline {color  "#003399"  "Rahmenfarbe"}
            width   {scale  2  1 8    "Rahmenstärke"}
            smooth  {check  0          "Smooth"}
        }
        draw_opts {fill outline width smooth}
    }
    arc {
        label "Arc" status ok
        note "Alle -style Varianten (pieslice, chord, arc) korrekt exportiert."
        options {
            fill    {color  "#ffd0a0"  "Füllfarbe"}
            outline {color  "#cc6600"  "Rahmenfarbe"}
            width   {scale  2  1 8    "Rahmenstärke"}
            start   {scale  45  0 360  "Start-Winkel"}
            extent  {scale  270 10 360 "Bogen-Umfang"}
            style   {choice "pieslice" {pieslice chord arc} "Stil"}
        }
        draw_opts {fill outline width start extent style}
    }
    text {
        label "Text" status ok
        note "Text-Export OK. -angle wird exportiert. -underline geht verloren."
        options {
            text    {entry  "Canvas Text"  "Text"}
            fill    {color  "#000000"      "Farbe"}
            size    {scale  14  6 32       "Schriftgröße"}
            bold    {check  0              "Fett"}
            italic  {check  0              "Kursiv"}
            angle   {scale  0  0 360       "Winkel"}
            anchor  {choice "center" {n ne e se s sw w nw center} "Anker"}
        }
        draw_opts {text fill size bold italic angle anchor}
    }
    line_smooth {
        label "Line -smooth" status different
        note "ACHTUNG: -smooth 1 (Bezier) in Tk anders als in Cairo! Cairo exportiert als gerade Segmente."
        options {
            width  {scale  2  1 8   "Breite"}
            smooth {choice "1" {0 1 raw} "Smooth-Modus"}
        }
        draw_opts {width smooth}
    }
    dash_styles {
        label "Dash-Stile" status different
        note "Canvas-Kurznotation (. - -.) kann in Cairo abweichen."
        options {
            width {scale  2  1 8   "Breite"}
            style {choice "pattern" {pattern shorthand} "Modus"}
        }
        draw_opts {width style}
    }
    active_states {
        label "Active/Disabled States" status different
        note "ACHTUNG: -activefill etc. Tk-spezifisch. Cairo exportiert immer normalen Zustand."
        options {
            state {choice "normal" {normal active disabled} "Zustand"}
        }
        draw_opts {state}
    }
    image_item {
        label "Image Item" status ok
        note "Photo-Images werden korrekt als Bitmap exportiert."
        options {
            size   {scale  60 20 120  "Bildgröße"}
            anchor {choice "center" {n center s w e} "Anker"}
        }
        draw_opts {size anchor}
    }
    stipple {
        label "Stipple (Muster)" status missing
        note "FEHLT: -stipple wird in canvas2cairo ignoriert. Flächen erscheinen solid."
        options {
            stipple {choice "gray25" {gray12 gray25 gray50 gray75} "Stipple"}
            fill    {color "#0055aa" "Farbe"}
        }
        draw_opts {stipple fill}
    }
    window_item {
        label "Window Item" status missing
        note "FEHLT: Eingebettete Tk-Widgets können nicht exportiert werden."
        options {}
        draw_opts {}
    }
    z_order {
        label "Z-Order / Stacking" status ok
        note "Z-Order wird korrekt übertragen. raise/lower wirkt auf Cairo-Export."
        options {
            order {choice "normal" {normal reversed} "Reihenfolge"}
        }
        draw_opts {order}
    }
}

# ================================================================
# UI
# ================================================================
proc ::ce::buildUI {} {
    variable preview_size

    wm title . "Canvas/Cairo Explorer"
    wm geometry . "1100x720"

    ttk::frame .top
    ttk::frame .main
    ttk::frame .bottom
    pack .top    -fill x
    pack .main   -fill both -expand 1
    pack .bottom -fill x

    # Toolbar
    ttk::label .top.lbl -text "Canvas Item:" -font {TkDefaultFont 10 bold}
    ttk::button .top.exp    -text "Cairo Export ⟳" -command ::ce::doExport
    ttk::button .top.expall -text "Alle exportieren" -command ::ce::exportAll
    pack .top.lbl    -side left  -padx 8 -pady 6
    pack .top.expall -side right -padx 6 -pady 6
    pack .top.exp    -side right -padx 6 -pady 6

    # Item-Liste
    ttk::frame .main.left -width 180
    pack .main.left -side left -fill y
    ttk::label .main.left.hdr -text "Item-Typen" \
        -font {TkDefaultFont 9 bold} -background "#334466" \
        -foreground white -anchor w -padding {8 4}
    pack .main.left.hdr -fill x
    ttk::scrollbar .main.left.sb -orient vertical
    listbox .main.left.lb \
        -yscrollcommand {.main.left.sb set} \
        -selectmode single -font {TkDefaultFont 10} \
        -width 20 -relief flat -borderwidth 0 \
        -selectbackground "#4a7aaa" -selectforeground white \
        -background "#f5f5f5"
    .main.left.sb configure -command {.main.left.lb yview}
    pack .main.left.sb -side right -fill y
    pack .main.left.lb -fill both -expand 1

    foreach {key def} $::ce::items {
        set lbl [dict get $def label]
        set st  [dict get $def status]
        .main.left.lb insert end $lbl
        .main.left.lb itemconfigure end \
            -foreground $::ce::status_color($st)
    }
    bind .main.left.lb <<ListboxSelect>> ::ce::onItemSelect

    # Previews
    ttk::frame .main.center
    pack .main.center -fill both -expand 1

    ttk::frame .main.center.tk
    pack .main.center.tk -side left -fill both -expand 1 -padx 8 -pady 8
    ttk::label .main.center.tk.hdr \
        -text "Tk Canvas (Screen)" \
        -font {TkDefaultFont 10 bold} -foreground "#0055aa"
    pack .main.center.tk.hdr -fill x
    canvas .main.center.tk.c \
        -width $preview_size -height $preview_size \
        -background white -relief sunken -borderwidth 2
    pack .main.center.tk.c

    ttk::frame .main.center.cairo
    pack .main.center.cairo -side left -fill both -expand 1 -padx 8 -pady 8
    ttk::label .main.center.cairo.hdr \
        -text "Cairo Export (PNG)" \
        -font {TkDefaultFont 10 bold} -foreground "#cc6600"
    pack .main.center.cairo.hdr -fill x
    label .main.center.cairo.img \
        -width $preview_size -height $preview_size \
        -background "#f0f0f0" -relief sunken -borderwidth 2 \
        -text "← Klick 'Cairo Export'" \
        -font {TkDefaultFont 9 italic} -foreground "#888888"
    pack .main.center.cairo.img
    ttk::label .main.center.cairo.diff -text "" -font {TkDefaultFont 9}
    pack .main.center.cairo.diff -pady 4

    # Optionen
    ttk::frame .main.right -width 220
    pack .main.right -side right -fill y -padx 4
    ttk::label .main.right.hdr \
        -text "Optionen" \
        -font {TkDefaultFont 9 bold} -background "#334466" \
        -foreground white -anchor w -padding {8 4}
    pack .main.right.hdr -fill x
    ttk::frame .main.right.opts
    pack .main.right.opts -fill both -expand 1 -padx 4 -pady 4
    ttk::frame .main.right.status
    pack .main.right.status -fill x -padx 4 -pady 4

    # Code
    ttk::frame .bottom.code
    pack .bottom.code -fill both -expand 1 -padx 8 -pady 4
    ttk::label .bottom.code.hdr -text "Tcl Code:" \
        -font {TkDefaultFont 9 bold}
    pack .bottom.code.hdr -anchor w
    text .bottom.code.t -height 4 -font {Courier 10} \
        -background "#1a1a2e" -foreground "#c8d8f0" \
        -relief flat -borderwidth 4 -wrap word -state disabled
    pack .bottom.code.t -fill both -expand 1

    # Legende
    ttk::frame .bottom.legend
    pack .bottom.legend -fill x -padx 8 -pady 2
    foreach st {ok different missing} {
        ttk::label .bottom.legend.$st \
            -text $::ce::status_label($st) \
            -foreground $::ce::status_color($st) \
            -background $::ce::status_bg($st) \
            -font {TkDefaultFont 9} -padding {6 2}
        pack .bottom.legend.$st -side left -padx 4
    }

    .main.left.lb selection set 0
    ::ce::onItemSelect
}

# ================================================================
# Item auswählen
# ================================================================
proc ::ce::onItemSelect {} {
    set sel [.main.left.lb curselection]
    if {$sel eq ""} return
    set key [lindex [dict keys $::ce::items] $sel]
    set def [dict get $::ce::items $key]
    set ::ce::current_item $key
    showItem $key $def
}

proc ::ce::showItem {key def} {
    variable option_vars
    set status [dict get $def status]
    set note   [dict get $def note]

    # Status-Box
    foreach w [winfo children .main.right.status] { destroy $w }
    ttk::label .main.right.status.lbl \
        -text $::ce::status_label($status) \
        -foreground $::ce::status_color($status) \
        -background $::ce::status_bg($status) \
        -font {TkDefaultFont 10 bold} -padding {6 4}
    pack .main.right.status.lbl -fill x
    ttk::label .main.right.status.note \
        -text $note -wraplength 200 \
        -font {TkDefaultFont 8} -foreground "#444" -justify left
    pack .main.right.status.note -fill x -pady 4

    # Optionen
    foreach w [winfo children .main.right.opts] { destroy $w }
    array unset option_vars
    set options [dict get $def options]
    set row 0
    foreach {optname optdef} $options {
        lassign $optdef type default
        set lbl [lindex $optdef end]
        set ::ce::option_vars($optname) $default

        ttk::label .main.right.opts.l$row \
            -text "$lbl:" -font {TkDefaultFont 9} -anchor w
        grid .main.right.opts.l$row -row $row -column 0 -sticky w -pady 2

        switch $type {
            scale {
                lassign $optdef _ default min max lbl
                set ::ce::option_vars($optname) $default
                ttk::scale .main.right.opts.w$row \
                    -from $min -to $max \
                    -variable ::ce::option_vars($optname) \
                    -orient horizontal \
                    -command [list ::ce::onOptionChange $key]
                grid .main.right.opts.w$row -row $row -column 1 -sticky ew
            }
            check {
                ttk::checkbutton .main.right.opts.w$row \
                    -variable ::ce::option_vars($optname) \
                    -command [list ::ce::onOptionChange $key ""]
                grid .main.right.opts.w$row -row $row -column 1 -sticky w
            }
            choice {
                lassign $optdef _ default choices lbl
                set ::ce::option_vars($optname) $default
                ttk::combobox .main.right.opts.w$row \
                    -textvariable ::ce::option_vars($optname) \
                    -values $choices -state readonly -width 12
                bind .main.right.opts.w$row <<ComboboxSelected>> \
                    [list ::ce::onOptionChange $key ""]
                grid .main.right.opts.w$row -row $row -column 1 -sticky ew
            }
            color {
                frame .main.right.opts.w$row -width 24 -height 24 \
                    -background $default -relief sunken -borderwidth 2
                bind .main.right.opts.w$row <Button-1> \
                    [list ::ce::pickColor $optname $key .main.right.opts.w$row]
                grid .main.right.opts.w$row -row $row -column 1 -sticky w -pady 2
            }
            entry {
                ttk::entry .main.right.opts.w$row \
                    -textvariable ::ce::option_vars($optname) \
                    -width 14
                bind .main.right.opts.w$row <Return>   \
                    [list ::ce::onOptionChange $key ""]
                bind .main.right.opts.w$row <FocusOut> \
                    [list ::ce::onOptionChange $key ""]
                grid .main.right.opts.w$row -row $row -column 1 -sticky ew
            }
        }
        incr row
    }
    grid columnconfigure .main.right.opts 1 -weight 1
    drawTk $key $def
    updateCode $key $def
}

proc ::ce::pickColor {optname key frm} {
    set c [tk_chooseColor -initialcolor $::ce::option_vars($optname)]
    if {$c ne ""} {
        set ::ce::option_vars($optname) $c
        $frm configure -background $c
        onOptionChange $key ""
    }
}

proc ::ce::onOptionChange {key args} {
    set def [dict get $::ce::items $key]
    drawTk $key $def
    updateCode $key $def
}

proc ::ce::drawTk {key def} {
    variable preview_size
    variable option_vars
    set c .main.center.tk.c
    $c delete all

    set draw_opts [dict get $def draw_opts]
    set cmd [list ::ce::draw_${key} $c $preview_size $preview_size]
    foreach p $draw_opts {
        lappend cmd $option_vars($p)
    }
    if {[catch {uplevel #0 $cmd} err]} {
        $c create text [expr {$preview_size/2}] [expr {$preview_size/2}] \
            -text "Fehler:\n$err" -fill red -anchor center \
            -font {Helvetica 9}
    }
}

proc ::ce::updateCode {key def} {
    variable option_vars
    set draw_opts [dict get $def draw_opts]
    set cmd [list ::ce::code_${key}]
    foreach p $draw_opts {
        lappend cmd $option_vars($p)
    }
    if {[catch {uplevel #0 $cmd} code]} {
        set code "# Fehler: $code"
    }
    .bottom.code.t configure -state normal
    .bottom.code.t delete 1.0 end
    .bottom.code.t insert end $code
    .bottom.code.t configure -state disabled
}

# ================================================================
# Export
# ================================================================
proc ::ce::doExport {} {
    variable preview_size
    variable export_img
    set key $::ce::current_item
    if {$key eq ""} return
    set def [dict get $::ce::items $key]
    drawTk $key $def
    set c .main.center.tk.c
    update idletasks

    set tmpf "/tmp/ce_export_[pid].png"
    if {[catch { canvas2cairo::export $c $tmpf } err]} {
        catch { .main.center.cairo.diff configure \
            -text "Export-Fehler: $err" -foreground "#cc0000" }
        return
    }

    catch { image delete $export_img }
    if {[catch { set export_img [image create photo -file $tmpf] } err]} {
        catch { .main.center.cairo.diff configure \
            -text "Bild-Fehler: $err" -foreground "#cc0000" }
        return
    }

    set ow [image width  $export_img]
    set oh [image height $export_img]
    if {$ow > $preview_size || $oh > $preview_size} {
        set scaled [image create photo]
        $scaled copy $export_img -subsample \
            [expr {max(1, int(ceil(double($ow)/$preview_size)))}] \
            [expr {max(1, int(ceil(double($oh)/$preview_size)))}]
        image delete $export_img
        set export_img $scaled
    }

    .main.center.cairo.img configure -image $export_img -text ""

    set status [dict get $def status]
    set msgs {
        ok        "✔ Cairo-Export identisch"
        different "! Unterschiede möglich — vergleichen!"
        missing   "✗ Feature fehlt im Export"
        partial   "~ Teilweise exportiert"
    }
    catch { .main.center.cairo.diff configure \
        -text [dict get $msgs $status] \
        -foreground $::ce::status_color($status) }
}

proc ::ce::exportAll {} {
    tk_messageBox -message "Export aller Items nach /tmp/ce_all_*.png" -type ok
    foreach {key def} $::ce::items {
        set tmpf "/tmp/ce_all_${key}.png"
        # draw to offscreen canvas
        set c [canvas .ce_tmp_$key -width 220 -height 220 -background white]
        set draw_opts [dict get $def draw_opts]
        set cmd [list ::ce::draw_${key} $c 220 220]
        foreach p $draw_opts {
            set optdef [dict get [dict get $def options] $p]
            lappend cmd [lindex $optdef 1]
        }
        catch { uplevel #0 $cmd }
        update idletasks
        catch { canvas2cairo::export $c $tmpf }
        catch { destroy $c }
    }
    tk_messageBox -message "Exportiert nach /tmp/ce_all_*.png" -type ok
}

# ================================================================
# Main
# ================================================================
::ce::buildUI
after 300 ::ce::doExport
