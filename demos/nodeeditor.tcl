#!/usr/bin/env wish
# nodeeditor.tcl — Node Editor Demo for tclmcairo / canvas2cairo
#
# Demonstrates canvas2cairo in a real application:
#   - Tk Canvas as the drawing surface
#   - Export to SVG, PDF, PS, EPS via canvas2cairo
#   - Export region (crop) with rubber-band selection
#
# Features:
#   - Drag-and-drop node editing
#   - Port-to-port connections (drag from port dot to port dot)
#   - Orthogonal (Manhattan) edge routing
#   - Undo/Redo (Ctrl+Z / Ctrl+Y)
#   - Save/Load diagram (.dia format, Tcl-native)
#   - Export full diagram or selected region
#   - Double-click node to edit title/subtitle/color
#   - Click edge + Delete to remove connection
#   - Snap-to-grid (toggle with Ctrl+G or toolbar)
#   - Resize nodes by dragging bottom-right handle
#
# Usage:
#   wish nodeeditor.tcl
#
# Requirements:
#   package require tclmcairo     ;# Cairo binding
#   package require canvas2cairo
#   package require shape_renderer  ;# included in tclmcairo/tcl/
#
# Part of tclmcairo — https://github.com/gregnix/tclmcairo
# License: BSD

package require Tk 8.6

# Locate tclmcairo + tcl modules
set _ne_dir [file dirname [file normalize [info script]]]
set _ne_tcl [file join $_ne_dir .. tcl]
tcl::tm::path add $_ne_tcl
if {[info exists env(TCLMCAIRO_LIBDIR)]} {
    lappend auto_path $env(TCLMCAIRO_LIBDIR)
    tcl::tm::path add $env(TCLMCAIRO_LIBDIR)
}
unset _ne_dir _ne_tcl

package require tclmcairo
package require canvas2cairo
package require shape_renderer



namespace eval ::demo {
    variable data
    variable canvas
    variable statusVar    "Ready"
    variable selectedNode ""
    variable dragInfo
    variable zoom         1.0
    variable gridSize     40
    variable showGrid     1
    variable nodeCounter  0
    variable connectStart ""
    variable connectLine  ""
    variable popupX       0
    variable popupY       0
    variable undoStack    {}
    variable redoStack    {}
    variable currentFile  ""
    variable exportRect   ""    ;# {x1 y1 x2 y2} canvas coords, or ""
    variable exportMode   0     ;# 1 = user is drawing export rect
    variable shapeImages         ;# canvas photo images, key=nodeId
    array set shapeImages {}
    variable snapGrid     1     ;# snap-to-grid on/off
    variable resizeNode   ""    ;# node being resized
    variable resizeStart  {}    ;# {mx my origW origH}
    variable selectedEdge ""    ;# "from->to" tag of selected edge
}

# ============================================================
# Undo / Redo
# ============================================================
proc ::demo::pushUndo {} {
    variable data
    variable undoStack
    variable redoStack
    lappend undoStack $data
    if {[llength $undoStack] > 50} {
        set undoStack [lrange $undoStack end-49 end]
    }
    set redoStack {}
    updateUndoButtons
}

proc ::demo::undo {} {
    variable data
    variable undoStack
    variable redoStack
    if {![llength $undoStack]} return
    lappend redoStack $data
    set data       [lindex $undoStack end]
    set undoStack  [lrange $undoStack 0 end-1]
    drawAll
    updateUndoButtons
    set ::demo::statusVar "Undo"
}

proc ::demo::redo {} {
    variable data
    variable undoStack
    variable redoStack
    if {![llength $redoStack]} return
    lappend undoStack $data
    set data       [lindex $redoStack end]
    set redoStack  [lrange $redoStack 0 end-1]
    drawAll
    updateUndoButtons
    set ::demo::statusVar "Redo"
}

proc ::demo::updateUndoButtons {} {
    variable undoStack
    variable redoStack
    catch {
        .toolbar.undo state [expr {[llength $undoStack] ? "!disabled" : "disabled"}]
        .toolbar.redo state [expr {[llength $redoStack] ? "!disabled" : "disabled"}]
    }
}

# ============================================================
# Data model
# ============================================================
proc ::demo::newNodeId {} {
    variable nodeCounter
    incr nodeCounter
    return "node$nodeCounter"
}

proc ::demo::addNode {x y title subtitle color {type generic}} {
    variable data
    set id [newNodeId]
    # Node size based on type
    switch $type {
        router      -
        switch      -
        database    -
        workstation -
        accesspoint -
        wifi        -
        phone       { set w 120; set h 110 }
        server      -
        firewall    -
        printer     -
        scanner     { set w 130; set h 100 }
        fiber       { set w 150; set h 90  }
        building    { set w 130; set h 120 }
        table       { set w 160; set h 120 }
        default     { set w 180; set h 90  }
    }
    dict set data nodes $id [dict create \
        id $id x $x y $y w $w h $h \
        title $title subtitle $subtitle color $color type $type]
    return $id
}

proc ::demo::addEdge {fromPort toPort} {
    variable data
    dict lappend data edges [dict create from $fromPort to $toPort]
}

proc ::demo::getNode {id} {
    variable data
    return [dict get $data nodes $id]
}

proc ::demo::setNodeField {id field value} {
    variable data
    dict set data nodes $id $field $value
}

proc ::demo::allNodeIds {} {
    variable data
    if {![dict exists $data nodes]} { return {} }
    return [dict keys [dict get $data nodes]]
}

proc ::demo::allEdges {} {
    variable data
    if {![dict exists $data edges]} { return {} }
    return [dict get $data edges]
}

# ============================================================
# Port coordinates  (port = "nodeId:side")
# ============================================================
proc ::demo::portCoords {port} {
    lassign [split $port :] nodeId side
    set node [getNode $nodeId]
    dict with node {
        switch $side {
            left   { return [list $x              [expr {$y + $h/2.0}]] }
            right  { return [list [expr {$x + $w}] [expr {$y + $h/2.0}]] }
            top    { return [list [expr {$x + $w/2.0}] $y] }
            bottom { return [list [expr {$x + $w/2.0}] [expr {$y + $h}]] }
        }
    }
}

