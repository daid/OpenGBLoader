INCLUDE "hardware.inc"


SECTION "font", ROM0
fontData:
    INCBIN ".build/res/font.2bpp"
.end:

loadFontData::
    call waitVBlank
    ldh  [rLCDC], a ; a is zero after waitVBlank
    ld   hl, fontData
    ld   bc, fontData.end - fontData
    ld   de, _VRAM9000 + $0200
    call copyMemoryLarge
    
    ld   a, LCDCF_ON | LCDCF_BGON
    ldh  [rLCDC], a
    ret

waitVBlank::
    ld   a, IEF_VBLANK
    ldh  [rIE], a
    xor  a
    ldh  [rIF], a
    halt
    ret
    

copyMemory::
    ld   a, [hl+]
    ld   [de], a
    inc  de
    dec  c
    jr   nz, copyMemory
    ret

copyMemoryLarge::
    ld   a, [hl+]
    ld   [de], a
    inc  de
    dec  bc
    ld   a, b
    or   c
    jr   nz, copyMemoryLarge
    ret

; Display a text on screen
; hl pointer to data
; de screen position
displayString::
    ld   a, [hl+]
    and  a
    ret  z
    ld   c, a
.waitVRAM:
    ld   a, [rSTAT]
    and  $02
    jr   nz, .waitVRAM
    ld   a, c
    ld   [de], a
    inc  de
    jr   displayString

displayChar::
    ld   c, a
.waitVRAM:
    ld   a, [rSTAT]
    and  $02
    jr   nz, .waitVRAM
    ld   a, c
    ld   [de], a
    inc  de
    ret

; Display a text on screen
; a index in string table
; hl pointer to string table
; de screen position
displayStringFromTable::
    ld   b, $00
    ld   c, a
    add  hl, bc
    add  hl, bc
    ld   a, [hl+]
    ld   h, [hl]
    ld   l, a
    jp   displayString

clearScreen::
    call waitVBlank
    ldh  [rLCDC], a ; a is zero after waitVBlank
    ld   hl, _SCRN0
    ld   bc, SCRN_VX_B * SCRN_Y_B
.loop:
    xor  a
    ld   [hl+], a
    dec  bc
    ld   a, c
    or   b
    jr   nz, .loop

    ld   a, LCDCF_ON | LCDCF_BGON
    ldh  [rLCDC], a
    ret
