set root [file dirname [info script]]
if {![info exists work]} {set work [file join $root work]}
source [file join $work symbols.tcl]
set log [open [file join $work smoke.log] w]
set renderer none
# Power-on mapper registers as an MSX2 BIOS leaves them (3,2,1,0). openMSX
# starts them at 0 and an MSX1 BIOS never sets them, which aliases pages 2/3
# of a mapper cartridge used as main RAM and crashes the boot. Applied just
# after power-on, because the reset itself clears them.
after time 0.00001 {foreach {port segment} {0xFC 3 0xFD 2 0xFE 1 0xFF 0} {debug write ioports $port $segment}}
set throttle off
set speed 100
bind F12 cycle videosource
plug printerport simpl
proc log {s} {puts $::log $s; flush $::log}
# Resident banked layout: page-1 addresses are read from the editor's mapper
# segment, so bank variables stay readable while the caller owns page 1.
proc byte {p} {
    if {[info exists ::bank_segment] && $p>=0x4000 && $p<0x8000} {
        return [debug read [mapper_ram] [expr {$::bank_segment*16384+$p-0x4000}]]
    }
    debug read memory $p
}
# True unless a banked editor's page-1 breakpoint address currently shows
# someone else's code (DiskROM, BASIC, TPA).
proc in_bank {} {
    if {![info exists ::bank_segment]} {return 1}
    set p $::A(keyboard_idle)
    expr {[debug read_block memory $p 6] eq [debug read_block [mapper_ram] [expr {$::bank_segment*16384+$p-0x4000}] 6]}
}
proc word {p} {expr {[byte $p]+256*[byte [expr {$p+1}]]}}
proc field {name} {
    set p $::A($name)
    expr {[byte $p]+256*[byte [expr {$p+1}]]+65536*[byte [expr {$p+2}]]}
}
proc inject {args} {
    set p [word 0xF3F8]
    foreach c $args {
        debug write memory $p $c
        incr p
        if {$p==0xFC18} {set p 0xFBF0}
    }
    debug write memory 0xF3F8 [expr {$p&255}]
    debug write memory 0xF3F9 [expr {$p>>8}]
}
proc input {text} {
    set chars {}
    foreach c [split $text ""] {scan $c %c n; lappend chars $n}
    inject {*}$chars
}
proc screen {} {
    set out ""
    set base [word $::A(video_name_base)]
    for {set row 0} {$row<24} {incr row} {
        set line ""
        for {set col 0} {$col<40} {incr col} {
            set v [debug read VRAM [expr {$base+$row*40+$col}]]
            append line [format %c $v]
        }
        append out "$row|$line\n"
    }
    return $out
}
proc document {} {
    set result ""
    set base [word $::A(storage_base)]
    set lo [field gap_lo]; set hi [field gap_hi]; set cap [field capacity]
    for {set i 0} {$i<$lo} {incr i} {append result [format %c [storage_byte $i]]}
    for {set i $hi} {$i<$cap} {incr i} {append result [format %c [storage_byte $i]]}
    return $result
}
proc storage_byte {offset} {
    if {[byte $::A(storage_kind)]==0} {
        return [debug read VRAM [expr {[word $::A(storage_base)]+$offset}]]
    }
    set segment [byte [expr {$::A(segments)+($offset>>14)}]]
    return [debug read [mapper_ram] [expr {$segment*16384+($offset&16383)}]]
}
# The editor picks the mapper with most free segments: the largest RAM.
proc mapper_ram {} {
    if {![info exists ::mapper_ram]} {
        set best 0
        foreach n [debug list] {
            if {![string match -nocase "*RAM" $n] || [string match -nocase "*VRAM" $n] || [string match -nocase "*SRAM" $n]} continue
            if {[debug size $n]>$best} {set best [debug size $n]; set ::mapper_ram $n}
        }
    }
    return $::mapper_ram
}
proc line_start {text pos} {
    while {$pos>0} {
        set c [string index $text [expr {$pos-1}]]
        if {$c eq "\r" || $c eq "\n"} {break}
        incr pos -1
    }
    return $pos
}
proc display_column {text start pos} {
    set col 0
    for {set i $start} {$i<$pos} {incr i} {
        if {[string index $text $i] eq "\t"} {set col [expr {($col|7)+1}]} else {incr col}
    }
    return $col
}
# Start offsets of every line (CRLF, LF and bare CR separators).
proc line_starts {text} {
    set starts {0}
    set n [string length $text]
    for {set i 0} {$i<$n} {incr i} {
        set c [string index $text $i]
        if {$c eq "\r" && [string index $text [expr {$i+1}]] eq "\n"} {incr i}
        if {$c eq "\r" || $c eq "\n"} {lappend starts [expr {$i+1}]}
    }
    return $starts
}
proc check_screen {} {
    # Independent logical-line oracle, including TAB expansion, clipping and
    # horizontal scrolling of the cursor line only.
    set text [document]
    set pos [field view_top]
    set cursor [field gap_lo]
    set base [word $::A(video_name_base)]
    set cline [line_start $text $cursor]
    set ccol [display_column $text $cline $cursor]
    set cleft [word $::A(view_cursor_left)]
    if {$ccol<40 && $cleft!=0} {error "Short cursor line scrolled: column=$ccol left=$cleft"}
    if {$ccol<$cleft || $ccol>=$cleft+40} {error "Cursor outside window: column=$ccol left=$cleft"}
    set cursor_row -1
    for {set row 0} {$row<22} {incr row} {
        set left [expr {$pos==$cline ? $cleft : 0}]
        set line ""; set col 0
        while 1 {
            if {$pos==$cursor && $cursor_row<0} {set cursor_row $row}
            if {$pos>=[string length $text]} {break}
            set ch [string index $text $pos]
            if {$ch eq "\r" || $ch eq "\n"} {
                incr pos
                if {$ch eq "\r" && [string index $text $pos] eq "\n"} {incr pos}
                break
            }
            if {$ch eq "\t"} {
                set n [expr {8-($col%8)}]
                append line [string repeat " " $n]; incr col $n
            } else {
                scan $ch %c n
                if {$n<32} {set ch "."}
                append line $ch; incr col
            }
            incr pos
        }
        set line [string range "$line[string repeat " " [expr {$left+80}]]" $left [expr {$left+39}]]
        for {set c 0} {$c<40} {incr c} {
            set address [expr {$base+$row*40+$c}]
            if {$address==[word $::A(view_cursor_address)]} {continue}
            scan [string index $line $c] %c expected_byte
            set actual [debug read VRAM $address]
            if {$actual!=$expected_byte} {error "Render mismatch row=$row column=$c actual=$actual expected=$expected_byte"}
        }
    }
    if {$cursor_row<0} {error "Cursor line not on screen"}
    set expected [expr {$base+$cursor_row*40+$ccol-$cleft}]
    if {[word $::A(view_cursor_address)]!=$expected || [debug read VRAM $expected]!=35} {
        error "Cursor overlay at [word $::A(view_cursor_address)], expected $expected"
    }
    log "PASS screen matches independent renderer (cursor row=$cursor_row column=$ccol left=$cleft)"
}
# The displayed pattern table must hold the machine's ROM font and the name
# table must not overlap it: this is what the user actually sees.
proc check_font {} {
    set msx2 [byte $::A(machine_msx2)]
    set r2 [debug read "VDP regs" 2]; set r4 [debug read "VDP regs" 4]
    set names [expr {($r2 & ($msx2?0x7F:0x0F))<<10}]
    set font [expr {($r4 & ($msx2?0x3F:0x07))<<11}]
    if {$names!=[word $::A(video_name_base)]} {error "R2 name table $names differs from editor base"}
    if {$names<$font+2048 && $font<$names+960} {error "Name table $names overlaps font $font"}
    set slot [byte 0xFCC1]
    set rom [expr {(($slot&3)*4+(($slot>>2)&3))*0x10000}]
    set cg [expr {[debug read "slotted memory" [expr {$rom+4}]]+256*[debug read "slotted memory" [expr {$rom+5}]]}]
    # Character 255 is excluded: the BIOS keeps its text cursor there.
    set vram [debug read_block VRAM $font 2040]
    set glyphs [debug read_block "slotted memory" [expr {$rom+$cg}] 2040]
    if {$vram ne $glyphs} {
        binary scan $vram cu* v; binary scan $glyphs cu* g
        set bad {}
        for {set i 0} {$i<2040 &&[llength $bad]<8} {incr i} {if {[lindex $v $i]!=[lindex $g $i]} {lappend bad [format %03X:%02X/%02X $i [lindex $v $i] [lindex $g $i]]}}
        error "Pattern table at $font is not the ROM font: CG=[format %04X $cg] saved=[binary encode hex [debug read_block memory $::A(saved_vdp) 8]] regs=[binary encode hex [debug read_block {VDP regs} 0 8]] $bad"
    }
    set r7 [debug read "VDP regs" 7]
    if {($r7>>4)==($r7&15)} {error "Text colour equals background: R7=$r7"}
    log "PASS font: names=[format %04X $names] patterns=[format %04X $font] R7=[format %02X $r7] load=[byte $::A(video_font_load)]"
}
proc dos_screen {} {
    set msx2 [byte $::A(machine_msx2)]
    set w [expr {[byte 0xFCAF]==1?32:[byte 0xF3AE]}]
    # TEXT2 (80 columns) ignores the two low bits of R2.
    set base [expr {([debug read "VDP regs" 2]&($msx2?($w>40?0x7C:0x7F):0x0F))<<10}]
    set out ""
    for {set i 0} {$i<24} {incr i} {append out [debug read_block VRAM [expr {$base+$i*$w}] $w] "\n"}
    return $out
}
proc snapshot_entry {} {
    set ::editor_active 1
    set ::saved_video [debug read_block VRAM 0 8224]
    set ::saved_registers [debug read_block "VDP regs" 0 8]
    set ::saved_keys [debug read_block memory 0xF87F 160]
}
proc check_exit {} {
    set ::editor_active 0
    set video [debug read_block VRAM 0 8224]
    if {[byte $::A(video_font_load)] && [byte $::A(storage_kind)]==0} {
        # A graphic screen already shares VRAM with the document; only the
        # editor's name table is restored, the ROM font stays at 0800h.
        set video [string replace $video 2048 4095 [string range $::saved_video 2048 4095]]
        log "NOTE graphic caller with VRAM storage: font area not restored"
    }
    if {$video ne $::saved_video} {
        binary scan $::saved_video cu* expected
        set diffs {}; set count 0
        for {set i 0} {$i<8224} {incr i} {
            set a [debug read VRAM $i]; set b [lindex $expected $i]
            if {$a!=$b} {incr count; if {$count<=24} {lappend diffs [format "%04X:%02X>%02X" $i $b $a]}}
        }
        error "Exit changed caller screen/font: count=$count $diffs"
    }
    if {[debug read_block "VDP regs" 0 8] ne $::saved_registers} {error "Exit changed VDP registers"}
    if {[debug read_block memory 0xF87F 160] ne $::saved_keys} {error "Exit changed function keys"}
    log "PASS ESC restores screen, font, registers and function keys"
    set ::exit_ok 1
}
set entry_condition {[byte 0x100]==195 && [word 0x101]==$::A(installer)}
debug set_bp $A(platform_enter) $entry_condition {snapshot_entry}
debug set_bp $A(memory_release) $entry_condition {if {[catch check_exit e]} {log "RESTORE ERROR $e"}}
debug set_bp $A(program_entry) $entry_condition {log "Entered program SP=[reg SP] HIMSAV=[word 0xF349] HIMEM=[word 0xFC4A] BDOS=[word 6]"; set ::entered 1}
proc status {s} {
    log "$s PC=[format %04X [reg PC]] cap=[field capacity] len=[field doc_length] cursor=[field gap_lo] kind=[byte $::A(storage_kind)]"
    log "RAM100=[binary encode hex [debug read_block memory 256 16]] SLOT=[debug read ioports 0xA8] SP=[reg SP]"
    log [screen]
}
set steps {}
proc step {delay cmd} {lappend ::steps [list $delay $cmd]}
proc run {} {
    if {![llength $::steps]} {close $::log; exit}
    set item [lindex $::steps 0]
    set ::steps [lrange $::steps 1 end]
    after time [lindex $item 0] [list execute [lindex $item 1]]
}
proc execute {cmd} {
    if {[info exists ::editor_active] && $::editor_active} {
        # Idle means every injected key has been consumed and processed.
        set ::sync_bp [debug set_bp $::A(keyboard_idle) {[in_bank] && [word 0xF3FA]==[word 0xF3F8]} [list execute_sync $cmd]]
        return
    }
    execute_now $cmd
}
proc execute_sync {cmd} {
    debug remove_bp $::sync_bp
    execute_now $cmd
}
proc execute_now {cmd} {
    if {[catch {uplevel #0 $cmd} e]} {log "ERROR $e\n$::errorInfo"; close $::log; exit}
    run
}
if {![info exists screen_mode]} {set screen_mode ""}
if {![info exists pre_command]} {set pre_command ""}
# Optional DOS command before the test, e.g. MSR I (DOS1 mapper support).
proc launch {} {
    if {$::pre_command ne ""} {
        type "$::pre_command\r"
        set ::steps [linsert $::steps 0 [list 8 {
            log "AFTER PRE\n[dos_screen]"
            launch_editor
        }]]
    } else {
        launch_editor
    }
}
proc launch_editor {} {
    if {$::screen_mode eq "G"} {
        # Graphic caller (SCREEN 2 register set, BIOS shadows included): the
        # editor must load the ROM font instead of reusing VRAM contents.
        set i 0
        foreach v {2 0xE0 6 0xFF 3 0x36 7 0x04} {
            debug write "VDP regs" $i $v
            debug write memory [expr {0xF3DF+$i}] $v
            incr i
        }
        type "SKMSX3 /T\r"
    } elseif {$::screen_mode ne ""} {
        # DOS's built-in MODE switches the console width (40/80: SCREEN 0).
        type "MODE $::screen_mode\r"
        set ::steps [linsert $::steps 0 [list 4 {
            log "AFTER MODE SCRMOD=[byte 0xFCAF] LINL40=[byte 0xF3AE]\n[dos_screen]"
            type "SKMSX3 /T\r"
        }]]
    } else {
        type "SKMSX3 /T\r"
    }
}
if {$testcase eq "functions"} {
    source [file join $root functions.tcl]
    run
    return
}
if {$testcase eq "resident"} {
    source [file join $root resident.tcl]
    run
    return
}
step 50 {
    log "BOOT mode=[byte 0xFCAF] PC=[format %04X [reg PC]] devices=[debug list]"
    set base [expr {([debug read "VDP regs" 2]&15)<<10}]
    set w [expr {[byte 0xFCAF]==1?32:40}]
    for {set i 0} {$i<24} {incr i} {log [debug read_block VRAM [expr {$base+$i*$w}] $w]}
    type "\r"
}
step 2 {launch}
step 6 {
    set base [expr {([debug read "VDP regs" 2]&15)<<10}]
    set w [expr {[byte 0xFCAF]==1?32:40}]
    for {set i 0} {$i<24} {incr i} {log [debug read_block VRAM [expr {$base+$i*$w}] $w]}
    if {![info exists ::entered]} {error "Program did not launch"}
    status started
    if {[byte $A(storage_kind)]>1} {error "Program failed during startup"}
    check_font
    check_screen
    inject 129
}
step 1 {input "msxarch.ini\r"}
step 4 {
    status loaded
    set f [open [file join $::work disk msxarch.ini] rb]; set expected [read $f]; close $f
    if {[document] ne $expected} {error "Loaded bytes differ"}
    log "PASS exact load"
    check_screen
    inject 28 28 31 31 29 30
}
step 3 {
    status moved
    if {[document] ne $expected} {error "Navigation changed bytes"}
    check_screen
    inject 131
}
step 1 {input "ROUND.INI\r"}
step 12 {
    status saved
    if {[string first "Saved" [screen]]<0} {error "Save did not finish successfully"}
    inject 27
}
step 5 {
    if {![info exists ::exit_ok]} {error "Editor did not return"}
    log "PASS completed"
}
run
