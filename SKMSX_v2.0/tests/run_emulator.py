"""Run isolated openMSX tests; never modifies the user's boot folders."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent
DEV = Path('/mnt/c/Users/roniv/Dev')

def native(path):
    return subprocess.check_output(['wslpath', '-w', str(path)], text=True).strip().replace('\\', '/')

def lines_fixture():
    """Fifty lines: long, TAB and mixed CRLF/LF/bare-CR separators."""
    parts = []
    for i in range(50):
        if i == 3:
            body = b'L03:' + bytes(48 + j % 10 for j in range(96))
        elif i == 5:
            body = b'\tTab\tstop\tX'
        elif i == 7:
            body = b'L07 ' + b'abcdefghij' * 9
        else:
            body = b'Line %02d ' % i + b'word ' * (i % 7)
        separator = b'\n' if i == 10 else b'\r' if i == 11 else b'\r\n'
        parts.append(body + (separator if i < 49 else b''))
    return b''.join(parts)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--machine', default='Panasonic_FS-A1WSX')
    ap.add_argument('--disk', default='FloppyA')
    ap.add_argument('--extension', action='append', default=[])
    ap.add_argument('--case', default='main')
    ap.add_argument('--vram64', action='store_true')
    ap.add_argument('--mode', default='', help='DOS MODE width before launch (40, 80, 32) or G for a graphic caller')
    ap.add_argument('--pre', default='', help='DOS command typed before the test, e.g. "MSR I"')
    args = ap.parse_args()
    args.pre = args.pre.replace('_', ' ')   # MSR_I in space-split matrix rows
    name = args.case
    if args.pre:
        name += '-' + args.pre.split()[0]
    if args.vram64:
        name += '-vram64'
    if args.mode:
        name += '-mode' + args.mode
    for ext in args.extension:
        name += '-' + ext
    work = HERE/'work'/f'{args.machine}-{args.disk}-{name}'
    work.mkdir(parents=True, exist_ok=True)
    disk = work/'disk'
    if disk.exists():
        shutil.rmtree(disk)
    source_disk = DEV/'MSX/MSXPi'/args.disk
    if not source_disk.exists():
        source_disk = DEV/'MSX'/args.disk     # e.g. MSXDOS22
    shutil.copytree(source_disk, disk)
    for f in disk.iterdir():
        if f.name.lower() == 'autoexec.bat':
            f.unlink()  # Test fixture only: user's DOS2 AUTOEXEC reboots recursively.
    shutil.copy2(PROJECT/'SKMSX3.COM', disk/'SKMSX3.COM')
    shutil.copy2(DEV/'MSX/MSXPi/FloppyA/msxarch.ini', disk/'msxarch.ini')
    (disk/'WORDS.TXT').write_bytes(b'alpha beta gamma\r\nsecond line\r\nlast')
    (disk/'LINES.TXT').write_bytes(lines_fixture())
    for stale in ('smoke.log', 'expected_out.bin'):
        (work/stale).unlink(missing_ok=True)
    symbols = {m[1]:int(m[2],16) for m in re.finditer(r'(?m)^(\w+): EQU 0x([\da-fA-F]+)', (PROJECT/'skmsx3.sym').read_text())}
    (work/'symbols.tcl').write_text(''.join(f'set A({k}) {v}\n' for k,v in symbols.items()))
    config = work/'run.tcl'
    config.write_text(f'set work {{{native(work)}}}\nset testcase {args.case}\nset screen_mode {{{args.mode}}}\nset pre_command {{{args.pre}}}\nsource {{{native(HERE/"emulator.tcl")}}}\n')
    machine = args.machine
    machine_file = None
    if args.vram64:
        source = DEV/'MSX/MSXPi/openmsx-MSXPi_v1.6/share/machines'/f'{args.machine}.xml'
        xml = source.read_text()
        assert '<vram>128</vram>' in xml
        machine_file = source.parent/'SKMSX3_test64.xml'
        assert not machine_file.exists()
        machine_file.write_text(xml.replace('<vram>128</vram>', '<vram>64</vram>'))
        machine = 'SKMSX3_test64'
    cmd = [str(DEV/'MSX/MSXPi/openmsx-MSXPi_v1.6/openmsx.exe'), '-machine', machine]
    for ext in args.extension:
        cmd += ['-ext', ext]
    cmd += ['-diska', native(disk), '-script', native(config)]
    try:
        with (work/'process.log').open('w') as output:
            subprocess.run(cmd, stdout=output, stderr=subprocess.STDOUT, timeout=180, check=True)
    finally:
        if machine_file is not None:
            machine_file.unlink()
    log = (work/'smoke.log').read_text()
    print(log)
    assert 'ERROR' not in log and 'PASS completed' in log
    if args.case == 'functions':
        target = next(p for p in disk.iterdir() if p.name.lower() == 'out.txt')
        assert target.read_bytes() == (work/'expected_out.bin').read_bytes(), 'Saved bytes differ'
        assert not [p for p in disk.iterdir() if p.name.upper().startswith('SK3')], 'Temporary files left'
    else:
        target = next(p for p in disk.iterdir() if p.name.lower() == 'round.ini')
        assert target.read_bytes() == (disk/'msxarch.ini').read_bytes(), 'Saved bytes differ'
    print('PASS host file identical, no padding, no added EOF byte')

if __name__ == '__main__':
    main()
