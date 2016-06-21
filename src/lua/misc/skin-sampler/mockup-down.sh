#!/bin/bash

# This script deletes all the files mockup-up.sh created.

cd mockup/demo-colors-dir

[ -p pipe-file ] && rm pipe-file

[ -c device-file ] && rm -f device-file
