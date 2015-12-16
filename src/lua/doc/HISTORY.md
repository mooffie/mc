A short history of how the Lua support came to be
=================================================

(Editors: This is the only place where the pronoun "I/me" is used.)

A change of mind
----------------

As explained on the @{~why|wiki}, there are many reasons why one would
want to see scripting support in MC. But, at the beginning, I was not
aware of any of the issues mentioned there. At that time scripting seemed
an absurd idea to me.

Gradually I began to find some merit in scripting, till a moment came
when I decided that the idea deserved a more serious examination.

[info]

It was only very recently that I learned of MC's
[unfortunate](https://mail.gnome.org/archives/mc-devel/2014-November/msg00000.html)
[situation](http://www.midnight-commander.org/ticket/3004).
Had I known of this before, I wouldn't have had any question in my mind
about the necessity of scripting support.

[/info]

Looking for answers
-------------------

I had no idea how this scripting support would look like. Nor did I know
the effect it'd have on MC's C code.

This last point was important: beside the benefits scripting would
introduce, I needed to find out what *costs and liabilities* it'd
introduce. In MC's history one can find several failed attempts at
misguided adventurism, and I needed to know that scripting wouldn't
necessarily be yet another.

Who could I turn to to get answers?

I didn't think anybody had answers, so I decided to try a hands-on
approach: to dabble with coding a little bit, not more than a week, and
then, knowing a tad more, to approach the MC community with my
preliminary findings.

Things didn't go as planned. The projected week turned into weeks and
months; into a long process during which insights were gained.


Secrecy
-------

One thing was clear to me: I couldn't share my plan with the community.
There were several reasons:

- I'd be swamped by gazillion of "2 cent" opinions.

- An endless and fierce Jihad war over programming languages or VMs.

- Demands for over-engineering / over-designing things. The project
would either crash under the weight or never even get off the ground.
For example, support for keyboard binding has been achieved through 1
line in the C code. Had I consulted with the community instead, the
maintainers might have demanded to establish some infrastructure to
"abstract away" whatever needed abstracting, and then to abstract the
abstraction itself, taking 6 years of back-and-forth comments on the
ticket.

- Bikeshedding. I had to decide on hundreds of little issues.

- No benefit. Patches that I may propose, to fix/refactor various corners
in MC's code, would be rejected/ignored because the underlying reason for
them --scripting support-- still wasn't there, making the unmotivated
maintainers unconvinced about the necessity/usefulness of the patch.

To sum it up: to make my venture public would have killed it in its
infancy. Secrecy was the only choice.

This secrecy had a price: I could not share with others the insights I
gained.

Choosing a language / technology
--------------------------------

I didn't have a horse in the race. Lua was not the first technology I
inspected. I wasn't familiar with it before.

Lua happened to answer all my requirements:

- Written in C and has small implementation. Its source, if we wanted to,
can be easily bundled with MC. This also paves the way for using it not
just as an "extension" language but as an implementation language.

- Has a simple C API, which makes it possible for *anyone* to contribute
and help maintain. No need for gurus.

- Is a simple language you can *master* (not just learn) in one evening.
There are no gurus.

- Has a "conventional" syntax (Lisp may be the gods' gift to mankind, but
its syntax is alien to most users).

- Popularity (that is, has a large user base; we want something that's
maintained and lasting).

- Psychology: it should have a connotation of "lightweight technology"
so administrators won't hesitate to enable this feature. This is
important. There's no point in having a Lua-capable MC with this feature
disabled.

I also gave consideration to only exposing MC's functionality as GObjects
using Vala.

[info]

It's not very important to me what solution is eventually adopted. I
present a Lua solution, as I have to present something. The
community/maintainers will have their own dynamics and they may settle on
something else (if at all). I'm only afraid they'll take a years-long
road that will end in nothing.

[/info]

Results
-------

I'm now completely "sold on the idea" that MC needs to be scriptable. I
myself would even go further and replace many parts of MC with Lua code,
but this "revolutionary" view may not be appreciated by many.

My initial fears were allayed: the implementation is simple and, overall,
has little maintenance liability.

The major problem, I believe, would be a psychological one: to convince
the maintainers that "scripting" isn't an anathema to C but its
complement.


"mc^2"
------

This name appears nowhere in the code. I had to come up with a "project
name" to put on the HTML documentation. "mc^2" sprung into my mind. It
happens to have a meaning (explained in @{~why#exponential}).