# ============================================================
# Orthogonal routing (Manhattan)
# ============================================================
proc ::demo::routeEdge {x1 y1 x2 y2 from to} {
    set side1 [lindex [split $from :] 1]
    set side2 [lindex [split $to   :] 1]
    set gap 30   ;# minimum clearance from port before turning

    # Horizontaler Ausgang (left/right)
    if {$side1 in {left right}} {
        set sign [expr {$side1 eq "right" ? 1 : -1}]
        # Genug Abstand vom Ausgangs-Node sicherstellen
        set exit [expr {$x1 + $sign * $gap}]
        # Wenn Ziel in gleicher oder Gegenrichtung: um den Node herumführen
        if {($side1 eq "right" && $x2 <= $exit) ||
            ($side1 eq "left"  && $x2 >= $exit)} {
            # U-Routing: raus, dann runter/hoch, dann rein
            set bypass [expr {$x1 + $sign * $gap}]
            set midy   [expr {($y1 + $y2) / 2.0}]
            return [list $x1 $y1  $bypass $y1  $bypass $midy  \
                         [expr {$x2 - $sign*$gap}] $midy  \
                         [expr {$x2 - $sign*$gap}] $y2  $x2 $y2]
        }
        set mid [expr {($x1 + $x2) / 2.0}]
        return [list $x1 $y1  $mid $y1  $mid $y2  $x2 $y2]
    }

    # Vertikaler Ausgang (top/bottom)
    if {$side1 in {top bottom}} {
        set sign [expr {$side1 eq "bottom" ? 1 : -1}]
        set exit [expr {$y1 + $sign * $gap}]
        if {($side1 eq "bottom" && $y2 <= $exit) ||
            ($side1 eq "top"    && $y2 >= $exit)} {
            set bypass [expr {$y1 + $sign * $gap}]
            set midx   [expr {($x1 + $x2) / 2.0}]
            return [list $x1 $y1  $x1 $bypass  $midx $bypass  \
                         $midx [expr {$y2 - $sign*$gap}]  \
                         $x2   [expr {$y2 - $sign*$gap}]  $x2 $y2]
        }
        set mid [expr {($y1 + $y2) / 2.0}]
        return [list $x1 $y1  $x1 $mid  $x2 $mid  $x2 $y2]
    }

    return [list $x1 $y1 $x2 $y2]
}

# ============================================================
# JSON Save / Load (ohne externe Pakete)
# ============================================================
proc ::demo::saveToFile {} {
    variable data
    variable currentFile
    variable nodeCounter

    set file [tk_getSaveFile \
        -defaultextension .dia \
        -filetypes {{"Diagram Files" .dia} {"All Files" *}} \
        -title "Save Diagram"]
    if {$file eq ""} return
    set currentFile $file

    set f [open $file w]
    puts $f "# tclmcairo node editor diagram"
    puts $f "set ::demo::nodeCounter $nodeCounter"
    puts $f "set ::__load_data \[list $data\]"
    close $f
    set ::demo::statusVar "Saved: $file"
}

proc ::demo::loadFromFile {} {
    variable data
    variable currentFile

    set file [tk_getOpenFile \
        -defaultextension .dia \
        -filetypes {{"Diagram Files" .dia} {"All Files" *}} \
        -title "Load Diagram"]
    if {$file eq ""} return

    set ::__load_data ""
    if {[catch {source $file} err]} {
        tk_messageBox -icon error -message "Load failed:\n$err"
        return
    }
    if {$::__load_data eq ""} {
        tk_messageBox -icon error -message "Invalid diagram file"
        return
    }
    set data $::__load_data
    unset -nocomplain ::__load_data
    set currentFile $file
    drawAll
    set ::demo::statusVar "Loaded: $file"
}


# ============================================================
# UI
# ============================================================
proc ::demo::buildUI {} {
    variable canvas

    wm title . "Node Editor — komplex3"

    ttk::frame .main
    pack .main -fill both -expand 1

    # Toolbar
    ttk::frame .toolbar
    pack .toolbar -in .main -side top -fill x

    ttk::label  .toolbar.ltype -text "Type:"
    ttk::combobox .toolbar.type -width 12         -values {generic router switch server firewall database workstation                  printer scanner accesspoint phone wifi fiber building table}         -state readonly
    .toolbar.type set generic
    ttk::button .toolbar.add   -text "Add Node"   -command {::demo::addRandomNode}
    ttk::button .toolbar.fit   -text "Fit"         -command {::demo::fitToContent}
    ttk::button .toolbar.grid  -text "Grid"        -command {::demo::toggleGrid}
    ttk::button .toolbar.reset -text "Reset"       -command {::demo::resetZoom}

    ttk::separator .toolbar.s1 -orient vertical

    ttk::button .toolbar.undo  -text "Undo ↩"     -command {::demo::undo} \
        -state disabled
    ttk::button .toolbar.redo  -text "Redo ↪"     -command {::demo::redo} \
        -state disabled

    ttk::separator .toolbar.s2 -orient vertical

    ttk::button .toolbar.save  -text "Save"        -command {::demo::saveToFile}
    ttk::button .toolbar.load  -text "Load"        -command {::demo::loadFromFile}

    ttk::separator .toolbar.s3 -orient vertical

    ttk::button .toolbar.svg   -text "Export SVG"  -command {::demo::exportFile svg}
    ttk::button .toolbar.pdf   -text "Export PDF"  -command {::demo::exportFile pdf}
    ttk::button .toolbar.crop  -text "Export Region…" -command {::demo::startExportRegion}

    ttk::button .toolbar.snap  -text "Snap ✓"    -command {::demo::toggleSnap}

    foreach w {ltype type add fit grid snap reset s1 undo redo s2 save load s3 svg pdf crop} {
        pack .toolbar.$w -side left -padx 2 -pady 4
    }

    # Canvas
    ttk::frame .work
    pack .work -in .main -fill both -expand 1

    ttk::scrollbar .work.xs -orient horizontal
    ttk::scrollbar .work.ys -orient vertical

    canvas .work.c \
        -background white \
        -xscrollcommand {.work.xs set} \
        -yscrollcommand {.work.ys set} \
        -scrollregion {-2000 -2000 4000 4000} \
        -highlightthickness 0 \
        -cursor crosshair

    set canvas .work.c
    .work.xs configure -command [list $canvas xview]
    .work.ys configure -command [list $canvas yview]

    grid $canvas  -row 0 -column 0 -sticky news
    grid .work.ys -row 0 -column 1 -sticky ns
    grid .work.xs -row 1 -column 0 -sticky ew
    grid rowconfigure    .work 0 -weight 1
    grid columnconfigure .work 0 -weight 1

    # Status
    ttk::label .status -textvariable ::demo::statusVar -anchor w
    pack .status -in .main -side bottom -fill x

    # Popup
    menu .popup -tearoff 0
    .popup add command -label "Add Node Here"        -command {::demo::popupAddNode}
    .popup add command -label "Delete Selected"      -command {::demo::deleteSelected}
    .popup add separator
    .popup add command -label "Bring To Front"       -command {::demo::raiseSelectedNode}

    bindCanvas
}


