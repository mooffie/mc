
# Installation

## Step 1: Installing Lua

Your first step is to install a Lua engine. There are two ways to do this. The
easiest is to use your distribution's package manager. For example, on
Debian-based systems you'd run a command along of:

    @plain
    $ sudo apt-get install liblua5.2-dev

The other way is to compile Lua yourself from a tarball. We'll see this briefly later.

## Step 2: Installing MC's build dependencies

If it's the first time you compile MC on your system, you'll have to
install some header files and utilities needed to compile MC.

If you're on a Debian-based system, you can do this by issuing:

    @plain
    $ sudo apt-get build-dep mc

Otherwise, if your system doesn't have a similar command, you'll have to do it
[by hand](https://www.midnight-commander.org/wiki/doc/buildAndInstall/req).

## Step 3: Downloading and preparing MC

Download from github:

    @plain
    $ git clone https://github.com/mooffie/mc.git

Switch to the Lua branch:

    @plain
    $ cd mc
    $ git co lua-4.8.14-port

Run './autogen.sh' to create the configuration script:

    @plain
    $ ./autogen.sh

Everything is now ready for compilation!

## Step 4: Enabling MC's Lua support

By default the Lua support in MC is disabled. To enable it, add the
`--with-lua` option to configure's invocation:

    @plain
    $ ./configure --with-lua

'configure' will then look for a Lua engine registered with pkg-config.

Optionally, you may want to install MC inside your home folder, instead of
overriding the system's MC. To do so, use the `--prefix` options:

    @plain
    $ ./configure --prefix=$HOME/local --with-lua

When configure finishes, it prints a summary:

<pre>
Configuration:

  Compiler:                   gcc -std=gnu99
  Compiler flags:             ...
  File system:                Midnight Commander Virtual Filesystem
&nbsp;                             cpio, tar, sfs, extfs, ftp, fish, <b>luafs</b>
  ...
  Internal editor:            yes
  Diff viewer:                yes
  Support for charset:        yes
  Search type:                glib-regexp
  <b>Lua support:</b>               <b>yes (Lua 5.2)</b>
</pre>

Pay attention to the last line, which in this case shows that everything
went fine.

'configure' searches for Lua engines in this order: LuaJIT, Lua 5.3, Lua
5.2, Lua 5.1.

You may explicitly specify the engine to use using `--with-lua=ENGINE`,
where ENGINE is one of "luajit", "lua5.3", "lua5.2", "lua5.1":

    @plain
    $ ./configure --with-lua=lua5.1

In fact, ENGINE can be the name of any Lua library registered with
pkg-config. Do:

    @plain
    $ pkg-config --list-all | grep lua

to see the available libraries. This is the first thing you'll want to
do when trying to troubleshoot: this will tell you if a Lua engine is
indeed installed, and whether your distribution uses some
non-conventional name for it. (If your Lua isn't registered with
pkg-config, see the section @{~#without pkg-config}.)

## Step 5: Compiling and installing MC

Next, run make:

    @plain
    $ make

If it succeeds, install MC:

    @plain
    $ sudo make install

(You don't need to use 'sudo' if you configured MC with a prefix
residing inside your home folder, as demonstrated above.)

## Configuring without pkg-config

Using `--with-lua` alone only works if your Lua engine is registered with
pkg-config. This may not be the case. For example, this may not be the
case when you compile Lua yourself from the official tarball.

In such cases you need to explicitly tell configure the location
of Lua's header files and library. This is done using two variables:

- **LUA_CFLAGS** - flags to pass to the C preprocessor.
- **LUA_LIBS** - flags to pass to the linker.

Let's see a complete example.

First, let's download and compile Lua:

    @plain
    $ cd /home/mooffie
    $ wget http://www.lua.org/ftp/lua-5.3.0.tar.gz
    $ tar zxvf lua-5.3.0.tar.gz
    $ cd lua-5.3.0
    $ make linux

Ensure you now have a `liblua.a` file in `/home/mooffie/lua-5.3.0/src`.

(We don't have to do `make install` here because in this example we'll be
compiling MC against Lua's static library. Static libraries don't need
to exist on a system once the executable using them has been created.)

Now, let's configure MC:

    @plain
    $ cd /home/mooffie/mc

We'll build it in a separate folder to keep things tidier (but this is not mandatory):

    @plain
    $ mkdir build_lua && cd build_lua

Now:

    @plain
    $ ../configure --with-lua LUA_LIBS="-L/home/mooffie/lua-5.3.0/src -llua -lm -ldl" LUA_CFLAGS="-I/home/mooffie/lua-5.3.0/src"

...and, as before, pay attention to the last summary line 'configure' prints.

Finally, continue with `make` and `make install`, as demonstrated in step 5.

## Troubleshooting

If the problem is in the 'configure' stage, check the output recorded in configure.log.

If the problem is in the 'make' stage, run it with `make V=1` to see the commands actually issued.

Things to pay attention to when using the **LUA_LIBS** variable:

- Do "-llua". Do *not* do "-lliblua", nor "-llua.a", nor "-lliblua.a".

- When linking against the static Lua library, don't forget to add "-lm" and (on Linux) "-ldl".

- Do *not* do "/path/to/liblua.a". Break it down into "-L/path/to -llua"
  instead. Otherwise libtools gets confused and doesn't add this library to
  the final link command (resulting in errors like "undefined reference
  to 'luaL_newstate'".)
