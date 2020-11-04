#!/bin/sh

#TODO: Might want to check mtools version, older versions fail at mformat.

set -eu

FILENAME=$1

createImageRaw()
{
    MTOOLS_PARAMS="-i ${FILENAME}"
    SIZE=$1
    FORMAT_PARAMS=$2

    rm -rf "${FILENAME}"
    truncate -s "${SIZE}" "${FILENAME}"
    fillImage
}

createImageMBR()
{
    MTOOLS_PARAMS="-i ${FILENAME}@@1M"
    SIZE=$1
    FORMAT_PARAMS=$2

    rm -rf "${FILENAME}"
    truncate -s "${SIZE}" "${FILENAME}"
    echo "2048,,c;" | sfdisk "${FILENAME}" > /dev/null
    fillImage
}

fillImage()
{
    mformat ${MTOOLS_PARAMS} ${FORMAT_PARAMS}
    echo "" | mcopy ${MTOOLS_PARAMS} - ::/empty.gb
    echo "" | mcopy ${MTOOLS_PARAMS} - ::/empty.gbc
}
