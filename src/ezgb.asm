INCLUDE "hardware.inc"

SECTION "ezgb-header", ROM0[$0100]
    jr entry
    ds $0150 - @
entry:
    call cartHardwareInit
    call fatInit
    jp   nz, cartInitFailure

    call loadFontData

    ld   hl, wFatCurrentFilename
    ld   de, _SCRN0
    call displayString

.haltLoop:
    xor  a
    ldh  [rIF], a
    halt
    call updateJoypadState
    ld   a, [wJoypadPressed]
    bit  PADB_DOWN, a
    jr   nz, .next
    jr .haltLoop

.next:
    call fatGetNextFile
    ld   hl, wFatCurrentFilename
    ld   de, _SCRN0
    call displayString
    jr .haltLoop


cartInitFailure:
    call loadFontData
    ld   hl, failureString
    ld   de, _SCRN0
    call displayString

.haltLoop:
    halt
    jr .haltLoop

failureString:
    db "Failed to init SD card", 0
