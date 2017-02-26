#!/bin/bash

srcdir="$(cd "$(dirname "$0")" && pwd)"   # taken from autogen.sh (")
cd "$srcdir"

########################################################################
# Variables.
#
# You may customize these in a file named 'generate.env_vars.sh'.

MC=mc                            # Points to an 'mc' binary with Lua support.
OUTPUT_DIR=`pwd`/output          # Where to write the HTML.
SKINS_DIR=/usr/share/mc/skins    # Where the skins are stored.

[ -f generate.env_vars.sh ] && . generate.env_vars.sh

# Set the terminal's dimensions. 100x30 is a fine choice.
stty cols 100 rows 30
#
# Note: if your terminal emulator resets these dimensions, you have several
# options:
#
# - switch to 'xterm'; or
# - run this script inside a pseudo terminal using 'generate-headless.sh'; or
# - add "> /dev/null" to MC's invocation (but this affects the prompt it shows
#   and prevents you from seeing error dialogs).
#

########################################################################
# Utils.

die() {
  echo "$@" 1>&2
  exit 1
}

########################################################################
# Setup the output directory.

[ -d $OUTPUT_DIR ] && rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR

# @FIXME: We need to add '<meta charset="UTF-8" />' to our HTML files
# because they have frame characters. In the meantime we solve this on
# the server side:
cat > $OUTPUT_DIR/.htaccess <<EOS
Options +Indexes
AddCharset UTF-8 .html
EOS

########################################################################
# Setup the mockup directory.

./mockup-up.sh || die "I cannot setup the mockup dir."

########################################################################
# Do the job.

# We're not using mcscript ('mc -L') because (currently) it doesn't let us
# bring up the panels. So we use the 'mc' binary. But how can we ask it to
# run our script? Answer: by tricking it to think that this directory, which
# holds the script, is the user Lua dir. It will then load all the Lua files
# in it.
export MC_LUA_USER_DIR=`pwd`

# Since we aren't using mcscript, we need to guard against the following
# case or else MC will complain that "Midnight Commander is already running
# on this terminal".
[ -z "$MC_SID" ] || die "You cannot run this script from inside MC. Exit MC first. Or use 'generate-headless.sh' instead."

# For 16M colors:
export COLORTERM=truecolor
# Some setups don't enable this by default:
export TERM=xterm-256color

# Go!
for skin in $SKINS_DIR/*.ini; do

  SKIN_NAME=$(basename $skin .ini)
  export MC_SKIN_SAMPLER_OUTPUT=$OUTPUT_DIR/$SKIN_NAME

  $MC -S $skin
  #break  # uncomment if you want to render just one skin (for debugging).

done

########################################################################
# Cleanup.

reset  # Because the os.exit() we do in Lua doesn't restore the screen.

./mockup-down.sh

# Move the "defbg" skins to a separate folder, because users browsing them
# are likely to think there's a bug somewhere: one needs to set the browser's
# background color to see them well.
cd $OUTPUT_DIR
mkdir skins_using_defbg
mv *-defbg-* skins_using_defbg
