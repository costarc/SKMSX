; DOS1-compatible FCB block I/O, record size one: no CP/M padding or ^Z added.
file_load:
    ld hl,gap_lo
    call offset_is_zero
    jr z,.prompt
    ld de,doc_length
    call cmp24
    jr z,.prompt
    ld hl,msg_load_position
    jp set_status
.prompt:
    ld de,label_load
    call file_prompt
    ret c
    ld de,file_fcb
    ld c,00Fh
    call dos_call
    or a
    jr z,.opened
    ; A nonexistent filename starts a new empty document only at HOME.
    ld hl,gap_lo
    call offset_is_zero
    jp nz,file_error
    call buffer_reset
    call adopt_name
    ld hl,msg_new
    jp set_status
.opened:
    ld a,(file_fcb+19)
    or a
    jp nz,.too_large
    ld hl,file_fcb+16
    ld de,io_size
    call copy24
    ld hl,gap_hi
    ld de,gap_lo
    call subtract_fields
    ld hl,io_remaining
    call w24
    ld de,io_size
    call cmp24
    jp c,.too_large
    ld hl,io_size
    ld de,io_remaining
    call copy24
    ld hl,gap_lo
    ld de,io_position
    call copy24
    call file_prepare
.read:
    ld hl,io_remaining
    call offset_is_zero
    jr z,.commit
    call io_chunk
    ld de,file_fcb
    ld c,027h
    call dos_call
    or a
    jr nz,.read_error
    ld hl,io_buffer
    ld a,(io_count)
    ld b,a
.stage:
    push bc
    push hl
    ld a,(hl)
    ld (io_byte),a
    ld hl,io_position
    call r24
    ex de,hl
    push af
    ld a,(io_byte)
    ld e,a
    pop af
    call storage_write
    ld hl,io_position
    call inc24
    ld hl,io_remaining
    call dec24
    pop hl
    inc hl
    pop bc
    djnz .stage
    jr .read
.commit:
    call file_close
    or a
    jp nz,file_error
    ld hl,gap_lo
    call offset_is_zero
    jr nz,.append
    ld hl,capacity
    ld de,gap_hi
    call copy24
    ld hl,io_size
    ld de,doc_length
    call copy24
    jr .position
.append:
    ld hl,io_position
    ld de,doc_length
    call copy24
.position:
    ld hl,io_position
    ld de,gap_lo
    call copy24
    call nav_home
    call reset_view
    call invalidate_marks
    call adopt_name
    ld hl,msg_loaded
    jp set_status
.too_large:
    call file_close
    jp memory_full
.read_error:
    call file_close
    jp file_error

file_save:
    ld a,(file_named)
    or a
    jp z,file_save_as
    ld hl,file_name
    ld de,pending_name
    ld bc,15
    ldir
    call parse_filename
    ret c
    jr save_transaction
file_save_as:
    ld de,label_save
    call file_prompt
    ret c
save_transaction:
    ; Keep original identity separate from the temporary FCB.
    ld hl,file_fcb
    ld de,target_fcb
    ld bc,37
    ldir
    ld hl,temp_name
    call set_work_name
    call file_exists
    jp z,temp_exists
    ld hl,backup_name
    call set_work_name
    call file_exists
    jp z,temp_exists
    ld hl,temp_name
    call set_work_name
    ld de,file_fcb
    ld c,016h
    call dos_call
    or a
    jp nz,file_error
    call file_prepare
    xor a
    ld hl,io_position
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    ld hl,doc_length
    ld de,io_remaining
    call copy24
.write:
    ld hl,io_remaining
    call offset_is_zero
    jr z,.finish
    call io_chunk
    ld a,(io_count)
    ld b,a
    ld de,io_buffer
.fill:
    push bc
    push de
    ld hl,io_position
    ld de,scan_pos
    call copy24
    call buffer_get
    pop de
    ld (de),a
    inc de
    ld hl,io_position
    call inc24
    ld hl,io_remaining
    call dec24
    pop bc
    djnz .fill
    ld a,(io_count)
    ld l,a
    ld h,0
    ld de,file_fcb
    ld c,026h
    call dos_call
    or a
    jr nz,.write_error
    jr .write
.finish:
    call file_close
    or a
    jr nz,.cleanup
    ; Move existing target to backup, then move completed temp to target.
    ld hl,target_fcb
    ld de,file_fcb
    ld bc,37
    ldir
    call file_exists
    ld a,0
    ld (save_had_original),a
    jr nz,.install
    ld a,1
    ld (save_had_original),a
    call file_close
    ld hl,backup_name
    call rename_work
    or a
    jr nz,.cleanup
.install:
    ld hl,temp_name
    call set_work_name
    ld hl,target_fcb+1
    call rename_work
    or a
    jr nz,.rollback
    ld a,(save_had_original)
    or a
    jr z,.success
    ld hl,backup_name
    call set_work_name
    call delete_work
.success:
    call adopt_name
    ld hl,msg_saved
    jp set_status
