INCLUDE "hardware.inc"

SECTION "testSetup", ROM0[$0100]
    jr entry
    ds $0150 - @
entry:
    call test

    ld   hl, strTestDone
    call serialPrint

    ; Do an illigal instruction to exit the emulator
    db   $dd
haltLoop:
    halt
    jr haltLoop

testFailed::
    ld   hl, strTestFailed
    call serialPrint
    ret

strTestFailed:
    db "FAILED\n", 0
strTestDone:
    db "DONE\n", 0

serialPrint::
.loop:
    ld   a, [hl+]
    and  a
    ret  z
    call serialCharOut
    jr   .loop

serialPrintHex::
    push af
    push bc
    ld   c, a
    swap a
    and  $0F
    add  "0"
    cp   "0" + 10
    jr   c, .upperDigit
    add  "A" - "0" - 10
.upperDigit:
    call serialCharOut
    ld   a, c
    and  $0F
    add  "0"
    cp   "0" + 10
    jr   c, .lowerDigit
    add  "A" - "0" - 10
.lowerDigit:
    call serialCharOut
    pop  bc
    pop  af
    ret

serialCharOut:
    ld   [rSB], a
    ld   a, $81
    ld   [rSC], a
.wait:
    ld   a, [rSC]
    and  $80
    jr   nz, .wait
    ret
