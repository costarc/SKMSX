; Storage ABI: storage_read/write take A:HL physical offset, write byte in E.
; Both preserve BC,DE,HL. read returns byte in A; write clobbers only AF.
; C=operation refused; NC=success. Every primitive checks its own bounds.

buffer_reset:
    xor a
    ld hl,gap_lo
    ld b,3
.zero:
    ld (hl),a
    inc hl
    djnz .zero
    ld hl,doc_length
    ld b,3
.length:
    ld (hl),a
    inc hl
    djnz .length
    ld hl,capacity
    ld de,gap_hi
    jp copy24

; Insert A at cursor, advancing cursor and length by one. No mutation if full.
buffer_insert:
    push af
    ld hl,gap_lo
    ld de,gap_hi
    call cmp24
    jr z,.full
    call r24
    ex de,hl
    pop bc
    ld e,b
    call storage_write
    ld hl,gap_lo
    call inc24
    ld hl,doc_length
    call inc24
    or a
    ret
.full:
    pop af
    scf
    ret

buffer_left:
    ld hl,gap_lo
    call offset_is_zero
    scf
    ret z
    call dec24
    call r24
    ex de,hl
    call storage_read
    push af
    ld hl,gap_hi
    call dec24
    call r24
    ex de,hl
    pop bc
    ld e,b
    call storage_write
    or a
    ret

buffer_right:
    ld hl,gap_hi
    ld de,capacity
    call cmp24
    scf
    ret z
    call r24
    ex de,hl
    call storage_read
    push af
    ld hl,gap_lo
    call r24
    ex de,hl
    pop bc
    ld e,b
    call storage_write
    ld hl,gap_lo
    call inc24
    ld hl,gap_hi
    call inc24
    or a
    ret

buffer_backspace:
    ld hl,gap_lo
    call offset_is_zero
    scf
    ret z
    call dec24
    ld hl,doc_length
    call dec24
    or a
    ret

buffer_delete:
    ld hl,gap_hi
    ld de,capacity
    call cmp24
    scf
    ret z
    call inc24
    ld hl,doc_length
    call dec24
    or a
    ret

; Read logical offset from scan_pos. Does not mutate cursor, gap or scan_pos.
; EOF: C set and A=0. Other bytes, including NUL and 1Ah, are ordinary data.
buffer_get:
    ld hl,scan_pos
    ld de,doc_length
    call cmp24
    jr nc,.eof
    ld de,gap_lo
    call cmp24
    call r24
    ex de,hl
    jr c,.physical
    ; physical = logical - gap_lo + gap_hi, in 24-bit arithmetic.
    ld b,a
    ld de,(gap_lo)
    or a
    sbc hl,de
    ld a,(gap_lo+2)
    ld c,a
    ld a,b
    sbc a,c
    ld b,a
    ld de,(gap_hi)
    add hl,de
    ld a,(gap_hi+2)
    adc a,b
.physical:
    call storage_read
    or a
    ret
.eof:
    xor a
    scf
    ret

offset_is_zero:
    ld a,(hl)
    inc hl
    or (hl)
    inc hl
    or (hl)
    dec hl
    dec hl
    ret

capacity:   db 0,0,0
gap_lo:     db 0,0,0
gap_hi:     db 0,0,0
doc_length: db 0,0,0
scan_pos:   db 0,0,0
