
# General Lua usage

Here are general tips about programming in Lua.

## Use the reference

The reference documentation is complete and detailed. If you don't know
what some function does, look it up.

## Restarting Lua

After you modify Lua code you need to reload it for it to take effect.
Obviously, one way to do this is to restart MC. But this "extreme" solution
can disrupt your work. A more comfortable solution is to reload only
Lua. You do this by pressing `C-x l` (this key binding is defined in
@{git:core/_bootstrap.lua}.)

## Quickly testing code

You can use the @{~sample|calculator} to evaluate expressions instantly.

## alert()

You'll often want to print messages.

While using Lua's @{print} is fine, you won't want to use it once MC's screen has been
initialized because it simply writes out to stdout and this will mess up
the "GUI". __Use @{globals.alert|alert} instead__. Or use @{devel.log|devel.log} if you
don't want to bother the user.

## devel.view() is your friend

When you want to inspect a variable, don't use @{globals.alert|alert}.
Use @{devel.view|devel.view}. It's a pretty-printer that works even for
very complicated structures. The output will be shown in MC's viewer for
your convenience (or on stdout if MC's screen hasn't been initialized
yet).

## Use T"string" when possible

Throughout the documentation, and stock code, you'll see that
human-readable strings are preceded by "T":

    alert(T"Who do you love?")

This makes your strings @{locale|localizable}.

## Modules

The Lua integration is organized in modules. While you may use
@{require} to load a builtin module, this isn't mandatory: any builtin
module will be automatically loaded for you when you reference it as a
global variable. But you still have to use @{require} if you want to
load your own, or 3'rd party, modules.

In other words, you can do:

    prompts.confirm(T"Delete this file?")

instead of:

    local prompts = require "prompt"
    ...
    prompts.confirm(T"Delete this file?")

## Organizing your code in files

Where do you write your code?

- You can write all your code in a single file in your Lua folder.

- This could become awkward rapidly, so you'd better write every feature in
a separate file. Files residing directly in your Lua folder are loaded
automatically.

- The next stage is to write your code in modules. At a minimum this
means to place it inside a directory named "modules" in your Lua folder.
You may want to create additional subfolders there, especially if your
module consists of several files.

[indent]

Modules have to be loaded explicitly. For example, if your module
consists of the following files:

    @plain
    ~/.local/share/mc/lua/modules/amusements/foo/init.lua
    ~/.local/share/mc/lua/modules/amusements/foo/logic.lua
    ~/.local/share/mc/lua/modules/amusements/foo/ui.lua

You'd load it by adding

    require('amusements.foo')

to one of the files residing directly in your Lua folder.

[/indent]

## Global variables

Lua is unjustly disparaged sometimes because of variables being global
"by default".

Don't worry, this issue doesn't come up in our Lua integration: the
global scope is protected. Accessing (setting or reading) a non-existent
global variable will raise an exception.

This means that you'll have to precede variables' and functions'
definitions with the keyword `local`.

If you *have* to use global variables (this would only happen with badly
written 3'rd party code), this is still selectively permissible using
@{globals.declare|declare}.

[tip]

Our @{~shots#linter|linter} (if you have
[lualint](http://lua-users.org/wiki/LuaLint) installed) will flag global
variables for you. It does static analysis of your code so even global
variables in branches that don't get executed will be detected.

[/tip]

## Use ":" to call methods, not "."

When the object on the left side isn't a module, you have to use ":" to
call its functions (commonly known as "methods").

This will become second nature to you before long.

If you err and use "." instead of ":", you'll get an error message
mentioning "argument #1", "self", or something related.

The following bad calls demonstrate this:

- `pnl.reload()`
  --<small>_Error: bad argument #1 to 'reload' (widget expected, got no value)_</small>
- `tty.get_canvas().draw_string("blah blah")`
  --<small>_Error: bad argument #1 to 'draw_string' (canvas expected, got string)_</small>
- `pnl.clear()`
  --<small>_Error: attempt to index local 'self' (a nil value)_</small>
