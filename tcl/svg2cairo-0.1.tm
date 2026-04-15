# svg2cairo-0.1.tm  (tclmcairo 0.3.4)
#
# SVG → tclmcairo Renderer via tDOM
#
# Strategie:
#   - SVG ohne <style>: nanosvg zeichnet Shapes (C, schnell)
#   - SVG mit <style>:  tDOM zeichnet alles (CSS korrekt)
#   - Text/tspan:       tDOM-Pass immer
#   - textPath:         Fallback — Text am Pfad-Startpunkt
#
# Unterstützte CSS-Selektoren: tag, .class, #id
# Unterstützte CSS-Properties: fill, stroke, stroke-width, stroke-opacity,
#   font-size, font-family, font-weight, font-style, text-anchor, opacity
# CSS-Farbnamen: 50 W3C-Farben (schwarz, weiß, rot, grün, blau, orange,
#   yellow, cyan, transparent, ... vollständige Liste in _colorToRGB)
#
# API:
#   svg2cairo::render      $ctx filename ?options?
#   svg2cairo::render_data $ctx svgstring ?options?
#   svg2cairo::size        filename   -> {width height}
#   svg2cairo::has_text    filename   -> 0|1
#
# Optionen für render/render_data:
#   -x      x-Offset (default 0)
#   -y      y-Offset (default 0)
#   -width  Zielbreite  (default: SVG width/viewBox)
#   -height Zielhöhe    (default: SVG height/viewBox)
#   -scale  Skalierung  (default: auto aus width/height)
#   -text   1|0  Text zeichnen (default 1)
#   -shapes 1|0  Shapes zeichnen (default 1)
#
# Bekannte Einschränkungen:
#   - <textPath>: Fallback am Pfad-Startpunkt (kein Text-auf-Pfad)
#   - Gradienten: nur via nanosvg (nicht im tDOM-Pass)
#   - <filter>, <mask>, <symbol>: nicht im tDOM-Pass
#   - Für vollständiges SVG: $ctx svg_file_luna (lunasvg, HAVE_LUNASVG)
#
# Requires: tclmcairo, tdom
# License: BSD 2-Clause  Author: gregnix

package provide svg2cairo 0.1

package require tclmcairo

namespace eval ::svg2cairo {
    namespace export render render_data size has_text
}

# ================================================================
# Hauptfunktionen
# ================================================================

proc ::svg2cairo::render {ctx filename args} {
    if {![file exists $filename]} {
        error "svg2cairo: file not found: $filename"
    }
    set fd [open $filename r]
    fconfigure $fd -encoding utf-8
    set data [read $fd]
    close $fd
    # Strip DOCTYPE before parsing
    set data [regsub {<!DOCTYPE[^>]*>} $data ""]
    render_data $ctx $data {*}$args
}

proc ::svg2cairo::render_data {ctx svgdata args} {
    array set opts {
        -x 0  -y 0
        -width  -1  -height -1  -scale -1
        -text   1   -shapes  1
    }
    foreach {k v} $args { set opts($k) $v }

    # Wenn CSS <style> vorhanden: nanosvg überspringen
    # (nanosvg ignoriert CSS → falsche Farben)
    # tDOM-Pass zeichnet Shapes mit korrekten CSS-Farben
    set hasStyle [expr {[string first "<style" $svgdata] >= 0}]

    # Shapes via nanosvg (nur wenn kein CSS)
    if {$opts(-shapes) && !$hasStyle} {
        # <defs>...</defs> entfernen: nanosvg rendert Marker-Paths aus <defs>
        # fälschlicherweise als normale Shapes (→ unerwünschte Linien)
        # string-Methode statt regsub (kein \s\S nötig, Tcl 8.6 kompatibel)
        set svgdata_nano $svgdata
        set _s [string first "<defs" $svgdata_nano]
        set _e [string first "</defs>" $svgdata_nano]
        if {$_s >= 0 && $_e >= 0} {
            set svgdata_nano [string replace $svgdata_nano $_s [expr {$_e + 6}] {}]
        }
        set sopts {}
        if {$opts(-width)  > 0} { lappend sopts -width  $opts(-width) }
        if {$opts(-height) > 0} { lappend sopts -height $opts(-height) }
        if {$opts(-scale)  > 0} { lappend sopts -scale  $opts(-scale) }
        if {[catch {$ctx svg_data $svgdata_nano $opts(-x) $opts(-y) {*}$sopts} _err]} {
            # nanosvg kann das SVG nicht parsen
        }
    }
    # tDOM-Pass: Text + CSS-Shapes
    set needTdom [expr {$opts(-text) || ($opts(-shapes) && $hasStyle)}]
    if {$needTdom} {
        if {[catch {package require tdom}]} {
            # tDOM nicht verfügbar — nanosvg ohne CSS
            if {$hasStyle} {
                set sopts {}
                if {$opts(-width)  > 0} { lappend sopts -width  $opts(-width) }
                if {$opts(-height) > 0} { lappend sopts -height $opts(-height) }
                if {$opts(-scale)  > 0} { lappend sopts -scale  $opts(-scale) }
                catch {$ctx svg_data $svgdata $opts(-x) $opts(-y) {*}$sopts}
            }
            return
        }
        _renderElements $ctx $svgdata $opts(-x) $opts(-y) \
            $opts(-width) $opts(-height) $opts(-scale)
    }
}

