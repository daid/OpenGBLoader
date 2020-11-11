INCLUDE "hardware.inc"

SECTION "ezgb-wram", WRAM0
wStack: ds $100
.end:

wRomMBC: ds 1
wRomHasTimer: ds 1
wRomHasSRam: ds 1 ; $01 = has SRAM, $02=SRAM with battery backup
wRomHeaderChecksum: ds 1
wRomRomSize: ds 2 ; in banks
wRomSRamSize: ds 1 ; in banks

SECTION "ezgb-header", ROM0[$0100]
    jr   entry
    ds   $0150 - @
entry:
    ld   sp, wStack.end
    call cartHardwareInit
    call fatInit
    jp   nz, cartInitFailure

    call loadFontData

getNextFile:
    call fatGetNextFile
    ld   a, [wFatCurrentFileType]
    and  a
    call z, fatOpenRootDir
    jr   z, getNextFile
    cp   $03 ; If we are a long filename entry, skip it.
    jr   z, getNextFile

    call getFileInfo

.haltLoop:
    xor  a
    ldh  [rIF], a
    halt
    call updateJoypadState
    ld   a, [wJoypadPressed]
    bit  PADB_RIGHT, a
    jr   nz, getNextFile
    bit  PADB_START, a
    call nz, startCurrentFile
    jr   .haltLoop

cartInitFailure:
    call loadFontData
    ld   hl, failureString
    ld   de, _SCRN0
    call displayString

.haltLoop:
    halt
    jr .haltLoop

failureString:
    db "SD init failure", 0

getFileInfo:
    call clearScreen
    ld   hl, wFatCurrentFilename
    ld   de, _SCRN0
    call displayString

    call fatReadFile
    ld   a, [SDSectorData + $104]
    cp   $CE
    jp   nz, displayInvalidFile
    ld   hl, SDSectorData + $134
    ld   de, _SCRN0 + SCRN_VX_B * 2
    call displayString

    xor  a
    ld   [wRomMBC], a
    ld   [wRomHasTimer], a
    ld   [wRomHasSRam], a
    ld   [wRomHeaderChecksum], a
    ld   [wRomRomSize], a
    ld   [wRomRomSize+1], a
    ld   [wRomSRamSize], a

    ld   a, [SDSectorData + $147]
    dec  a ; $01
    call z, setRomMBC1
    dec  a ; $02
    call z, setRomMBC1
    call z, setRomSRAM
    dec  a ; $03
    call z, setRomMBC1
    call z, setRomSRAMBattery
    dec  a ; $04
    dec  a ; $05
    call z, setRomMBC2
    call z, setRomSRAM
    dec  a ; $06
    call z, setRomMBC2
    call z, setRomSRAMBattery
    dec  a ; $07
    dec  a ; $08
    call z, setRomSRAM
    dec  a ; $09
    call z, setRomSRAMBattery
    dec  a ; $0a
    dec  a ; $0b
    ; MMM01
    dec  a ; $0c
    ; MMM01+RAM
    dec  a ; $0d
    ; MMM01+RAM+BATTERY
    dec  a ; $0e
    dec  a ; $0f
    call z, setRomMBC3
    call z, setRomTimer
    dec  a ; $10
    call z, setRomMBC3
    call z, setRomSRAMBattery
    call z, setRomTimer
    dec  a ; $11
    call z, setRomMBC3
    dec  a ; $12
    call z, setRomMBC3
    call z, setRomSRAM
    dec  a ; $13
    call z, setRomMBC3
    call z, setRomSRAMBattery
    sub  $06 ; $19
    call z, setRomMBC5
    dec  a ; $1a
    call z, setRomMBC5
    call z, setRomSRAM
    dec  a ; $1b
    call z, setRomMBC5
    call z, setRomSRAMBattery
    dec  a ; $1c
    call z, setRomMBC5
    dec  a ; $1d
    call z, setRomMBC5
    call z, setRomSRAM
    dec  a ; $1e
    call z, setRomMBC5
    call z, setRomSRAMBattery

    ld   a, [SDSectorData + $149]
    dec  a ; $01
    call z, setSRAMSize1
    dec  a ; $02
    call z, setSRAMSize1
    dec  a ; $03
    call z, setSRAMSize4
    dec  a ; $04
    call z, setSRAMSize16
    dec  a ; $05
    call z, setSRAMSize8

    ld   a, [SDSectorData + $14D]
    ld   [wRomHeaderChecksum], a

    ; Get the amount of banks in the file
    ; TODO: Round upwards
    ld   hl, wFatCurrentFileSize
    call load32Bit
    ; BCDE contains file size, we only care about multiples of $4000, so shift left twice to get the amount of banks in BC
    sla  d
    rl   c
    rl   b
    sla  d
    rl   c
    rl   b
    ld   a, c
    ld   [wRomRomSize], a
    ld   a, b
    ld   [wRomRomSize+1], a

    ; Display all the rom data to the screen.
    ld   hl, headerSizeString
    ld   de, _SCRN0 + SCRN_VX_B * 3 + 1
    call displayString
    ld   a, [wRomRomSize]
    ld   c, a
    xor  a
