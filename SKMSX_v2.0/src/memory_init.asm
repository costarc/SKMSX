; Choice of text memory and of where the editor program lives. Performed while
; DOS owns the machine, before editor entry.
;   storage: the larger of the best memory mapper and video memory
;   bank (resident install only): a mapper segment when the mapper is chosen,
;     otherwise video memory on an MSX2, otherwise one block in page 3
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
    ld hl,BANK_AREA
    ld (bank_area),hl
    call vram_probe
    call mapper_find
    ld (mapper_avail),a
    ld b,2                     ; a mapper needs two segments of text memory,
    ld a,(install_trim)
    or a
    jr z,.minimum
    inc b                      ; three when the resident bank takes one more
.minimum:
    ld a,(mapper_avail)
    cp b
    jp c,.vram
    ld e,a                     ; mapper_cap = segments * 16384
    and 3
    rrca
    rrca
    ld d,a
    ld a,e
    srl a
    srl a
    ld e,0
    ld hl,mapper_cap
    call w24
    ld hl,vram_cap
    ld de,mapper_cap
    call cmp24                 ; carry: the mapper is larger than video memory
    jp nc,.vram
    ld a,(mapper_direct)
    or a
    jr z,.allocate
    ld a,(mapper_first)        ; direct access: consecutive segments
    ld c,a
    ld a,(mapper_avail)
    ld b,a
    ld hl,segments
.fill:
    ld (hl),c
    inc hl
    inc c
    djnz .fill
    ld a,(mapper_avail)
    ld (segment_count),a
    jr .allocated
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
    ; the rest the document. Without room for both, use video memory.
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
    ld a,(segment_count)       ; segments * 16384
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
    ld hl,vram_cap
    ld de,capacity
    call copy24
    ; Resident install on an MSX2: the editor bank lives in video memory too,
    ; so that only the small core stays in page 3.
    ld a,(install_trim)
    or a
    jr z,.reserve
    ld a,(machine_msx2)
    or a
    jr z,.reserve
    ld a,2
    ld (bank_active),a
.reserve:
    ; Reserve at the end of the text memory: screen backup, DiskROM/BIOS
    ; context and function keys (3 KB; 16 KB with MSX-DOS 2), then for a video
    ; memory bank two areas for the bank image and the saved program RAM.
    ld de,0C00h
    ld a,(dos_version)
    cp 2
    jr c,.base
    ld de,04000h
.base:
    ld (bank_vram_off),de
    ld hl,BANK_AREA
    add hl,de
    ld (bank_save_off),hl
    ld a,(bank_active)
    cp 2
    jr nz,.reserve_size
    ld de,BANK_AREA
    add hl,de
    ex de,hl
.reserve_size:
    push de
    ld hl,capacity
    call r24
    ex de,hl
    pop de
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

; Video memory (text memory, before the reserve). Out: storage_base, vram_cap.
vram_probe:
    ld a,(machine_msx2)
    or a
    jr nz,.extended
    ld hl,02020h
    ld (storage_base),hl
    ld de,01FE0h
    xor a
    jr .store
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
.store:
    ld hl,vram_cap
    jp w24

; The memory mapper to use. Out: A = usable segments (0 = none), mapper_slot
; and the map_* entries set; mapper_direct = 1 when no OS routines serve it.
mapper_find:
    xor a
    ld (mapper_direct),a
    ld a,(0FB20h)
    bit 0,a
    jr z,.hardware
    xor a
    ld de,0402h
    call 0FFCAh
    di
    or a
    jr z,.hardware
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
    cp MAX_SEGMENTS+1
    ret c
    ld a,MAX_SEGMENTS
    ret
.hardware:
    ; MSX-DOS 1 without mapper support routines (such as MSR): look for a
    ; mapper on the hardware.
    ld a,(dos_version)
    cp 2
    jr nc,.none
    jp mapper_scan
.none:
    xor a
    ret

; Every slot is switched into page 2 and tested for a memory mapper. The
; segment registers (ports FCh-FFh) are shared by all mappers.
mapper_scan:
    di
    xor a
    ld (scan_best),a
    call get_page3_slot
    ld (scan_tpa),a
    call get_page2_slot
    ld (scan_page2),a
    in a,(0FEh)
    inc a
    jr nz,.readable
    ld a,2                     ; port cannot be read: the MSX-DOS 1 layout
.readable:
    dec a                      ; (FFh+1=0 -> 2-1 = segment 1 of page 2)
    ld (scan_segment),a
    ld b,0
