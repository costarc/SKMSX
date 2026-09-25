; All navigation uses gap-buffer operations; no display pointers are updated.
; A line separator is CRLF, LF, or bare CR. Pairing never deletes unrelated data.
cursor_peek:
    ld hl,gap_lo
    ld de,scan_pos
    call copy24
    jp buffer_get
cursor_peek_back:
    ld hl,gap_lo
    call offset_is_zero
    jr z,.eof
    ld de,scan_pos
    call copy24
    ld hl,scan_pos
    call dec24
    jp buffer_get
.eof:
    xor a
    scf
    ret

; Each primitive returns C only when nothing moved or was deleted.
nav_left:
    call cursor_peek_back
    ret c
    push af
    call buffer_left
    pop af
    cp 10
    jr nz,nav_done
    call cursor_peek_back
    jr c,nav_done
    cp 13
    call z,buffer_left
nav_done:
    or a
    ret
nav_right:
    call cursor_peek
    ret c
    push af
    call buffer_right
    pop af
    cp 13
    jr nz,nav_done
    call cursor_peek
    jr c,nav_done
    cp 10
    call z,buffer_right
    jr nav_done

delete_left:
    call cursor_peek_back
    ret c
    push af
    call buffer_backspace
    pop af
    cp 10
    jr nz,nav_done
    call cursor_peek_back
    jr c,nav_done
    cp 13
    call z,buffer_backspace
    jr nav_done
delete_right:
    call cursor_peek
    ret c
    push af
    call buffer_delete
    pop af
    cp 13
    jr nz,nav_done
    call cursor_peek
    jr c,nav_done
    cp 10
    call z,buffer_delete
    jr nav_done

nav_home:
    call buffer_left
    jr nc,nav_home
    ret
nav_end:
    call buffer_right
    jr nc,nav_end
    ret

is_newline:
    cp 13
    ret z
    cp 10
    ret
is_space:
    cp 33
    ret

nav_line_home:
    call cursor_peek_back
    ret c
    call is_newline
    ret z
    call buffer_left
    jr nav_line_home
nav_line_end:
    call cursor_peek
    ret c
    call is_newline
    ret z
    call buffer_right
    jr nav_line_end

nav_word_left:
    call cursor_peek_back
    ret c
    call is_space
    jr nc,.word
    call nav_left
    jr nav_word_left
.word:
    call cursor_peek_back
    ret c
    call is_space
    ret c
    call nav_left
    jr .word
nav_word_right:
    call cursor_peek
    ret c
    call is_space
    jr c,.spaces
    call nav_right
    jr nav_word_right
.spaces:
    call cursor_peek
    ret c
    call is_space
    ret nc
    call nav_right
    jr .spaces

delete_word_left:
    call cursor_peek_back
    ret c
    call is_newline
    jp z,delete_left
.spaces:
    call cursor_peek_back
    ret c
    call is_newline
    ret z
    call is_space
    jr nc,.word
    call delete_left
    jr .spaces
.word:
    call cursor_peek_back
    ret c
    call is_space
    ret c
    call delete_left
    jr .word
delete_word_right:
    call cursor_peek
    ret c
    call is_newline
    jp z,delete_right
.spaces:
    call cursor_peek
    ret c
    call is_newline
    ret z
    call is_space
    jr nc,.word
    call delete_right
    jr .spaces
.word:
    call cursor_peek
    ret c
    call is_space
    ret c
    call delete_right
    jr .word

delete_line_left:
    call cursor_peek_back
    ret c
    call is_newline
    ret z
    call delete_left
    jr delete_line_left
delete_line_right:
    call cursor_peek
    ret c
    call is_newline
    ret z
    call delete_right
    jr delete_line_right

; Capture cursor's display column by scanning backward to a line boundary,
; then forward with tab expansion. Text and cursor do not change.
cursor_column:
    ld hl,gap_lo
    ld de,scan_pos
    call copy24
.back:
    ld hl,scan_pos
    call offset_is_zero
    jr z,.start
    call dec24
    call buffer_get
    call is_newline
    jr nz,.back
    ld hl,scan_pos
    call inc24
