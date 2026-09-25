"""Execute assembled Z80 core against an independent byte-array document oracle.

Requires z80==1.2.0 (MIT, github.com/kosarev/z80). Storage calls are trapped;
the actual assembled buffer and navigation instructions run on the Z80 CPU.
"""
from pathlib import Path
import random
import re
import z80

HERE = Path(__file__).resolve().parent
SYMS = {m[1]: int(m[2], 16) for m in re.finditer(
    r'(?m)^(\w+): EQU 0x([\da-fA-F]+)', (HERE / 'core.sym').read_text())}
CODE = (HERE / 'core.bin').read_bytes()


class Core:
    def __init__(self, capacity=257, text=b'', cursor=0):
        self.cpu = z80.Z80Machine()
        self.cpu.set_memory_block(0x100, CODE)
        self.data = bytearray([0xA5]) * capacity
        self.capacity = capacity
        self.field('capacity', capacity)
        self.field('gap_lo', cursor)
        self.field('gap_hi', capacity - len(text) + cursor)
        self.field('doc_length', len(text))
        self.data[:cursor] = text[:cursor]
        self.data[capacity-len(text)+cursor:] = text[cursor:]
        for address in (0xFFFE, SYMS['storage_read'], SYMS['storage_write']):
            self.cpu.set_breakpoint(address)

    def field(self, name, value=None):
        address = SYMS[name]
        if value is not None:
            self.cpu.memory[address:address+3] = value.to_bytes(3, 'little')
        return int.from_bytes(self.cpu.memory[address:address+3], 'little')

    def call(self, name, a=0):
        m = self.cpu
        m.a = a
        m.pc = SYMS[name]
        m.sp = 0xF000
        m.memory[0xF000:0xF002] = b'\xfe\xff'
        for _ in range(100000):
            m.ticks_to_stop = 100000
            m.run()
            if m.pc == 0xFFFE:
                return m.a, bool(m.f & 1)
            if m.pc in (SYMS['storage_read'], SYMS['storage_write']):
                address = (m.a << 16) | m.hl
                assert 0 <= address < self.capacity, (name, 'storage bounds', address)
                if m.pc == SYMS['storage_read']:
                    m.a = self.data[address]
                else:
                    self.data[address] = m.e
                m.pc = int.from_bytes(m.memory[m.sp:m.sp+2], 'little')
                m.sp += 2
        raise AssertionError((name, 'CPU did not return', hex(m.pc)))

    def text(self):
        lo, hi = self.field('gap_lo'), self.field('gap_hi')
        assert 0 <= lo <= hi <= self.capacity
        text = bytes(self.data[:lo] + self.data[hi:])
        assert len(text) == self.field('doc_length')
        return text


def randomized():
    randomizer = random.Random(0x534B4D)
    count = 0
    for capacity in (1, 2, 17, 257, 16385, 65539, 131073):
        initial = bytes(randomizer.randrange(256) for _ in range(min(capacity, 80)))
        core = Core(capacity, initial)
        reference, cursor = bytearray(initial), 0
        for _ in range(1200):
            operation = randomizer.choice(['insert', 'left', 'right', 'backspace', 'delete', 'get'])
            if operation == 'get':
                index = randomizer.randrange(len(reference) + 2)
                core.field('scan_pos', index)
                value, refused = core.call('buffer_get')
                assert refused == (index >= len(reference))
                if not refused:
                    assert value == reference[index], (index, value, reference[index])
            else:
                value = randomizer.randrange(256)
                _, refused = core.call('buffer_' + operation, value)
                blocked = {'insert': len(reference) == capacity, 'left': cursor == 0,
                           'right': cursor == len(reference), 'backspace': cursor == 0,
                           'delete': cursor == len(reference)}[operation]
                assert refused == blocked, (operation, refused, blocked)
                if not blocked:
                    if operation == 'insert': reference[cursor:cursor] = bytes([value]); cursor += 1
                    if operation == 'left': cursor -= 1
                    if operation == 'right': cursor += 1
                    if operation == 'backspace': del reference[cursor-1]; cursor -= 1
                    if operation == 'delete': del reference[cursor]
            assert core.text() == reference, operation
            assert core.field('gap_lo') == cursor, operation
            count += 1
    print('PASS', count, 'random operations with independent model')


def boundaries():
    for size in (16383, 16384, 65535, 65536, 65537, 131070):
        original = bytes((i * 31) & 255 for i in range(size))
        core = Core(size+3, original, size-1)
        for operation in ('buffer_right', 'buffer_left', 'buffer_insert', 'buffer_backspace'):
            core.call(operation, 88)
        assert core.text() == original
        for index in (0, size-1, size//2):
            core.field('scan_pos', index)
            value, eof = core.call('buffer_get')
            assert not eof and value == original[index]
    for original in (b'', b'\r', b'\n', b'\r\n', b'a\r', b'a\n', b'a\r\nb', b'a\x00\x1ab'):
        core = Core(64, original)
        for _ in range(len(original)+2): core.call('nav_right')
        assert core.field('gap_lo') == len(original) and core.text() == original
        for _ in range(len(original)+2): core.call('nav_left')
        assert core.field('gap_lo') == 0 and core.text() == original
        for _ in range(len(original)+2): core.call('delete_right')
        assert core.text() == b''
    print('PASS bank boundaries, 64 KB crossing, binary bytes and line endings')


def commands():
    for name, expected in ((b'msxarch.ini', b'\0MSXARCH INI'), (b'A:README.TXT', b'\1README  TXT'), (b'a', b'\0A          ')):
        core = Core()
        core.cpu.memory[SYMS['pending_name']:SYMS['pending_name']+len(name)+1] = name+b'\0'
        _, failed = core.call('parse_filename')
        assert not failed, name
        assert bytes(core.cpu.memory[SYMS['file_fcb']:SYMS['file_fcb']+12]) == expected
    for target in (0, 1, 7, 11):
        core = Core(64, b'alpha beta!', 4)
        core.field('target_position', target)
        core.call('seek_target')
        assert core.field('gap_lo') == target
        assert core.text() == b'alpha beta!'
    for destination in (0, 2, 5, 8):
        text = b'abcdefgh'
        core = Core(32, text, destination)
        core.field('block_begin', 2)
        core.field('block_end', 5)
        core.cpu.memory[SYMS['mark_flags']] = 3
        core.call('block_copy')
        assert core.text() == text[:destination] + b'cde' + text[destination:]
    for start in (0, 1, 5):
        core = Core(64, b'ab ab ab', start)
        core.cpu.memory[SYMS['needle']:SYMS['needle']+3] = b'ab\0'
        core.call('find_execute')
        expected = b'ab ab ab'.find(b'ab', start)
        assert core.field('gap_lo') == expected
    core = Core(64, b'abab', 0)
    core.cpu.memory[SYMS['needle']:SYMS['needle']+3] = b'ab\0'
    core.cpu.memory[SYMS['replacement']:SYMS['replacement']+2] = b'X\0'
    core.call('replace_execute')
    core.call('replace_repeat')
    assert core.text() == b'XX'
    for capacity in (1, 2):
        core = Core(capacity)
        core.call('insert_newline')
        assert core.text() == (b'' if capacity == 1 else b'\r\n')
    print('PASS seek, block copy, search, adjacent replacement, atomic newline')


if __name__ == '__main__':
    randomized()
    boundaries()
    commands()
