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

The reason we use the shell script, in addition to Lua, is because we
haven't (yet) exposed to Lua a function to switch MC's skin. So we set
the skin with the `-S` command-line option. But it turns out using a
shell script was a good idea for other reasons too: it's probably a
better place to set up the environment.
