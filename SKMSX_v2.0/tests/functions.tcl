# Drives every editor function through the BIOS keyboard ring, checking the
# document bytes, cursor offsets and the rendered screen after each group.
# Modifier keys are held in the keyboard matrix while the key is consumed.
set F1 129; set F2 130; set F3 131; set F4 132; set F5 133
set F6 134; set F7 135; set F8 136; set F9 137; set F10 138
set RIGHT 28; set LEFT 29; set UP 30; set DOWN 31
set HOME 11; set CLS 12; set INS 18; set DEL 127; set BS 8
proc hold {mask} {keymatrixdown 6 $mask; set ::held $mask}
proc release {} {if {[info exists ::held]} {keymatrixup 6 $::held; unset ::held}}
proc shift {args} {hold 1; inject {*}$args}
proc ctrl {args} {hold 2; inject {*}$args}
proc expect_cursor {offset what} {
    set c [field gap_lo]
    if {$c!=$offset} {error "$what: cursor=$c expected=$offset"}
    log "PASS $what (cursor=$c)"
}
proc expect_text {text what} {
    set d [document]
    if {$d ne $text} {error "$what: text=[string map {\r <CR> \n <LF> \t <TAB>} $d]"}
    log "PASS $what"
}
proc expect_top {offset what} {
    if {[field view_top]!=$offset} {error "$what: view_top=[field view_top] expected=$offset"}
}
proc expect_left {left what} {
    if {[word $::A(view_cursor_left)]!=$left} {error "$what: cursor line left=[word $::A(view_cursor_left)] expected=$left"}
}
proc expect_status {text} {
    if {[string first $text [screen]]<0} {error "Status '$text' missing\n[screen]"}
}
proc line_offset {n} {lindex [line_starts [document]] $n}
proc line_end {n} {
    set text [document]
    set i [line_offset $n]
    while {$i<[string length $text] && [string index $text $i] ne "\r" && [string index $text $i] ne "\n"} {incr i}
    return $i
}
# Queue typing in chunks the 40-byte BIOS ring can hold.
proc type_steps {text} {
    for {set i 0} {$i<[string length $text]} {incr i 24} {
        step 1 [list input [string range $text $i [expr {$i+23}]]]
    }
}

