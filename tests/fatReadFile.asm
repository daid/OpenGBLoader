
SECTION "test", ROM0

test::
    call hardwareInit
    call fatInit
    jp   nz, testFailed
.loop:
    ld   a, [wFatCurrentFileType]
    cp   $03
    jr   z, .skip
    ld   a, [wFatCurrentFilename]
    cp   "T"
    jr   z, readFileTest
.skip:
    call fatGetNextFile
    ld   a, [wFatCurrentFileType]
    and  a
    jr   nz, .loop
    jp   testFailed
    ret

readFileTest:
    call fatReadFile
    ld   a, [SDSectorData + $104]
    cp   $ce
    jp   nz, testFailed
    ld   a, [SDSectorData + $147]
    cp   $01
    jp   nz, testFailed
    ret