# ============================================================
# Node edit dialog (double-click)
# ============================================================
proc ::demo::editNode {id} {
    set node [getNode $id]
    set title    [dict get $node title]
    set subtitle [dict get $node subtitle]
    set color    [dict get $node color]

    # Dialog window
    set dlg .nodeedit
    catch {destroy $dlg}
    toplevel $dlg
    wm title $dlg "Edit Node"
    wm transient $dlg .
    wm resizable $dlg 0 0

    ttk::frame $dlg.f -padding 12
    pack $dlg.f -fill both

    set ntype [expr {[dict exists $node type] ? [dict get $node type] : "generic"}]

    ttk::label $dlg.f.ltp -text "Type:"       -anchor w
    ttk::combobox $dlg.f.etp -width 14         -values {generic router switch server firewall database workstation table}         -state readonly
    $dlg.f.etp set $ntype

    ttk::label $dlg.f.lt -text "Title:"       -anchor w
    ttk::entry $dlg.f.et -width 30
    $dlg.f.et insert 0 $title

    ttk::label $dlg.f.ls -text "Subtitle:"    -anchor w
    ttk::entry $dlg.f.es -width 30
    $dlg.f.es insert 0 $subtitle

    ttk::label $dlg.f.lc -text "Color:"       -anchor w
    ttk::frame $dlg.f.cf
    ttk::entry $dlg.f.cf.e -width 12 -textvariable ::demo::_editColor
    set ::demo::_editColor $color
    ttk::button $dlg.f.cf.b -text "Pick…" -command {
        set c [tk_chooseColor -initialcolor $::demo::_editColor             -title "Node Color"]
        if {$c ne ""} { set ::demo::_editColor $c }
    }
    pack $dlg.f.cf.e $dlg.f.cf.b -side left -padx 2

    ttk::frame $dlg.f.btns
    ttk::button $dlg.f.btns.ok  -text "OK"     -default active         -command [list ::demo::_editNodeOK $dlg $id $dlg.f.et $dlg.f.es]
    ttk::button $dlg.f.btns.can -text "Cancel"         -command [list destroy $dlg]
    pack $dlg.f.btns.ok $dlg.f.btns.can -side left -padx 4

    grid $dlg.f.ltp -row 0 -column 0 -sticky w  -pady 4
    grid $dlg.f.etp -row 0 -column 1 -sticky w  -pady 4
    grid $dlg.f.lt  -row 1 -column 0 -sticky w  -pady 4
    grid $dlg.f.et  -row 1 -column 1 -sticky ew -pady 4
    grid $dlg.f.ls  -row 2 -column 0 -sticky w  -pady 4
    grid $dlg.f.es  -row 2 -column 1 -sticky ew -pady 4
    grid $dlg.f.lc  -row 3 -column 0 -sticky w  -pady 4
    grid $dlg.f.cf  -row 3 -column 1 -sticky w  -pady 4
    grid $dlg.f.btns -row 4 -column 0 -columnspan 2 -pady 8

    bind $dlg <Return> [list ::demo::_editNodeOK $dlg $id $dlg.f.et $dlg.f.es]
    bind $dlg <Escape> [list destroy $dlg]

    # Center over main window
    update idletasks
    set x [expr {[winfo rootx .] + ([winfo width  .] - [winfo reqwidth  $dlg])/2}]
    set y [expr {[winfo rooty .] + ([winfo height .] - [winfo reqheight $dlg])/2}]
    wm geometry $dlg +$x+$y
    focus $dlg.f.et
}

proc ::demo::_editNodeOK {dlg id etitle esubtitle} {
    set t [string trim [$etitle get]]
    set s [string trim [$esubtitle get]]
    set c $::demo::_editColor
    set tp [.${dlg}.f.etp get 2>/dev/null]
    catch { set tp [$dlg.f.etp get] }
    if {$t eq ""} { set t "Node" }
    if {$tp eq ""} { set tp "generic" }
    pushUndo
    setNodeField $id title    $t
    setNodeField $id subtitle $s
    setNodeField $id color    $c
    setNodeField $id type     $tp
    destroy $dlg
    drawAll
    set ::demo::statusVar "Edited $id"
}


# ============================================================
# Edge selection and deletion
# ============================================================
proc ::demo::selectEdge {tag} {
    variable selectedEdge
    variable canvas
    variable selectedNode
    set selectedNode ""
    # Deselect previous
    if {$selectedEdge ne ""} {
        # Find and recolor the visible line with this tag
        foreach item [$canvas find withtag $selectedEdge] {
            if {"edgevis" in [$canvas gettags $item]} {
                $canvas itemconfigure $item -fill "#3465a4" -width 2
            }
        }
    }
    set selectedEdge $tag
    # Highlight new selection
    foreach item [$canvas find withtag $tag] {
        if {"edgevis" in [$canvas gettags $item]} {
            $canvas itemconfigure $item -fill "#cc3300" -width 3
        }
    }
    set ::demo::statusVar "Edge selected — press Delete to remove"
}

