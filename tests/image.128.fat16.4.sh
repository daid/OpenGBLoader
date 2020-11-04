#!/bin/sh

set -eu

rm -rf ${1}
truncate -s 128M ${1}
mformat -i ${1}
