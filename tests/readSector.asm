
SECTION "test", ROM0

test::
    call hardwareInit

    ld BC, $0000
    ld DE, $0000
    call readSDSector
    jp   z, testFailed

    ; Check the boot sector signature.
    ld   a, [SDSectorData + 510]
    cp   $55
    jp   nz, testFailed
    ld   a, [SDSectorData + 511]
    cp   $aa
    jp   nz, testFailed

    ret
