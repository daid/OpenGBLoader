SECTION "32bit", ROM0
; Add the 32bit value stored at [HL] to BCDE
add32Bit::
    ld   a, [hl+]
    add  e
    ld   e, a
    ld   a, [hl+]
    adc  d
    ld   d, a
    ld   a, [hl+]
    adc  c
    ld   c, a
    ld   a, [hl+]
    adc  b
    ld   b, a
    ret

; Add A to the 32bit number in BCDE
addA32Bit::
    add  e
    ld   e, a
    ret  nc
    inc  d
    ret  nz
    inc  c
    ret  nz
    inc  b
    ret

; Substract A from the 32bit number in BCDE
subA32Bit::
    ld   h, a
    ld   a, e
    sub  h
    ld   e, a
    ret  nc
    dec  d
    ret  nz
    dec  c
    ret  nz
    dec  b
    ret

; Read a 32bit value from [hl] to BCDE
load32Bit::
    ld   e, [hl]
    inc  hl
    ld   d, [hl]
    inc  hl
    ld   c, [hl]
    inc  hl
    ld   b, [hl]
    ret

; Store the 32bit value in BCDE into [hl]
store32Bit::
    ld   [hl], e
    inc  hl
    ld   [hl], d
    inc  hl
    ld   [hl], c
    inc  hl
    ld   [hl], b
    ret
