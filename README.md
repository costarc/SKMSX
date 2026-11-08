# SKMSX

A text editor that lives inside your MSX.

SKMSX is a small, SideKick-style text editor for MSX computers running MSX-DOS. It is meant for the everyday jobs that do not deserve a big program: a quick note, a batch file, a few lines of source code, a configuration file. Press **Ctrl+Shift** and the editor opens over whatever you were doing; press **ESC** and you are back exactly where you were.

The original SKMSX 1.5 was written by Ronivon Candido Costa for the MSX1 in 1993. SKMSX 2 is a new implementation with the same keys, for MSX-DOS 1 and MSX-DOS 2, MSX1 and MSX2 or later.

## 📖 The Book

This project is **Chapter 8, "SKMSX"**, in a book:

**Chips, Code, and Cartridges: Turn Curiosity into Creation with 13 Hands-On Projects, from 8-bit Classics to FPGAs**

It walks through thirteen of my own hardware and software projects, from 8-bit classics to FPGAs, for beginners and curious makers. Each chapter explains how one project works and how to build it, with colour diagrams and real code from its repository.

### 👉 [Get the book on Amazon](https://link.amazon/B013Yaq9y)

<sub>As an Amazon Associate, the author earns from qualifying purchases. Buying through this link
supports these projects at no extra cost to you.</sub>

## What's in this repository