.bcdLoop:
    inc  a
    daa
    dec  c
    jr   nz, .bcdLoop
    ld   b, a
    swap a
    and  $0F
    add  "0"
    call displayChar
    ld   a, b
    and  $0F
    add  "0"
    call displayChar

    ld   hl, headerMBCString
    ld   de, _SCRN0 + SCRN_VX_B * 4 + 1
    call displayString
    ld   a, [wRomMBC]
    ld   hl, romMBCStrings
    call displayStringFromTable

    ld   hl, headerTimerString
    ld   de, _SCRN0 + SCRN_VX_B * 5 + 1
    call displayString
    ld   a, [wRomHasTimer]
    ld   hl, noYesStrings
    call displayStringFromTable

    ld   hl, headerSRamString
    ld   de, _SCRN0 + SCRN_VX_B * 6 + 1
    call displayString
    ld   a, [wRomHasSRam]
    ld   hl, romSRAMStrings
    call displayStringFromTable

    ld   hl, headerSizeString
    ld   de, _SCRN0 + SCRN_VX_B * 7 + 1
    call displayString
    ld   a, [wRomSRamSize]
    add  "0"
    call displayChar

    ret

setRomMBC1:
    ld   hl, wRomMBC
    ld   [hl], $01
    ret

setRomMBC2:
    ld   hl, wRomMBC
    ld   [hl], $02
    ret

setRomMBC3:
    ld   hl, wRomMBC
    ld   [hl], $03
    ret

setRomMBC5:
    ld   hl, wRomMBC
    ld   [hl], $04
    ret

setRomSRAM:
    ld   hl, wRomHasSRam
    ld   [hl], $01
    ret

setRomSRAMBattery:
    ld   hl, wRomHasSRam
    ld   [hl], $02
    ret

setRomTimer:
    ld   hl, wRomHasTimer
    ld   [hl], $01
    ret

setSRAMSize1:
    ld   hl, wRomSRamSize
    ld   [hl], $01
    ret

setSRAMSize4:
    ld   hl, wRomSRamSize
    ld   [hl], $04
    ret

setSRAMSize8:
    ld   hl, wRomSRamSize
    ld   [hl], $08
    ret

setSRAMSize16:
    ld   hl, wRomSRamSize
    ld   [hl], $10
    ret

displayInvalidFile:
    ld   hl, invalidFileString
    ld   de, _SCRN0 + SCRN_VX_B * 2
    call displayString
    ret

invalidFileString:
    db "Invalid file", 0

headerMBCString:   db "MBC:   ", 0
headerTimerString: db "Timer: ", 0
headerSRamString:  db "SRAM:  ", 0
headerSizeString:  db " size: ", 0

