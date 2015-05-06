Notes for people reviewing the code
===================================

Code size
---------

The source code may seem big at first glance but that's because it's
laden with comments. A source file usually contains just 10% to 50% of
actual code.


Code simplicity
---------------

You don't need to be a rocket scientist to understand the C code.

The C code is simple. It's "flat". It doesn't contain big functions that
call other functions, but instead many small independent functions
that expose some C function to Lua.

(Sometimes our C functions aren't small. This happens when we need to
fight around deficient API of MC itself. This should be solved in the
future by refactoring MC's code.)


We don't modify MC's core
-------------------------

To prove our claim, that adding scripting support doesn't add
significant maintenance liabilities, we don't modify MC's core. We just
add a few lines to it.


Pushing decisions and complexity to the Lua side
------------------------------------------------

You'll notice that our C code is simple and that we're pushing
as much as possible to the Lua side. For example, LuaFS is implemented
almost entirely in Lua. Its C portion simply delegates everything to the
Lua side. We do this for several reasons:

- It's easier to experiment with ideas on the Lua side as its a higher
level language. Sometimes we aren't sure of how the API we're designing
should look like. It's easy to "change your mind" in Lua.

- This higher level language also makes it trivial to implement things
that are much harder in C. As a result, what we create in Lua is
often more powerful than what we'd create in C.

- There's no reason not to. This might seem like a grave sin to a
diehard C programmer, but Lua isn't intended just for the end-user.
We too may use it.

- Users could apply patches (bug fixes, upgrades) without compiling
the MC binary.

- Greater transparency: there's something beautiful in having the
"average Joe" browse our code and understand how the system works.

- Encouraging the community to participate: more people would feel
cozy with a high level language.


No support for the pulldown menu
--------------------------------

Currently there's no support for adding items to the pulldown menu. There's
no special reason for that: it just didn't look important enough. The
project had to be released to the public and some features just had to be
left out.


No support for...
-----------------

Beside the menu, there's also no support for plugging Lua into the "Directory
hotlist", the "user menu" and the "file extensions" mechanism.

These three features have many, many shortcomings. It's preferable, and easy,
to just write them anew in Lua. In return, thanks to Lua's dynamic nature,
we get virtually unlimited customizability and extensibility (and, of course,
break free of the current limitations).


Some things can be done differently and/or better
-------------------------------------------------

Care was taken not to look in other projects' code, in fear it'd violate
copyright issues. This was an unjustified precaution and we can
certainly revisit some decisions and see if we can borrow ideas from
other projects.


'src' vs 'lib'
--------------

Some sherlocks would point out that some of the scripting stuff should
be placed in the 'lib' tree, not in 'src'. They are right. But there are
some questions the community will have to address before we decide on the
details.


"But it crashes!"
-----------------

No, it doesn't. That is, not because of the Lua support. What you've
stumbled upon is most probably a bug in MC itself that might have been
fixed already in the "master" branch.


"But it's slow!"
----------------

No, it's not. That is, not because of Lua itself. There are a few modules
(e.g., the GIT-related ones) that execute various shell commands. To learn
more about what/when such commands are executed, enable the @{devel.log|log}.

mc^2 was developed on a slow computer (Pentium 4) and no performance
issues with MC + Lua were ever encountered, or ever been seen on the
horizon --not even with a telescope.


"I'm looking at code samples and I see that the key sequences are hardcoded! E.g., 'C-y' is in the code. So your Lua code isn't customizable! It's a sham! Let me out of here!"
---------------------------

No, no, no, no, no. You're looking at code _snippets_. Since
they serve as examples, they have to be small and complete. So the key is
hardcoded. But if you look at @{git:official-suggestions.lua} you see
that the proper way is for modules to expose functions and then in your
startup file(s) to bind these functions to keys.


"But it's old!"
---------------

At the time of this writing, the `lua` branch is based on MC 4.8.10,
which is not the latest release of MC. Rebasing it on up-to-date MC won't
be a difficult task, as our modifications to MC's core are minimal
anyway. But why bother? The updated branch of today will be outdated
tomorrow. It's an endless chase. At the moment, the purpose is to show
that there's merit in scripting. Whether we use a one-month old MC
or a one-year old is immaterial. Unless a maintainer says "I'm
inclined to accept the idea, but let's first see it on master", there'd
be no point wasting time on porting.
