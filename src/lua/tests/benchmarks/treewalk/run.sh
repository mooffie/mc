#!/bin/bash

ATTR_BOLD=$'\x1b[1m'
ATTR_UNDERLINE=$'\x1b[4m'
ATTR_REVERSE=$'\x1b[7m'
ATTR_NORMAL=$'\x1b[0m'

export TIME="$ATTR_BOLD%Uuser %Ssystem %eelapsed %PCPU %M k$ATTR_NORMAL"

DIR=/usr/share/doc

MCSCRIPT=mcscript
MCSCRIPT_DEFS="times=1"

RUBY=ruby
RUBY_DEFS="--times 1"

PYTHON=python
PYTHON_DEFS="--times 1"

tm=/usr/bin/time

function run {
  CMD="$1"
  echo
  echo "${ATTR_REVERSE}Running: ${CMD}$ATTR_NORMAL"
  $tm $CMD
}

run "$MCSCRIPT -V"
run "$MCSCRIPT bench.lua flavor=none        $MCSCRIPT_DEFS $DIR"
run "$MCSCRIPT bench.lua flavor=posix_files $MCSCRIPT_DEFS $DIR"
run "$MCSCRIPT bench.lua flavor=posix_dir   $MCSCRIPT_DEFS $DIR"
run "$MCSCRIPT bench.lua flavor=files       $MCSCRIPT_DEFS $DIR"
#run "$MCSCRIPT bench.lua flavor=opendir     $MCSCRIPT_DEFS $DIR"
#run "$MCSCRIPT bench.lua flavor=dir         $MCSCRIPT_DEFS $DIR"
#run "$MCSCRIPT bench.lua flavor=glob        $MCSCRIPT_DEFS $DIR"

run "$RUBY bench.rb"
run "$RUBY bench.rb --flavor default        $RUBY_DEFS $DIR"

run "$PYTHON bench.py --flavor none         $PYTHON_DEFS $DIR"
run "$PYTHON bench.py --flavor default      $PYTHON_DEFS $DIR"