proc ::demo::deleteSelectedEdge {} {
    variable data
    variable selectedEdge
    if {$selectedEdge eq ""} return
    set tag $selectedEdge
    pushUndo
    set newEdges {}
    foreach edge [allEdges] {
        set from [dict get $edge from]
        set to   [dict get $edge to]
        set etag "edge:[string map {: _} $from]->[string map {: _} $to]"
        if {$etag eq $tag} continue
        lappend newEdges $edge
    }
    dict set data edges $newEdges
    set selectedEdge ""
    drawAll
    set ::demo::statusVar "Edge deleted"
}


# ============================================================
# Snap-to-grid
# ============================================================
proc ::demo::snapCoord {v} {
    variable snapGrid
    variable gridSize
    if {!$snapGrid} { return $v }
    return [expr {round($v / double($gridSize)) * $gridSize}]
}

proc ::demo::snapNode {id} {
    set node [getNode $id]
    setNodeField $id x [snapCoord [dict get $node x]]
    setNodeField $id y [snapCoord [dict get $node y]]
}


# ============================================================
# Node resize (handle at bottom-right corner)
# ============================================================
proc ::demo::drawResizeHandle {id} {
    variable canvas
    set node [getNode $id]
    dict with node {
        set hx [expr {$x + $w - 6}]
        set hy [expr {$y + $h - 6}]
    }
    $canvas create rectangle         $hx $hy [expr {$hx+10}] [expr {$hy+10}]         -fill "#888" -outline ""         -tags [list resizehandle "node:$id" "resize:$id"]
}

proc ::demo::getResizeFromClick {sx sy} {
    variable canvas
    set x [$canvas canvasx $sx]
    set y [$canvas canvasy $sy]
    set r 8
    set items [$canvas find overlapping         [expr {$x-$r}] [expr {$y-$r}]         [expr {$x+$r}] [expr {$y+$r}]]
    foreach item $items {
        foreach t [$canvas gettags $item] {
            if {[string match "resize:*" $t]} {
                return [string range $t 7 end]
            }
        }
    }
    return ""
}

proc ::demo::bindCanvas {} {
    variable canvas

    bind $canvas <ButtonPress-1>   {::demo::onPress   %x %y}
    bind $canvas <B1-Motion>       {::demo::onDrag    %x %y}
    bind $canvas <ButtonRelease-1> {::demo::onRelease %x %y}

    bind $canvas <ButtonPress-2>   {::demo::startPan %x %y}
    bind $canvas <B2-Motion>       {::demo::doPan    %x %y}

    bind $canvas <ButtonPress-3>   {::demo::showPopup %X %Y %x %y}

    bind $canvas <MouseWheel>      {::demo::mouseWheel %D %x %y}
    bind $canvas <Button-4>        {::demo::zoomAt 1.1 %x %y}
    bind $canvas <Button-5>        {::demo::zoomAt 0.9 %x %y}

    bind . <Delete>      {::demo::deleteSelected}
    bind . <Escape>      {::demo::cancelConnect; ::demo::cancelExportRegion; ::demo::clearSelection}
    bind . <Control-z>   {::demo::undo}
    bind . <Control-y>   {::demo::redo}
    bind . <Control-Z>   {::demo::undo}
    bind . <Control-s>   {::demo::saveToFile}
    bind . <Control-e>   {::demo::startExportRegion}
}

# ============================================================
# Mouse handler
# ============================================================
proc ::demo::getPortFromClick {sx sy} {
    variable canvas
    set x [$canvas canvasx $sx]
    set y [$canvas canvasy $sy]
    # Use overlapping with a small area — works on both Press and Release
    set r 8
    set items [$canvas find overlapping \
        [expr {$x-$r}] [expr {$y-$r}] \
        [expr {$x+$r}] [expr {$y+$r}]]
    foreach item $items {
        foreach t [$canvas gettags $item] {
            if {[string match "port:*:*" $t]} { return $t }
        }
    }
    return ""
}


proc ::demo::onDoubleClick {sx sy} {
    variable canvas
    set item [$canvas find withtag current]
    if {$item eq ""} return
    set tags [$canvas gettags $item]
    set nodeId [extractNodeId $tags]
    if {$nodeId ne ""} {
        editNode $nodeId
    }
}

proc ::demo::onPress {sx sy} {
    variable canvas
    variable connectStart
    variable connectLine
    variable dragInfo
    variable selectedNode
    variable resizeNode
    variable resizeStart
    variable selectedEdge

    # Check resize handle first
    set rid [getResizeFromClick $sx $sy]
    if {$rid ne ""} {
        set resizeNode $rid
        set node [getNode $rid]
        set resizeStart [list             [$canvas canvasx $sx] [$canvas canvasy $sy]             [dict get $node w] [dict get $node h]]
        set ::demo::statusVar "Resizing $rid"
        return
    }

    # Check edge click — use wider invisible hit area
    set x [$canvas canvasx $sx]
    set y [$canvas canvasy $sy]
    set r 6
    set items [$canvas find overlapping         [expr {$x-$r}] [expr {$y-$r}]         [expr {$x+$r}] [expr {$y+$r}]]
    foreach item $items {
        set itags [$canvas gettags $item]
        if {"edgehit" in $itags} {
            foreach t $itags {
                if {[string match "edge:*" $t]} {
                    selectEdge $t
                    return
                }
            }
        }
    }
    # Deselect edge if clicking elsewhere
    # Deselect edge if clicking elsewhere
    if {$selectedEdge ne ""} {
        foreach item [$canvas find withtag $selectedEdge] {
            if {"edgevis" in [$canvas gettags $item]} {
                $canvas itemconfigure $item -fill "#3465a4" -width 2
            }
        }
        set selectedEdge ""
    }

    set port [getPortFromClick $sx $sy]
    if {$port ne ""} {
        set connectStart $port
        set x [$canvas canvasx $sx]
        set y [$canvas canvasy $sy]
        set connectLine [$canvas create line $x $y $x $y \
            -dash {6 3} -width 2 -fill "#cc3300" -tags connect_rubber]
        # port tag = "port:nodeId:side" -> extract nodeId:side
        set portId [join [lrange [split $port :] 1 end] :]
        set ::demo::statusVar "Connecting from $portId ..."
        return
    }

    set x [$canvas canvasx $sx]
    set y [$canvas canvasy $sy]
    set item [$canvas find withtag current]
    if {$item eq ""} { clearSelection; return }
    set nodeId [extractNodeId [$canvas gettags $item]]
    if {$nodeId ne ""} {
        set selectedNode $nodeId
        set dragInfo(lastX) $x
        set dragInfo(lastY) $y
        drawAll
        set ::demo::statusVar "Selected $nodeId"
    } else {
        clearSelection
    }
}