.start:
    ld hl,scan_pos
    ld de,cursor_line
    call copy24
    ld bc,0
.forward:
    ld hl,scan_pos
    ld de,gap_lo
    call cmp24
    jr z,.done
    push bc
    call buffer_get
    pop bc
    cp 9
    jr nz,.plain
    ld a,c
    or 7
    ld c,a
.plain:
    inc bc
    ld hl,scan_pos
    call inc24
    jr .forward
.done:
    ld (wanted_column),bc
    ret

; Vertical movement keeps a goal column across consecutive up/down commands,
; so passing through a short line does not lose the original column. The goal
; is dropped by the editor loop after any other command.
vertical_goal:
    ld a,1
    ld (goal_keep),a
    ld a,(goal_valid)
    or a
    ret nz
    call cursor_column
    ld hl,(wanted_column)
    ld (goal_column),hl
    ld a,1
    ld (goal_valid),a
    ret

; On the first/last line the cursor stays where it is (C returned).
nav_up:
    call vertical_goal
    call nav_save
    call nav_line_home
    call nav_left
    jr c,nav_restore
    call nav_line_home
    jr move_to_column
nav_down:
    call vertical_goal
    call nav_save
    call nav_line_end
    call nav_right
    jr c,nav_restore
; Advance along the current line to the goal display column, never past the
; line end, and never onto a TAB that would expand beyond the goal.
move_to_column:
    ld bc,0
.loop:
    ld hl,(goal_column)
    or a
    sbc hl,bc
    jp z,nav_done
    jp c,nav_done
    push bc
    call cursor_peek
    pop bc
    jp c,nav_done
    call is_newline
    jp z,nav_done
    ld d,b
    ld e,c
    cp 9
    jr nz,.plain
    ld a,e
    or 7
    ld e,a
.plain:
    inc de
    ld hl,(goal_column)
    or a
    sbc hl,de
    jp c,nav_done
    ld b,d
    ld c,e
    push bc
    call nav_right
    pop bc
    jr .loop
nav_save:
    ld hl,gap_lo
    ld de,nav_saved
    jp copy24
nav_restore:
    ld hl,nav_saved
    ld de,target_position
    call copy24
    call seek_target
    scf
    ret

page_up:
    ld b,18
.loop:
    push bc
    call scroll_up
    pop bc
    djnz .loop
    ret
page_down:
    ld b,18
.loop:
    push bc
    call scroll_down
    pop bc
    djnz .loop
    ret

scroll_up:
    call nav_up
    ld hl,view_top
    ld de,scan_pos
    call copy24
    call scan_previous_line
    ret c
    ld hl,scan_pos
    ld de,view_top
    jp copy24

; scan_pos at a line start -> start of the previous line; C if already first.
scan_previous_line:
    ld hl,scan_pos
    call offset_is_zero
    scf
    ret z
    call dec24
    call buffer_get
    cp 10
    jr nz,scan_line_start
    ld hl,scan_pos
    call offset_is_zero
    ret z
    call dec24
    call buffer_get
    cp 13
    jr z,scan_line_start
    ld hl,scan_pos
    call inc24
; scan_pos at a line separator or inside a line -> start of that line. NC.
scan_line_start:
    ld hl,scan_pos
    call offset_is_zero
    ret z
    call dec24
    call buffer_get
    call is_newline
    jr nz,scan_line_start
    ld hl,scan_pos
    call inc24
    or a
    ret
scroll_down:
    call nav_down
    ld hl,view_top
    ld de,scan_pos
    call copy24
.forward:
    call buffer_get
    ret c
    push af
    ld hl,scan_pos
    call inc24
    pop af
    cp 10
    jr z,.set
    cp 13
    jr nz,.forward
    call buffer_get
    jr c,.set
    cp 10
    jr nz,.set
    ld hl,scan_pos
    call inc24
.set:
    ld hl,scan_pos
    ld de,view_top
    jp copy24
wanted_column: dw 0
goal_column: dw 0
goal_valid: db 0
goal_keep: db 0
nav_saved: db 0,0,0
cursor_line: db 0,0,0
