#!/bin/bash

# This script deletes all the files mockup-up.sh created.

cd mockup/demo-colors-dir

[ -p pipe-file ] && rm pipe-file

[ -h broken-link ] && rm broken-link

[ -c device-file ] && rm -f device-file
