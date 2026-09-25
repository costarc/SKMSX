; 24-bit little-endian offsets. No CPU pointer is a document offset.
; r24: HL -> field; returns A:DE; preserves HL, BC.
r24:
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    ld a,(hl)
    dec hl
    dec hl
    ret
; w24: HL -> field, A:DE -> field. Preserves all registers.
w24:
    ld (hl),e
    inc hl
    ld (hl),d
    inc hl
    ld (hl),a
    dec hl
    dec hl
    ret
; inc24/dec24: HL -> field. Caller proves the operation is within bounds.
inc24:
    inc (hl)
    ret nz
    inc hl
    inc (hl)
    jr nz,.done
    inc hl
    inc (hl)
    dec hl
.done:
    dec hl
    ret
dec24:
    ld a,(hl)
    dec (hl)
    or a
    ret nz
    inc hl
    ld a,(hl)
    dec (hl)
    or a
    jr nz,.done
    inc hl
    dec (hl)
    dec hl
.done:
    dec hl
    ret
; cmp24: HL -> left, DE -> right. Unsigned C=left<right, Z=equal.
; Preserves HL, DE, BC. AF changed.
cmp24:
    push hl
    push de
    push bc
    inc hl
    inc hl
    inc de
    inc de
    ld b,3
.byte:
    ld a,(de)
    ld c,a
    ld a,(hl)
    cp c
    jr nz,.done
    dec hl
    dec de
    djnz .byte
.done:
    pop bc
    pop de
    pop hl
    ret
; copy24: HL -> source, DE -> destination; preserves pointers and BC.
copy24:
    push bc
    push hl
    push de
    ld bc,3
    ldir
    pop de
    pop hl
    pop bc
    ret
