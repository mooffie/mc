#!/bin/bash

# This script creates mockup files that can't be recorded in git (e.g.,
# pipe & device special files), or that are unwise to put there (e.g.,
# huge files), or that can make "make dist" fail (e.g., broken links).

function die {
  echo "$@" 1>&2
  exit 1
}

cd mockup/demo-colors-dir || die "I cannot see the mockup dir."

[ -p pipe-file ] || mkfifo pipe-file

[ -h broken-link ] || ln -s missing broken-link

# sudo mknod device-file c 1 3

chmod +x shell.sh  # In case git didn't keep the permission.
