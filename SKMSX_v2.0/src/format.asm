; A:HL -> seven decimal characters and NUL at number_text, leading zeroes
; shown as spaces. Repeated 24-bit division by ten, least significant first.
format_u24:
    ld e,a
    ld ix,number_text+7
    ld (ix+0),0
    ld b,7
.digit:
    push bc
    ld b,24
    xor a
.divide:
    add hl,hl
    rl e
    rla
    cp 10
    jr c,.bit
    sub 10
    inc l
.bit:
    djnz .divide
    pop bc
    dec ix
    add a,'0'
    ld (ix+0),a
    ld a,e
    or h
    or l
    jr z,.pad
    djnz .digit
    ret
.pad:
    dec b
    ret z
.space:
    dec ix
    ld (ix+0),' '
    djnz .space
    ret
number_text: ds 8
