Why does MC need scripting?
===========================

This document, which people are encouraged to edit and contribute to,
lists some benefits of having MC support an extension language.

[note short]

Editors: This document belongs in the
[wiki](https://www.midnight-commander.org/wiki/TitleIndex).

[/note]

[note]

For brevity, this document uses the word "Lua" instead
of the language-neutral term "scripting support".

[/note]

<!-- --------------------------------------------------------------------- -->

## Intro

At first, the idea of scripting MC seems absurd. After all, MC already
supports an excellent extension language for its domain: shell
scripts. MC deals with files. You don't need JavaScript to
manipulate files.

Let's see some arguments to the contrary.

<!-- --------------------------------------------------------------------- -->

## Preventing code bloat / Lean C core

By implementing features in Lua we keep the C core lean.

With this we unburden the core maintainers of swamps of work and free
up their time to work on the important issues.


Features that could previously only be created by gurus (in C and MC's
internals) can now be created by novice programmers with but a
tiny fraction of the effort.

<!-- --------------------------------------------------------------------- -->

## No need for "gurus"

Because programming in Lua is @{~#easier|easy}, the "average Joe"
himself can customize and develop his MC.

Features that could previously only be created by gurus (in C and MC's
internals) can now be created by novice programmers with but a
tiny fraction of the effort.

<!-- --------------------------------------------------------------------- -->

## Sharing and distributing responsibilities

Since the Lua side is organized in modules, features can
be implemented and maintained by, or "outsourced" to, individuals and
groups outside MC's core team.

Because of the different nature of C and Lua, the community at
large can take greater part in contributing and maintaining code.

<!-- --------------------------------------------------------------------- -->

## Peace of mind for all

It's not uncommon for tickets to sit in the queue for years.

Many such tickets simply can't be resolved:

- Either because their solution, or their _importance_, is a matter of personal
taste;

- Or because the maintainers feel that some patches, albeit
providing some useful functionality, aren't critical enough to offset the
cost in maintenance liability that would be incurred
henceforth. "Code bloat" too comes to mind.

[indent]

This is a legitimate concern. While ignored/rejected patches
are a sad story, it would be sadder still to saddle MC's core
with more and more code.

[/indent]

This leaves many users @{3004|frustrated and embittered}.

This also, no doubt, has a toll on the maintainers, who have to
face a growing list of unresolvable tickets and fend off demands
from users.

Lua __solves this problem__ by eliminating it: code bloat is
no more, and "personal taste" is just a matter of @{require|require()}ing, or not,
a module, and customizing its settings.

<!-- --------------------------------------------------------------------- -->

## Making the C code better

Some parts of MC's C code need refactoring.

Adding scripting support will propel this much needed refactoring,
leading to better code quality.

Exposing the C code to the outside world is also likely to reveal
previously-unknown bugs in it, requiring a fix.

<!-- --------------------------------------------------------------------- -->

## Code reuse

Currently, MC is somewhat like a locked room: nothing can go out and
little can come in.

MC holds many treasures (VFS, widget library, string utilities, syntax
highlighting, etc.), but they can't be used by the world
outside. Conversely, MC can't use the many treasures of the outside world
(except in a few places, using shell commands).

By exposing MC to scripting we lift these walls.

<!-- --------------------------------------------------------------------- -->

## Tests

While it's possible to write tests @{git:tests/lib|in C}, writing them
in a scripting language is @{git:lua/tests/auto|another possibility}
and is usually easier.

**Regression tests**

Let's have an example using regression tests. These are tests in which
you compare the current behavior of the program to its previous behavior
in order to detect undesired effects of your modification to the code.

Take for example a [certain family of bugs](https://www.midnight-commander.org/ticket/2142)
in mcedit's syntax highlighting. Let's say that you've written a patch
to fix the problem. How do you know that your patch, which fixes the
problem for one syntax (say JavaScript) doesn't break other syntaxes
(say PHP or Haskell)?

The solution is simple and pleasant: Thanks to our Lua integration we
can @{git:misc/bin/htmlize|convert a source file to HTML}. So we can
create a corpus of demonstrative source files in different languages
(JavaScript, PHP, Haskell, ...) and store together with them their
correct highlighted syntax in HTML form. The task of testing your patch
would then be simple: you'd run the script that generates the HTML files
and if they now differ from the old HTML files you'd know that your
patch had undesired effects. Inspecting the HTML tells you how exactly
your patch fails.

<!-- --------------------------------------------------------------------- -->

## Parsers hell

When a feature is needed in C, a parser is often devised to support it.

MC contains around two dozen parsers, ranging from the
"Extension file" parser to the "User defined" listing mode parser.

A relatively minor problem with these parsers is that each has
different rules, requiring users to study them first and nevertheless
[often](https://github.com/MidnightCommander/mc/commit/68e813db551bc8b45d28bcfcf684f7e19da7fd2b)
[tripping](https://github.com/MidnightCommander/mc/commit/e281ca2890c2af1107205d05c9ebcebe9fec21fd)
[them](http://www.midnight-commander.org/ticket/1987#comment:4).

A more substantial problem with these parsers is that they're not
extensible. If we want to add a feature, we need to modify the parser
--often quite substantially. The effort involved, concerns about
introducing bugs, and breaking backward-compatibility may hold off,
sometimes indefinitely, the implementation of new features.

All these problems are solved by using an extension languages. Virtually
all such languages have a data structure suitable for describing a
configuration, whose literal also looks readable to non-programmers
(think Python's dictionaries, Ruby's hashes, Lua's tables, Lisp's
s-expressions, JSON, etc) and in some cases it's even possible to design
a DSL. Such data format is usually easily extensible (by adding keys to
the tables, which can be nested). For example, in the
@{git:linter.lua|linter} plugin the 'alternatives' key was added at a
late stage and didn't affect backward-compatibility.

<!-- --------------------------------------------------------------------- -->

## Configuration hell

MC's configuration is strewn over many @{~#parser|kinds} of
files, and having various problems:

- Collecting: The user can't arrange his configuration in just one place (one file, or one folder).

- Splitting: The user @{1633|can't} @{2948|split} a configuration over several files.

- Cascading: The user can't combine configuration from several files. I.e.,
you can't have a base configuration file and augment/override it
with yours. Configuration files are _mutually exclusive_.
This creates several problems:

[indent]

- if a user customizes a configuration file, he either
  @{1677|loses it on the next MC upgrade}, or it
  @{2772|becomes outdated}. This problem exists even for a basic file
  like the "extensions file".

- This poses an insurmountable problem for site administrators and
  @{1984|distributions} who want to augment the user's configuration.

[/indent]

- Combining: You can't @{3169|pull different portions} from different configurations files.

- Programming: You can't use variables or conditional sections.

An extension language solves these problems because configuration then is
executable code. Whatever can be done with code applies to
configuration as well.

<!-- --------------------------------------------------------------------- -->

## Giving new life to C patches

We've already mentioned that patches often sit in the ticket queue for years.

We've also explained that many such tickets are effectively unresolvable.

_Fortunately, scripting comes to the rescue:_

Many C patches become unnecessary: they can be rewritten in pure Lua.

Other C patches can benefit too: they can be rewritten to just
expose some functionality to Lua. They no longer need
to contain the user interaction part. Take for example
this big @{2979|bookmark manager} patch: if rewritten in Lua,
it would require adding __only about 10 lines__ to MC's C code, to support
the "frequency" field. The rest would be pure Lua.

<!-- --------------------------------------------------------------------- -->

## "Exponential growth" of features

When you add a feature to the C side, you end up having n+1 features.

When you also expose this single feature to the Lua side, you end up
having more than this one additional feature. Metaphoritcally speaking, it's
as if you now have n*n features. That's because with scripting you can
combine this feature with others. And use it to implement other, new
features.

Indeed, when one looks at the growing @{git:samples} tree
one might get the impression our Lua API is expansive. It isn't. The
"samples" scripts use a relatively small API.

In other words, "the whole is greater than the sum of its parts".

<!-- --------------------------------------------------------------------- -->

## Less bugs

C code, especially in a non trivial application like MC,
is susceptible to bugs.

Lua code has much, much less of this problem. It's not a matter of
opinion but of math: A feature implemented in 10 lines of high-level code
(Lua) has less room for bugs than the same feature implemented
in 200 lines of low-level code ( C ).

<!-- --------------------------------------------------------------------- -->

## Easier coding

Another reason it's easier to code in Lua is because we provide an API to the user.

When coding for MC in C, on the other hand, there isn't quite an API but
a series of moves one has to carry out in sequence, often depending
on one's situation (an issue addressed in @{~#better}).

<!-- --------------------------------------------------------------------- -->

## Implement features immediately

A user desiring some feature is no longer dependent on the will of
MC's maintainers to accept a patch.

<!-- --------------------------------------------------------------------- -->

## Health

Last but not least, there are health issues with MC.

The key sequences one has to repeat ad nauseam to navigate among
directories in MC can hurt people with musculoskeletal disorders (CTS,
tendinitis, tenosynovitis, etc.).

(Similar issue exists with editing files. Because of
some @{git:editbox/locking.lua|locking snafu} you can't just press F4. You
have to visit each desktop, and verify each MC process, in every terminal
tab, lest the file is already being edited, before pressing F4.)

In fact, one reason mc^2 was started was because its programmer sought a
way to relieve the stress of this keyboard humping.

When users propose @{2719|various} "outlandish" features
to solve their specific needs, they're sometimes answered with skepticism
or outright derision. Which is not surprising:
no two persons use their software the same way. One person
cannot necessarily understand another's needs and predicaments.

Scripting solves this problem by empowering the user himself to create
his very own solution, however wacky it seems to others. He no longer
needs to seek the approval or genius of others.

<!-- --------------------------------------------------------------------- -->
