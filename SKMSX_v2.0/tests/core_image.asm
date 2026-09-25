    output "core.bin"
    org 0100h
    include "../src/offsets.asm"
    include "../src/buffer.asm"
    include "../src/navigation.asm"
    include "../src/commands.asm"
    include "../src/view.asm"
    include "../src/format.asm"
    include "../src/files.asm"
storage_read: ret
storage_write: ret
keyboard_read: ret
dos_call: ret
video_write_address: ret
storage_kind: db 0
machine_msx2: db 0
file_fcb: ds 37
IO_RECORDS equ 64
io_buffer:
row_buffer: ds IO_RECORDS
    assert $ < 6000h