proc ::demo::onDrag {sx sy} {
    variable canvas
    variable connectLine
    variable selectedNode
    variable dragInfo
    variable resizeNode
    variable resizeStart

    if {$resizeNode ne ""} {
        set x [$canvas canvasx $sx]
        set y [$canvas canvasy $sy]
        lassign $resizeStart mx0 my0 ow oh
        set nw [expr {max(80, $ow + ($x - $mx0))}]
        set nh [expr {max(50, $oh + ($y - $my0))}]
        setNodeField $resizeNode w $nw
        setNodeField $resizeNode h $nh
        drawAll
        set ::demo::statusVar [format "Resize %s → %d×%d" $resizeNode [expr {int($nw)}] [expr {int($nh)}]]
        return
    }

    if {$connectLine ne ""} {
        set x [$canvas canvasx $sx]
        set y [$canvas canvasy $sy]
        lassign [$canvas coords $connectLine] x1 y1
        $canvas coords $connectLine $x1 $y1 $x $y
        return
    }

    if {$selectedNode ne ""} {
        set x [$canvas canvasx $sx]
        set y [$canvas canvasy $sy]
        set dx [expr {$x - $dragInfo(lastX)}]
        set dy [expr {$y - $dragInfo(lastY)}]
        moveNode $selectedNode $dx $dy
        set dragInfo(lastX) $x
        set dragInfo(lastY) $y
        drawAll
    }
}

proc ::demo::onRelease {sx sy} {
    variable canvas
    variable connectStart
    variable connectLine
    variable resizeNode

    if {$resizeNode ne ""} {
        snapNode $resizeNode
        set resizeNode ""
        drawAll
        return
    }

    if {$connectLine ne ""} {
        set port2 [getPortFromClick $sx $sy]
        if {$port2 ne "" && $port2 ne $connectStart} {
            pushUndo
            # Convert canvas tag format "port:nodeId:side" to "nodeId:side"
            set p1 [join [lrange [split $connectStart :] 1 end] :]
            set p2 [join [lrange [split $port2        :] 1 end] :]
            addEdge $p1 $p2
            set ::demo::statusVar "Connected $p1 → $p2"
        } else {
            set ::demo::statusVar "Connection cancelled"
        }
        $canvas delete $connectLine
        set connectLine  ""
        set connectStart ""
        drawAll
        return
    }

    if {$::demo::selectedNode ne ""} {
        snapNode $::demo::selectedNode
        drawAll
        set ::demo::statusVar "Moved $::demo::selectedNode"
    }
}

proc ::demo::cancelConnect {} {
    variable canvas
    variable connectLine
    variable connectStart
    if {$connectLine ne ""} {
        $canvas delete $connectLine
        set connectLine  ""
        set connectStart ""
    }
}

# ============================================================
# Drawing
# ============================================================
proc ::demo::drawAll {} {
    variable canvas
    $canvas delete all
    # Temporary state reset
    variable connectLine
    variable connectStart
    variable resizeNode
    set connectLine  ""
    set connectStart ""
    set resizeNode   ""
    # Keep shape image cache alive — images persist until zoom changes
    variable shapeImages
    drawGrid
    drawEdges
    foreach id [allNodeIds] { drawNode $id }
    # Z-Order: grid and edgehit always at bottom, ports always on top
    # Individual node items are drawn in correct order inside drawNode
    $canvas lower grid
    $canvas lower edgehit   ;# hit areas below everything
    $canvas raise port
    updateScrollregion
}

proc ::demo::drawGrid {} {
    variable canvas
    variable gridSize
    variable showGrid
    if {!$showGrid} return
    set xmin -2000; set ymin -2000
    set xmax  4000; set ymax  4000
    for {set x $xmin} {$x <= $xmax} {incr x $gridSize} {
        $canvas create line $x $ymin $x $ymax -fill #eeeeee -tags grid
    }
    for {set y $ymin} {$y <= $ymax} {incr y $gridSize} {
        $canvas create line $xmin $y $xmax $y -fill #eeeeee -tags grid
    }
    for {set x $xmin} {$x <= $xmax} {incr x [expr {$gridSize*5}]} {
        $canvas create line $x $ymin $x $ymax -fill #dddddd -tags grid
    }
    for {set y $ymin} {$y <= $ymax} {incr y [expr {$gridSize*5}]} {
        $canvas create line $xmin $y $xmax $y -fill #dddddd -tags grid
    }
}


proc ::demo::typeColor {type} {
    switch $type {
        router      { return {0.2 0.45 0.75} }
        switch      { return {0.2 0.55 0.3}  }
        server      { return {0.35 0.35 0.6} }
        firewall    { return {0.75 0.25 0.1} }
        cloud       { return {0.5  0.65 0.85} }
        database    { return {0.25 0.5  0.65} }
        workstation { return {0.3  0.4  0.6}  }
        table       { return {0.3  0.5  0.45} }
        printer     { return {0.4  0.4  0.5}  }
        scanner     { return {0.3  0.4  0.6}  }
        accesspoint { return {0.2  0.6  0.8}  }
        phone       { return {0.2  0.5  0.3}  }
        wifi        { return {0.1  0.5  0.9}  }
        fiber       { return {0.6  0.2  0.8}  }
        building    { return {0.5  0.45 0.4}  }
        default     { return {0.5  0.5  0.75} }
    }
}

