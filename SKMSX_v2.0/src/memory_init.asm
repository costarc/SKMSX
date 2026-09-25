; Allocation is performed while DOS owns the machine, before editor entry.
memory_init:
    ld bc,006Fh
    call 0005h
    di
    ld a,b
    ld (dos_version),a
    ld a,(0FCC1h)
    ld hl,002Dh
    call 000Ch                 ; RDSLT: main ROM MSX generation
    di
    ld (machine_msx2),a
    ld a,(0FB20h)
    bit 0,a
    jp z,.vram
    xor a
    ld de,0402h
    call 0FFCAh
    di
    or a
    jp z,.vram
    ld de,0
    add hl,de
    ld (map_allocate+1),hl
    ld de,3
    add hl,de
    ld (map_free+1),hl
    ld de,021h
    add hl,de
    ld (map_put_p2+1),hl
    ld de,3
    add hl,de
    ld (map_get_p2+1),hl
    ld de,-9                   ; PUT_P1 = table+1Eh, GET_P1 = table+21h
    add hl,de
    ld (map_put_p1+1),hl
    ld de,3
    add hl,de
    ld (map_get_p1+1),hl
    xor a
    ld de,0401h
    call 0FFCAh
    di
    ld c,0
.slot:
    ld a,(hl)
    or a
    jr z,.chosen
    ld b,a
    inc hl
    inc hl
    ld a,(hl)
    cp c
    jr c,.next
    jr z,.next
    ld c,a
    ld a,b
    ld (mapper_slot),a
.next:
    ld de,6
    add hl,de
    jr .slot
.chosen:
    ld a,c
    or a
    jr z,.vram
.allocate:
    ld a,(mapper_slot)
    ld b,a
    ld a,1                    ; System segments are explicitly released.
    call map_allocate
    jr c,.allocated
    push af
    ld a,(segment_count)
    ld e,a
    ld d,0
    ld hl,segments
    add hl,de
    pop af
    ld (hl),a
    ld a,(segment_count)
    inc a
    ld (segment_count),a
    cp MAX_SEGMENTS
    jr nz,.allocate
.allocated:
    ld a,(install_trim)
    or a
    jr z,.sized
    ; Resident install: one segment holds the editor bank (page 1 at 4000h),
    ; the rest the document. Without room for both, fall back to VRAM.
    call trim_segments
    ld a,(segment_count)
    cp 3
    jr nc,.bank
    ld l,0
    call release_segments
    jr .vram
.bank:
    dec a
    ld (segment_count),a
    ld e,a
    ld d,0
    ld hl,segments
    add hl,de
    ld a,(hl)
    ld (code_segment),a
    ld a,1
    ld (bank_active),a
.sized:
    ld a,(segment_count)
    or a
    jr z,.vram
    ; Easier exact 24-bit count: segments * 16384.
    ld a,(segment_count)
    ld e,a
    and 3
    rrca
    rrca
    ld d,a
    ld a,e
    srl a
    srl a
    ld e,0
    ld hl,capacity
    call w24
    ld a,1
    ld (storage_kind),a
    jr .reserve
.vram:
    ld a,(machine_msx2)
    or a
    jr nz,.extended
    ld hl,02020h
    ld (storage_base),hl
    ld de,01FE0h
    xor a
    jr .size
.extended:
    ; Probe 64K aliasing reversibly. All touched bytes are restored.
    xor a
    ld hl,03FFEh
    call storage_read
    ld (probe_low),a
    ld a,1
    call storage_read
    ld (probe_high),a
    xor a
    ld e,055h
    call storage_write
    ld a,1
    ld e,0AAh
    call storage_write
    ld a,1
    call storage_read
    cp 0AAh
    jr nz,.small
    xor a
    call storage_read
    cp 055h
    ld a,0
    jr nz,.probed
    inc a
    jr .probed
.small:
    xor a
.probed:
    ld (vram_large),a
    ld a,(probe_high)
    ld e,a
    ld a,1
    call storage_write
    ld a,(probe_low)
    ld e,a
    xor a
    call storage_write
    ld hl,04000h
    ld (storage_base),hl
    ld a,(vram_large)
    ld de,0C000h
.size:
    ld hl,capacity
    call w24
.reserve:
    ; Last 3 KB hold screen, DiskROM/BIOS context and function keys.
    ld hl,capacity
    call r24
    ex de,hl
    ld de,0C00h
    push af
    ld a,(dos_version)
    cp 2
    jr c,.reserve_size
    ld de,04000h
.reserve_size:
    pop af
    or a
    sbc hl,de
    sbc a,0
    ex de,hl
    ld hl,capacity
    call w24
    ld hl,capacity
    ld de,screen_store
    call copy24
    jp buffer_reset

; Resident install only: each segment costs a page-3 byte beside the banked
; image (core + extras), and DOS's BDOS entry (rebuilt below it) must stay
; above C000h. Keep the segments that fit and return the rest.
trim_segments:
    ld hl,(0006h)
    ld de,0C000h+BANKED_PAGE3
    or a
    sbc hl,de
    jr nc,.room
    ld hl,0
.room:
    ld a,h
    or a
    ret nz
; Release segments until L remain.
release_segments:
.loop:
    ld a,(segment_count)
    cp l
    ret z
    ret c
    dec a
    ld (segment_count),a
    push hl
    ld e,a
    ld d,0
    ld hl,segments
    add hl,de
    ld a,(mapper_slot)
    ld b,a
    ld a,(hl)
    call map_free
    pop hl
    jr .loop
install_trim: db 0
