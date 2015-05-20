
# Standalone mode

Sometimes you wish to run code "outside" of MC. (or "independently")

In other words, you want to be able run your scripts from the
command-line, just like you do with your Ruby/Perl/Python/whatever
scripts of yours.

Guess what? *--It's possible.*

To do this, use the 'mcscript' binary:

    @plain
    $ mcscript name_of_your_script.lua

[info]

We sometimes use the _.mcs_ extension (instead of _.lua_) for scripts
intended for mcscript. This has documentation merit only. It reminds
people that such scripts don't work under the plain `/usr/bin/lua`
interpreter (because of the API they use). It also reminds people that
this isn't _necessarily_ code you can run inside MC.

[/info]

Alternatively: begin your script with a "shebang" line, give it an
executable permission, and you'll be able to execute it directly.

Let's have an example.

## Example

Put the following in a file named "listetc":

    #!/usr/bin/env mcscript

    -- List all the directories in /etc.
    for file in fs.glob("/etc/*/") do
      print(file)
    end

...turn on this script's executable bit:

    @plain
    $ chmod +x listetc

...and run it:

    @plain
    $ ./listetc

In your script you have access to all of MC's facilities: the virtual
file system, the UI, etc.

Tip: 'mcscript' isn't really a binary. It's a symlink to the 'mc' binary,
in the same way that 'mcedit' is. Running a script by issuing
`mcscript some_script` is equivalent to issuing `mc --script some_script`.

## Having a user interface

If you want to use the UI, go ahead and do it. Upon invoking most UI
functions, the terminal will enter UI mode automatically:

    #!/usr/bin/env mcscript

    local dlg = ui.Dialog()
    local moral_person = ui.Checkbox(T"I love MC")

    dlg:add(moral_person, ui.DefaultButtons())

    if dlg:run() then
      if moral_person.checked then
        alert(T"The world needs people like you.")
      else
        alert(T"Scumbag!")
      end
    end

Tip: It is very easy to write UI programs that run both "inside" and
"outside" MC. The @{git:misc/bin} folder contains several mcscript
executables that launch the @{git:bin/calc|calculator}, the
@{git:bin/game-blocks|blocks game}, and other
@{git:bin/clock|assortments} "outside" MC.

[tip]

mcscript can be an ideal replacement for
[dialog](http://invisible-island.net/dialog/dialog.html),
[zenity](http://live.gnome.org/Zenity) and similar utilities.

So, when you write the next Damn Tiny Linux distro, think about basing
it on mcscript!

[/tip]

## Explicitly entering UI mode

Some functions, like @{prompts.alert|alert} and @{devel.view}, won't
enter @{tty.is_ui_ready|UI mode} for you: they're happy to work in
non-UI mode. If you want them to use the UI, you need to start it
yourself explicitly. You do this by calling @{ui.open}:

    #!/usr/bin/env mcscript

    ui.open()
    alert("Hi")

## Command-line arguments

You can access the command-line arguments via the global variable
@{globals.argv|argv}.
