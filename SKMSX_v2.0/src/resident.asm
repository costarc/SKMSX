; The hook always runs from reserved page-3 RAM, with a private page-3 stack.
; Main/alternate registers and the interrupted interrupt frame remain intact.
resident_interrupt:
    push af
    push bc
    push de
    push hl
    push ix
    push iy
    ld a,(resident_busy)
    or a
    jp nz,resident_chain
    in a,(0AAh)
    ld b,a
    and 0F0h
    or 6
    out (0AAh),a
    in a,(0A9h)
    and 3
    ld c,a
    ld a,b
    out (0AAh),a
    ld a,c
    or a
    jr z,.pressed
    xor a
    ld (resident_latch),a
    jp resident_chain
.pressed:
    ld a,(resident_latch)
    or a
    jp nz,resident_chain
    ld a,1
    ld (resident_latch),a
    ld (resident_busy),a
    ex af,af'
    push af
    ex af,af'
    exx
    push bc
    push de
    push hl
    exx
    ld (interrupted_sp),sp
    ld sp,resident_stack_end
    ld a,(bank_active)
    or a
    call nz,bank_enter
    ; Snapshot the DiskROM's public dispatcher variables, including its saved
    ; SP/DTA/abort vectors. Screen work areas and keyboard ring are separate.
    ld hl,0F1C9h            ; F1C9h..F3FFh, one contiguous block
    ld de,0800h
    ld bc,0237h
    call context_save
    ld hl,0FBF0h
    ld de,0A37h
    ld bc,40
    call context_save
    call session
    ld hl,0F1C9h            ; F1C9h..F3FFh, one contiguous block
    ld de,0800h
    ld bc,0237h
    call context_restore
    ld hl,0FBF0h
    ld de,0A37h
    ld bc,40
    call context_restore
    ld a,(bank_active)
    or a
    call nz,bank_leave
resident_restored:
    call storage_flush
    xor a
    ld (resident_busy),a
    ld sp,(interrupted_sp)
    exx
    pop hl
    pop de
    pop bc
    exx
    ex af,af'
    pop af
    ex af,af'
resident_chain:
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    jp saved_keyc

saved_keyc: ds 5,0C9h
resident_busy: db 0
resident_latch: db 0
interrupted_sp: dw 0
dos_version: db 0
resident_stack: ds 256
resident_stack_end:

; Copy BC bytes between HL and reserved external storage at screen_store+DE.
; HL is a CPU address (context_*) or a VRAM bank-zero address (vram_*).
context_save:
    xor a
    jr reserve_copy
context_restore:
    ld a,1
    jr reserve_copy
vram_backup:
    ld a,2
    jr reserve_copy
vram_restore:
    ld a,3
reserve_copy:
    ld (copy_mode),a
    ld a,b
    or c
    ret z
    push hl
    ld hl,(screen_store)
    add hl,de
    ld (copy_position),hl
    ld a,(screen_store+2)
    adc a,0
    ld (copy_position+2),a
    pop hl
.loop:
    push bc
    push hl
    ld a,(copy_mode)
    rra
    jr c,.restore
    rra
    jr c,.video
    ld a,(hl)
    jr .save
.video:
    call video_read_address
    in a,(098h)
.save:
    ld e,a
    ld hl,(copy_position)
    ld a,(copy_position+2)
    call storage_write
    jr .next
.restore:
    ld hl,(copy_position)
    ld a,(copy_position+2)
    call storage_read
    ld e,a
    pop hl
    push hl
    ld a,(copy_mode)
    and 2
    jr nz,.screen
    ld (hl),e
    jr .next
.screen:
    call video_write_address
    ld a,e
    out (098h),a
.next:
    ld hl,copy_position
    call inc24
    pop hl
    inc hl
    pop bc
    dec bc
    ld a,b
    or c
    jr nz,.loop
    ret
copy_mode: db 0
copy_position: ds 3
