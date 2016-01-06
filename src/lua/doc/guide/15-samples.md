
# Sample applications

MC comes with @{git:samples|sample scripts} (or "applications", if you
will) for you to use, some of which:

[indent]

[indent]

- __Editor__
  --<small>_linter, visual replace, speller, modeline, ... _</small>
- __Fields__
  --<small>_git, mplayer, bidi, ..._</small>
- __Filesystems__
  --<small>_MHT, MySQL, SQLite_</small>
- __Filemanager__
  --<small>_visual rename, ..._</small>
- __Accessories__
  --<small>_calculator, find-as-you-type, screensavers, ... _</small>
- __Games__

[/indent]

[/indent]

Tip: By "samples" we don't at all mean to say that these are incomplete
applications. We use the word "samples" merely to distinguish such code
from the code we consider @{git:core}.

To enable most of these applications all you have to do is to add the
following line to a Lua file in your @{~start!user-lua-folder|user Lua folder}:

    require('samples.official-suggestions')

Take a peek at that file (@{git:official-suggestions.lua}) to see what
**key bindings** activate the various applications.

A better approach is to copy that file (@{git:official-suggestions.lua})
to your user Lua folder: you'll then be able to edit it to your liking.

Tip-short: Lua code is organized in modules. You use Lua's
@{require|require()} to load a module.

[info]

**Using modules**

What to do when you see a module you like? How do you "activate" it?

The sample modules follow these rules:

* It's generally enough to just require() a module. This activates the
  feature the module provides.

[indent]

  Example:

    -- Enable "modeline" support for the editor.
    require('samples.editbox.modeline')

  Tip: Alternatively, you may _symlink_ to such modules in your user Lua
  folder. This technique works for any kind of files: e.g., you can
  symlink to code snippets in @{git:snippets|snippets/} to "activate"
  them.

[/indent]

* Modules that provide some intrusive feature, where automatic activation
  is not always desired, provide an install() function which you need to
  call.

[indent]

  Example:

    -- Enable a screensaver.
    require('samples.screensavers.clocks.analog').install()

[/indent]

* If the module has some entry point, e.g. a dialog box that starts some
  process, it provides a run() function to trigger it.

[indent]

  Example:

    -- Bring up the calculator.
    keymap.bind('C-x c', function()
      require('samples.apps.calc').run()
    end)

[/indent]

All modules have a comment at their top explaining their purpose and how
to enable them.

[/info]


