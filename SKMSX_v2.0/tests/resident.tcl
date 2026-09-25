proc hotkey {} {
    keymatrixdown 6 2
    after time 0.05 {keymatrixdown 6 1}
    after time 0.3 {keymatrixup 6 1; keymatrixup 6 2}
}
debug set_bp [expr {0xB000+$A(bootstrap_usr)-$A(bootstrap)}] {} {log "USR SP=[reg SP] HIMEM=[word 0xFC4A] HIMSAV=[word 0xF349] return=[word [reg SP]]"}
step 50 {
    set ::old_himsav [word 0xF349]
    set ::old_hook [debug read_block memory 0xFDCC 5]
    log "BOOT HIMSAV=$::old_himsav\n[dos_screen]"
    type "\r"
}
step 2 {if {$::pre_command ne ""} {type "$::pre_command\r"}}
step 8 {
    # Baseline after any pre-command (MSR lowers HIMSAV itself).
    set ::old_himsav [word 0xF349]
    set ::old_hook [debug read_block memory 0xFDCC 5]
    if {$::screen_mode ne ""} {type "MODE $::screen_mode\r"}}
step 4 {type "SKMSX3\r"}
step 18 {
    log "INSTALLED HIMSAV=[word 0xF349] HOOK=[word 0xFDCD]\n[dos_screen]"
    if {[byte 0xFDCC]!=195} {error "Resident hook not installed"}
    set base [word 0xFDCD]
    if {[debug read_block memory [expr {$base+3}] 4] ne "SKM3"} {error "Resident signature not found"}
    # Each region moved by its own delta (see install.asm): core to the hook
    # base; bank to 4000h and extras after the core when banked.
    set core [expr {$base-$A(resident_start)}]
    set banked [debug read memory [expr {$A(bank_active)+$core}]]
    set bank_delta [expr {$banked ? 0x4000-$A(bank_start) : $core}]
    set extras_delta [expr {$banked ? $base+$A(core_end)-$A(resident_start)-$A(extras_start) : $core}]
    set start $A(resident_start); set bank $A(bank_start); set extras $A(extras_start); set end [expr {$A(segments)+64}]
    foreach k [array names A] {
        set v $A($k)
        if {$v<$start || $v>=$end} continue
        if {$v<$bank} {incr A($k) $core} elseif {$v<$extras} {incr A($k) $bank_delta} else {incr A($k) $extras_delta}
    }
    if {$banked} {
        set ::bank_segment [debug read memory $A(code_segment)]
        log "BANKED editor in segment $::bank_segment"
    }
    set ::resident_bps [list \
        [debug set_bp $A(platform_enter) {[in_bank]} {snapshot_entry}] \
        [debug set_bp $A(resident_restored) {} {if {[catch {check_exit} err]} {log "RESTORE ERROR $err"}}]]
    log "Resident page-3 size=[expr {$::old_himsav-$base}] capacity=[field capacity]"
    # Stack watermark: fill the private stack, measure its deepest use at the end.
    for {set i $A(resident_stack)} {$i<$A(resident_stack_end)} {incr i} {debug write memory $i 0xA5}
    hotkey
}
step 30 {
    status activated
    log "DOS2 lower=[word $A(dos2_lower)] lower_size=[word $A(dos2_lower_size)] upper_size=[word $A(dos2_upper_size)]"
    if {![info exists ::editor_active] || !$::editor_active} {error "Ctrl+Shift did not activate"}
    check_font
    check_screen
    input "alpha beta gamma\rsecond line\rlast"
}
step 3 {
    set ::persistent [document]
    if {$::persistent ne "alpha beta gamma\r\nsecond line\r\nlast"} {error "Typed text differs"}
    check_screen
    inject 130
}
step 1 {
    status first_save_prompt
    if {[string first "Save as:" [screen]]<0} {error "First F2 did not use Save As"}
    input "FIRST.TXT\r"
}
step 12 {
    status first_saved
    if {[string first "Saved" [screen]]<0} {error "Resident save failed"}
    inject 27
}
step 4 {
    if {![info exists ::exit_ok]} {error "ESC did not restore DOS"}
    log "DOS AFTER ESC\n[dos_screen]"
    hotkey
}
step 30 {
    if {[document] ne $::persistent} {error "Resident text lost after ESC"}
    log "PASS document survives ESC and reactivation"
    inject 11 129
}
step 1 {input "msxarch.ini\r"}
step 6 {
    set f [open [file join $::work disk msxarch.ini] rb]; set expected [read $f]; close $f
    status loaded
    if {[document] ne $expected} {error "Resident load differs"}
    check_screen
    inject 131
}
step 1 {input "ROUND.INI\r"}
step 12 {
    if {[string first "Saved" [screen]]<0} {error "Resident round-trip save failed"}
    inject 27
}
step 4 {
    foreach bp $::resident_bps {debug remove_bp $bp}
    set low $::A(resident_stack)
    while {$low<$::A(resident_stack_end) && [byte $low]==0xA5} {incr low}
    log "STACK peak use [expr {$::A(resident_stack_end)-$low}] of [expr {$::A(resident_stack_end)-$::A(resident_stack)}] bytes"
    set ::editor_active 0
    type "SKMSX3 /U\r"
}
step 18 {
    log "REMOVED HIMSAV=[word 0xF349]\n[dos_screen]"
    if {[word 0xF349]!=$::old_himsav} {error "Uninstall did not restore HIMSAV"}
    if {[debug read_block memory 0xFDCC 5] ne $::old_hook} {error "Uninstall did not restore previous hook"}
    log "PASS resident install, first save, persistent text, load/save and uninstall"
    log "PASS completed"
}