.primary:
    ld e,b
    ld d,0
    ld hl,0FCC1h
    add hl,de
    ld a,(hl)
    and 080h
    jr z,.plain
    ld c,0
.sub:
    ld a,c
    rlca
    rlca
    or b
    or 080h
    push bc
    call scan_slot
    pop bc
    inc c
    ld a,c
    cp 4
    jr nz,.sub
    jr .next
.plain:
    ld a,b
    push bc
    call scan_slot
    pop bc
.next:
    inc b
    ld a,b
    cp 4
    jr nz,.primary
    ld a,(scan_best)
    or a
    ret z
    ld hl,map_put_p2           ; IN/OUT stubs on the segment ports
    ld a,0D3h
    ld c,0FEh
    call direct_stub
    ld hl,map_get_p2
    ld a,0DBh
    call direct_stub
    ld hl,map_put_p1
    ld a,0D3h
    ld c,0FDh
    call direct_stub
    ld hl,map_get_p1
    ld a,0DBh
    call direct_stub
    ld a,0C9h
    ld (map_allocate),a        ; nothing to allocate or free: RET
    ld (map_free),a
    ld a,1
    ld (mapper_direct),a
    ld a,(scan_best)
    ret

; HL = three-byte entry, A = IN/OUT opcode, C = port: "IN/OUT (port),A; RET".
direct_stub:
    ld (hl),a
    inc hl
    ld (hl),c
    inc hl
    ld (hl),0C9h
    ret

; A = slot ID. Records the slot when it holds a larger usable mapper.
scan_slot:
    ld (scan_id),a
    ld h,080h
    call bios_enaslt
    call probe_mapper          ; A = segments (255 = 256), 0 = no mapper
    push af
    ld a,(scan_page2)
    ld h,080h
    call bios_enaslt
    ld a,(scan_segment)
    out (0FEh),a
    pop af
    or a
    ret z
    ld b,a
    ld c,0
    ld a,(scan_id)
    ld hl,scan_tpa
    cp (hl)
    jr nz,.count
    ld c,4                     ; segments 0-3 of the TPA slot belong to DOS
.count:
    ld a,b
    sub c
    ret z
    ret c
    cp MAX_SEGMENTS+1
    jr c,.capped
    ld a,MAX_SEGMENTS
.capped:
    ld hl,scan_best
    cp (hl)
    ret c
    ret z
    ld (hl),a
    ld a,(scan_id)
    ld (mapper_slot),a
    ld a,c
    ld (mapper_first),a
    ret

; Page 2 shows the slot under test. The first byte of every segment is saved,
; each segment gets its own number written (aliased segments end up holding
; the number of the last alias), the pattern is checked and every byte is
; restored. A = size in segments (255 for 256), 0 when it is not a mapper.
probe_mapper:
    ld hl,savebuf
    ld e,0
.save:
    ld a,e
    out (0FEh),a
    ld a,(08000h)
    ld (hl),a
    inc hl
    inc e
    jr nz,.save
.mark:
    ld a,e
    out (0FEh),a
    ld (08000h),a
    inc e
    jr nz,.mark
    xor a
    out (0FEh),a
    ld a,(08000h)
    ld c,a                     ; C = 256 - size
    xor a
    sub c
    ld b,a                     ; B = size, 0 = 256
    or a
    jr z,.verify
    cp 4
    jr c,.bad
    ld d,b
    dec d
    and d
    jr nz,.bad                 ; not a power of two
.verify:
    ld e,0
.check:
    ld a,e
    out (0FEh),a
    ld a,(08000h)
    ld d,a
    ld a,c
    add a,e
    cp d
    jr nz,.bad
    inc e
    ld a,e
    cp b
    jr nz,.check
    ld a,b
    or a
    jr nz,.good
    ld a,255
.good:
    ld (probe_size),a
    jr .restore
.bad:
    xor a
    ld (probe_size),a
.restore:
    ld hl,savebuf
    ld e,0
.rest:
    ld a,e
    out (0FEh),a
    ld a,(hl)
    ld (08000h),a
    inc hl
    inc e
    jr nz,.rest
    ld a,(probe_size)
    ret

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
vram_cap: ds 3
mapper_cap: ds 3
mapper_avail: db 0
mapper_first: db 0
scan_best: db 0
scan_tpa: db 0
scan_page2: db 0
scan_segment: db 0
scan_id: db 0
probe_size: db 0
; 256-byte scratch for the mapper probe: free TPA at the top of page 1 (page 2
; is the window under test), above the program.
savebuf equ 07F00h
    assert program_end <= savebuf
