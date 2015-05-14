# Extending MC

We've seen in a previous chapter how to create a basic @{~start#first|"Hello World!"}
program by connecting (binding) our code to a key press. This
begets a question:

What are all the ways to _"connect"_, or _"plug in"_, our own code into
MC?

Or, in other words: how can we _"extend"_ MC?

We'll summarize the answer to this question here.

## Key bindings

As we've seen, we can @{keymap|bind} our code to a key:

    keymap.bind("C-x C-i y", function()
      alert("Hi!")
    end)

We can use an arbitrary long @{~mod:keymap!key-sequences|key sequence},
like in Emacs. These bindings are global: they're in effect
**everywhere** inside MC: in the file manager, in the editor, in the
viewer, in dialogs, ...

Alternatively, we can use the bind() function @{ui.bind|of a widget class}
to make the binding effective only for that widget. For example, to
trigger our code only inside the @{ui.Editbox|editor}, we'd do:

    ui.Editbox.bind("C-x z", function()
      alert(T"Hi! You're inside the editor!")
    end)

Or, for example, to trigger our code only inside the @{ui.Panel|filemanager}:

    ui.Panel.bind("C-x z", function(pnl)
      alert(T"The currently selected file is %s":format(pnl.current))
    end)

Tip: Note that none of this code contains the words "editor" or
"filemanager". Instead, we have here a **widget-based** API.

Info: You'll learn more about widgets later. Basically, widgets in MC
are just like widgets in any other environment: they're the controls you
interact with. Anything you have on your screen is a widget. Widgets,
like *objects* from other languages you're familiar with, have methods and
properties.

You may bind a function to a key that's already in use. This way you can
override or tweak a default behavior.

For example, we can override the F4 key to ask for permission before
editing huge files:

    local max_size = 5e6  -- That's 5 megabytes.

    -- Ask for confirmation before editing a huge file.
    ui.Panel.bind("f4", function(pnl)
      local filename, stat = pnl:get_current()
      if stat.size < max_size
          or prompts.confirm(T"This file is huge. You really want to edit it?")
      then
        return false -- Continue to default behavior.
      end
    end)

(For more on this, see @{~mod:keymap!binding-chain|binding chain}.)

## Event bindings

We can also bind our code to non-keyboard @{event|events}:

    ui.Editbox.bind("<<load>>", function(edt)
      alert(T"You're editing the file %s":format(edt.filename))
    end)

(See more interesting examples @{~mod:ui.Editbox#events|here} and
@{~mod:ui.Panel#events|here}.)

## Fields

You can create new @{~fields|fields} to show and sort information about
files.

## Filesystems

You can write your own @{~filesystems|filesystems}.

## Timers

Do you have a pizza in the oven? Use the @{timer} to remind you when it's ready:

    timer.set_timeout(tty.beep, 15*60*1000)  -- 15 minutes.

## Stand-alone scripts

You can use all of MC's facilities from "outside" of it. Are you writing
a shell utility? a cronjob? a UI game? Write it in @{~standalone|mcscript}!
