
SECTION "test", ROM0

test::
    call hardwareInit
    call fatInit
    jp   nz, testFailed
    ret
