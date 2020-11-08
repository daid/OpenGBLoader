SECTION "libfatRAM", WRAM0
wFATStartSector:                ds 4  ; LBA, LSB first
wRootDirectoryStart:            ds 4  ; LBA, LSB first
wClustersStart:                 ds 4  ; LBA, LSB first
wFatClusterSize::               ds 1  ; In sectors
wClusterSizeShift:              ds 1  ; In number of required left shifts
wFAT16:                         ds 1
; Directory iteration internals
wDirectoryEntryCluster:         ds 4  ; Note, on FAT16 this can be a sector number when wCurrentDirectoryIsFixed is set
wDirectoryEntryIndex:           ds 1
wDirectoryEntrySectorInCluster: ds 1
wCurrentDirectoryIsFixed:       ds 1  ; Current open directory is the FAT16 fixed directory list
; Directory iteration output memory
wFatCurrentFilename::           ds 24
wFatCurrentFileType::           ds 1  ; 0 = End of list, 1 = Regular file, 2 = Directory
wFatCurrentTargetCluster::      ds 4
wMemEnd:

SECTION "libfat", ROM0

; Initialize the FAT library.
;   Returns with zero flag clear if there is an error.
fatInit::
    xor  a
    ld   hl, wFATStartSector
    ld   c, wMemEnd - wFATStartSector
.clearLoop:
    ld   [hl+], a
    dec  c
    jr   nz, .clearLoop

    ; Read sector 0 to see if we have a raw FAT filesystem or a MBR+partition table.
    ld   b, a
    ld   c, a
    ld   d, a
    ld   e, a
    call readSDSector
    jp   z, errorRet

    ; Both the MBR and the FAT boot sector contain this signature.
    ld   a, [SDSectorData + 510]
    cp   $55
    ret  nz
    ld   a, [SDSectorData + 511]
    cp   $aa
    ret  nz

    ; Check if we have an MBR
    ld   a, [SDSectorData + $1BE + 4]
    cp   $0C    ; check if we are a FAT32+LBA marked partition
    jr   nz, .checkForBootSector

    ; Load the start LBA with LSB first
    ld   de, SDSectorData + $1BE + 8
    ld   hl, wFATStartSector
    ld   c, 4
.copyStartSectorLBA:
    ld   a, [de]
    inc  de
    ld   [hl+], a
    dec  c
    jr   nz, .copyStartSectorLBA
    ld   hl, wFATStartSector
    call load32Bit
    call readSDSector
    jp   z, errorRet

.checkForBootSector:
    ; Both the MBR and the FAT boot sector contain this signature.
    ld   a, [SDSectorData + 510]
    cp   $55
    ret  nz
    ld   a, [SDSectorData + 511]
    cp   $aa
    ret  nz

    ; Check the bytes per sector value
    ld   a, [SDSectorData + $0b]
    and  a
    ret  nz
    ld   a, [SDSectorData + $0c]
    cp   $02
    ret  nz

    ; Read the number of sectors per cluster
    ld   a, [SDSectorData + $0d]
    ld   [wFatClusterSize], a
    ld   c, $00
    ld   b, $01
.setClusterSizeLoop:
    cp   b
    jr   z, .setClusterSize
    inc  c
    sla  b
    jr   nz, .setClusterSizeLoop
    jp   errorRet
.setClusterSize:
    ld   a, c
    ld   [wClusterSizeShift], a

    ; Load the number of reserved sectors, and skip past them for the start of the FAT.
    ld   a, [SDSectorData + $0e]
    ld   e, a
    ld   a, [SDSectorData + $0f]
    ld   d, a
    xor  a
    ld   c, a
    ld   b, a
    ld   hl, wFATStartSector
    call add32Bit
    ld   hl, wFATStartSector
    call store32Bit

    ; Load the amount of FAT sectors into wRootDirectoryStart so we have a place to store it.
    ld   hl, wRootDirectoryStart
    ld   a, [SDSectorData + $16]
    ld   c, a
    ld   [hl+], a
    ld   a, [SDSectorData + $17]
    ld   b, a
    ld   [hl+], a
    xor  a
    ld   [hl+], a
    ld   [hl+], a

    ld   a, b
    or   c
    jr   nz, .no32BitFatSectorCount ; If the 16bit sector FAT sector size is zero then we have FAT32.
    ; Load the cluster number where the root directory starts
    ld   hl, wRootDirectoryStart
    ld   a, [SDSectorData + $24]
    ld   [hl+], a
    ld   a, [SDSectorData + $25]
    ld   [hl+], a
    ld   a, [SDSectorData + $26]
    ld   [hl+], a
    ld   a, [SDSectorData + $27]
    ld   [hl+], a
