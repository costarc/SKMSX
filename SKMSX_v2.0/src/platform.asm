; Reserve layout, offsets from screen_store: 0000h editor name-table backup
; (2 KB), 0800h..0AFFh machine context, 0C00h DOS2 context, FONT_BACKUP font
; backup. Mapper storage implies DOS2 and its 16 KB reserve (memory_init).
FONT_BACKUP equ 03800h

platform_enter:
    di
    ld hl,0F3DFh            ; Eight VDP register shadows
    ld de,saved_vdp
    ld bc,8
    ldir
    ld hl,0F87Fh            ; FNKSTR, ten 16-byte function strings
    ld de,0A5Fh
    ld bc,160
    call context_save
    ld hl,0F87Fh
    ld b,10
    ld c,081h
.keys:
    ld (hl),c
    inc hl
    ld (hl),0
    ld de,15
    add hl,de
    inc c
    djnz .keys
    ; The editor's name table never overlaps the font it displays. A caller in
    ; a text mode keeps its font where it is; otherwise the ROM font is loaded.
    ; Blank the display first: a TMS9918 showing a graphic screen admits CPU
    ; VRAM access only in sparse slots, too slow for these copy loops.
    ld a,(saved_vdp+1)
    and 0BFh
    ld c,1
    call write_vdp_reg
    call video_select_layout
    ld hl,(video_name_base)
    ld de,0
    ld bc,0800h
    call vram_backup
    ld a,(video_font_load)
    or a
    jr z,.registers
    ld a,(storage_kind)
    or a
    jr z,.font              ; VRAM document already overlaps graphic screens
    ld hl,(video_font_base)
    ld de,FONT_BACKUP
    ld bc,0800h
    call vram_backup
.font:
    call load_rom_font
.registers:
    ; 40-column text on both generations. Preserve interrupt enable in R1.
    xor a
    ld c,0
    call write_vdp_reg
    ld a,(saved_vdp+1)
    and 083h
    or 070h
    ld c,1
    call write_vdp_reg
    ld a,(video_name_base+1)
    rrca
    rrca
    and 03Fh
    ld c,2
    call write_vdp_reg
    ld a,(video_font_base+1)
    rrca
    rrca
    rrca
    and 01Fh
    ld c,4
    call write_vdp_reg
    ; TEXT1 takes both colours from R7: FORCLR on BAKCLR, never invisible.
    ld a,(0F3E9h)
    and 0Fh
    ld b,a
    ld a,(0F3EAh)
    and 0Fh
    cp b
    jr nz,.colors
    ld b,0Fh
    ld a,4
.colors:
    ld c,a
    ld a,b
    rlca
    rlca
    rlca
    rlca
    or c
    ld c,7
    jp write_vdp_reg

platform_leave:
    di
    ld hl,(video_name_base)
    ld de,0
    ld bc,0800h
    call vram_restore
    ld a,(video_font_load)
    or a
    jr z,.registers
    ld a,(storage_kind)
    or a
    jr z,.registers
    ld hl,(video_font_base)
    ld de,FONT_BACKUP
    ld bc,0800h
    call vram_restore
.registers:
    ld hl,saved_vdp
    ld c,0
.register:
    ld a,(hl)
    call write_vdp_reg
    inc hl
    inc c
    ld a,c
    cp 8
    jr c,.register
    ld hl,0F87Fh
    ld de,0A5Fh
    ld bc,160
    jp context_restore

; TEXT1, TEXT2 and GRAPHIC1 display a font from the pattern table at R4*800h.
; Any other mode (or a font outside VDP bank zero) uses the ROM font at 0800h.
video_select_layout:
    xor a
    ld (video_font_load),a
    ld a,(saved_vdp+1)
    ld b,a
    bit 3,a                 ; M2: multicolour
    jr nz,.graphic
    ld a,(saved_vdp)
    and 00Ah                ; M3/M5: bitmap and pattern graphic modes
    jr nz,.graphic
    ld a,(saved_vdp)
    bit 2,a                 ; M4 is TEXT2 only together with M1
    jr z,.text
    bit 4,b
    jr z,.graphic
.text:
    ld a,(saved_vdp+4)
    and 03Fh
    cp 8
    jr nc,.graphic
    add a,a
    add a,a
    add a,a
    ld h,a
    ld l,0
    ld (video_font_base),hl
    ld hl,0
    or a
    jr nz,.names
    ld hl,0800h
.names:
    ld (video_name_base),hl
    ret
.graphic:
    ld hl,0800h
    ld (video_font_base),hl
    ld hl,0
    ld (video_name_base),hl
    ld a,1
    ld (video_font_load),a
    ret

; Copy CGTABL's 2 KB font from the main ROM with RDSLT (DOS and BIOS page 0).
; DOS1's RDSLT enables interrupts, which move the VDP address: stage each
; 64-byte chunk in io_buffer, then write it with a fresh address and DI.
load_rom_font:
    ld a,(0FCC1h)
    ld hl,4
    call 000Ch
    ld (platform_font),a
    ld a,(0FCC1h)
    ld hl,5
    call 000Ch
    ld (platform_font+1),a
    ld hl,(video_font_base)
    ld (platform_target),hl
.chunk:
    ld hl,(platform_font)
    ld de,io_buffer
    ld b,64
.read:
    push bc
    push de
    ld a,(0FCC1h)
    call 000Ch
    pop de
    ld (de),a
    inc de
    inc hl
    pop bc
    djnz .read
    ld (platform_font),hl
    di
    ld hl,(platform_target)
    call video_write_address
    ld de,64
    add hl,de
    ld (platform_target),hl
    ld hl,io_buffer
    ld b,64
.write:
    ld a,(hl)
    out (098h),a
    inc hl
    djnz .write
    ld a,(platform_target+1)
    ld hl,video_font_base+1
    sub (hl)
    cp 8
    jr c,.chunk
    ret

write_vdp_reg:
    out (099h),a
    ld a,c
    or 080h
    out (099h),a
    ret
keyboard_read:
    call storage_flush
    ; BIOS keyboard scanning runs with VDP bank zero. We consume only its ring.
    ld hl,0
    call video_read_address
keyboard_idle:
    ei
    halt
    di
    ld hl,(0F3FAh)          ; GETPNT
    ld de,(0F3F8h)          ; PUTPNT
    or a
    sbc hl,de
    jr z,keyboard_idle
    ld hl,(0F3FAh)
    ld a,(hl)
    push af
    inc hl
    ld de,0FC18h            ; KEYBUF+40
    or a
    sbc hl,de
    add hl,de
    jr nz,.pointer
    ld hl,0FBF0h
.pointer:
    ld (0F3FAh),hl
    in a,(0AAh)
    ld c,a
    and 0F0h
    or 6
    out (0AAh),a
    in a,(0A9h)
    cpl
    and 3
    ld (modifiers),a
    ld a,c
    out (0AAh),a
    pop af
    ret

caller_sp: dw 0
platform_font: dw 0
platform_target: dw 0
video_font_base: dw 0
video_font_load: db 0
saved_vdp: ds 8
