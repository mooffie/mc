Screenshots
===========

As is the practice nowadays, we show you some screenshots to wet your appetite.

These screenshots demonstrate various features implemented with Lua. No C code is used.

See @{~samples|here} how to enable these features.


<!-- --------------------------------------------------------------------- -->

## Fields

You can @{~fields|write your own fields} in Lua.

[figure]

[ss:screenshots/fieldsgit.png]

[split]

* This image shows some @{git:fields/git.lua|git-related fields}. This
saves you from having to do "git status" repeatedly.

* We also see here that the __Size__ field was
@{git:better-size.lua|redefined} (again, using Lua alone) to show commas
(or some other means the locale rules dictate), to make it easier to read.

[/figure]

[tip]

Let's analyze what we see in the picture:

[expand]

The git branch name is is displayed at the bottom of the panel (it's not
a field). The working directory is dirty (we have local modifications),
which is why it's displayed in red.

The __When__, __Author__, and __Message__ fields tell us the details of the
last commit of the file. For example, `arg.c` was last committed _22 days_
ago by _Andrew_. The commit's ID (shown at the mini status) is _8c88aa01ad_.

<hr />

The __St[atus]__ field is the _realy_ useful field here (and is probably
the _only_ field you'll want displayed, especially since it has little
performance penalty). It's a two-character field showing the status of
the file (see @{git-status(1)} for the letters' meaning):

- We've modified `cons.handler.c`.
- We've renamed `help.h` to `helping.h` and also modified it.
- We've added `newfile.c` (but not yet committed it).
- We've created `output.html`, which is not tracked by git.
- The subtree under `man2hlp` too has been modified in some way, to which the `**` hints.

On the right panel: `defs.js` is ignored (by being listed in `.gitignore`),
and a few other files are not tracked by git (indicated by `??`). The working
directory there is clean (displayed in green).

[/expand]

[/tip]

<!-- --------------------------------------------------------------------- -->

## More fields; BiDi

[figure]

[ss:screenshots/fieldsmplayer.png]

[split]

* This image shows some @{git:fields/mplayer.lua|multimedia fields}. We see
the __Durat[ion]__ of videos / songs, the __Bi[trate]__ and, for videos,
the __Hei[ght]__ in pixels. These fields are sortable.

Indent: These fields are aggressively cached, so it's feasible to use them
even on slow machines.

* The __Name__ field was @{git:fields/bidi.lua|redefined} to support BiDi
languages like Arabic and Hebrew: the letters order is reversed and, for
Arabic, character shaping is performed.

[/figure]

Tip: Note the @{git:drop-shadow.lua|drop-shadow} effect for dialogs, the
@{git:dialog-icons.lua|frame icons}, and how the _Sort order_ dialog was
@{git:dialog_mover.lua|moved} away from the center to make the screenshot
more useful. This "pyrotechnic" is implemented with just a few lines of
Lua code. No "code bloat" is involved here.

<!-- --------------------------------------------------------------------- -->

## Visual Rename

[figure]

[ss:screenshots/visren.png]

[split]

Sometimes you wish to rename a bunch of files using some regexp. MC
__can__ do this but with MC it's like shooting in the dark: you don't
know the names you'll end up with till you perform the rename, and then
you may discover, to your dismay, that you'll be overwriting some files!

@{git:visren|Visual Rename} solves this by showing you, as you type, how
your files will end up. It also warns you if clashes (overwriting files)
will occur. You can also rename files down a directory tree by
"panelize"ing first.

You may even plug in your own code. No more wasting time on writing
those little shell/ruby/perl script to rename files!

<hr class="separator" />

Also note the "Panelize" button. There's a special mode that makes
Visual Rename act somewhat like a @{~#filter|filter-as-you-type} feature.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Filesystems

You can @{~filesystem|write filesystems} in Lua. The following naive code:

````
local myfs = {

  prefix = "myfs",

  readdir = function ()
    return { "one.txt", "two.txt", "three.txt" }
  end,

  file = function (_, path)
    if path == "one.txt" then
      return "Mary had a little lamb.\nHis fleece was white as snow."
    end
  end

}

fs.register_filesystem(myfs)
````

results in:

[figure]

[ss:screenshots/luafs.png]

[split]

You'll also @{git:filesystems|find bundled} filesystems for SQLite, MySQL and
MHT.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Editor

The editor too can benefit from scripting, as we'll see here.

<!-- --------------------------------------------------------------------- -->

## Speller

[figure]

[ss:screenshots/speller.png]

[split]

A basic speller can be implemented
in @{ui.Editbox:add_keyword|just 5 lines of code}.

The speller script shown here interacts with your actual speller via the
aspell / ispell / hunspell / spell binary.

[expand]

This is very different than MC's current approach of linking against a
certain C library, an approach which deprives you of the freedom to
choose a speller, and of the freedom to decide whether this feature is
actually enabled (as it's a compile-time decision).

[/expand]

Note, in the picture, that misspellings are only highlighted when they
occur in comments (and string literals). We certainly don't want
"misspellings" occurring in the main code (e.g. "g_getenv") to be
highlighted.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Linter

[figure]

[ss:screenshots/linter.png]

[split]

@{git:linter.lua|Linter} for various languages.

[/figure]


[figure]

[ss:screenshots/linter-disassembly.png]

[split]

... you can also use it to conveniently browse a disassembler's output (or
whatever other tool that's of interest to you).

[/figure]

<!-- --------------------------------------------------------------------- -->

## Visual Replace

[figure]

[ss:screenshots/visrep.png]

[split]

The _Visual Rename_ we've seen earlier also works in the editor, where
it's known as _Visual Replace_. It lets you see all the changes in
advance, making it a safe alternative to the potentially hazardous
"Replace All".

[/figure]

<!-- --------------------------------------------------------------------- -->

## Function list

[figure]

[ss:screenshots/funclist.png]

[split]

Shows a menu of your functions.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Modeline

[figure]

[ss:screenshots/modeline.png]

[split]

@{git:modeline.lua|Modeline} support.

[/figure]

<!-- --------------------------------------------------------------------- -->

## UnicodeData.txt; ruler; scrollbar

[figure]

[ss:screenshots/unicodedata-ruler-scroll.png]

[split]

We see three features here:

- The @{git:unicodedata.lua|unicodedata.lua} script shows the UTF-8 bytes,
and the appropriate line from UnicodeData.txt, of a character we're curious
about.

- There's a @{git:ruler.lua|ruler} if you need to measure distances
on the screen. It works anywhere, not just in the editor.

- There's a @{git:editbox/scrollbar.lua|scrollbar} at the left.

[/figure]

<!-- --------------------------------------------------------------------- -->

## "Actors"

[figure]

[ss:screenshots/actors-and-dictionary.png]

[split]

The idea behind the "modeline" feature --of embedding meta information in
the text-- can be used for implementing various creative ideas.

Here we've embedded the names of the characters of a novel at the start of
the text. Our @{ui.Editbox:add_keyword|"actors"} script then colors them
up. Males are in bluish color; females in pinkish.

Also shown here is our @{git:dictionary.lua} script.

[/figure]

<!-- --------------------------------------------------------------------- -->

## User Interface

We have an elegant, easy, and yet powerful API for
creating @{~interface|user interfaces}.

[figure]

[ss:screenshots/game.png]

[split]

A @{git:blocks|game}.

In this picture we also happen to be editing the source code of the
game. We can edit Lua code right inside MC and then ask it to reload the
Lua subsystem when we want to see the effects of our modified code. We
don't need to restart MC.

Notice, in the picture, several things borrowed from the JavaScript
world: @{timer.set_interval|set_interval} and
@{~mod:ui*button:on_click|on_click}. Additionally, Lua is a dynamic language, which
makes it possible to use @{ui.Custom:on_key|different styles} of
programming.

<hr class="separator" />

Also note the @{git:editbox/scrollbar.lua|scrollbar} at the left.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Creating frontends for command-line tools

[figure]

[ss:screenshots/frontend-scanimage.png]

[split]

While the command-line is gods' gift to mankind, it's sometimes a drag
having to revisit the manual pages to refresh your memory on how to run
some programs.

Dread no more! You can now create your own UI frontends. Here is one used
to @{git:scanimage.lua|scan images}.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Recently Visited Files; xterm titles

[figure]

[ss:screenshots/recently-visited-files.png]

[split]

Here's a box showing you the files @{git:recently-visited-files|you've recently edited}.

This feature saves you a _huge_ amount of keystrokes because you
no longer need to navigate among directories. There's also a
"Goto" button which makes this box an alternative to the "Directory
hotlist" box.

Files you're currently editing are marked with "*". You can switch to them
right from this box, which makes it a replacement for MC's "Screens" box.

Files edited in _other_ MC processes are marked with "!".

You can even provide your own code to alter the list. E.g., you can add
there files edited in Vim or gedit. Or you can populate it with all the
files in your project.

<hr class="separator" />

You also see here @{git:set-xterm-title.lua|alternative xterm titles}.
Note the terminal's three tabs: MC's builtin xterm titles would have
@{1364|wasted precious space}. Here we have "[M] /path/to/dir" shown for
the filemanager, and "[E] edited-file.txt" for the editor. You may
customize this. E.g., you can add the process ID to the title.

Note that we're editing the "TODO" file in the left tab. Indeed, our
_Recently visited files_ box indicates (with a "!") that this file is
being edited by another process.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Snapshots

[figure]

[ss:screenshots/snapshots.png]

[split]

Want to save the state of your panels? You have it: @{git:snapshots|snapshots}.

This feature is somewhat like tabs, and somewhat like the "Directory hotlist".

<hr class="separator" />

Note the "sb" snapshot, which doesn't record a directory (indicated by
`<none>`). We use it to easily restore a sorting order and a
custom listing format.

The "p" snapshot, on the other hand, records nothing but directory
paths (indicated by a missing `+`).

[/figure]

<!-- --------------------------------------------------------------------- -->

## Calculator

[figure]

[ss:screenshots/calculator.png]

[split]

Tired of running `irb`, `python`, `ghci`, etc. every time you need to
evaluate some formula? Sure you are.

Here's the solution. A @{git:apps/calc|calculator}.

You're not limited to math formulas: any Lua expression works.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Find-as-you-type; hotkeys; clock

[figure]

[ss:screenshots/find-as-you-type-and-hotkeys.png]

[split]

This image shows three accessories:

- As the purple arrows shows, you can
@{git:find-as-you-type.lua|search in any listbox}. Here we
demonstrate this with the Directory Hotlist dialog, but it works
anywhere.

Indent: ("broo" matches "Brooks" because the search is case insensitive
unless you type an uppercase letter. If the search string isn't found,
the "Search" box is painted in alert colors (typically red).)

- The yellow arrows demonstrate the @{git:hotlist-keys.lua|hotlist-keys}
module, which lets you associate keys with directories (or groups). You
embed key names in square brackets and then you can activate items by
pressing these keys. (The "Raw" button is a convenience button that opens
~/.config/mc/hotlist in the editor.)

- You also see a @{git:clock.lua|clock} at the top-right corner.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Docks

[figure]

[ss:screenshots/docks.png]

[split]

You can inject your own widgets into the filemanager (this is just a "by
product" of our fine user interface API).

The @{git:ticker.lua|ticker} module injects widgets that show you the output
of shell commands and have this display updated every X seconds.

In this picture we see two tickers. The top one (the reddish) shows
some RSS feeds. The bottom one (the khaki) shows a random line
from a text file (useful for people learning some [human] language and
needing to improve their vocabulary, for example).

The user can easily improvise a clock by using a ticker, but there's
@{~#clock|already one}.

<hr class="separator" />

Some other potential uses for this ability:

- A bar with extra information about the selected file or files.
- A tab bar.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Access-warning

[figure]

[ss:screenshots/access-warning.png]

[split]

We can inject widgets to the editor too. Here we use this ability 
to inject, besides a scrollbar, a @{git:access-warning.lua|label warning you}
about files you won't be able to save. It also makes the editbox read-only in
such cases.

(This label, as the scrollbar, doesn't come on top
of the text: it's docked south of it.)

[/figure]

<!-- --------------------------------------------------------------------- -->

## Scrollbar; filter-as-you-type

[figure]

[ss:screenshots/filter-scrollbar.png]

[split]

We see two feature here:

- A @{git:accessories/scrollbar.lua|scrollbar}. (If you look
very carefully you'll see that it's shown for the inactive panel too.)

Indent: Unlike MC's useless
[non-proportional](http://www.digitalmedievalist.org/journal/7/rosselliDelTurco/support/figure5.jpg) listbox scrollbar,
__this__ scrollbar is
[proportional](http://www.digitalmedievalist.org/journal/7/rosselliDelTurco/support/figure6.jpg)
(same is true for the scrollbar in the editor).

- A @{git:filter-as-you-type.lua|filter-as-you-type}
box. But you may find the panelize mode of _Visual Rename_ superior (as,
among other things, it can filter directories).

[/figure]

<!-- --------------------------------------------------------------------- -->

## Restore selection

[figure]

[ss:screenshots/restore-selection.png]

[split]

You find out that the USB stick you copied a few files to was
accidentally formatted. So you use the
@{git:restore-selection.lua|restore selection} feature to go back in time
and re-select those files.

[/figure]

<!-- --------------------------------------------------------------------- -->

## Various accessories

<a name="size-calculator"></a>

[figure]

[ss:screenshots/size-calculator.png]

[split]

Will the four files on the left, weighting "1,857,302K bytes" fit in the
"1,819" MiB free space on the right? You're not sure. Thankfully,
@{git:size-calculator.lua|Size calculator} says your files consume just
"1,813.77 MiB". Hurrey! They will fit!

[/figure]

<!-- --------------------------------------------------------------------- -->

## Screensavers

[figure]

[ss:screenshots/screensaver.png]

[split]

A @{git:screensavers/simplest.lua|screensaver} showing an analog clock
(indicating 12:38:26).

[/figure]

<!-- --------------------------------------------------------------------- -->

## Standalone mode

You can run scripts from the @{~standalone|command line}. You don't have
to be "inside" MC. Let’s see some examples.

<!-- --------------------------------------------------------------------- -->

## HTMLizer

[figure]

[ss:screenshots/htmlize1.png]

[split]

The @{git:htmlize|htmlizer} uses the syntax highlighting support of MC's
editor to convert source files to HTML.

[/figure]

<!-- --------------------------------------------------------------------- -->

## User interface

You can use the UI even in standalone mode...

[figure]

[ss:screenshots/standalone-game.png]

[split]

We've seen this game earlier. Here we see it used "outside" MC.

[/figure]

...which makes standalone mode an ideal replacement for dialog(1) and zenity(1).

<!-- --------------------------------------------------------------------- -->

More...
-------

There are many bundled useful scripts that aren't mentioned here.
@{~start|Go ahead and experiment}!


[ignore]

skip-toc

[/ignore]
