editor_main:
    xor a
    ld (exit_requested),a
.loop:
    call view_redraw
    call keyboard_read
    push af
    xor a
    ld (goal_keep),a
    pop af
    call dispatch
    ld a,(goal_keep)
    or a
    jr nz,.goal
    ld (goal_valid),a
.goal:
    ld a,(exit_requested)
    or a
    jr z,.loop
    ret

; Keys with Shift/Ctrl variants: key, plain, Shift, Ctrl (Ctrl wins).
dispatch:
    ld (command_key),a
    cp 8
    call z,invalidate_marks
    ld a,(command_key)
    cp 127
    call z,invalidate_marks
    ld a,(command_key)
    ld hl,modified_keys
    ld de,7
    ld b,modified_count
.modified:
    cp (hl)
    jr z,.variant
    add hl,de
    djnz .modified
    ld hl,plain_keys
    ld b,plain_count
.plain:
    cp (hl)
    inc hl
    jr z,.jump
    inc hl
    inc hl
    djnz .plain
    cp 9
    jp z,type_character
    cp 32
    ret c
    jp type_character
.variant:
    inc hl
    ld a,(modifiers)
    bit 1,a
    jr z,.shift
    inc hl
    inc hl
    inc hl
    inc hl
    jr .jump
.shift:
    bit 0,a
    jr z,.jump
    inc hl
    inc hl
.jump:
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    jp (hl)

toggle_insert:
    ld a,(insert_mode)
    xor 1
    ld (insert_mode),a
    ret

modified_keys:
    db 00Bh
    dw nav_home,nav_end,nav_home
    db 01Ch
    dw nav_right,nav_word_right,nav_line_end
    db 01Dh
    dw nav_left,nav_word_left,nav_line_home
    db 01Eh
    dw nav_up,scroll_up,page_up
    db 01Fh
    dw nav_down,scroll_down,page_down
    db 8
    dw delete_left,delete_word_left,delete_line_left
    db 127
    dw delete_right,delete_word_right,delete_line_right
modified_count equ ($-modified_keys)/7
plain_keys:
    db 27
    dw request_exit
    db 081h
    dw file_load
    db 082h
    dw file_save
    db 083h
    dw file_save_as
    db 084h
    dw find_prompt
    db 085h
    dw replace_prompt
    db 086h
    dw mark_begin
    db 087h
    dw mark_end
    db 088h
    dw block_copy
    db 089h
    dw find_repeat
    db 08Ah
    dw replace_repeat
    db 00Ch
    dw nav_end
    db 012h
    dw toggle_insert
    db 13
    dw insert_newline
plain_count equ ($-plain_keys)/3

request_exit:
    ld a,1
    ld (exit_requested),a
    ret
invalidate_marks:
    xor a
    ld (mark_flags),a
    ld (status_message),a
    ret

type_character:
    ld (typed_byte),a
    call invalidate_marks
    ld a,(insert_mode)
    or a
    jr nz,.insert
    call cursor_peek
    jr c,.insert
    call is_newline
    jr z,.insert
    call buffer_delete
.insert:
    ld a,(typed_byte)
    call buffer_insert
    ret nc
    jp memory_full

insert_newline:
    ; Atomic capacity check: free >= 2 before either CR or LF is inserted.
    ld hl,gap_lo
    ld de,temp_position
    call copy24
    ld hl,temp_position
    call inc24
    ld de,gap_hi
    call cmp24
    jp nc,memory_full
    call invalidate_marks
    ld a,13
    call buffer_insert
    ld a,10
    jp buffer_insert
memory_full:
    ld hl,msg_full
    jp set_status

mark_begin:
    ld hl,gap_lo
    ld de,block_begin
    call copy24
    ld a,1
    ld (mark_flags),a
    ld hl,msg_mark_start
    jp set_status
mark_end:
    ld a,(mark_flags)
    or a
    jr z,block_missing
    ld hl,block_begin
    ld de,gap_lo
    call cmp24
    jr nc,block_missing
    ld hl,gap_lo
    ld de,block_end
    call copy24
    ld a,3
    ld (mark_flags),a
    ld hl,msg_mark_end
    jp set_status
