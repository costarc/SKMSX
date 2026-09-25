; Page-3 extras, installed only with DOS2 or mapper storage (banked editor).
; DOS2 must be called via its RAM page-zero entry, never Disk BASIC F37Dh.
dos2_call:
    push bc
    push de
    push hl
    call storage_flush
    ld a,(0F341h)
    ld h,0
    call 0024h
    ; DOS2 prints a bare LF through CHPUT on every call made from here. Keep
    ; the BIOS cursor on row 1 so it can never scroll the caller's screen;
    ; the caller's CSRY is restored with the F1C9h..F3FFh context on exit.
    ld a,1
    ld (0F3DCh),a
    pop hl
    pop de
    pop bc
    ei
    call 0005h
    di
    push af
    push bc
    push de
    push hl
    ld a,(0FCC1h)
    ld h,0
    call 0024h
    pop hl
    pop de
    pop bc
    pop af
    ret

mapper_open:
    ; Bank = offset >> 14, within-bank pointer = 8000h | (offset & 3FFFh).
    add a,a
    add a,a
    ld b,a
    ld a,h
    rlca
    rlca
    and 3
    or b
    ld c,a
    ld b,0
    ld a,h
    and 03Fh
    or 080h
    ld h,a
    push hl
    ld a,(mapper_active)
    or a
    jr nz,.active
    push bc
    call map_get_p2
    ld (restore_segment),a
    call get_page2_slot
    ld (restore_slot),a
    ld a,(mapper_slot)
    ld h,080h
    call bios_enaslt
    pop bc
    ld a,1
    ld (mapper_active),a
    jr .select
.active:
    ld a,(mapper_index)
    cp c
    jr z,.done
.select:
    ld a,c
    ld (mapper_index),a
    ld hl,segments
    add hl,bc
    ld a,(hl)
    call map_put_p2
.done:
    pop hl
    ret
mapper_close:
    ld a,(mapper_active)
    or a
    ret z
    xor a
    ld (mapper_active),a
    ld a,(restore_segment)
    call map_put_p2
    ld a,(restore_slot)
    ld h,080h
    jp bios_enaslt

; Full primary+secondary ID of the slot currently mapped into CPU page 2/1.
get_page2_slot:
    in a,(0A8h)
    rrca
    rrca
    ld b,0
    jr page_slot
get_page1_slot:
    in a,(0A8h)
    ld b,1
page_slot:
    rrca
    rrca
    and 3
    ld c,a
    ld a,b
    ld (page_slot_shift),a
    ld b,0
    ld hl,0FCC1h
    add hl,bc
    ld a,(hl)
    and 080h
    or c
    ret p
    ld e,a
    ld hl,0FCC5h
    add hl,bc
    ld a,(hl)
    ld b,a
    ld a,(page_slot_shift)
    or a
    ld a,b
    jr nz,.page1
    rrca
    rrca
.page1:
    and 00Ch
    or e
    ret
page_slot_shift: db 0

; Map the editor bank (code_segment of the mapper slot) into page 1 for an
; activation, and give the interrupted program its page 1 back afterwards.
bank_enter:
    call map_get_p1
    ld (bank_saved_segment),a
    call get_page1_slot
    ld (bank_saved_slot),a
    ld a,(mapper_slot)
    ld h,040h
    call bios_enaslt
    ld a,(code_segment)
    jp map_put_p1
bank_leave:
    ld a,(bank_saved_segment)
    call map_put_p1
    ld a,(bank_saved_slot)
    ld h,040h
    jp bios_enaslt
bank_saved_segment: db 0
bank_saved_slot: db 0

; ENASLT (A=slot, H=page). Page 0 holds ENASLT both inside the BIOS hook and
; under DOS (installer, /T). Not through CALSLT: its return restores the whole
; primary slot register and would undo the switch of another page.
bios_enaslt:
    push bc
    push de
    push hl
    push ix
    push iy
    call 0024h
    di
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    ret

mapper_active: db 0
mapper_index: db 0
