    output "SKMSX.COM"
; Mapper segments owned by the editor (64 = 1 MB document). Each costs one
; resident page-3 byte, which DOS must also fit above C000h.
MAX_SEGMENTS equ 64
; Resident layouts (install.asm relocates each region with its own delta):
;   banked:     page 3 = core + extras + segment table; the editor bank runs at
;               4000h and is kept in a mapper segment (bank_active 1) or in
;               video memory (bank_active 2, copied in for each activation)
;   monolithic: page 3 = core + bank (+ extras with DOS2), as assembled;
;               only on machines without a mapper or MSX2 video memory
BANKED_PAGE3 equ (core_end-resident_start)+(extras_end-extras_start)
; Bytes copied for each load/save of a video memory bank (whole 256-byte units).
BANK_AREA equ ((bank_end-bank_start)+255)/256*256
    org 0100h
    jp installer
    relocate_start
resident_start:
    jp resident_interrupt
    db "SKM2"
previous_himsav: dw 0
    include "src/resident.asm"
    include "src/offsets.asm"
    include "src/storage.asm"
    include "src/memory.asm"
    include "src/core.asm"
core_end:
bank_start:
    include "src/session.asm"
    include "src/buffer.asm"
    include "src/navigation.asm"
    include "src/commands.asm"
    include "src/view.asm"
    include "src/format.asm"
    include "src/files.asm"
    include "src/platform.asm"
bank_end:
extras_start:
    include "src/dos2.asm"
    include "src/dos2_context.asm"
extras_end:
segments: ds MAX_SEGMENTS
    relocate_end
    assert bank_end-bank_start <= 04000h
relocations:
    relocate_table
    include "src/memory_init.asm"
    include "src/foreground.asm"
    include "src/install.asm"
program_end:
    assert $ < 08000h
