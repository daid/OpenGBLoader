
SECTION "test", ROM0

test::
    call hardwareInit
    call fatInit
    jp   nz, testFailed
    xor  a
    push af
.loop:
    ld   a, [wFatCurrentFileType]
    cp   $03
    jr   z, .skip
    ;ld hl, wFatCurrentFilename
    ;call serialPrint
    pop  af
    inc  a
    push af
.skip:
    call fatGetNextFile
    ld   a, [wFatCurrentFileType]
    and  a
    jr   nz, .loop
    
    pop  af
    cp   14
    jp   nz, testFailed
    ret
