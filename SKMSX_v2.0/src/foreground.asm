program_entry:
    ld (caller_sp),sp
    ; DOS supplies a page-3 stack. Inter-slot BIOS calls must never use a stack
    ; in page 0, which disappears while the main ROM is selected.
    call memory_init
    ld de,banner
    ld c,9
    call dos_call
    ld a,(storage_kind)
    or a
    ld de,vram_message
    jr z,.report
    ld de,mapper_message
.report:
    ld c,9
    call dos_call
    ld hl,capacity
    call r24
    ex de,hl
    call format_u24
    ld a,'$'
    ld (number_text+7),a
    ld de,number_text
    ld c,9
    call dos_call
    xor a
    ld (number_text+7),a
    ld de,bytes_message
    ld c,9
    call dos_call
    call platform_enter
    call editor_main
    call platform_leave
    call memory_release
    ei
    ld sp,(caller_sp)
    ret


banner: db 13,10,"SKMSX 2 development - ","$"
vram_message: db "VRAM, usable bytes: $"
mapper_message: db "Memory mapper, usable bytes: $"
bytes_message: db 13,10,"ESC returns to DOS.",13,10,"$"