proc ::demo::drawNode {id} {
    variable canvas
    variable selectedNode
    variable zoom
    variable shapeImages

    set node [getNode $id]
    set ntype [expr {[dict exists $node type] ? [dict get $node type] : "generic"}]
    dict with node {
        set x2 [expr {$x + $w}]
        set y2 [expr {$y + $h}]
    }

    set sel     [expr {$id eq $selectedNode}]
    set outline [expr {$sel ? "#004a99" : "#404040"}]
    set lw      [expr {$sel ? 3 : 1}]

    # ---- Shape icon (left side) ----
    set ico_size [expr {min(int(($h - 32) * 0.9), 60)}]
    set ic [typeColor $ntype]
    set ikey "$ntype:$ico_size:$ic"
    if {![info exists shapeImages($ikey)]} {
        # Use only alphanumeric chars in filename
        set safek [regsub -all {[^a-zA-Z0-9_]} $ikey "_"]
        set tmpf "/tmp/ne_${safek}.png"
        shape_renderer::render_to_file $ntype $ico_size $ico_size $tmpf -color $ic
        set shapeImages($ikey) [image create photo -file $tmpf]
    }

    set ico_x [expr {$x + 6}]
    set ico_y [expr {$y + ($h - $ico_size)/2}]

    # Draw in strict Z-order — no raise/lower needed
    # 1. Body background
    $canvas create rectangle $x $y $x2 $y2 \
        -fill $color -outline $outline -width $lw \
        -tags [list node "node:$id" "body:$id"]

    # 2. Header stripe
    $canvas create rectangle $x $y $x2 [expr {$y+26}] \
        -fill "#d8e8f4" -outline "" \
        -tags [list node "node:$id" "header:$id"]

    # 3. Type badge background
    $canvas create rectangle $x $y [expr {$x+26}] [expr {$y+26}] \
        -fill "#4a7aaa" -outline "" \
        -tags [list node "node:$id" "badge:$id"]

    # 4. Cairo shape icon (drawn before text so text is on top)
    $canvas create image [expr {$x+4}] [expr {$y+30}] \
        -image $shapeImages($ikey) -anchor nw \
        -tags [list node "node:$id" "icon:$id"]

    # 5. Badge letter (on top of badge background)
    $canvas create text [expr {$x+13}] [expr {$y+13}] \
        -text [string index [string toupper $ntype] 0] \
        -font {TkDefaultFont 9 bold} -fill white -anchor center \
        -tags [list node "node:$id" "text:$id"]

    # 6. Title in header
    $canvas create text [expr {$x+32}] [expr {$y+13}] \
        -text $title -anchor w -font {TkDefaultFont 9 bold} \
        -tags [list node "node:$id" "text:$id"]

    # 7. Subtitle (right of icon)
    set tx [expr {$x + $ico_size + 10}]
    $canvas create text $tx [expr {$y + 30 + $ico_size*0.45}] \
        -text $subtitle -anchor w -font {TkDefaultFont 9} \
        -fill "#444444" -width [expr {$w - $ico_size - 14}] \
        -tags [list node "node:$id" "text:$id"]

    # 8. Selected glow (on top of everything in node)
    if {$sel} {
        $canvas create rectangle [expr {$x-2}] [expr {$y-2}] \
            [expr {$x2+2}] [expr {$y2+2}] \
            -outline "#004a99" -width 2 -fill "" \
            -tags [list node "node:$id" "glow:$id"]
    }

    foreach {pname px py} {
        left   0.0 0.5
        right  1.0 0.5
        top    0.5 0.0
        bottom 0.5 1.0
    } {
        set cx [expr {$x + $px * $w}]
        set cy [expr {$y + $py * $h}]
        # Outer dot (no white outline — avoids Cairo bleed into node body)
        $canvas create oval \
            [expr {$cx-6}] [expr {$cy-6}] \
            [expr {$cx+6}] [expr {$cy+6}] \
            -fill "#333" -outline "" \
            -tags [list port "node:$id" "port:$id:$pname"]
        # Inner highlight ring (pure fill, no stroke)
        $canvas create oval \
            [expr {$cx-3}] [expr {$cy-3}] \
            [expr {$cx+3}] [expr {$cy+3}] \
            -fill "#aaaaaa" -outline "" \
            -tags [list port "node:$id" "port:$id:$pname"]
    }

    # Resize handle (bottom-right corner)
    drawResizeHandle $id
}

proc ::demo::drawEdges {} {
    variable canvas
    foreach edge [allEdges] {
        set from [dict get $edge from]
        set to   [dict get $edge to]

        if {[catch {portCoords $from} p1]} continue
        if {[catch {portCoords $to}   p2]} continue

        lassign $p1 x1 y1
        lassign $p2 x2 y2

        set coords [routeEdge $x1 $y1 $x2 $y2 $from $to]

        set etag "edge:[string map {: _} $from]->[string map {: _} $to]"
        # Invisible wide line for easy clicking (drawn first, under visible line)
        $canvas create line {*}$coords \
            -width 12 -fill "#ffffff" -stipple gray12 \
            -tags [list edge edgehit $etag]
        # Visible line on top
        $canvas create line {*}$coords \
            -width 2 -fill "#3465a4" \
            -arrow last \
            -joinstyle miter \
            -tags [list edge edgevis $etag]
    }
}

# ============================================================
# Selection / interaction
# ============================================================
proc ::demo::extractNodeId {tags} {
    foreach t $tags {
        if {[string match "node:*" $t]} { return [string range $t 5 end] }
    }
    return ""
}

proc ::demo::clearSelection {} {
    variable selectedNode
    set selectedNode ""
    drawAll
    set ::demo::statusVar "Ready"
}

proc ::demo::moveNode {id dx dy} {
    set node [getNode $id]
    setNodeField $id x [expr {[dict get $node x] + $dx}]
    setNodeField $id y [expr {[dict get $node y] + $dy}]
}

proc ::demo::deleteSelectedNode {} {
    variable data
    variable selectedNode
    if {$selectedNode eq ""} return
    set id $selectedNode
    pushUndo

    dict unset data nodes $id

    set newEdges {}
    foreach edge [allEdges] {
        set from [lindex [split [dict get $edge from] :] 0]
        set to   [lindex [split [dict get $edge to]   :] 0]
        if {$from eq $id || $to eq $id} continue
        lappend newEdges $edge
    }
    dict set data edges $newEdges

    set selectedNode ""
    drawAll
    set ::demo::statusVar "Deleted $id"
}


