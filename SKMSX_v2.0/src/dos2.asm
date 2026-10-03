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
    call mapper_p2_now
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

; Full primary+secondary ID of the slot currently mapped into CPU page B.
get_page3_slot:
    ld b,3
    jr get_page_slot
get_page2_slot:
    ld b,2
    jr get_page_slot
get_page1_slot:
    ld b,1
get_page_slot:
    in a,(0A8h)
    ld d,b
.primary:
    rrca
    rrca
    dec d
    jr nz,.primary
    and 3
    ld e,a
    ld d,0
    ld hl,0FCC1h            ; EXPTBL: bit 7 = primary slot is expanded
    add hl,de
    ld a,(hl)
    and 080h
    or e
    ret p
    ld c,a
    ld hl,0FCC5h            ; SLTTBL: shadow of the sub-slot register
    add hl,de
    ld a,(hl)
    ld d,b
.sub:
    rrca
    rrca
    dec d
    jr nz,.sub
    and 3
    rlca
    rlca
    or c
    ret

; Segment currently selected in page 2 / page 1. Mapper ports that cannot be
; read return FFh; direct access then assumes the MSX-DOS 1 layout 3,2,1,0.
mapper_p2_now:
    call map_get_p2
    ld b,1
    jr mapper_now
mapper_p1_now:
    call map_get_p1
    ld b,2
mapper_now:
    cp 0FFh
    ret nz
    ld a,(mapper_direct)
    or a
    ld a,0FFh
    ret z
    ld a,b
    ret

; The editor bank is mapped at 4000h for each activation (bank_active = 1:
; in a mapper segment; 2: copied in from video memory). The interrupted
; program's page 1 is given back afterwards.
bank_enter:
    cp 2
    jr z,bank_enter_vram
    call mapper_p1_now
    ld (bank_saved_segment),a
    call get_page1_slot
    ld (bank_saved_slot),a
    ld a,(mapper_slot)
    ld h,040h
    call bios_enaslt
    ld a,(code_segment)
    jp map_put_p1
bank_leave:
    cp 2
    jr z,bank_leave_vram
    ld a,(bank_saved_segment)
    call map_put_p1
    ld a,(bank_saved_slot)
    ld h,040h
    jp bios_enaslt
bank_saved_segment: db 0
bank_saved_slot: db 0

; Video memory bank: page 1 is switched to the RAM slot of page 3 (the TPA),
; the program RAM there is saved to video memory and the bank image is copied
; over it. Leaving reverses this and keeps the bank's changes in the image.
bank_enter_vram:
    call get_page1_slot
    ld (bank_saved_slot),a
    call get_page3_slot
    ld h,040h
    call bios_enaslt
    ld hl,04000h
    ld de,(bank_save_off)
    ld bc,(bank_area)
    xor a
    call bank_block
    ld hl,04000h
    ld de,(bank_vram_off)
    ld bc,(bank_area)
    ld a,1
    jp bank_block
bank_leave_vram:
    ld hl,04000h
    ld de,(bank_vram_off)
    ld bc,(bank_area)
    xor a
    call bank_block
    ld hl,04000h
    ld de,(bank_save_off)
    ld bc,(bank_area)
    ld a,1
    call bank_block
    ld a,(bank_saved_slot)
    ld h,040h
    jp bios_enaslt

; Copy BC bytes between CPU HL and video memory at screen_store+DE.
; A = 0: CPU to video memory, 1: video memory to CPU. The address is set
; every 256 bytes; 37 T-states per byte keeps within the VDP access limit.
bank_block:
    ld (blk_dir),a
    ld (blk_cpu),hl
    ld (blk_left),bc
    ld hl,(screen_store)
    add hl,de
    ld (blk_off),hl
    ld a,(screen_store+2)
    adc a,0
    ld (blk_off+2),a
.chunk:
    ld hl,(blk_left)
    ld a,h
    or l
    ret z
    ld e,l
    ld a,h
    or a
    jr z,.size
    ld e,0                  ; 0 = a full 256-byte chunk
.size:
    ld a,e
    ld (blk_n),a
    ld hl,(blk_off)
    ld a,(blk_off+2)
    ld b,a                  ; (preserved copy; vram_address clobbers B)
    ld a,(blk_dir)
    or a
    ld a,b
    jr nz,.read_address
    call vram_address_write
    jr .address_set
.read_address:
    call vram_address_read
.address_set:
    ld a,(blk_n)
    ld b,a
    ld hl,(blk_cpu)
    ld a,(blk_dir)
    or a
    jr nz,.in
.out:
    ld a,(hl)
    out (098h),a
    inc hl
    djnz .out
    jr .done
.in:
    in a,(098h)
    ld (hl),a
    inc hl
    djnz .in
.done:
    ld (blk_cpu),hl
    ld a,(blk_n)
    ld e,a
    ld d,0
    or a
    jr nz,.advance
    inc d                   ; 256
.advance:
    ld hl,(blk_off)
    add hl,de
    ld (blk_off),hl
    jr nc,.left
    ld a,(blk_off+2)
    inc a
    ld (blk_off+2),a
.left:
    ld hl,(blk_left)
    or a
    sbc hl,de
    ld (blk_left),hl
    jr .chunk
blk_dir: db 0
blk_cpu: dw 0
blk_left: dw 0
blk_off: ds 3
blk_n: db 0

; ENASLT (A=slot, H=page). Page 0 holds ENASLT both inside the BIOS hook and
; under DOS (installer, foreground). Not through CALSLT: its return restores the whole
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
