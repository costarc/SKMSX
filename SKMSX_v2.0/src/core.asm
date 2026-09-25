; Page-3 core services used by the editor wherever it runs: DOS entry, VDP
; addressing and the buffers DOS reads or writes (never in the page-1 bank,
; which DOS1's DiskROM replaces while it works).
dos_call:
    push bc
    push de
    push hl
    call storage_flush
    pop hl
    pop de
    pop bc
    ld a,(resident_busy)
    or a
    jr nz,.resident
    ei
    call 0005h
    di
    ret
.resident:
    ld a,(dos_version)
    cp 2
    jp nc,dos2_call
    ; Disk BASIC's entry accepts calls with the BIOS in page zero. It avoids
    ; the interrupted DOS program's private CP/M dispatcher/FCB-copy buffer.
    ei
    call 0F37Dh
    di
    ret

video_read_address:
    ld a,(machine_msx2)
    or a
    jr z,.low
    xor a
    out (099h),a
    ld a,08Eh
    out (099h),a
.low:
    ld a,l
    out (099h),a
    ld a,h
    and 03Fh
    out (099h),a
    ret


; Display address, independent of the bank last selected by the document backend.
video_write_address:
    ld a,(machine_msx2)
    or a
    jr z,.low
    xor a
    out (099h),a
    ld a,08Eh
    out (099h),a
.low:
    ld a,l
    out (099h),a
    ld a,h
    and 03Fh
    or 040h
    out (099h),a
    ret


file_fcb: ds 37
; Shared: file records during I/O, screen rows otherwise.
IO_RECORDS equ 64              ; records (bytes) per DOS block call, >= 40
io_buffer:
row_buffer: ds IO_RECORDS
