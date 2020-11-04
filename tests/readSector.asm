
SECTION "test", ROM0

test::
    call hardwareInit

    ld BC, $0000
    ld DE, $0000
    call readSDSector
    jp   z, testFailed

    ; Check if there is data in the sector
    ld   hl, SDSectorData
REPT $200
    ld   a, [hl+]
    and  a
    ret  nz
ENDR
    jp   testFailed
