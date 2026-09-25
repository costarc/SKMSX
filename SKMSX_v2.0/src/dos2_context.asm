; DOS2 activation context (page-3 extras, present whenever DOS2 is).
dos2_context_enter:
    ld a,(0F341h)
    ld hl,6
    call 000Ch
    ld e,a
    ld a,(0F341h)
    inc hl
    call 000Ch
    ld d,a
    di
    ld e,0
    ld (dos2_lower),de
    ld hl,resident_start
    or a
    sbc hl,de
    ld (dos2_lower_size),hl
    ld b,h
    ld c,l
    ld hl,(dos2_lower)
    ld de,0C00h
    call context_save
    ld hl,(dos2_lower_size)
    ld de,0C00h
    add hl,de
    ld (dos2_upper_offset),hl
    ex de,hl
    ld hl,0F380h
    ld bc,(previous_himsav)
    or a
    sbc hl,bc
    ld (dos2_upper_size),hl
    ld b,h
    ld c,l
    ld hl,(previous_himsav)
    call context_save
    ; Isolate FCB file handles from the interrupted command interpreter.
    ld c,019h
    call dos2_call
    ld (dos2_drive),a
    ld c,060h
    call dos2_call
    ld a,b
    ld (dos2_parent),a
    ld a,(dos2_drive)
    ld e,a
    ld c,00Eh
    call dos2_call
    ret

dos2_context_leave:
    ld a,(dos2_parent)
    ld b,a
    ld c,061h
    call dos2_call
    ld hl,(dos2_lower)
    ld bc,(dos2_lower_size)
    ld de,0C00h
    call context_restore
    ld hl,(previous_himsav)
    ld bc,(dos2_upper_size)
    ld de,(dos2_upper_offset)
    jp context_restore

dos2_lower: dw 0
dos2_lower_size: dw 0
dos2_upper_size: dw 0
dos2_upper_offset: dw 0
dos2_parent: db 0
dos2_drive: db 0

