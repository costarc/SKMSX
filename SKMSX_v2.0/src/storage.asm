; Banked storage. Public byte API preserves BC/DE/HL, clobbers AF only.
; Calls occur with interrupts disabled. Platform restores VDP page zero before EI.
; Installer supplies mapper jump entries, selected slot, segment table and base.
storage_read:
    push bc
    push de
    push hl
    ld b,a
    ld a,(storage_kind)
    or a
    ld a,b
    jr nz,.mapper
    call vram_address_read
    in a,(098h)
    jr .done
.mapper:
    call mapper_open
    ld a,(hl)
.done:
    pop hl
    pop de
    pop bc
    ret

storage_write:
    push bc
    push de
    push hl
    ld b,a
    ld a,(storage_kind)
    or a
    ld a,b
    jr nz,.mapper
    push de
    call vram_address_write
    pop de
    ld a,e
    out (098h),a
    jr .done
.mapper:
    push de
    call mapper_open
    pop de
    ld (hl),e
.done:
    pop hl
    pop de
    pop bc
    ret

; Release the page-2 window before any interrupt, DOS call or hook return.
storage_flush:
    ld a,(storage_kind)
    or a
    ret z
    jp mapper_close

; A:HL offset -> VDP address (base + offset). B=read/write address flag.
vram_address_write:
    ld b,040h
    jr vram_address
vram_address_read:
    ld b,0
vram_address:
    ld de,(storage_base)
    add hl,de
    adc a,0
    ld c,a
    ld a,(machine_msx2)
    or a
    jr z,.low
    ld a,h
    rlca
    rlca
    and 3
    ld d,a
    ld a,c
    add a,a
    add a,a
    or d
    out (099h),a
    ld a,08Eh
    out (099h),a
.low:
    ld a,l
    out (099h),a
    ld a,h
    and 03Fh
    or b
    out (099h),a
    ret

; Patched to operating-system mapper routines before relocation.
map_allocate: jp 0
map_free:     jp 0
map_put_p2:   jp 0
map_get_p2:   jp 0
map_put_p1:   jp 0
map_get_p1:   jp 0

storage_kind: db 0              ; 0 VRAM, 1 mapper
machine_msx2: db 0
storage_base: dw 0
mapper_slot: db 0
segment_count: db 0
restore_segment: db 0
restore_slot: db 0
bank_active: db 0               ; editor bank mapped at 4000h on activation
code_segment: db 0