proc ::demo::deleteSelected {} {
    variable selectedNode
    variable selectedEdge
    if {$selectedEdge ne ""} {
        deleteSelectedEdge
    } elseif {$selectedNode ne ""} {
        deleteSelectedNode
    }
}

proc ::demo::raiseSelectedNode {} {
    variable canvas
    variable selectedNode
    if {$selectedNode eq ""} return
    $canvas raise "node:$selectedNode"
}

# ============================================================
# Export region (crop)
# ============================================================
proc ::demo::startExportRegion {} {
    variable canvas
    variable exportMode
    variable exportRect
    set exportMode 1
    set exportRect ""
    $canvas configure -cursor crosshair
    # Temporarily override bindings for rect selection
    bind $canvas <ButtonPress-1>   {::demo::regionPress   %x %y}
    bind $canvas <B1-Motion>       {::demo::regionDrag    %x %y}
    bind $canvas <ButtonRelease-1> {::demo::regionRelease %x %y}
    set ::demo::statusVar "Draw export region — drag to select area, ESC to cancel"
}

proc ::demo::cancelExportRegion {} {
    variable canvas
    variable exportMode
    variable exportRect
    set exportMode 0
    set exportRect ""
    $canvas delete export_rect
    $canvas configure -cursor crosshair
    # Restore normal bindings
    bind $canvas <ButtonPress-1>   {::demo::onPress   %x %y}
    bind $canvas <B1-Motion>       {::demo::onDrag    %x %y}
    bind $canvas <ButtonRelease-1> {::demo::onRelease %x %y}
    set ::demo::statusVar "Ready"
}

proc ::demo::regionPress {sx sy} {
    variable canvas
    variable exportRect
    set x [$canvas canvasx $sx]
    set y [$canvas canvasy $sy]
    set exportRect [list $x $y $x $y]
    $canvas delete export_rect
    $canvas create rectangle $x $y $x $y         -outline "#cc3300" -width 2 -dash {6 3}         -tags export_rect
}

proc ::demo::regionDrag {sx sy} {
    variable canvas
    variable exportRect
    if {$exportRect eq ""} return
    set x [$canvas canvasx $sx]
    set y [$canvas canvasy $sy]
    set x1 [lindex $exportRect 0]
    set y1 [lindex $exportRect 1]
    set exportRect [list $x1 $y1 $x $y]
    $canvas coords export_rect $x1 $y1 $x $y
}

proc ::demo::regionRelease {sx sy} {
    variable canvas
    variable exportRect
    if {$exportRect eq ""} { cancelExportRegion; return }

    lassign $exportRect x1 y1 x2 y2
    # Normalize
    if {$x1 > $x2} { lassign [list $x2 $x1] x1 x2 }
    if {$y1 > $y2} { lassign [list $y2 $y1] y1 y2 }

    set w [expr {int($x2 - $x1)}]
    set h [expr {int($y2 - $y1)}]

    $canvas delete export_rect
    cancelExportRegion

    if {$w < 10 || $h < 10} {
        set ::demo::statusVar "Region too small"
        return
    }

    # Ask for filename + format
    set file [tk_getSaveFile         -defaultextension .svg         -filetypes {{"SVG Files" .svg} {"PDF Files" .pdf}                     {"PNG Files" .png} {"All Files" *}}         -title "Export Region"]
    if {$file eq ""} return

    set ext [string tolower [file extension $file]]

    if {$ext eq ".png"} {
        exportRegionRaster $canvas $x1 $y1 $w $h $file
    } else {
        exportRegionVector $canvas $x1 $y1 $w $h $file
    }
}

proc ::demo::exportRegionVector {canvas x1 y1 w h file} {
    exportCleanup
    set ext [string tolower [string trimleft [file extension $file] .]]
    switch $ext {
        svg  { set mode svg }
        pdf  { set mode pdf }
        ps   { set mode ps  }
        eps  { set mode eps }
        default { set mode svg }
    }

    set ctx [tclmcairo::new $w $h -mode $mode -file $file]
    $ctx push
    $ctx transform -translate [expr {-$x1}] [expr {-$y1}]
    canvas2cairo::render $canvas $ctx
    $ctx pop
    $ctx finish
    $ctx destroy
    exportRestore
    set ::demo::statusVar "Exported region [expr {int($w)}]×[expr {int($h)}]px → $file"
}

proc ::demo::exportRegionRaster {canvas x1 y1 w h file} {
    exportCleanup
    set ctx [tclmcairo::new $w $h]
    $ctx clear 1 1 1
    $ctx push
    $ctx transform -translate [expr {-$x1}] [expr {-$y1}]
    canvas2cairo::render $canvas $ctx
    $ctx pop
    $ctx save $file
    $ctx destroy
    exportRestore
    set ::demo::statusVar "Exported region [expr {int($w)}]×[expr {int($h)}]px → $file"
}

# ============================================================
# Export
# ============================================================
proc ::demo::exportCleanup {} {
    variable canvas
    variable connectLine
    $canvas delete connect_rubber
    $canvas delete export_rect
    if {$connectLine ne ""} {
        $canvas delete $connectLine
        set connectLine ""
    }
    # Delete (not hide) items that must not appear in export
    # hide/state has no effect in Cairo for stipple lines
    $canvas itemconfigure grid        -state hidden
    $canvas itemconfigure resizehandle -state hidden
    $canvas delete edgehit            ;# delete entirely — stipple renders as solid in Cairo
}

proc ::demo::exportRestore {} {
    variable canvas
    variable showGrid
    if {$showGrid} {
        $canvas itemconfigure grid -state normal
    }
    $canvas itemconfigure resizehandle -state normal
    # Restore edgehit lines by redrawing edges
    drawEdges
    $canvas lower edgehit
}

