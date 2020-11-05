#!/bin/sh

if [ "$#" -ne 3 ]; then echo "$0 should be run from make"; exit 1; fi

ROM="${1}"
IMAGE="${2}"
SRC="${3}"

RES=$("${BADBOY}" -c 1000000 "${1}" -e "${2}" 2>/dev/null)
EXP=$(cat ${SRC}.expect 2>/dev/null || echo "DONE")
if [ "${RES}" != "${EXP}" ]; then
    echo "Test failed: ${SRC} ${IMAGE}"
    echo "Result: ${RES}"
    echo "Expected: ${EXP}"
    exit 1
fi
