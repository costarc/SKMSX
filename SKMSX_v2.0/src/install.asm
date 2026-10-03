; Installer is transient. SjASMPlus generates the complete relocation table.
; Without switches the editor runs once in the foreground; /R installs it
; resident (Ctrl+Shift), /U removes the resident copy.
installer:
    ld hl,0081h
    ld a,(0080h)
    ld b,a
.argument:
    call argument_switch
    jr c,.dispatch
    cp 'F'
    call z,argument_file
    cp 'R'
    jr nz,.not_resident
    ld (argument_mode),a
.not_resident:
    cp 'U'
    jr nz,.argument
    ld (argument_mode),a
    jr .argument
.dispatch:
    ld a,(argument_mode)
    cp 'U'
    jp z,uninstall
    cp 'R'
    jp nz,program_entry
.install:
    call locate_resident
    jp z,already_installed
    ld hl,(0F349h)
    ld (previous_himsav),hl
    ld a,1
    ld (install_trim),a
    call memory_init
    ld hl,0
    ld de,bank_end-resident_start
    ld a,(bank_active)
    or a
    jr nz,.banked_size
    ld a,(dos_version)
    cp 2
    jr c,.image_size
    ld de,extras_end-resident_start
    jr .image_size
.banked_size:
    ld a,(segment_count)
    ld l,a
    ld de,BANKED_PAGE3
.image_size:
    add hl,de
    ld (resident_bytes),hl
    ld (bootstrap_size+1),hl
    ex de,hl
    ld hl,(previous_himsav)
    or a
    sbc hl,de
    ld a,h
    cp 0C0h
    jp c,insufficient_ram
    ld (final_base),hl
    ; DiskROM's reloaded DOS dispatcher must itself remain in page 3.
    ld hl,(0006h)
    ld de,(resident_bytes)
    or a
    sbc hl,de
    ld a,h
    cp 0C0h
    jp c,insufficient_ram
    ld de,install_banner
    ld c,9
    call dos_call
    ld a,(storage_kind)
    or a
    ld de,vram_message
    jr z,.kind
    ld de,mapper_message
.kind:
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
    ld de,installed_message
    ld c,9
    call dos_call
    ld hl,0FDCCh
    ld de,saved_keyc
    ld bc,5
    ldir
    ; Relocate the RAM image in place, then stage it away from BASIC work RAM.
    ; Each word is moved by the delta of the region its target lies in.
    ld hl,(final_base)
    ld de,resident_start
    or a
    sbc hl,de
    ld (delta_core),hl
    ld (delta_bank),hl
    ld (delta_extras),hl
    ld a,(bank_active)
    or a
    jr z,.deltas
    cp 1
    jr nz,.bank_deltas         ; video memory bank: no mapper state to keep
    ; Page-2 state for copy_bank, read while the extras still run unrelocated.
    call mapper_p2_now
    ld (install_p2_segment),a
    call get_page2_slot
    ld (install_p2_slot),a
.bank_deltas:
    ld hl,04000h-bank_start
    ld (delta_bank),hl
    ld hl,(final_base)
    ld de,core_end-resident_start
    add hl,de
    ld de,extras_start
    or a
    sbc hl,de
    ld (delta_extras),hl
.deltas:
    ld ix,relocations
    ld bc,relocate_count
.relocate:
    ld l,(ix+0)
    ld h,(ix+1)
    inc ix
    inc ix
    ld e,(hl)
    inc hl
    ld d,(hl)
    push hl
    ex de,hl
    push hl
    ld de,bank_start
    or a
    sbc hl,de
    pop hl
    ld de,(delta_core)
    jr c,.add
    push hl
    ld de,extras_start
    or a
    sbc hl,de
    pop hl
    ld de,(delta_bank)
    jr c,.add
    ld de,(delta_extras)
.add:
    add hl,de
    ex de,hl
    pop hl
    ld (hl),d
    dec hl
    ld (hl),e
    dec bc
    ld a,b
    or c
    jr nz,.relocate
    ld a,(bank_active)
    or a
    jr nz,.stage_banked
    ld hl,resident_start
    ld de,08000h
    ld bc,(resident_bytes)
    ldir
    jr .staged
.stage_banked:
    ld a,(bank_active)
    cp 2
    jr z,.stage_video
    call copy_bank
    jr .stage_core
.stage_video:
    call copy_bank_vram
