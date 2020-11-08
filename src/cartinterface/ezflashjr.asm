
REG_UNLOCK1         equ $7F00
REG_UNLOCK2         equ $7F10
REG_UNLOCK3         equ $7F20
REG_LOCK            equ $7FF0


REG_SRAM_MAPPING    equ $7FC0
SRAM_MAP_NONE       equ $00
SRAM_MAP_SRAM       equ $03
SRAM_MAP_FW_VERSION equ $04
SRAM_MAP_RTC        equ $04


REG_SD_MAPPING      equ $7F30
SD_MAP_NONE         equ $00
SD_MAP_DATA         equ $01
SD_MAP_STATUS       equ $03
SD_STATUS_BUSY      equ $E1
REG_SD_ADDR0        equ $7FB0
REG_SD_ADDR1        equ $7FB1
REG_SD_ADDR2        equ $7FB2
REG_SD_ADDR3        equ $7FB3
REG_SD_COMMAND      equ $7FB4


SECTION "ezflash", ROMX
; Call at the start of the rom to setup the hardware properly.
hardwareInit::
    ld   a, $E1
    ld   [REG_UNLOCK1], a
    ld   a, $E2
    ld   [REG_UNLOCK2], a
    ld   a, $E3
    ld   [REG_UNLOCK3], a
    xor  a
    ld   [REG_SRAM_MAPPING], a
    ld   [REG_SD_MAPPING], a
    ret

; IN:  BCDE, sector number
; OUT: Sector is stored in SDSectorData
; OUT: Z flag set if there is an error reading the SD card
readSDSector::
    ld   hl, REG_SD_ADDR0
    ld   [hl], e
    inc  hl
    ld   [hl], d
    inc  hl
    ld   [hl], c
    inc  hl
    ld   [hl], b
    inc  hl
    xor  a
    ld   [REG_SRAM_MAPPING], a
    inc  a
    ld   [hl], a
    ld   a, SD_MAP_STATUS
    ld   [REG_SD_MAPPING], a

.waitForSD:
    ld   a, [$A000]
    cp   a, SD_STATUS_BUSY
    jr   z, .waitForSD

    ld   a, SD_MAP_DATA
    ld   [REG_SD_MAPPING], a

    ret


SECTION "ezflashSRAM", SRAM[$A000]
SDSectorData::
