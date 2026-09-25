; One activation of the editor, entered from the page-3 hook. In the banked
; layout this runs from the mapper segment at 4000h.
session:
    ld a,(dos_version)
    cp 2
    call nc,dos2_context_enter
    call platform_enter
    ; Discard the activation keystroke, without changing the caller's saved ring.
    ld hl,(0F3F8h)
    ld (0F3FAh),hl
    call editor_main
    call platform_leave
    ld a,(dos_version)
    cp 2
    ret c
    jp dos2_context_leave