block_missing:
    ld hl,msg_no_block
    jp set_status

block_copy:
    ld a,(mark_flags)
    cp 3
    jr nz,block_missing
    ld hl,gap_lo
    ld de,block_begin
    call cmp24
    jr c,.outside
    jr z,.outside
    ld de,block_end
    call cmp24
    jr nc,.outside
    ld hl,msg_inside
    jp set_status
.outside:
    ; Count = end - begin. Check count <= gap_hi-gap_lo using 24-bit fields.
    ld hl,block_end
    ld de,block_begin
    call subtract_fields
    ld hl,copy_remaining
    call w24
    ld hl,gap_hi
    ld de,gap_lo
    call subtract_fields
    ld hl,temp_position
    call w24
    ld de,copy_remaining
    call cmp24
    jp c,memory_full
    ld hl,block_begin
    ld de,copy_source
    call copy24
.loop:
    ld hl,copy_source
    ld de,scan_pos
    call copy24
    call buffer_get
    ld (typed_byte),a
    ld hl,gap_lo
    ld de,copy_source
    call cmp24
    jr c,.adjust
    jr nz,.insert
.adjust:
    ld hl,copy_source
    call inc24
.insert:
    ld a,(typed_byte)
    call buffer_insert
    ld hl,copy_source
    call inc24
    ld hl,copy_remaining
    call dec24
    call offset_is_zero
    jr nz,.loop
    jp invalidate_marks

; Fields HL minus DE -> A:DE, unsigned. Caller proves left >= right.
subtract_fields:
    push de
    call r24
    ld (arith_left),de
    ld (arith_left+2),a
    pop hl
    call r24
    ld c,a
    ld hl,(arith_left)
    or a
    sbc hl,de
    ld a,(arith_left+2)
    sbc a,c
    ex de,hl
    ret

; Move the gap to target_position without modifying text.
seek_target:
    ld hl,target_position
    ld de,doc_length
    call cmp24
    jr c,.valid
    jr z,.valid
    scf
    ret
.valid:
    ld hl,gap_lo
    ld de,target_position
    call cmp24
    ret z
    jr c,.right
    call buffer_left
    jr .valid
.right:
    call buffer_right
    jr .valid

find_prompt:
    ld de,label_find
    ld hl,needle
    ld b,31
    call prompt_input
    ret c
    xor a
    ld (find_next),a
    jp find_execute
find_repeat:
    ld a,1
    ld (find_next),a
find_execute:
    ld a,(needle)
    or a
    jr z,find_not_found
    ld hl,gap_lo
    ld de,find_position
    call copy24
    ld a,(find_next)
    or a
    jr z,.candidate
    ld hl,find_position
    call inc24
.candidate:
    ld hl,find_position
    ld de,doc_length
    call cmp24
    jr nc,find_not_found
    ld de,scan_pos
    call copy24
    ld ix,needle
.match:
    ld a,(ix+0)
    or a
    jr z,.found
    call buffer_get
    jr c,find_not_found
    cp (ix+0)
    jr nz,.next
    ld hl,scan_pos
    call inc24
    inc ix
    jr .match
.next:
    ld hl,find_position
    call inc24
    jr .candidate
.found:
    ld hl,find_position
    ld de,target_position
    call copy24
    call seek_target
    ld hl,msg_found
    call set_status
    or a
    ret
find_not_found:
    ld hl,msg_not_found
    call set_status
    scf
    ret

replace_prompt:
    ld de,label_find
    ld hl,needle
    ld b,31
    call prompt_input
    ret c
    ld de,label_replace
    ld hl,replacement
    ld b,31
    call prompt_input
    ret c
    xor a
    ld (find_next),a
    jr replace_execute
replace_repeat:
    xor a
    ld (find_next),a
