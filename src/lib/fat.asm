SECTION "libfatRAM", WRAM0
wFATStartSector: ds 4       ; LBA, LSB first
wRootDirectoryStart: ds 4   ; LBA, LSB first
wClustersStart: ds 4        ; LBA, LSB first
wClusterSize: ds 1          ; In number of required left shifts
wFAT16: ds 1
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
    ld   [wClusterSize], a

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
    call add32Bit
    dec  a
    jr   nz, .multiplyFATSize
    ld   hl, wFATStartSector
    call add32Bit
    ld   hl, wRootDirectoryStart
    call store32Bit

    ; Get the size of the root directory. This is 16byte entries. So we need to divide by 32 to get the amount of sectors
    ld   a, [SDSectorData + $11]
    ld   e, a
    ld   a, [SDSectorData + $12]
    ld   d, a
    or   e
    jr   nz, .fixedRootDirectory
    ; /32, inefficient, but easy to code. Sorry. Could be done with a swap and some more clever bit twiddling
REPT 5
    srl  d
    rr   e
ENDR

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
    ; TODO: Set current directory to root
    

    ; Done
    xor  a
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
