#!/bin/bash

PROG=./generate.sh               # 'empty' needs the './' !
LOG=generate-headless.log

echo
echo "This is a wrapper around $PROG that makes it easy to run it"
echo "on a headless server."
echo
echo "It makes use of the 'empty' program, which you can get here:"
echo
echo "    http://empty.sourceforge.net/"
echo
echo "Ok,"
echo
echo "I'm about to run $PROG, in a pseudo terminal."
echo "You'll see nothing, hear nothing, smell nothing, know nothing."
echo
echo "If shit happens:"
echo "(1) Run $PROG directly to see if it displays any error dialog."
echo "(2) Examine '$LOG' to see the transaction."
echo
echo "Good luck."
echo
echo "Note: if you press ^C before I'm done, 'empty' will still be"
echo "running in the background. Do 'killall empty' to kill it."
echo
echo "Working... (patience! it will take several seconds)"

cd "$(dirname "$0")"

killall -q empty  # Clear prior failed invocations.

[ -f $PROG ] || { echo "I cannot find $PROG"; exit 1; }
[ -f $LOG ] && rm $LOG

unset MC_SID  # See comment in generate.sh.

empty -L $LOG -i in.fifo -o out.fifo -f $PROG

# Read all the program's output, thus unblocking it.
time cat out.fifo > /dev/null