replace_execute:
    call find_execute
    ret c
    ld hl,needle
    call string_length
    ld (needle_length),a
    ld hl,replacement
    call string_length
    ld (replacement_length),a
    ld hl,gap_hi
    ld de,gap_lo
    call subtract_fields
    or a
    jr nz,.fits
    ld hl,0
    ld a,(needle_length)
    ld l,a
    add hl,de
    ld a,h
    or a
    jr nz,.fits
    ld a,(replacement_length)
    cp l
    jr c,.fits
    jr z,.fits
    jp memory_full
.fits:
    call invalidate_marks
    ld a,(needle_length)
    ld b,a
.delete:
    push bc
    call buffer_delete
    pop bc
    djnz .delete
    ld ix,replacement
.insert:
    ld a,(ix+0)
    or a
    ret z
    call buffer_insert
    inc ix
    jr .insert

string_length:
    ld b,0
.loop:
    ld a,(hl)
    or a
    ld a,b
    ret z
    inc b
    inc hl
    jr .loop

set_status:
    ld de,status_message
    ld b,13
.loop:
    ld a,(hl)
    ld (de),a
    or a
    ret z
    inc hl
    inc de
    djnz .loop
    xor a
    ld (de),a
    ret

; Prompt state is independent of the document, and every exit is explicit.
prompt_input:
    ld (prompt_buffer),hl
    ld (prompt_label),de
    ld a,b
    ld (prompt_limit),a
    xor a
    ld (prompt_length),a
    ld (hl),a
.loop:
    call prompt_render
    call keyboard_read
    cp 27
    jr z,.escape
    cp 13
    jr z,.done
    cp 8
    jr z,.backspace
    cp 32
    jr c,.loop
    cp 127
    jr nc,.loop
    ld c,a
    ld a,(prompt_length)
    ld b,a
    ld a,(prompt_limit)
    cp b
    jr z,.loop
    ld a,b
    inc a
    ld (prompt_length),a
    ld e,b
    ld d,0
    ld hl,(prompt_buffer)
    add hl,de
    ld (hl),c
    inc hl
    ld (hl),0
    jr .loop
.backspace:
    ld a,(prompt_length)
    or a
    jr z,.loop
    dec a
    ld (prompt_length),a
    ld e,a
    ld d,0
    ld hl,(prompt_buffer)
    add hl,de
    ld (hl),0
    jr .loop
.escape:
    ld hl,msg_cancel
    call set_status
    scf
    ret
.done:
    or a
    ret

prompt_render:
    call view_blank_row
    ld a,23
    ld (view_row),a
    ld hl,(prompt_label)
    ld de,row_buffer
.label:
    ld a,(hl)
    or a
    jr z,.input
    ld (de),a
    inc de
    inc hl
    jr .label
.input:
    ld hl,(prompt_buffer)
.text:
    ld a,(hl)
    or a
    jr z,.cursor
    ld (de),a
    inc de
    inc hl
    jr .text
.cursor:
    ld a,'_'
    ld (de),a
    jp view_output_row

file_name: db "Untitled",0
    ds 6
file_named: db 0
insert_mode: db 1
exit_requested: db 0
modifiers: db 0
command_key: db 0
typed_byte: db 0
mark_flags: db 0
block_begin: ds 3
block_end: ds 3
copy_remaining: ds 3
copy_source: ds 3
target_position: ds 3
temp_position: ds 3
arith_left: ds 3
find_position: ds 3
find_next: db 0
needle: ds 32
replacement: ds 32
needle_length: db 0
replacement_length: db 0
prompt_buffer: dw 0
prompt_label: dw 0
prompt_limit: db 0
prompt_length: db 0
status_message: ds 14
label_find: db "Find: ",0
label_replace: db "With: ",0
msg_full: db "Buffer full",0
msg_mark_start: db "Block start",0
msg_mark_end: db "Block marked",0
msg_no_block: db "Mark a block",0
msg_inside: db "Inside block",0
msg_found: db "Found",0
msg_not_found: db "Not found",0
msg_cancel: db "Cancelled",0