# ================================================================
# tDOM-basierter Renderer
# ================================================================

# Parse CSS <style> block -> dict of tag->properties
# Keys: "tag", ".class", "#id"
# Uses raw SVG string — tDOM asText is unreliable for CDATA/style content
proc ::svg2cairo::_parseStyleSheet {doc} {
    set css {}
    # Get raw SVG from doc
    catch {
        set svgraw [$doc asXML]
    }
    if {![info exists svgraw]} { return $css }
    _parseStyleString $svgraw css
    return $css
}

proc ::svg2cairo::_parseStyleFromData {svgdata} {
    set css {}
    _parseStyleString $svgdata css
    return $css
}

proc ::svg2cairo::_parseStyleString {svgdata cssVar} {
    upvar 1 $cssVar css
    # Extract content of all <style> blocks
    set allcss ""
    foreach {_ block} [regexp -all -inline {<style[^>]*>(.*?)</style>} $svgdata] {
        append allcss " " $block
    }
    if {$allcss eq ""} return
    # Normalize
    set txt [regsub -all {\s+} $allcss " "]
    # Find selector { block } pairs
    set pat {([\#\.]?[a-zA-Z][a-zA-Z0-9_-]*)[ \t]*\{}
    set pos 0
    while {[regexp -start $pos -indices $pat $txt m sm]} {
        set sel [string trim [string range $txt [lindex $sm 0] [lindex $sm 1]]]
        set bstart [expr {[lindex $m 1] + 1}]
        set depth 1; set bpos $bstart
        while {$depth > 0 && $bpos < [string length $txt]} {
            set ch [string index $txt $bpos]
            if {$ch eq "\{"} { incr depth }
            if {$ch eq "\}"} { incr depth -1 }
            incr bpos
        }
        set block [string range $txt $bstart [expr {$bpos - 2}]]
        set props {}
        foreach part [split $block ";"] {
            set part [string trim $part]
            if {[regexp {^([^:]+):(.+)$} $part -> k v]} {
                dict set props [string trim $k] [string trim $v]
            }
        }
        dict set css $sel $props
        set pos $bpos
    }
}

# Get CSS properties for a node (tag + class + id)
proc ::svg2cairo::_cssForNode {node css} {
    set props {}
    # Tag selector
    set tag [lindex [split [$node nodeName] :] end]
    if {[dict exists $css $tag]} {
        set props [_mergeStyle $props [dict get $css $tag]]
    }
    # Class selector(s)
    set cls [$node getAttribute class ""]
    foreach c [split $cls " "] {
        set c [string trim $c]
        if {$c ne "" && [dict exists $css ".$c"]} {
            set props [_mergeStyle $props [dict get $css ".$c"]]
        }
    }
    # ID selector
    set id [$node getAttribute id ""]
    if {$id ne "" && [dict exists $css "#$id"]} {
        set props [_mergeStyle $props [dict get $css "#$id"]]
    }
    return $props
}

proc ::svg2cairo::_renderElements {ctx svgdata ox oy req_w req_h scale} {
    # Strip DOCTYPE — tDOM tries to fetch DTD which may fail
    set rawsvg $svgdata
    set svgdata [regsub {<!DOCTYPE[^>]*>} $svgdata ""]
    if {[catch {set doc [dom parse $svgdata]} err]} {
        return  ;# kein valides XML
    }
    set root [$doc documentElement]

    # SVG-Dimensionen + Skalierung berechnen
    lassign [_svgDims $root] svgw svgh vx vy vw vh
    lassign [_calcScale $svgw $svgh $vw $vh $req_w $req_h $scale] sx sy

    # CSS aus raw SVG-String parsen (zuverlässiger als tDOM asText)
    set css [_parseStyleFromData $rawsvg]

    # Alle Elemente durchgehen
    _renderNode $ctx $root $ox $oy $sx $sy {} $css

    $doc delete
}

proc ::svg2cairo::_svgDims {root} {
    set w  [_attrNum $root width  0]
    set h  [_attrNum $root height 0]
    set vb [$root getAttribute viewBox ""]
    if {$vb ne ""} {
        lassign $vb vx vy vw vh
    } else {
        set vx 0; set vy 0
        set vw [expr {$w > 0 ? $w : 100}]
        set vh [expr {$h > 0 ? $h : 100}]
    }
    list $w $h $vx $vy $vw $vh
}

proc ::svg2cairo::_calcScale {svgw svgh vw vh req_w req_h scale} {
    if {$scale > 0} { return [list $scale $scale] }
    if {$req_w > 0 && $vw > 0} { set sx [expr {$req_w / double($vw)}] } \
    else { set sx 1.0 }
    if {$req_h > 0 && $vh > 0} { set sy [expr {$req_h / double($vh)}] } \
    else { set sy $sx }
    list $sx $sy
}

proc ::svg2cairo::_renderNode {ctx node ox oy sx sy parentStyle {css {}}} {
    # Nur Element-Knoten verarbeiten (keine Text-, Comment-, PI-Knoten)
    if {[$node nodeType] ne "ELEMENT_NODE"} { return }

    set _nn [$node nodeName]
    set tag [lindex [split $_nn :] end]

    # Eigene Styles sammeln: CSS-Match + direkte Attribute
    # CSS muss hier einbezogen werden damit <g id='x'>-Regeln
    # als parentStyle an Kinder weitergegeben werden
    set nodecss [_cssForNode $node $css]
    set style   [_mergeStyle $parentStyle $nodecss]
    set style   [_mergeStyle $style [_nodeStyle $node]]

    switch $tag {
        svg - g {
            # Transform auswerten
            lassign [_nodeTransform $node $sx $sy] tx ty tsx tsy
            foreach child [$node childNodes] {
                _renderNode $ctx $child \
                    [expr {$ox + $tx}] [expr {$oy + $ty}] \
                    [expr {$sx * $tsx}] [expr {$sy * $tsy}] \
                    $style $css
            }
        }
        text {
            _renderText $ctx $node $ox $oy $sx $sy $style $css
        }
        tspan { }
        rect - circle - ellipse - line - polyline - polygon - path {
            # Shapes: CSS-Styling via tDOM (nanosvg ignoriert <style>)
            _renderShape $ctx $node $tag $ox $oy $sx $sy $style $css
        }
    }
}

# ================================================================
# Shape-Rendering via tDOM (ergänzt nanosvg mit CSS-Farben)
# ================================================================
proc ::svg2cairo::_renderShape {ctx node tag ox oy sx sy parentStyle css} {
    # CSS + direkte Node-Attribute zusammenführen
    set cssprops  [_cssForNode $node $css]
    # Wenn kein CSS-Match UND nanosvg hat bereits gerendert (hasStyle=0) → überspringen
    # Wenn hasStyle=1: nanosvg wurde übersprungen → alle Shapes hier rendern (auch ohne CSS-Match)
    if {[dict size $cssprops] == 0 && [dict size $css] > 0} {
        # CSS vorhanden aber kein Match für diesen Node → nanosvg hat es nicht → SVG-Default
    } elseif {[dict size $cssprops] == 0 && [dict size $css] == 0} {
        # Kein CSS überhaupt → nanosvg hat alle Shapes bereits korrekt gerendert
        return
    }
    set nodeprops [_nodeStyle $node]
    set merged [_mergeStyle $parentStyle $cssprops]
    set merged [_mergeStyle $merged $nodeprops]

    set fill    [_styleVal $merged fill    "black"]
    set stroke  [_styleVal $merged stroke  ""]
    set lw      [_styleVal $merged stroke-width 1]
    set opacity [_styleVal $merged opacity 1.0]
    set rx      [_attrNum $node rx 0]
    set ry      [_attrNum $node ry $rx]

    # stroke-width: strip px
    regexp {^([\d.]+)} $lw -> lw
    set lw [expr {double($lw) * $sx}]

    # Farben
    set fopts {}
    set sopts {}
    if {$fill ne "" && $fill ne "none"} {
        lappend fopts -fill [_colorToRGB $fill $opacity]
    }
    if {$stroke ne "" && $stroke ne "none"} {
        set sop [_styleVal $merged stroke-opacity 1.0]
        lappend sopts -stroke [_colorToRGB $stroke $sop] -width $lw
    }
    set dopts [concat $fopts $sopts]
    if {[llength $dopts] == 0} return

    switch $tag {
        rect {
            set x [expr {$ox + [_attrNum $node x 0] * $sx}]
            set y [expr {$oy + [_attrNum $node y 0] * $sy}]
            set w [expr {[_attrNum $node width  0] * $sx}]
            set h [expr {[_attrNum $node height 0] * $sy}]
            set r [expr {$rx * $sx}]
            $ctx rect $x $y $w $h {*}$dopts -radius $r
        }
        circle {
            set cx [expr {$ox + [_attrNum $node cx 0] * $sx}]
            set cy [expr {$oy + [_attrNum $node cy 0] * $sy}]
            set r  [expr {[_attrNum $node r 0] * $sx}]
            $ctx circle $cx $cy $r {*}$dopts
        }
        ellipse {
            set cx [expr {$ox + [_attrNum $node cx 0] * $sx}]
            set cy [expr {$oy + [_attrNum $node cy 0] * $sy}]
            set rx2 [expr {[_attrNum $node rx 0] * $sx}]
            set ry2 [expr {[_attrNum $node ry 0] * $sy}]
            $ctx ellipse $cx $cy $rx2 $ry2 {*}$dopts
        }
        line {
            set x1 [expr {$ox + [_attrNum $node x1 0] * $sx}]
            set y1 [expr {$oy + [_attrNum $node y1 0] * $sy}]
            set x2 [expr {$ox + [_attrNum $node x2 0] * $sx}]
            set y2 [expr {$oy + [_attrNum $node y2 0] * $sy}]
            if {$stroke ne "" && $stroke ne "none"} {
                $ctx line $x1 $y1 $x2 $y2 -color [_colorToRGB $stroke $opacity] -width $lw
            }
        }
        path {
            set d [$node getAttribute d ""]
            if {$d ne ""} {
                # push/pop (cairo_save/restore) — CTM korrekt setzen ohne Akkumulation
                # cairo_transform multipliziert — daher push/scale/translate/pop
                $ctx push
                if {$ox != 0 || $oy != 0} { $ctx transform -translate $ox $oy }
                if {$sx != 1.0 || $sy != 1.0} { $ctx transform -scale $sx $sy }
                $ctx path $d {*}$dopts
                $ctx pop
            }
        }
    }
}

# ================================================================
# Text-Rendering
# ================================================================

proc ::svg2cairo::_renderText {ctx node ox oy sx sy style {css {}}} {
    set x    [expr {$ox + [_attrNum $node x 0] * $sx}]
    set y    [expr {$oy + [_attrNum $node y 0] * $sy}]

    # Style-Attribute — CSS-Stylesheet zuerst, dann direkte Attribute
    set tagcss {}
    if {[dict exists $css text]} { set tagcss [dict get $css text] }
    set merged [_mergeStyle $style $tagcss]
    set merged [_mergeStyle $merged [_nodeStyle $node]]
    set fs     [_styleVal $merged font-size    12]
    set ff     [_styleVal $merged font-family  "Sans"]
    set fw     [_styleVal $merged font-weight  "normal"]
    set fi     [_styleVal $merged font-style   "normal"]
    set fill   [_styleVal $merged fill         "black"]
    set anchor [_styleVal $merged text-anchor  "start"]
    set opacity [_styleVal $merged opacity     1.0]

    # font-size skalieren
    if {[string match "*px" $fs]} {
        set fs [expr {[string trimright $fs "px"] * $sy}]
    } elseif {[string match "*pt" $fs]} {
        set fs [expr {[string trimright $fs "pt"] * $sy * 1.333}]
    } else {
        set fs [expr {double($fs) * $sy}]
    }
    if {$fs < 4} { set fs 4 }

    # Font-String zusammenbauen
    set fontstr "$ff"
    if {$fw eq "bold"} { append fontstr " Bold" }
    if {$fi eq "italic"} { append fontstr " Italic" }
    append fontstr " [expr {int($fs)}]"

    # Farbe
    set col [_colorToRGB $fill $opacity]

    # Anchor → tclmcairo anchor
    set anc [_textAnchor $anchor]

    # Nur direkten Textinhalt rendern (nicht rekursiv via asText)
    # asText gibt auch Kinder-Inhalte zurück → textPath-Text würde doppelt erscheinen
    set txt ""
    foreach tchild [$node childNodes] {
        if {[$tchild nodeType] eq "TEXT_NODE"} {
            append txt [$tchild nodeValue]
        }
    }
    set txt [string trim $txt]
    if {$txt ne ""} {
        $ctx text $x $y $txt -font $fontstr -color $col -anchor $anc
    }

    # tspan + textPath Kinder
    foreach child [$node childNodes] {
        set ctag [lindex [split [$child nodeName] :] end]
        if {$ctag eq "tspan"} {
            _renderTspan $ctx $child $x $y $sx $sy $merged $fontstr $col $anc
        } elseif {$ctag eq "textPath"} {
            # textPath: Text auf Pfad — Fallback: Text an Pfad-Startpunkt
            set ctxt ""
            catch {set ctxt [$child asText]}
            if {$ctxt eq ""} { catch {set ctxt [$child text]} }
            set ctxt [string trim $ctxt]
            if {$ctxt ne ""} {
                # Pfad-Startpunkt aus href-Referenz holen
                set href [$child getAttribute href ""]
                if {$href eq ""} {
                    catch {set href [$child getAttribute "xlink:href" ""]}
                }
                set px $x; set py $y
                if {$href ne ""} {
                    set pid [string trimleft $href "#"]
                    catch {
                        set doc [[$child ownerDocument] documentElement]
                        foreach pnode [$doc selectNodes //*\[@id='$pid'\]] {
                            set d [$pnode getAttribute d ""]
                            # Erster M-Befehl: M x,y
                            if {[regexp {M\s*([\d.]+)[,\s]+([\d.]+)} $d -> mx my]} {
                                set px [expr {$ox + $mx * $sx}]
                                set py [expr {$oy + $my * $sy}]
                            }
                        }
                    }
                }
                $ctx text $px $py $ctxt -font $fontstr -color $col -anchor sw
            }
        }
    }
}

proc ::svg2cairo::_renderTspan {ctx node px py sx sy parentStyle pfont pcol panc} {
    set x [expr {[_attrNum $node x -999999] != -999999 ?
        $px + [_attrNum $node x 0] * $sx : $px}]
    set y [expr {[_attrNum $node y -999999] != -999999 ?
        $py + [_attrNum $node y 0] * $sy : $py}]
    set dx [expr {[_attrNum $node dx 0] * $sx}]
    set dy [expr {[_attrNum $node dy 0] * $sy}]

    set merged [_mergeStyle $parentStyle [_nodeStyle $node]]
    set fill [_styleVal $merged fill ""]
    set col  [expr {$fill ne "" ? [_colorToRGB $fill 1.0] : $pcol}]

    set txt ""
    catch {set txt [$node asText]}
    if {$txt eq ""} { catch {set txt [$node text]} }
    set txt [string trim $txt]
    if {$txt ne ""} {
        $ctx text [expr {$x + $dx}] [expr {$y + $dy}] $txt \
            -font $pfont -color $col -anchor $panc
    }
}

# ================================================================
# Transform-Parser
# ================================================================

proc ::svg2cairo::_nodeTransform {node sx sy} {
    set tf [$node getAttribute transform ""]
    set tx 0.0; set ty 0.0; set tsx 1.0; set tsy 1.0
    if {$tf eq ""} { return [list $tx $ty $tsx $tsy] }

    # translate(x,y) oder translate(x y)
    if {[regexp {translate\(\s*([\-\d.]+)[,\s]+([\-\d.]+)\s*\)} $tf -> ttx tty]} {
        set tx [expr {$ttx * $sx}]
        set ty [expr {$tty * $sy}]
    } elseif {[regexp {translate\(\s*([\-\d.]+)\s*\)} $tf -> ttx]} {
        set tx [expr {$ttx * $sx}]
    }

    # scale(x,y) oder scale(x)
    if {[regexp {scale\(\s*([\-\d.]+)[,\s]+([\-\d.]+)\s*\)} $tf -> ssx ssy]} {
        set tsx $ssx; set tsy $ssy
    } elseif {[regexp {scale\(\s*([\-\d.]+)\s*\)} $tf -> ss]} {
        set tsx $ss; set tsy $ss
    }

    list $tx $ty $tsx $tsy
}

# ================================================================
# Style-Hilfsfunktionen
# ================================================================

proc ::svg2cairo::_nodeStyle {node} {
    set style {}

    # style="..." parsen
    set styleattr [$node getAttribute style ""]
    if {$styleattr ne ""} {
        foreach part [split $styleattr ";"] {
            set part [string trim $part]
            if {[regexp {^([^:]+):\s*(.+)$} $part -> k v]} {
                dict set style [string trim $k] [string trim $v]
            }
        }
    }

    # Direkte Attribute
    foreach attr {fill stroke stroke-width stroke-opacity font-size font-family font-weight
                  font-style text-anchor opacity fill-opacity} {
        set v [$node getAttribute $attr ""]
        if {$v ne ""} { dict set style $attr $v }
    }

    return $style
}

proc ::svg2cairo::_mergeStyle {parent child} {
    set merged $parent
    dict for {k v} $child { dict set merged $k $v }
    return $merged
}

proc ::svg2cairo::_styleVal {style key default} {
    if {[dict exists $style $key]} { return [dict get $style $key] }
    return $default
}

# ================================================================
# Farb-Konvertierung
# ================================================================

proc ::svg2cairo::_colorToRGB {color {alpha 1.0}} {
    # CSS-Farbnamen (vollständige W3C-Liste der gebräuchlichsten)
    set named {
        black        {0 0 0}
        white        {1 1 1}
        red          {1 0 0}
        green        {0 0.502 0}
        blue         {0 0 1}
        yellow       {1 1 0}
        orange       {1 0.647 0}
        cyan         {0 1 1}
        aqua         {0 1 1}
        magenta      {1 0 1}
        fuchsia      {1 0 1}
        lime         {0 1 0}
        maroon       {0.502 0 0}
        navy         {0 0 0.502}
        olive        {0.502 0.502 0}
        purple       {0.502 0 0.502}
        teal         {0 0.502 0.502}
        silver       {0.753 0.753 0.753}
        gray         {0.502 0.502 0.502}
        grey         {0.502 0.502 0.502}
        darkgray     {0.663 0.663 0.663}
        darkgrey     {0.663 0.663 0.663}
        lightgray    {0.827 0.827 0.827}
        lightgrey    {0.827 0.827 0.827}
        darkred      {0.545 0 0}
        darkgreen    {0 0.392 0}
        darkblue     {0 0 0.545}
        pink         {1 0.753 0.796}
        hotpink      {1 0.412 0.706}
        deeppink     {1 0.078 0.576}
        coral        {1 0.498 0.314}
        tomato       {1 0.388 0.278}
        salmon       {0.98 0.502 0.447}
        gold         {1 0.843 0}
        khaki        {0.941 0.902 0.549}
        violet       {0.933 0.51 0.933}
        indigo       {0.294 0 0.51}
        brown        {0.647 0.165 0.165}
        chocolate    {0.824 0.412 0.118}
        tan          {0.824 0.706 0.549}
        beige        {0.961 0.961 0.863}
        ivory        {1 1 0.941}
        lavender     {0.902 0.902 0.980}
        turquoise    {0.251 0.878 0.816}
        skyblue      {0.529 0.808 0.922}
        steelblue    {0.275 0.51 0.706}
        slategray    {0.439 0.502 0.565}
        slategrey    {0.439 0.502 0.565}
        crimson      {0.863 0.078 0.235}
        transparent  {0 0 0 0}
        none         {}
    }
    if {[dict exists $named $color]} {
        set rgb [dict get $named $color]
        if {$rgb eq {}} { return {0 0 0 0} }
        # transparent hat bereits alpha=0
        if {[llength $rgb] == 4} { return $rgb }
        return [list {*}$rgb $alpha]
    }

    # #rgb
    if {[regexp {^#([0-9a-fA-F]{3})$} $color -> h]} {
        set r [expr {("0x[string index $h 0][string index $h 0]" + 0) / 255.0}]
        set g [expr {("0x[string index $h 1][string index $h 1]" + 0) / 255.0}]
        set b [expr {("0x[string index $h 2][string index $h 2]" + 0) / 255.0}]
        return [list $r $g $b $alpha]
    }

    # #rrggbb
    if {[regexp {^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$} \
            $color -> rh gh bh]} {
        return [list \
            [expr {("0x$rh" + 0) / 255.0}] \
            [expr {("0x$gh" + 0) / 255.0}] \
            [expr {("0x$bh" + 0) / 255.0}] \
            $alpha]
    }

    # rgb(r,g,b)
    if {[regexp {^rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$} \
            $color -> r g b]} {
        return [list \
            [expr {$r / 255.0}] \
            [expr {$g / 255.0}] \
            [expr {$b / 255.0}] \
            $alpha]
    }

    # Fallback: schwarz
    return [list 0 0 0 $alpha]
}

proc ::svg2cairo::_textAnchor {anchor} {
    # SVG y-Koordinate ist Baseline — tclmcairo sw/s/se = Baseline
    switch $anchor {
        middle  { return s  }
        end     { return se }
        default { return sw }
    }
}

proc ::svg2cairo::_attrNum {node attr default} {
    set v [$node getAttribute $attr ""]
    if {$v eq ""} { return $default }
    # Einheit entfernen (px, pt, em, %)
    if {![regexp {^([\-\d.]+)} $v -> v]} { return $default }
    if {[string is double -strict $v]} { return $v }
    return $default
}

# ================================================================
# Hilfsfunktionen (öffentlich)
# ================================================================

proc ::svg2cairo::size {filename} {
    if {![file exists $filename]} { return {0 0} }
    set fd [open $filename r]
    fconfigure $fd -encoding utf-8
    set data [read $fd]; close $fd
    set data [regsub {<!DOCTYPE[^>]*>} $data ""]
    if {[catch {set doc [dom parse $data]}]} {
        # Fallback: regex
        if {[regexp {width=['"]([0-9.]+)} $data -> w] &&
            [regexp {height=['"]([0-9.]+)} $data -> h]} {
            return [list $w $h]
        }
        return {100 100}
    }
    set root [$doc documentElement]
    set w [_attrNum $root width  0]
    set h [_attrNum $root height 0]
    # Try viewBox if w/h are 0
    if {$w == 0 || $h == 0} {
        set vb [$root getAttribute viewBox ""]
        if {$vb ne ""} {
            lassign $vb _ _ w h
        }
    }
    $doc delete
    if {$w <= 0} { set w 100 }
    if {$h <= 0} { set h 100 }
    list $w $h
}

proc ::svg2cairo::has_text {filename} {
    if {![file exists $filename]} { return 0 }
    set fd [open $filename r]
    fconfigure $fd -encoding utf-8
    set data [read $fd]; close $fd
    expr {[string first "<text" $data] >= 0}
}
