
SECTION "test", ROM0

test::
    call cartHardwareInit
    call fatInit
    jp   nz, testFailed
    ret
