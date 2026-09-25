memory_release:
    call storage_flush
    ld a,(storage_kind)
    or a
    ret z
    ld a,(bank_active)
    or a
    jr z,.loop
    xor a
    ld (bank_active),a
    ld a,(mapper_slot)
    ld b,a
    ld a,(code_segment)
    call map_free
.loop:
    ld a,(segment_count)
    or a
    ret z
    dec a
    ld (segment_count),a
    ld e,a
    ld d,0
    ld hl,segments
    add hl,de
    ld a,(mapper_slot)
    ld b,a
    ld a,(hl)
    call map_free
    jr .loop

screen_store: ds 3
probe_low: db 0
probe_high: db 0
vram_large: db 0