.stage_core:
    ld hl,resident_start
    ld de,08000h
    ld bc,core_end-resident_start
    ldir
    ld hl,extras_start
    ld a,(segment_count)
    ld c,a
    ld b,0
    push hl
    ld hl,extras_end-extras_start
    add hl,bc
    ld b,h
    ld c,l
    pop hl
    ldir
.staged:
    ld hl,(final_base)
    ld (0F349h),hl
    ld (bootstrap_destination+1),hl
    ld (bootstrap_hook+1),hl
    jp transition

; Write the relocated editor bank into its mapper segment through page 2,
; then give page 2 back to the TPA. Only routines without relocated operands
; (mapper jumps, bios_enaslt) may run here.
copy_bank:
    ld a,(mapper_slot)
    ld h,080h
    call bios_enaslt
    ld a,(code_segment)
    call map_put_p2
    ld hl,bank_start
    ld de,08000h
    ld bc,bank_end-bank_start
    ldir
    ld a,(install_p2_segment)
    call map_put_p2
    ld a,(install_p2_slot)
    ld h,080h
    jp bios_enaslt

; Advance HL/B (command tail) to the next "/x" switch; A = x in upper case.
; Carry when the tail is exhausted.
argument_switch:
    ld a,b
    or a
    scf
    ret z
    ld a,(hl)
    inc hl
    dec b
    cp '/'
    jr nz,argument_switch
    ld a,b
    or a
    scf
    ret z
    ld a,(hl)
    inc hl
    dec b
    and 0DFh
    ret

; /F name: stage the filename in the editor image, loaded on first activation.
argument_file:
    ld de,pending_name          ; set before any exit: .end always stores through DE
.spaces:
    ld a,b
    or a
    jr z,.end
    ld a,(hl)
    cp ' '
    jr z,.skip
    cp 9
    jr nz,.name
.skip:
    inc hl
    dec b
    jr .spaces
.name:
    ld c,14
.copy:
    ld a,b
    or a
    jr z,.end
    ld a,(hl)
    cp ' '+1
    jr c,.end
    cp '/'
    jr z,.end
    ld (de),a
    inc de
    inc hl
    dec b
    dec c
    jr nz,.copy
.end:
    xor a
    ld (de),a
    ld a,(pending_name)
    or a
    ld (autoload_pending),a
    ret z
    ld a,1
    ld (autoload_pending),a
    xor a
    ret

