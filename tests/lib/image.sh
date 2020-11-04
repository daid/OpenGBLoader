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
    mformat ${MTOOLS_PARAMS} ${FORMAT_PARAMS}
}

createImageMBR()
{
    MTOOLS_PARAMS="-i ${FILENAME}"
    SIZE=$1
    FORMAT_PARAMS=$2

    rm -rf "${FILENAME}"
    truncate -s "${SIZE}" "${FILENAME}"
    mformat ${MTOOLS_PARAMS} ${FORMAT_PARAMS}
}
