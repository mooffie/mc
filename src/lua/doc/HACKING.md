Hacking guide
=============

This document is a collection of comments on how to write code for mc^2.

Header files
------------

Suppose you're writing code that needs to use some Lua facility.

**LOW-LEVEL**

If your source file uses Lua's API (things like lua_xxx()), you need to
include src/lua/capi.h. This file pulls-in the Lua engine's header files.
It also provides some convenience functions.

**HI-LEVEL**

You'll notice, however, that most source files outside the src/lua folder
don't use src/lua/capi.h. They use the higher-level API in src/lua/plumbing.h.

Makefile.am's
-------------

If a makefile's sources include (directly or indirectly) src/lua/capi.h, then
you need to add LUA_CFLAGS to AM_CPPFLAGS:

    AM_CPPFLAGS = ... $(LUA_CFLAGS)

that's because capi.h pulls-in the Lua engine's header
files, and the compiler (the preprocessor, to be exact) needs to know
where these files are.

(Don't blame us for not naming it LUA_CPPFLAGS instead
of LUA_CFLAGS: it's pkg-config's fault.)

Otherwise don't bother. For example, the makefiles of lib/widget and
lib/tty and src/editor don't need LUA_CFLAGS because they include
src/lua/plumbing.h, which is a high-level interface that doesn't pull-in
capi.h.

Another example: src/vfs/luafs/makefile.am *does* need it because it uses the Lua API.

Another example: src/makefile.am *does* need it, because textconf.c includes capi.h.

(Don't bother with LUA_LIBS: it need only appear in lib/Makefile.am.)

Naming conventions
------------------

By default we make the names in the Lua API identical to those of the C
API. E.g., Lua's fs.getlocalcopy() mirrors C's mc_getlocalcopy().
However, changes are made in the following cases:

- To make Lua code clearer. Sometimes C names aren't clear enough.
  Sometimes they're confusing.

- When the C names are wrong.

- When the C names have to to with C internals that a Lua programmer
  doesn't need to know about.

Examples of name changes:

<pre>
C names                Lua names
-------                ---------
widget->lines      ->  widget.rows    ("lines" is a name for an iterator (file:lines, ui.Editbox:lines); and it seems at first glance related to data, not presentation.)
WEdit              ->  ui.Editbox     ("edit" is a verb, not a noun. This doesn't match the other widgets, and it's confusing to read.)
dlg_stop()         ->  dlg:close()    (Lua programmer doesn't have to know about the internals.)
WPanel.selected    ->  panel:current  (User may confuse "selected" with "marked file".)
"color"            ->  "style"        (A style holds two colors + attribs. Using the term "color" would have caused enormous confusion in documentation.)
tty_use_colors     ->  tty.is_color   (We shouldn't have some predicates named use_* and some is_*. We settle on is_*.)
tty_use_256colors  ->  tty.is_hicolor
lookup_key         ->  tty.keyname_to_keycode
lookup_key_by_code ->  tty.keycode_to_keyname
</pre>

In the tty department MC has a complete snafu which we fix by partitioning
the functions into "redraw" and "refresh" (see @{~mod:tty#refresh|explanation in ldoc}
for the tty module):

<pre>
C names          Lua names
-------          ---------
do_refresh    -> tty.redraw()
mc_refresh    -> tty.refresh()
dlg_redraw    -> dlg:redraw()
update_cursor -> dlg:redraw_cursor()
</pre>

Naming Lua functions written in C
---------------------------------

We prefix them with "l_". So we get l_open (for fs.open()), l_beep (for
tty.beep()), etc. Whether you embed there the module's name too is your
own decision.

Naming constructors
-------------------

By convention we name functions we want to give the impression are
"constructors" simply by capitalizing their first letter. Not by
naming them "new". Therefore, we have:

    ui.Label(), ui.Button(), ...
    fs.VPath()
    fs.StatBuf()

Underscores
-----------

We use underscores to separate words in function names, e.g.,
luaMC_register_system_callback. However, when we provide an alternative
to a Lua API function, we preserve the original name (which doesn't use
underscore, as is the style in Lua's source code), so we have
luaMC_setmetatable (instead of luaMC_set_metatable).

We also use the underscore for push/check functions. Unfortunately, this
makes these functions stand out when interspersed among the conventional non-underscored
functions, but we can't help it :-(

Naming "full" versions (C side)
-------------------------------

Let's examine a function on the C side that does something:

    do_something(a,b)

Sometimes we want a more complicated flavor, which gets gazillion more
arguments. There are two conventions for doing this. GLib does this by
appending "`_full`" to the function name. Windows does this by appending
"`_ex`". We do the latter:

    do_something_ex(a,b,c,d,e)

Writing comments
----------------

(1) Please try not to write "todo" comments. If a feature
is incomplete, don't write it at all: we don't want to
exasperate the user.

(2) Don't use the first pronoun. Write "we", not "I". And certainly
don't use your name. When you use the first pronoun people think
you're the authority on a certain line of code and they won't bother
to validate it, or to modify it, thinking that you know the in-and-outs
of the code and of all the Universe's secrets. If people see "I", or a
name, they'll think they need to contact you to get your
approval for their modification.

A related issue:

When you put your name in a header you're forcing everybody coming after
you who contribute substantially to do the same because otherwise it
won't do justice not to mention them. Additionally, they will have to devise
civilized ways to "demote" you, like rewriting that header
as a "change log". That's a lot of work.


"FIXME" comments
----------------

Sometimes we need to write silly code in order to circumvent
some deficiency in MC's own code. When this happens, blame MC in a
"FIXME" comment.

Pushing integers
----------------

Use lua_pushi() to push potentially huge integers (>32 bits). See
explanation in <capi.h>.

check / push
------------

Lua's own API has the following convention:

- luaL_check_XYZ() converts a Lua value to C.
- lua_push_XYZ() convert a C value to Lua.

We follow this convention in our own API and therefore end up with, e.g.:

  luaUI_check_widget() / luaUI_push_widget()

Please stick to this convention. It makes code much easier to read (as we
know what to expect).

Readability
-----------

When you use Lua's API, make sure it doesn't end up looking like
PDP-666's Assembly.

It's very easy. The key to doing this is something invented 90 years ago
before your grandma even came to your country. This key is called
*functions*: you organize your code in functions. Trouble is (judging by
some questions on StackOverflow), people seem to do their utmost to
forget about functions when they use Lua's API.

Let's have an example.

Consider:

    lua_newtable(L);
    lua_newtable(L);
    lua_pushstring(L, "__mode");
    lua_pushstring(L, "v");
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);

Even if you figured out what this code does, it probably took you at least
500 milliseconds. Commenting this code would have still required your reading it.
An improvement would be to put this code in a function with a descriptive
name: luaMC_push_weak_table. Then your code would turn into:

    luaMC_push_weak_table(L, "v");

Smart, eh?

As another example: if you needed to generate Lua tables like { x=5.6,
y=89.1 } in multiple places you'd create a function named luaMC_push_point
and then:

    luaMC_push_point(L, 5.6, 89.1);

Short, eh?

You'll notice that we have only one or two places where our use of Lua's
API seems complicated. But anywhere else our code is short and clear and
would be the ideal material for public reading in family gatherings.

Writing hybrid modules
----------------------

For modules that are part C, part Lua, we expose the C module under the
name "c.NAME". Then the Lua module require()s it and augments it.

