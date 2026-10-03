# SKMSX 2: implementation contract

This is a new implementation. The supplied New_v2.0_Redesigned/skmsxv2.0.asm
is a reference for the gap-buffer idea, not a source of relocation tables or
interrupt/VDP code. Original v1.5 behavior is specified by Original/skmsx80.txt.

## State and ownership

- Document addresses are unsigned 24-bit offsets, never CPU or screen addresses.
- A gap buffer maintains `0 <= gap_lo <= gap_hi <= capacity` and
  `length = capacity - (gap_hi - gap_lo)`. Its logical cursor is gap_lo.
- Only buffer.asm changes the gap boundaries or length. Movement cannot change
  logical text. Read operations never read the gap or beyond length.
- Navigation operates on document offsets and recognizes CRLF, LF and bare CR.
  Tabs remain bytes; only the view expands tabs at stops of eight columns.
- The view is derived from document state. A row is assembled in RAM before
  writing it to VRAM because the document itself can also reside in VRAM.
- Screen layout follows the caller: in TEXT1/TEXT2/GRAPHIC1 the font already in
  VRAM (R4) is reused and the 40-column name table goes to 0000h, or 0800h when
  the font is at 0000h. Other modes get the ROM font (CGTABL via RDSLT) at 0800h.
  Only the name table (and, with mapper storage, a loaded font area) is backed
  up. The display is blanked before any backup copy (TMS9918 access slots).
- Horizontal scrolling applies to the cursor line only; other rows always start
  at column 0. The cursor line keeps its offset while the cursor is visible,
  shows from column 0 when the column fits, and otherwise centres the cursor.
  Up/down keep a goal column across consecutive vertical moves; a TAB that would
  expand past the goal stops the cursor before it.
- DOS2 prints a bare LF on every call made from the resident context; dos2_call
  pins CSRY to row 1 so it can never scroll the caller's screen.
- Keyboard input consumes the BIOS ring; it does not call CHGET/BDOS recursively.
- Platform code owns interrupt state, slots, mapper pages, VDP state, DOS entry,
  residency, screen backup, and restoration. Core code does not manipulate them.
- File input is staged in unused memory and committed only after successful
  reads/close. Buffer exhaustion and I/O errors must preserve existing text.
- Function-key definitions and the interrupted application's screen and machine
  state are restored on ESC. The document remains resident.

## Storage selection

The text goes to the larger of the best memory mapper and video memory.

1. Mapper candidates, in order:
   - DOS2 or mapper support routines (MSR) reachable through the extended BIOS:
     enumerate their mapper slots, choose the one with the most allocatable
     space and reserve system segments. Ownership is explicit; uninstall
     releases exactly those segments.
   - Plain MSX-DOS 1 (direct mapper): every slot is switched into page 2 and
     probed, with all bytes restored: the first byte of each of the 256 segment
     numbers is saved, each segment gets its own number written, and the
     read-back pattern gives the size (a power of two of at least 4; plain RAM
     and ROM fail the pattern). Ports FCh-FFh are shared by all mappers. In the
     TPA's own slot, segments 0-3 belong to DOS; every other slot is all free.
     The map_* entries become IN/OUT stubs on ports FEh/FDh; page-2/page-1
     segments that cannot be read back (FFh) are assumed to be 1 and 2.
2. Video memory is always probed (MSX1: 2020h-3FFFh; MSX2: 64 or 128 KB).
   MSX1 must work with 16 KB; MSX2 must distinguish 64 and 128 KB.

The capacities are compared before the reserve is taken. A mapper needs at
least two free segments (three for a resident install: one holds the bank).

Resident layout. Only a small page-3 part is always present: the core (hook,
private stack, context save/restore, storage access, DOS entry, FCB and DTA
buffers) plus the extras (DOS2 calls, mapper paging, bank switching, DOS2
context, segment table), about 1.7 KB + one byte per segment. The editor
itself (session, buffer, navigation, commands, view, files, platform) is the
bank, relocated to run at 4000h, and it is kept in one of:

- `bank_active = 1`, a reserved mapper segment mapped into page 1 for each
  activation (the mapper is the chosen storage);
- `bank_active = 2`, a video memory image (MSX2 with video memory storage).
  Each activation switches page 1 to the RAM slot of page 3 (the TPA), saves the
  program RAM under the window to video memory, copies the image over it and
  runs; on exit it writes the image back (the bank holds the document pointers
  and view state), restores the program RAM and gives page 1 back. Two areas
  are reserved after the DOS context: the bank image and the saved RAM;
- `bank_active = 0`, none: core, bank (and extras with DOS2) stay in page 3 as
  one block. Only on an MSX1 without a mapper.

The installer relocates the three regions with separate deltas, chosen by the
region each relocated word points into. DOS never sees page-1 buffers: DOS1's
DiskROM occupies page 1 while it works. Slots are switched with ENASLT at
0024h directly; CALSLT restores the whole primary slot register on return.

Video memory is accessed with the TMS9918's limits in mind: after every
address setup a short delay (the BIOS's `ex (sp),hl` pair) precedes the data
access, and block loops spend at least 37 T-states per byte. Without this the
MSX1 chip drops or misplaces writes (seen as a corrupted context restore).

Mapper storage is capped at MAX_SEGMENTS (64 = 1 MB): every segment costs a
resident byte and DOS needs the whole resident image to fit with its BDOS
entry above C000h. Uninstall calls the mapper release on the resident page-3
stack, because DOS2 mapper routines swap page 2.

Installation reports storage kind, reserved bytes, usable document capacity and
resident conventional-RAM cost separately. Installed physical memory is never
reported as free document memory. All offset arithmetic supports bank boundaries.

## Modules

| Module | Responsibility |
|---|---|
| platform.asm | Install/uninstall, Ctrl+Shift, save/restore, keyboard and DOS ABI |
| storage.asm | Memory selection, ownership, banked byte access |
| buffer.asm | Bounded 24-bit gap-buffer primitives |
| navigation.asm | Character, word, line and page movement/deletion |
| view.asm | Viewport, tabs, complete row rendering and cursor overlay |
| commands.asm | F1-F10, prompts, block marks, search and replacement |
| files.asm | DOS file parsing, load, save and error handling |

## Required functions

Ctrl+Shift activation; ESC return; `/U`; F1 load/new/append; F2 save (unnamed
documents use F3); F3 Save As; F4 find; F5 find/change; F6/F7 block start/end;
F8 copy block; F9/F10 repeat find/change; Home/Shift+Home; Insert; Delete;
Backspace; arrows; Shift+arrows for word movement and line scrolling;
Ctrl+arrows for line boundaries and 18-line page movement; Shift+Delete/BS for
word deletion; Ctrl+Delete/BS for deletion to line boundaries.

## Acceptance

Build success is not runtime validation. Tests must verify buffer bytes, cursor
offsets, rendered row bytes, memory guards, entry/exit state, and saved file bytes.
Run everything with `bash tests/run_matrix.sh` (WSL). Required targets: MSX1 with 16 KB VRAM, MSX2 with 64 KB VRAM, MSX2 with 128 KB
VRAM, and mapper-backed MSX-DOS 2. Missing/exhausted mapper services must fall
back cleanly. Hardware probing must restore every byte touched.

Reference ABI: https://map.grauw.nl/resources/dos2_environment.php (original
MSX-DOS 2 Program Interface Specification, mapper support).