.no32BitFatSectorCount:
    xor  a
    ld   e, a
    ld   d, a
    ld   c, a
    ld   b, a

    ; Get the number of FAT tables
    ld   a, [SDSectorData + $10]
    and  a
    jp   z, errorRet

    ; Multiply number of FAT tables by amount of FAT sectors
.multiplyFATSize
    ld   hl, wRootDirectoryStart
    push af
    call add32Bit
    pop  af
    dec  a
    jr   nz, .multiplyFATSize
    ld   hl, wFATStartSector
    call add32Bit
    ld   hl, wRootDirectoryStart
    call store32Bit

    ; Get the size of the root directory. This is 32byte entries. So we need to divide by 16 to get the amount of sectors
    ld   a, [SDSectorData + $11]
    ld   e, a
    ld   a, [SDSectorData + $12]
    ld   d, a
    or   e
    jr   nz, .fixedRootDirectory

    ; FAT32, root directory is located in cluster data.
    ld   hl, wRootDirectoryStart
    call load32Bit
    ld   hl, wClustersStart
    call store32Bit
    ld   hl, SDSectorData + $2C
    ld   de, wRootDirectoryStart
    ld   c, 4
.copyRootDirStart:
    ld   a, [hl+]
    ld   [de], a
    inc  de
    dec  c
    jr   nz, .copyRootDirStart
    jp   .rootDirDone

.fixedRootDirectory:
    ; /16, inefficient, but easy to code. Sorry. Could be done with a swap and some more clever bit twiddling
REPT 4
    srl  d
    rr   e
ENDR
    ; If we have a fixed root directory location, we are FAT16 (or FAT12)
    ; Not the recommended/best way, but works for now.
    ld   a, $01
    ld   [wFAT16], a
    ; Find out where the clusters start by skipping over the root directory list
    ; de contains the root directory size in sectors
    xor  a
    ld   c, a
    ld   b, a
    ld   hl, wRootDirectoryStart
    call add32Bit
    ld   hl, wClustersStart
    call store32Bit

.rootDirDone:
    call fatOpenRootDir
    call fatGetNextFile

    ; Done
    xor  a
    ret

; Change the current directory to the root directory, so we can start reading files there.
fatOpenRootDir::
    ld   hl, wRootDirectoryStart
    call load32Bit
    ld   hl, wDirectoryEntryCluster
    call store32Bit
    xor  a
    ld   [wDirectoryEntryIndex], a
    ld   [wDirectoryEntrySectorInCluster], a
    ld   a, [wFAT16]
    ld   [wCurrentDirectoryIsFixed], a
    ret

fatGetNextFile::
    ; Get the SD card sector
    ld   hl, wDirectoryEntryCluster
    call load32Bit
    ld   a, [wCurrentDirectoryIsFixed]
    and  a
    jr   nz, .readSector
    ; We got a cluster number, need to translate that to a sector number
    call clusterToSectorNumber
    ld   a, [wDirectoryEntrySectorInCluster]
    call addA32Bit
.readSector:
    call readSDSector
    
    ; Get a pointer in HL to the directory entry
    ld   a, [wDirectoryEntryIndex]
    swap a
    ld   l, a
    res  0, l
    and  $01
    ld   h, a
    ld   de, SDSectorData
    add  hl, hl
    add  hl, de
    
    ; Check if we are at the end of the directory list.
    ld   a, [hl]
    and  a
    ld   [wFatCurrentFileType], a
    ret  z

    ; TODO: Parse the directory entry properly, only reading short filename at the moment.
    ld   de, wFatCurrentFilename
    ld   c, 8
.filenameCopyLoop:
    ld   a, [hl+]
    cp   $20
    jr   z, .skipSpace
    ld   [de], a
    inc  de
.skipSpace:
    dec  c
    jr   nz, .filenameCopyLoop
    ld   a, "."
    ld   [de], a
    inc  de
    ; copy file extension
    ld   c, 3
.filenameCopyLoop2:
    ld   a, [hl+]
    cp   $20
    jr   z, .skipSpace2
    ld   [de], a
    inc  de
.skipSpace2:
    dec  c
    jr   nz, .filenameCopyLoop2
    xor  a
    ld   [de], a

    ; Get the directory entry attributes to see if we are an directory or file
    ld   a, [hl]
    cp   $0F
    jr   z, .entryIsLongFilename
    and  $10
    jr   z, .entryIsFile
    ld   a, $02 ; mark as directory
    jr   .setType
.entryIsLongFilename:
    ld   a, $03
    jr   .setType
.entryIsFile:
    ld   a, $01 ; mark as file
