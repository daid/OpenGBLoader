#!/bin/sh

set -eu

rm -rf ${1}
truncate -s 128M ${1}
echo ',,c;' | /sbin/sfdisk ${1} >/dev/null
mformat -i ${1}@@1M