noYesStrings:
    dw noString, yesString
noString: db "No", 0
yesString: db "Yes", 0

romMBCStrings:
    dw romMBCStringMBCNone, romMBCStringMBC1, romMBCStringMBC2, romMBCStringMBC3, romMBCStringMBC5, romMBCStringMBC1m
romMBCStringMBCNone: db "No MBC", 0
romMBCStringMBC1: db "MBC1", 0
romMBCStringMBC2: db "MBC2", 0
romMBCStringMBC3: db "MBC3", 0
romMBCStringMBC5: db "MBC5", 0
romMBCStringMBC1m: db "MBC1m", 0
romSRAMStrings:
    dw romSRAMStringNone, romSRAMStringRAM, romSRAMStringBATTERY
romSRAMStringNone: db "No", 0
romSRAMStringRAM: db "RAM", 0
romSRAMStringBATTERY: db "RAM+Battery", 0

; TODO: This belongs with the ezflash specific code.
startCurrentFile:
    ld   a, [wRomRomSize]
    and  a
    ret  z

    ld   a, [wRomHasTimer]
    and  a
    ld   a, [wRomMBC]
    jr   z, .noTimer
    or   $80
.noTimer:
    ld   [$7f37], a
    xor  a
    ld   [$7fd4], a
    ld   a, [wRomSRamSize]
    dec  a
    ld   [$7fc4], a
    ld   hl, wRomRomSize
    ld   e, [hl]
    inc  hl
    ld   d, [hl]
    dec  de
    ld   a, e
    ld   [$7fc1], a
    ld   a, d
    ld   [$7fc2], a
    ld   a, [wRomHeaderChecksum]
    ld   [$7fc2], a

    xor  a
    ld   [$7f30], a
    ld   [$7fc0], a
    inc  a
    ld   [$7f36], a

    ; TODO: fill ROMLoadInfo properly, with fragmentation support
    ld   hl, $A000
    xor  a
    ld   [hl+], a
    ld   [hl+], a
    ld   [hl+], a
    ld   [hl+], a
    push hl
    ld   hl, wFatCurrentTargetCluster
    call load32Bit
    call fatClusterToSectorNumber
    pop  hl
    ld   a, e
    ld   [hl+], a
    ld   a, d
    ld   [hl+], a
    ld   a, c
    ld   [hl+], a
    ld   a, b
    ld   [hl+], a
    ld   a, $ff
    ld   [hl+], a
    ld   [hl+], a
    ld   [hl+], a
    ld   [hl+], a
    ld   hl, $A1F0
    ld   a, [wFatCurrentFileSize]
    ld   [hl+], a
    ld   a, [wFatCurrentFileSize+1]
    ld   [hl+], a
    ld   a, [wFatCurrentFileSize+2]
    ld   [hl+], a
    ld   a, [wFatCurrentFileSize+3]
    ld   [hl+], a
    ld   a, $00
    ld   [hl+], a
    xor  a
    ld   [hl+], a
    ld   [hl+], a
    ld   [hl+], a
    ld   a, [wFatClusterSize]
    ld   [hl+], a
    xor  a
    ld   [hl+], a
    ld   [hl+], a
    ld   [hl+], a

    ld   hl, romStartRoutineInROM
    ld   de, romStartRoutine
    ld   c, romStartRoutine.end - romStartRoutine
    call copyMemory
    jp   romStartRoutine

SECTION "RomStartRoutineROM", ROM0
romStartRoutineInROM:
LOAD "RomStartRoutine", WRAM0
romStartRoutine:
    ld   a, $03
    ld   [$7f36], a
.loadWait:
    ld   a, [$A000]
    cp   $02
    jr   nz, .loadWait
    xor  a
    ld   [$7f36], a
    ld   [$7f31], a
    ld   [$7f33], a
    ld   a, $80
    ld   [$7fe0], a
    ; We should never get here.
    ret
.end:
