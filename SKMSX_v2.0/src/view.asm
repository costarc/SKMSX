; Rendering is a pure projection of document offsets. No persistent CPU/VRAM
; pointers track cursor movement. Storage access and screen writes are separated.
; Horizontal scrolling applies to the cursor line only; every other row is
; shown from column zero.
view_redraw:
    call cursor_column
    call view_scroll_horizontal
    ld hl,gap_lo
    ld de,view_top
    call cmp24
    jr nc,view_draw_rows
    ld hl,cursor_line
    ld de,view_top
    call copy24
view_draw_rows:
    ld hl,view_top
    ld de,scan_pos
    call copy24
    xor a
    ld (view_row),a
    ld (view_cursor_seen),a
.row:
    call view_blank_row
    ld hl,0
    ld (view_column),hl
    ld (view_left),hl
    ld hl,scan_pos
    ld de,cursor_line
    call cmp24
    jr nz,.character
    ld hl,(view_cursor_left)
    ld (view_left),hl
.character:
    ld hl,scan_pos
    ld de,gap_lo
    call cmp24
    call z,view_record_cursor
    call buffer_get
    jr c,.row_done
    push af
    ld hl,scan_pos
    call inc24
    pop af
    cp 13
    jr z,.cr
    cp 10
    jr z,.row_done
    cp 9
    jr z,.tab
    cp 32
    jr nc,.printable
    ld a,'.'
.printable:
    call view_place_char
    ld hl,(view_column)
    inc hl
    ld (view_column),hl
    jr .character
.tab:
    ld hl,(view_column)
    ld a,l
    or 7
    ld l,a
    inc hl
    ld (view_column),hl
    jr .character
.cr:
    call buffer_get
    jr c,.row_done
    cp 10
    jr nz,.row_done
    ld hl,scan_pos
    call inc24
.row_done:
    call view_output_row
    ld a,(view_row)
    inc a
    ld (view_row),a
    cp 22
    jr c,.row
    ld a,(view_cursor_seen)
    or a
    jr nz,.shown
    ; Cursor below the window: place its line on the last text row.
    call view_top_above_cursor
    jp view_draw_rows
.shown:
    call view_ruler
    call view_status
    ; Cursor is an overlay in VRAM only. Full redraw removes its old location.
    ld hl,(view_cursor_address)
    call video_write_address
    ld a,'#'
    out (098h),a
    ret

; Keep the cursor line's offset while the cursor stays visible. A column that
; fits the screen always shows the line from its start; otherwise the cursor
; lands in the middle of the screen.
view_scroll_horizontal:
    ld hl,(wanted_column)
    ld a,(view_width)
    ld e,a
    ld d,0
    or a
    sbc hl,de
    jr nc,.long
    ld hl,0
    ld (view_cursor_left),hl
    ret
.long:
    ld hl,(wanted_column)
    ld de,(view_cursor_left)
    or a
    sbc hl,de
    jr c,.jump
    ld a,h
    or a
    jr nz,.jump
    ld a,(view_width)
    dec a
    cp l
    ret nc
.jump:
    ld hl,(wanted_column)
    ld a,(view_width)
    srl a
    ld e,a
    ld d,0
    or a
    sbc hl,de
    ld (view_cursor_left),hl
    ret

; view_top = start of the line 21 lines above the cursor line (or text start).
view_top_above_cursor:
    ld hl,cursor_line
    ld de,scan_pos
    call copy24
    ld b,21
.line:
    push bc
    call scan_previous_line
    pop bc
    jr c,.set
    djnz .line
.set:
    ld hl,scan_pos
    ld de,view_top
    jp copy24

view_blank_row:
    ld hl,row_buffer
    ld a,(view_width)
    ld b,a
    ld a,' '
.loop:
    ld (hl),a
    inc hl
    djnz .loop
    ret

view_place_char:
    push af
    ld hl,(view_column)
    ld de,(view_left)
    or a
    sbc hl,de
    jr c,.off
    ld a,h
    or a
    jr nz,.off
    ld a,(view_width)
    cp l
    jr z,.off
    jr c,.off
    ld de,row_buffer
    add hl,de
    pop af
    ld (hl),a
    ret
.off:
    pop af
    ret

view_record_cursor:
    ld a,(view_cursor_seen)
    or a
    ret nz
    ld a,1
    ld (view_cursor_seen),a
    ld hl,(view_column)
    ld de,(view_left)
    or a
    sbc hl,de
    push hl
    call view_row_address
    pop de
    add hl,de
    ld (view_cursor_address),hl
    ret

view_row_address:
    ld hl,(video_name_base)
    ld a,(view_width)
    ld e,a
    ld d,0
    ld a,(view_row)
    or a
    ret z
    ld b,a
.loop:
    add hl,de
    djnz .loop
    ret
view_output_row:
    call view_row_address
    call video_write_address
    ld hl,row_buffer
    ld a,(view_width)
    ld b,a
.loop:
    ld a,(hl)
    out (098h),a
    inc hl
    djnz .loop
    ret

view_ruler:
    call view_blank_row
    ; Tick marks follow the cursor line's columns: '|' at multiples of ten.
    ld hl,(view_cursor_left)
    ld de,10
.modulo:
    or a
    sbc hl,de
    jr nc,.modulo
    add hl,de
    ld c,l
    ld hl,row_buffer
    ld a,(view_width)
    ld b,a
.loop:
    ld a,c
    or a
    ld a,'-'
    jr nz,.store
    ld a,'|'
.store:
    ld (hl),a
    inc hl
    inc c
    ld a,c
    cp 10
    jr nz,.next
    ld c,0
.next:
    djnz .loop
    jp view_output_row

view_status:
    ld a,23
    ld (view_row),a
    call view_blank_row
    ld hl,file_name
    ld de,row_buffer
    ld b,14
.name:
    ld a,(hl)
    or a
    jr z,.mode
    ld (de),a
    inc hl
    inc de
    djnz .name
.mode:
    ld hl,row_buffer+15
    ld a,(insert_mode)
    or a
    ld a,'O'
    jr z,.setmode
    ld a,'I'
.setmode:
    ld (hl),a
    ld a,(storage_kind)
    or a
    ld a,'V'
    jr z,.setmemory
    ld a,'M'
.setmemory:
    ld (row_buffer+17),a
    ld hl,doc_length
    call r24
    ex de,hl
    call format_u24
    ld hl,number_text
    ld de,row_buffer+19
    ld bc,7
    ldir
    ld hl,status_message
    ld de,row_buffer+27
    ld b,13
.message:
    ld a,(hl)
    or a
    jr z,.done
    ld (de),a
    inc hl
    inc de
    djnz .message
.done:
    jp view_output_row

view_top: db 0,0,0
view_left: dw 0
view_width: db 40
view_row: db 0
view_column: dw 0
view_cursor_seen: db 0
view_cursor_address: dw 0
view_cursor_left: dw 0
video_name_base: dw 0