step 50 {
    log "BOOT mode=[byte 0xFCAF]"
    type "\r"
}
step 2 {launch}
step 8 {
    if {![info exists ::entered]} {error "Program did not launch"}
    status started
    check_font
    check_screen
    inject $F1
}
step 1 {input "LINES.TXT\r"}
step 6 {
    set f [open [file join $::work disk LINES.TXT] rb]; set ::lines [read $f]; close $f
    expect_text $::lines "load LINES.TXT"
    check_screen
    inject $DOWN $DOWN $DOWN
}
# --- Horizontal scrolling is limited to the cursor line -------------------
step 2 {expect_cursor [line_offset 3] "down x3 keeps column 0"; check_screen; ctrl $RIGHT}
step 2 {
    release
    expect_cursor [line_end 3] "ctrl+right to end of 100-column line"
    expect_left 80 "long line scrolls"
    check_screen
    inject $UP
}
step 2 {expect_cursor [line_end 2] "up to shorter line clamps to its end"; expect_left 0 "short line"; check_screen; inject $UP}
step 2 {expect_cursor [line_end 1] "up again"; check_screen; inject $DOWN $DOWN}
step 2 {
    expect_cursor [line_end 3] "goal column restored on the long line"
    expect_left 80 "long line scrolls again"
    check_screen
    inject $DOWN
}
step 2 {expect_cursor [line_end 4] "down to short line"; check_screen; inject $DOWN}
step 2 {expect_cursor [line_end 5] "down to TAB line"; check_screen; inject $DOWN}
step 2 {expect_cursor [line_end 6] "down to 38-column line"; expect_left 0 "38 columns fit"; check_screen; inject $DOWN}
step 2 {expect_cursor [line_end 7] "down to 94-column line"; expect_left 74 "94-column line"; check_screen; inject $LEFT}
step 2 {expect_cursor [expr {[line_end 7]-1}] "left resets goal"; inject $UP}
step 2 {expect_cursor [line_end 6] "up with new goal"; check_screen; inject $DOWN}
step 2 {
    expect_cursor [expr {[line_offset 7]+93}] "down returns to column 93"
    expect_left 73 "window re-centred after a short line"
    check_screen
    ctrl $LEFT
}
step 2 {release; expect_cursor [line_offset 7] "ctrl+left to line start"; expect_left 0 "line start"; check_screen; inject $UP $UP $RIGHT $RIGHT $DOWN}
step 2 {expect_cursor [expr {[line_offset 6]+9}] "TAB line column 9 to next line"; inject $UP}
step 2 {expect_cursor [expr {[line_offset 5]+2}] "back to TAB line column 9"; inject $RIGHT $RIGHT $RIGHT $UP}
step 2 {expect_cursor [expr {[line_offset 4]+16}] "column 16 after TAB"; check_screen; ctrl $LEFT}
step 1 {release; inject {*}[lrepeat 13 $RIGHT] $DOWN}
step 3 {expect_cursor [expr {[line_offset 5]+4}] "goal 13 stops before TAB expanding to 16"; check_screen; inject $HOME {*}[lrepeat 10 $DOWN]}
# --- LF-only and bare-CR line separators -----------------------------------
step 4 {expect_cursor [line_offset 10] "line 10 after CRLF"; inject $DOWN}
step 2 {expect_cursor [line_offset 11] "line 11 after LF"; inject $DOWN}
step 2 {expect_cursor [line_offset 12] "line 12 after bare CR"; inject $UP $UP $LEFT}
step 2 {expect_cursor [line_end 9] "left over CRLF"; inject $RIGHT}
step 2 {expect_cursor [line_offset 10] "right over CRLF"; ctrl $RIGHT}
step 2 {release; inject $RIGHT}
step 2 {expect_cursor [line_offset 11] "right over LF"; ctrl $RIGHT}
step 2 {release; inject $RIGHT}
step 2 {expect_cursor [line_offset 12] "right over bare CR"; check_screen; inject $HOME}
# --- Vertical paging and scrolling -----------------------------------------
step 2 {expect_cursor 0 "HOME"; ctrl $DOWN}
step 4 {
    release
    expect_cursor [line_offset 18] "ctrl+down pages 18 lines"
    expect_top [line_offset 18] "page view"
    check_screen
    inject {*}[lrepeat 25 $DOWN]
}
step 8 {
    expect_cursor [line_offset 43] "down x25"
    expect_top [line_offset 22] "cursor kept on last row"
    check_screen
    shift $UP
}
step 2 {release; expect_cursor [line_offset 42] "shift+up"; expect_top [line_offset 21] "shift+up scrolls"; check_screen; ctrl $UP}
step 4 {release; expect_cursor [line_offset 24] "ctrl+up"; expect_top [line_offset 3] "ctrl+up view"; check_screen; shift $DOWN}
step 2 {release; expect_cursor [line_offset 25] "shift+down"; expect_top [line_offset 4] "shift+down scrolls"; check_screen; inject $CLS}
step 3 {expect_cursor [string length $::lines] "shift+home (CLS code) to end"; check_screen; inject $HOME}
step 2 {expect_cursor 0 "HOME to start"; shift $HOME}
step 3 {release; expect_cursor [string length $::lines] "shift+home"; inject $HOME}
step 2 {expect_text $::lines "navigation never changed text"; inject $F1}
# --- Editing on a new document ----------------------------------------------
step 1 {input "NEW.TXT\r"}
step 3 {expect_text "" "F1 at HOME with a new name starts empty"; expect_status "New file"; input "alpha beta gamma"}
step 2 {expect_text "alpha beta gamma" "typing"; ctrl $LEFT}
step 1 {release; shift $RIGHT}
step 1 {release; expect_cursor 6 "shift+right word"; shift $DEL}
step 1 {release; expect_text "alpha  gamma" "shift+delete word"; expect_cursor 6 "cursor kept"; shift $BS}
step 1 {release; expect_text " gamma" "shift+BS word"; expect_cursor 0 "cursor at start"; inject $INS; input "G"}
step 1 {expect_text "Ggamma" "overwrite mode"; inject $INS; input "x"}
step 1 {expect_text "Gxgamma" "insert mode"; ctrl $DEL}
step 1 {release; expect_text "Gx" "ctrl+delete to line end"; ctrl $BS}
step 1 {release; expect_text "" "ctrl+BS to line start"; input "ab\rcd"}
step 1 {expect_text "ab\r\ncd" "Enter inserts CRLF"; inject $LEFT $LEFT $LEFT}
step 1 {expect_cursor 2 "left crosses CRLF as one"; inject $BS}
step 1 {expect_text "a\r\ncd" "backspace"; inject $DEL}
step 1 {expect_text "acd" "delete removes CRLF pair"; ctrl $BS}
step 1 {release; ctrl $DEL}
step 1 {release; expect_text "" "cleared"; input "top\r"}
type_steps [string repeat "abcdefghij" 5]
step 2 {expect_left 20 "typing past column 40 scrolls the line by half a screen"; check_screen; input "\rbottom"}
step 2 {expect_left 0 "new line unscrolled"; check_screen; inject $UP}
step 2 {expect_cursor [expr {[line_offset 1]+6}] "up to long line column 6"; check_screen; ctrl $RIGHT}
step 2 {release; expect_left 30 "end of long line"; check_screen; inject $DOWN}
step 2 {expect_cursor [line_end 2] "down clamps"; expect_left 0 "short line"; check_screen; input "\tx"}
step 2 {check_screen; inject $HOME $F1}
step 1 {input "NEW2.TXT\r"}
# --- Find, replace, block, prompts --------------------------------------------
step 2 {expect_text "" "second new document"; input "one two one two"}
step 1 {inject $HOME $F4}
step 1 {input "two\r"}
step 1 {expect_cursor 4 "F4 find"; expect_status "Found"; inject $F9}
step 1 {expect_cursor 12 "F9 repeat find"; inject $F9}
step 1 {expect_cursor 12 "F9 at last match"; expect_status "Not found"; inject $HOME $F5}
step 1 {input "one\r"}
step 1 {input "ONE\r"}
step 1 {expect_text "ONE two one two" "F5 replace"; expect_cursor 3 "after replacement"; inject $F10}
step 1 {expect_text "ONE two ONE two" "F10 repeat replace"; inject $F10}
step 1 {expect_text "ONE two ONE two" "F10 without match"; expect_status "Not found"; inject $F4}
step 1 {inject 27}
step 1 {
    if {!$::editor_active || [byte $::A(exit_requested)]} {error "ESC in a prompt left the editor"}
    expect_status "Cancelled"
    inject $F8
}
step 1 {expect_status "Mark a block"; inject $HOME $F6}
step 1 {shift $RIGHT}
step 1 {release; expect_cursor 4 "word right"; inject $F7 $CLS $F8}
step 2 {expect_text "ONE two ONE twoONE " "F6/F7/F8 block copy"; check_screen; inject $HOME $F6 $RIGHT $RIGHT $RIGHT $F7 $LEFT $F8}
step 2 {expect_status "Inside block"; expect_text "ONE two ONE twoONE " "no copy inside block"; inject $F3}
step 1 {input "OUT.TXT\r"}
step 12 {
    expect_status "Saved"
    input "!"
}
step 1 {inject $F2}
step 12 {
    expect_status "Saved"
    set f [open [file join $::work expected_out.bin] wb]; puts -nonewline $f [document]; close $f
    check_screen
    inject 27
}
step 5 {
    if {![info exists ::exit_ok]} {error "Editor did not return"}
    log "PASS completed"
}