; Write the relocated editor bank into its video memory image (bank_active 2).
; Runs after relocation, so it uses only plain code and variables of the
; image, never a routine of it. MSX2 video memory addressing (R#14).
copy_bank_vram:
    ld hl,(screen_store)
    ld de,(bank_vram_off)
    add hl,de
    ld (cb_off),hl
    ld a,(screen_store+2)
    adc a,0
    ld (cb_off+2),a
    ld hl,bank_end-bank_start
    ld (cb_left),hl
    ld hl,bank_start
.chunk:
    ld de,(cb_left)
    ld a,d
    or e
    ret z
    ld c,e                     ; chunk size; 0 = a full 256 bytes
    ld a,d
    or a
    jr z,.size
    ld c,0
.size:
    push hl
    ld hl,(cb_off)
    ld de,(storage_base)
    add hl,de
    ld a,(cb_off+2)
    adc a,0
    ld d,a
    ld a,h
    rlca
    rlca
    and 3
    ld e,a
    ld a,d
    add a,a
    add a,a
    or e
    out (099h),a
    ld a,08Eh
    out (099h),a
    ld a,l
    out (099h),a
    ld a,h
    and 03Fh
    or 040h
    out (099h),a
    ex (sp),hl              ; let the address settle before the data access
    ex (sp),hl
    pop hl
    ld b,c
.out:
    ld a,(hl)
    out (098h),a
    inc hl
    djnz .out
    push hl
    ld a,c
    ld e,a
    ld d,0
    or a
    jr nz,.advance
    inc d
.advance:
    ld hl,(cb_off)
    add hl,de
    ld (cb_off),hl
    jr nc,.left
    ld a,(cb_off+2)
    inc a
    ld (cb_off+2),a
.left:
    ld hl,(cb_left)
    or a
    sbc hl,de
    ld (cb_left),hl
    pop hl
    jr .chunk
cb_off: ds 3
cb_left: dw 0

locate_resident:
    ld a,(0FDCCh)
    cp 0C3h
    ret nz
    ld hl,(0FDCDh)
    inc hl
    inc hl
    inc hl
    ld de,signature
    ld b,4
.compare:
    ld a,(de)
    cp (hl)
    ret nz
    inc hl
    inc de
    djnz .compare
    xor a
    ret

uninstall:
    call locate_resident
    jp nz,not_installed
    ld hl,(0FDCDh)
    ld de,(0F349h)
    or a
    sbc hl,de
    jp nz,not_last
    ld hl,(0FDCDh)
    ld (final_base),hl
    ld de,saved_keyc-resident_start
    add hl,de
    ld de,0FDCCh
    ld bc,5
    di
    ldir
    ; Execute the resident release routine while its data are still valid.
    ld hl,(final_base)
    ld de,memory_release-resident_start
    add hl,de
    ld (release_call+1),hl
    ; DOS2 mapper routines map the kernel's data segment into page 2, where a
    ; small TPA keeps this program's stack. Use the idle resident page-3 stack.
    ld (uninstall_sp),sp
    ld hl,(final_base)
    ld de,resident_stack_end-resident_start
    add hl,de
    ld sp,hl
release_call:
    call 0
    ld sp,(uninstall_sp)
    ld hl,(final_base)
    ld de,previous_himsav-resident_start
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld (0F349h),de
    ld a,0C9h
    ld (bootstrap_usr),a
    ei
    ld de,removed_message
    ld c,9
    call 0005h
    jp transition

transition:
    ld hl,bootstrap
    ld de,0B000h
    ld bc,bootstrap_end-bootstrap
    ldir
    jp 0B000h

; Enter BASIC and CALL SYSTEM so DiskROM rebuilds DOS below the new HIMSAV.
; No hand-maintained relocation table or jump to an obsolete DOS stack.
bootstrap:
    ld a,(0FCC1h)
    push af
    ld h,0
    call 0024h
    pop af
    ld h,040h
    call 0024h
    ; A full editor is larger than a small hook TSR. Move BASIC's stack below
    ; the reserved block BEFORE invoking USR, or the copy overwrites its frames
    ; and subsequent BASIC pushes corrupt the freshly installed editor.
    ld hl,(0F349h)
    ld (0FC4Ah),hl
    ld (0F672h),hl
    ld de,0200h
    or a
    sbc hl,de
    ld (0F674h),hl
    ld sp,hl
    xor a
    ld hl,0F41Fh
    ld (0F860h),hl
    ld hl,0F423h
    ld (0F41Fh),hl
    ld (hl),a
    ld hl,0F52Ch
    ld (0F421h),hl
    ld (hl),a
    ld hl,0F42Ch
    ld (0F862h),hl
    ld hl,0B000h+bootstrap_line-bootstrap
    jp 04601h
bootstrap_line:
    db 03Ah,097h,0DDh,0EFh,00Ch
    dw 0B000h+bootstrap_usr-bootstrap
    db 03Ah,091h,0DDh,'(',34,34,')',03Ah,0CAh,"SYSTEM",0
bootstrap_usr:
    ld hl,08000h
bootstrap_destination:
    ld de,0
bootstrap_size:
    ld bc,0
    ldir
    di
bootstrap_hook:
    ld hl,0
    ld (0FDCDh),hl
    ld a,0C9h
    ld (0FDCCh+3),a
    ld (0FDCCh+4),a
    ld a,0C3h
    ld (0FDCCh),a
    ei
    ret
bootstrap_end:

already_installed:
    ld de,already_message
    jr install_error
not_installed:
    ld de,missing_message
    jr install_error
not_last:
    ld de,last_message
    jr install_error
insufficient_ram:
    call memory_release
    ld de,ram_message
install_error:
    ld c,9
    jp 0005h

final_base: dw 0
argument_mode: db 0
uninstall_sp: dw 0
delta_core: dw 0
install_p2_segment: db 0
install_p2_slot: db 0
delta_bank: dw 0
delta_extras: dw 0
resident_bytes: dw 0
signature: db "SKM2"
install_banner: db 13,10,"SKMSX 2 resident - $"
installed_message: db 13,10,"Ctrl+Shift opens; ESC closes; /U removes.",13,10,"$"
removed_message: db 13,10,"SKMSX 2 removed.",13,10,"$"
already_message: db 13,10,"SKMSX 2 is already resident.",13,10,"$"
missing_message: db 13,10,"SKMSX 2 hook not found.",13,10,"$"
last_message: db 13,10,"Remove later residents first.",13,10,"$"
ram_message: db 13,10,"Insufficient page-3 RAM for resident editor.",13,10,"$"
