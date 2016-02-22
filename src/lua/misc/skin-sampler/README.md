# skin-sampler

This application generates screenshots (in HTML format) demonstrating all
of Midnight Commander's skins.

It is composed of a shell script, `generate.sh`, which iterates over all
MC's skins and for each one runs a Lua program, `skin-sampler.lua`, which
generates screenshots for it.

The output is written to the 'output' folder.

(There's also the `generate-headless.sh` script, which may be more
convenient than `generate.sh` if you're on a headless server.)

## Reference

This app was instigated by this ticket:

  http://www.midnight-commander.org/ticket/2147
  "create a skin repository"

## Other notes

* Since we can't store special files in git (like pipes & devices), which
are files we want to show in screenshots, we create such files using the
shell script `mockup-up.sh`. You may need to edit this file to adjust it
to your system.

* We could have written the entire thing in Lua (we have
`tty.skin_change()`). Shell scripts weren't a must, but they happen to
fit comfortably here.