proc ::demo::exportFile {ext} {
    variable canvas
    set file [tk_getSaveFile \
        -defaultextension .$ext \
        -filetypes [list \
            {"SVG Files" .svg} {"PDF Files" .pdf} {"All Files" *}] \
        -title "Export as [string toupper $ext]"]
    if {$file eq ""} return
    exportCleanup
    if {[catch {canvas2cairo::export $canvas $file} err]} {
        tk_messageBox -icon error -message "Export failed:\n$err"
        exportRestore
        return
    }
    exportRestore
    set ::demo::statusVar "Exported: $file"
}

# ============================================================
# Popup
# ============================================================
proc ::demo::showPopup {X Y sx sy} {
    variable canvas
    variable popupX
    variable popupY
    set popupX [$canvas canvasx $sx]
    set popupY [$canvas canvasy $sy]
    tk_popup .popup $X $Y
}

proc ::demo::popupAddNode {} {
    variable popupX
    variable popupY
    pushUndo
    addNode $popupX $popupY "New Node" "via popup" "#fff2cc"
    drawAll
}

# ============================================================
# Pan / Zoom
# ============================================================

proc ::demo::toggleSnap {} {
    variable snapGrid
    set snapGrid [expr {!$snapGrid}]
    set lbl [expr {$snapGrid ? "Snap ✓" : "Snap ✗"}]
    catch { .toolbar.snap configure -text $lbl }
    set ::demo::statusVar "Snap: [expr {$snapGrid ? {on} : {off}}]"
}

proc ::demo::startPan {x y} {
    variable canvas
    $canvas scan mark $x $y
}

proc ::demo::doPan {x y} {
    variable canvas
    $canvas scan dragto $x $y 1
}

proc ::demo::mouseWheel {delta x y} {
    if {$delta > 0} { zoomAt 1.1 $x $y } else { zoomAt 0.9 $x $y }
}

proc ::demo::zoomAt {factor sx sy} {
    variable canvas
    variable zoom

    set x [$canvas canvasx $sx]
    set y [$canvas canvasy $sy]
    set newZoom [expr {$zoom * $factor}]
    if {$newZoom < 0.2 || $newZoom > 4.0} return

    $canvas scale all $x $y $factor $factor
    set zoom $newZoom

    foreach id [allNodeIds] {
        set node [getNode $id]
        setNodeField $id x [expr {$x + ([dict get $node x] - $x) * $factor}]
        setNodeField $id y [expr {$y + ([dict get $node y] - $y) * $factor}]
        setNodeField $id w [expr {[dict get $node w] * $factor}]
        setNodeField $id h [expr {[dict get $node h] * $factor}]
    }

    set ::demo::gridSize \
        [expr {max(8, min(200, int(round($::demo::gridSize * $factor))))}]
    drawAll
    set ::demo::statusVar [format "Zoom %.2f" $zoom]
}

proc ::demo::resetZoom {} {
    variable zoom
    variable shapeImages
    set zoom 1.0
    set ::demo::gridSize 40
    # Clear shape cache on zoom reset — sizes change
    foreach key [array names shapeImages] {
        catch { image delete $shapeImages($key) }
    }
    array unset shapeImages
    array set shapeImages {}
    initData
    drawAll
    set ::demo::statusVar "Zoom reset"
}

proc ::demo::fitToContent {} {
    variable canvas
    set bbox [$canvas bbox all]
    if {$bbox eq ""} return
    lassign $bbox x1 y1 x2 y2
    set w [winfo width $canvas]
    set h [winfo height $canvas]
    if {$w < 10 || $h < 10} return
    set f [expr {min(1.5, max(0.3,
        min($w/($x2-$x1+40.0), $h/($y2-$y1+40.0))))}]
    resetZoom
    zoomAt $f [expr {$w/2}] [expr {$h/2}]
    set ::demo::statusVar "Fit to content"
}

proc ::demo::toggleGrid {} {
    variable showGrid
    set showGrid [expr {!$showGrid}]
    drawAll
}

proc ::demo::updateScrollregion {} {
    variable canvas
    set bbox [$canvas bbox all]
    if {$bbox eq ""} {
        $canvas configure -scrollregion {-1000 -1000 1000 1000}
        return
    }
    lassign $bbox x1 y1 x2 y2
    set p 200
    $canvas configure -scrollregion \
        [list [expr {$x1-$p}] [expr {$y1-$p}] [expr {$x2+$p}] [expr {$y2+$p}]]
}

proc ::demo::addRandomNode {} {
    set colors {#fce5cd #d9ead3 #d0e0e3 #ead1dc #fff2cc}
    # Get type from toolbar combobox
    set type "generic"
    catch { set type [.toolbar.type get] }
    pushUndo
    set id [addNode         [expr {int(rand()*700)}]         [expr {int(rand()*500)}]         [string totitle $type]         "double-click to edit"         [lindex $colors [expr {int(rand()*5)}]]         $type]
    drawAll
    set ::demo::statusVar "Added $id ($type)"
}

# ============================================================
# Demo data
# ============================================================
proc ::demo::initData {} {
    variable data
    variable nodeCounter
    set data [dict create nodes {} edges {}]
    set nodeCounter 0

    set n1 [addNode  80  80 "Input"     "CSV / Oracle / REST"  "#fce5cd" server]
    set n2 [addNode 360 100 "Normalize" "cleanup + mapping"    "#d9ead3" generic]
    set n3 [addNode 680 180 "Database"  "SQLite / PostgreSQL"  "#d0e0e3" database]
    set n4 [addNode 360 300 "UI Layer"  "tablelist + form"     "#ead1dc" workstation]
    set n5 [addNode 700 380 "Export"    "PDF / Label / Mail"   "#fff2cc" server]
    set n6 [addNode  80 320 "Log"       "status + errors"      "#f4cccc" generic]

    addEdge "$n1:right"  "$n2:left"
    addEdge "$n2:right"  "$n3:left"
    addEdge "$n2:bottom" "$n4:top"
    addEdge "$n4:right"  "$n5:left"
    addEdge "$n1:bottom" "$n6:top"
    addEdge "$n6:right"  "$n4:left"
}

# ============================================================
# Main
# ============================================================
::demo::buildUI
::demo::initData
::demo::drawAll