| Folder | Contents |
|---|---|
| [`SKMSX_v2.0`](SKMSX_v2.0) | SKMSX 2: source, the ready-to-run `SKMSX.COM`, the [User's Guide](SKMSX_v2.0/SKMSX_Users_Guide.pdf) and the [architecture notes](SKMSX_v2.0/ARCHITECTURE.md). |
| [`SKMSX v1.5`](SKMSX%20v1.5) | The original 1993 binary and its manuals (Portuguese/English, 40- and 80-column versions). |
| [`SKMSX_v1.5-Recovered _Source`](SKMSX_v1.5-Recovered%20_Source) | Z80 source recovered from the original binary. It assembles byte-identical to the 1993 `skmsx.com`; see the [recovery notes](SKMSX_v1.5-Recovered%20_Source/SKMSX_RECOVERY_NOTES.md). |

## Features (SKMSX 2)

- **Opens on demand.** Installed as a resident program, it opens with Ctrl+Shift. On ESC, the interrupted program's screen, function keys and machine state are put back.
- **Keeps your text.** While resident, the text stays in memory between sessions, so you can leave the editor, run a command and come back to the same text.
- **Uses the memory your machine has.** The text goes into whichever is larger: a memory mapper (up to 1 MB) or video memory (about 5 KB on an MSX1, 36 to 110 KB on an MSX2). MSX-DOS 1 needs no mapper support program for this.
- **Reads and writes plain files.** Files are saved byte for byte, with no end-of-file marker and no padding. Lines ending in CR LF, LF or a lone CR are all understood.
- **Safe saving.** The new contents go to a temporary file first; the original file is only replaced once the write has succeeded.
- **Scrolls only the line you are on.** When a line is wider than the 40-column screen, only that line moves sideways.

## Requirements

- An MSX1, MSX2 or later computer with a disk drive and MSX-DOS 1 or MSX-DOS 2.
- `SKMSX.COM` (about 9.6 KB).
- Text memory: a memory mapper, or at least 16 KB of video memory.
- For the resident editor, free memory at the top of RAM (page 3): about 1.7 KB on an MSX2 or with a mapper, about 5.6 KB on an MSX1 without a mapper.

With plain MSX-DOS 1, SKMSX finds a memory mapper by itself and uses every segment DOS does not use. With MSX-DOS 2, or a mapper support program such as Konamiman's MSR, it asks those for its segments instead.

## Usage

Copy `SKMSX_v2.0/SKMSX.COM` to your MSX disk and run it from the DOS prompt.

| Command | What it does |
|---|---|
| `SKMSX` | Open the editor once. The text is discarded when you press ESC, so save first. |
| `SKMSX /F name` | Open once with the file `name` loaded. |
| `SKMSX /R` | Install the resident editor. It opens with Ctrl+Shift. |
| `SKMSX /R /F name` | Install resident; `name` is loaded the first time the editor opens. |
| `SKMSX /U` | Remove the resident editor and free its memory (only if it is the most recently installed resident program). |

Switches are not case sensitive and can come in any order. File names are plain 8.3 names with an optional drive letter (`B:LETTER.TXT`); directories are not supported.

```
A>skmsx /R
SKMSX 2 resident - Memory mapper, usable bytes:  1029120
Ctrl+Shift opens; ESC closes; /U removes.
```

### The screen

The editor uses a 40-column text screen: 22 rows of text, a ruler, and a status line showing the file name, insert/overwrite mode (`I`/`O`), where the text is kept (`V` video memory, `M` mapper), the text size in bytes, and the last message. On an MSX2 you can start it from an 80-column screen; that screen is restored when you leave.

### Keys

| Key | Action |
|---|---|
| Ctrl + Shift | Open the resident editor |
| ESC | Leave the editor (cancels a prompt first) |
| Arrows | Move one character or line |
| Shift + Left / Right | Previous / next word |
| Shift + Up / Down | Scroll one line |
| Ctrl + Left / Right | Start / end of line |
| Ctrl + Up / Down | 18 lines up / down |
| Home | Start of text |
| Shift + Home | End of text |
| Insert | Toggle insert / overwrite |
| Backspace / Delete | Delete a character |
| Shift + Backspace / Delete | Delete a word |
| Ctrl + Backspace / Delete | Delete to the start / end of the line |
| F1 | Load a file (cursor at start of text), start a new one, or append (cursor at end of text) |
| F2 | Save |
| F3 | Save as |
| F4 / F9 | Find / find again |
| F5 / F10 | Find and replace / replace again |
| F6 / F7 | Mark block start / end |
| F8 | Copy the block to the cursor |

The [User's Guide](SKMSX_v2.0/SKMSX_Users_Guide.pdf) covers every key, message and limit in detail.

## Memory and capacity

| Storage | Capacity |
|---|---|
| Memory mapper | Up to 1 MB (64 segments of 16 KB) |
| Video memory, MSX2 with 128 KB | About 100 KB resident, 110 KB in quick mode |
| Video memory, MSX2 with 64 KB | About 36 KB resident, 45 KB in quick mode |
| Video memory, MSX1 (16 KB) | About 5 KB |

The video memory figures are for MSX-DOS 1; with MSX-DOS 2 take off about 13 KB. The banner shows the exact number of bytes you can type.

Only a small core (about 1.7 KB) stays in ordinary RAM. The editor itself is kept in a mapper segment, or on an MSX2 in video memory, and is brought in when you press Ctrl+Shift. On an MSX1 without a mapper everything stays in RAM as one block (about 5.6 KB).

Two things to be aware of:

- On plain MSX-DOS 1, SKMSX cannot know which mapper segments other programs use. Do not combine it with another program that keeps data in the same mapper (a RAM disk, for example), or install a mapper support program first.
- In video memory mode, the text can overwrite what a graphics program keeps in video RAM. DOS and BASIC text screens are not affected.

## Building

SKMSX 2 is written in Z80 assembly and builds into a single `SKMSX.COM` with [SjASMPlus](https://github.com/z00m128/sjasmplus) (built with 1.24.0; it relies on SjASMPlus' relocation directives, so use a recent version).

On Windows, from the `SKMSX_v2.0` folder:

```
make            build SKMSX.COM
make clean      delete SKMSX.COM and skmsx.sym
```

`make.bat` uses the `SJASMPLUS` environment variable if set (full path to `sjasmplus.exe`), otherwise the assembler on the PATH.

On other systems, from the `SKMSX_v2.0` folder:

```sh
sjasmplus --nologo --sym=skmsx.sym skmsx.asm
```

The resident part is assembled once and relocated to the top of RAM at install time, using an address list SjASMPlus generates itself. The build stops with an error if the editor grows beyond 16 KB or the program no longer fits below 8000h.

The recovered 1.5 source builds with:

```sh
sjasmplus skmsx_recovered.asm
```

## Documentation

- [SKMSX 2 User's Guide](SKMSX_v2.0/SKMSX_Users_Guide.pdf) ([ODT](SKMSX_v2.0/SKMSX_Users_Guide.odt))
- [SKMSX 2 architecture](SKMSX_v2.0/ARCHITECTURE.md): storage selection, resident layout, module responsibilities
- [SKMSX 1.5 recovery notes](SKMSX_v1.5-Recovered%20_Source/SKMSX_RECOVERY_NOTES.md)
- [SKMSX 1.5 original manual](SKMSX%20v1.5/skmsx80.txt) (Portuguese, with English key reference)