.setType:
    ld   [wFatCurrentFileType], a
    
    ; Get the cluster number for this entry
    ld   de, $1A - $0B ; hl is at entry+$0b, and we want it at entry+$1A
    add  hl, de
    ld   a, [hl+]
    ld   [wFatCurrentTargetCluster], a
    ld   a, [hl+]
    ld   [wFatCurrentTargetCluster + 1], a
    ld   de, $14 - $1C ; hl is at entry+$1C, and we want it at entry+$14
    add  hl, de
    ld   a, [hl+]
    ld   [wFatCurrentTargetCluster + 2], a
    ld   a, [hl+]
    ld   [wFatCurrentTargetCluster + 3], a
    ld   a, [wFAT16]
    and  a
    jr   z, .notFAT16
    xor  a
    ld   [wFatCurrentTargetCluster + 2], a
    ld   [wFatCurrentTargetCluster + 3], a
.notFAT16:

    ; Done with directory entry,
    ; Move index to next entry in sector.
    ld   a, [wDirectoryEntryIndex]
    inc  a
    and  $0F
    ld   [wDirectoryEntryIndex], a
    ret  nz

    ; Move sector/cluster number forward
    ld   a, [wFAT16]
    and  a
    jr   z, .advanceInCluster
    ld   hl, wDirectoryEntryCluster
    call load32Bit
    ld   a, $01
    call addA32Bit
    ld   hl, wDirectoryEntryCluster
    call store32Bit
    ret
.advanceInCluster:
    ld   a, [wDirectoryEntrySectorInCluster]
    inc  a
    ld   [wDirectoryEntrySectorInCluster], a
    ld   hl, wFatClusterSize
    cp   [hl]
    ret  nz
    xor  a
    ld   [wDirectoryEntrySectorInCluster], a
    
    ld   hl, wDirectoryEntryCluster
    call load32Bit
    call getNextCluster
    ld   hl, wDirectoryEntryCluster
    call store32Bit
    ret

; Read the first sector of a file.
fatReadFile::
    ld   hl, wFatCurrentTargetCluster
    call load32Bit
    call clusterToSectorNumber
    jp   readSDSector

; Translate a cluster number to a sector number.
; BCDE contains the current sector number.
clusterToSectorNumber:
    ; Cluster numbers start at 2, so subtract the 2.
    ld   a, $02
    call subA32Bit
    ld   a, [wClusterSizeShift]
    and  a
    jr   z, .noShift
.shiftRepeat:
    sla  e
    rl   d
    rl   c
    rl   b
    dec  a
    jr   nz, .shiftRepeat
.noShift:
    ld   hl, wClustersStart
    jp   add32Bit

; Get the next cluster number from the current cluster number
; BCDE contains the current cluster on entry and the new cluster on return.
getNextCluster:
    ld   a, [wFAT16]
    and  a
    jp   z, getNextClusterFAT32
    ; Get next cluster for FAT16
    ; First 8 bits are the index into the SD sector, while the other 8 bits are the sector number. (cluster number is only 16 bit in FAT16)
    xor  a
    ld   h, a
    ld   l, e
    ld   e, d
    ld   d, a
    ld   c, a
    ld   b, a
    push bc
    push hl
    ld   hl, wFATStartSector
    call add32Bit
    call readSDSector
    pop  hl
    add  hl, hl
    ld   de, SDSectorData
    add  hl, de
    ld   a, [hl+]
    ld   e, a
    ld   d, [hl]
    pop  bc
    ret
getNextClusterFAT32:
    ; First 7 bits = index in SD sector, so store those for later use.
    ld   a, e
    and  $7f
    ; Remaining 25 bits = SD sector index
    rl   e
    rl   d
    rl   c
    rl   b ; we can safely drop the upper bit as FAT cluster numbers are only 28 bit.
    ld   e, d
    ld   d, c
    ld   c, b
    ld   b, $00
    ld   hl, wFATStartSector
    push af
    call add32Bit
    call readSDSector
    pop  af
    ld   h, $00
    ld   l, a
    add  hl, hl
    add  hl, hl
    ld   de, SDSectorData
    add  hl, de
    call load32Bit
    ld   a, b
    and  $0F
    ld   b, a
    ret

; Add the 32bit value stored at [HL] to BCDE
add32Bit:
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
addA32Bit:
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
subA32Bit:
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
load32Bit:
    ld   e, [hl]
    inc  hl
    ld   d, [hl]
    inc  hl
    ld   c, [hl]
    inc  hl
    ld   b, [hl]
    ret

; Store the 32bit value in BCDE into [hl]
store32Bit:
    ld   [hl], e
    inc  hl
    ld   [hl], d
    inc  hl
    ld   [hl], c
    inc  hl
    ld   [hl], b
    ret

errorRet:
    xor  a
    inc  a
    ret

serialPrint32Bit:
    ld   a, b
    call serialPrintHex
    ld   a, c
    call serialPrintHex
    ld   a, d
    call serialPrintHex
    ld   a, e
    call serialPrintHex
    ld   a, "\n"
    call serialCharOut
    ret
