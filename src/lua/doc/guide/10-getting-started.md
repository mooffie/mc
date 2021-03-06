
# Getting started

This documents describes how to do "Hello World!" from Lua inside MC.

## Quick installation

First you have to install MC with Lua support, of course.

There's a separate @{~installation|installation document} describing
installation in depth. If you're too excited to read it (and rightly
so!), and if you're on a Debian-based system, then you can do with this
trimmed down recipe:

    @plain
    $ sudo apt-get install liblua5.2-dev
    $ sudo apt-get build-dep mc
    $ git clone https://github.com/mooffie/mc.git
    $ cd mc
    $ git checkout luatip
    $ ./autogen.sh
    $ ./configure --prefix=$HOME/local --with-lua
    $ make
    $ make install

Don't forget the `--with-lua` option!

This will install mc in your $HOME/local folder (because we don't want
to overwrite the system's MC, although you're free to do that if you
wish).

(If anything goes wrong, see the full @{~installation|installation document}.)

## Writing your first Lua script

Let's write a "Hello World" program.

<a name="user-lua-folder"></a>

__Where are scripts stored?__

When MC starts it executes all the Lua scripts found in a certain folder
within your home. This is where you may put your own scripts. We will
often call this folder _"user Lua folder"_, and to the files within
we'll sometimes call  _"startup scripts"_.

To discover the location of this folder, run MC with the -F option:

    @plain
    $ $HOME/local/bin/mc -F

Here's an _example_ output for this command:

<pre>
Root directory: /home/mooffie

[System data]
   Config directory: /usr/etc/mc/
   Data directory:   /usr/share/mc/
   File extension handlers: /usr/libexec/mc/ext.d/
   VFS plugins and scripts: /usr/libexec/mc/
&nbsp;     extfs.d:        /usr/libexec/mc/extfs.d/
&nbsp;     fish:           /usr/libexec/mc/fish/
   <b>Lua scripts:     /usr/libexec/mc/lua-0.3/</b>

[User data]
   Config directory: /home/mooffie/.config/mc/
   Data directory:   /home/mooffie/.local/share/mc/
&nbsp;     skins:          /home/mooffie/.local/share/mc/skins/
&nbsp;     extfs.d:        /home/mooffie/.local/share/mc/extfs.d/
&nbsp;     fish:           /home/mooffie/.local/share/mc/fish/
&nbsp;     mcedit macros:  /home/mooffie/.local/share/mc/mc.macros
&nbsp;     mcedit external macros: /home/mooffie/.local/share/mc/mcedit/macros.d/macro.*
&nbsp;     <b>Lua scripts:   /home/mooffie/.local/share/mc/lua-0.3/</b>
   Cache directory:  /home/mooffie/.cache/mc/
</pre>

(*Your* output will be different, especially since we instructed you to
use `--prefix=$HOME/local` when configuring.)

Note the two folders intended for "Lua scripts". One, under [System
data], is system-global: it contains the implementation of built-in
modules, and you don't normally have write permission there. The other,
under [User data], is the folder intended for the user, for you, to
store your own scripts.

In the above example the user folder is ~/.local/share/mc/lua-0.3/.

[tip]

The version number embedded in the folder name, "0.3" in this case, makes it
possible to install different major versions of MC exposing different
major versions of API: each would have a different number.

[/tip]

Let's create this folder and place in it a file containing:

    print("Hello World!")

The name you pick for this file doesn't matter (as long as it has a ".lua"
extension and doesn't start with a dot). Let's name it "hello.lua".

Now restart MC.

Nothing too exciting seems to have happened, has it? Press `C-o` to
switch to the shell. Voila! You can see our "Hello World!" there.
Hurrey! (Note: You @{~general#alert|wouldn't normally use print()}.)

Let's have a more exciting exercise. Add the following to hello.lua:

    keymap.bind("C-q", function()
      alert("Hello World!")
    end)

This will bind the `C-q` key (Control q) to a function that popups a
"Hello World!" message. Restart MC, or, better,
@{~general#restart|restart Lua only}, and press `C-q`.

[info]

__If something goes wrong...__

- If you have a syntax error in your code, an alert box will appear
  telling you the number of the offending line. Fix it.

- If nothing seems to happen, make sure you're indeed using the
  Lua-enabled MC. Run it with `mc -F` or `mc -V` to verify that it's indeed
  the case.

- If still nothing seems to happen, examine the log:

[indent]

    @plain

    # in one terminal window:
    $ export MC_LUA_LOG_FILE=~/log.txt
    $ mc

    # in another terminal window:
    $ tail -F ~/log.txt

Specifically, look for a line telling you that your script has been loaded.

[/indent]

[/info]

## What next?

* You can play with the @{~sample|sample applications}.

* You can learn more about @{~extend|how to extend MC}.