.rollback:
    ld a,(save_had_original)
    or a
    jr z,.cleanup
    ld hl,backup_name
    call set_work_name
    ld hl,target_fcb+1
    call rename_work
    ; On rollback failure retain BOTH backup and temp for manual recovery.
    or a
    jp nz,recovery_error
.cleanup:
    ld hl,temp_name
    call set_work_name
    call delete_work
    jp file_error
.write_error:
    call file_close
    jr .cleanup

file_exists:
    ld de,file_fcb
    ld c,00Fh
    call dos_call
    or a
    ret nz
    call file_close
    xor a
    ret
file_close:
    ld de,file_fcb
    ld c,010h
    jp dos_call
delete_work:
    ld de,file_fcb
    ld c,013h
    jp dos_call
rename_work:
    ld de,file_fcb+17
    ld bc,11
    ldir
    ld de,file_fcb
    ld c,017h
    jp dos_call
set_work_name:
    push hl
    ld hl,file_fcb
    ld de,file_fcb+1
    ld bc,36
    ld (hl),0
    ldir
    ld a,(target_fcb)
    ld (file_fcb),a
    pop hl
    ld de,file_fcb+1
    ld bc,11
    ldir
    ret
file_prepare:
    ld hl,1
    ld (file_fcb+14),hl
    ld hl,0
    ld (file_fcb+33),hl
    ld (file_fcb+35),hl
    ld de,io_buffer
    ld c,01Ah
    jp dos_call
io_chunk:
    ld hl,io_remaining
    call r24
    or d
    jr nz,.full
    ld a,e
    cp IO_RECORDS
    jr c,.count
.full:
    ld a,IO_RECORDS
.count:
    ld (io_count),a
    ld l,a
    ld h,0
    ret

file_prompt:
    ld hl,pending_name
    ld b,14
    call prompt_input
    ret c
parse_filename:
    ld hl,file_fcb
    ld de,file_fcb+1
    ld bc,36
    ld (hl),0
    ldir
    ld hl,file_fcb+1
    ld b,11
.spaces:
    ld (hl),' '
    inc hl
    djnz .spaces
    ld hl,pending_name
    ld a,(hl)
    or a
    jp z,bad_filename
    inc hl
    ld a,(hl)
    dec hl
    cp ':'
    jr nz,.name
    ld a,(hl)
    and 0DFh
    sub 'A'-1
    cp 9
    jp nc,bad_filename
    or a
    jp z,bad_filename
    ld (file_fcb),a
    inc hl
    inc hl
.name:
    ld de,file_fcb+1
    ld b,8
    ld c,0
.character:
    ld a,(hl)
    or a
    jr z,.done
    cp '.'
    jr z,.extension
    cp 'a'
    jr c,.upper
    cp 'z'+1
    jr nc,.upper
    sub 32
.upper:
    cp 33
    jp c,bad_filename
    cp 127
    jp nc,bad_filename
    push hl
    push de
    ld e,a
    ld hl,invalid_chars
.invalid:
    ld a,(hl)
    or a
    jr z,.valid_character
    cp e
    jr z,.invalid_found
    inc hl
    jr .invalid
.valid_character:
    ld a,e
    pop de
    pop hl
    ld (de),a
    inc de
    inc hl
    inc c
    djnz .character
    ld a,(hl)
    or a
    jr z,.done
    cp '.'
    jp nz,bad_filename
.extension:
    ld a,c
    or a
    jp z,bad_filename
    bit 7,c
    jp nz,bad_filename
    set 7,c
    ld de,file_fcb+9
    ld b,3
    inc hl
    jr .character
.done:
    ld a,c
    and 07Fh
    jp z,bad_filename
    or a
    ret
.invalid_found:
    pop de
    pop hl
bad_filename:
    ld hl,msg_name
    call set_status
    scf
    ret
adopt_name:
    ld hl,pending_name
    ld de,file_name
    ld bc,15
    ldir
    ld a,1
    ld (file_named),a
    ret
reset_view:
    xor a
    ld (view_top),a
    ld (view_top+1),a
    ld (view_top+2),a
    ret
file_error:
    ld hl,msg_io
    jp set_status
temp_exists:
    ld hl,msg_temp
    jp set_status
recovery_error:
    ld hl,msg_recovery
    jp set_status

label_load: db "Load/new: ",0
label_save: db "Save as: ",0
msg_load_position: db "Use HOME/EOF",0
msg_name: db "Bad 8.3 name",0
msg_io: db "Disk error",0
msg_temp: db "SK2 temp used",0
msg_recovery: db "Keep SK2BAK!",0
msg_loaded: db "Loaded",0
msg_saved: db "Saved",0
msg_new: db "New file",0
invalid_chars: db '"*+,/:;<=>?[\]|',0
temp_name: db "SK2SAVE $$$"
backup_name: db "SK2BAK  $$$"
pending_name: ds 15
target_fcb: ds 37
io_size: ds 3
io_remaining: ds 3
io_position: ds 3
io_count: db 0
io_byte: db 0
save_had_original: db 0
