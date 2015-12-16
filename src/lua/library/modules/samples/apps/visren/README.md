Visual Rename (files) / Visual Replace (editor)

Table of Contents
-----------------

- Keys
- Patterns
- Tips and tricks

KEYS
----

You can scroll the "diff" view with Control-<left/right/up/down>, and
with <PgUp>, <PgDn>.

PATTERNS
--------

Let's say we have the following files:

    draft.txt1
    draft.txt4
    draft.txt32

and we want to move the number before the extension. We'd do:

    - Pattern: (\.txt)(\d+)
    - Replace width: \2\1

which gives us:

    draft1.txt
    draft4.txt
    draft32.txt

which is fine, but not yet perfect. We prefer the numbers to have the
same width: "draft04.txt" instead of "draft4.txt", etc. To do this we'll
use a "modifier":

    - Pattern: (\.txt)(\d+)
    - Replace width: \{02d}2\1
or:
    - Replace width: \{%02d}2\1

The "02d" is our modifier. It means: do `sprintf("%02d")` on the
capture (it actually uses Lua's string.format, not C's sprintf).

You may register your own code as a modifier. Example:

    require('samples.apps.visren.search').modifiers.novowels = function(s)
      return s:gsub('[eaiou]', '')
    end

This modifier removes all vowels from a string. Therefore:

    - Pattern: .*
    - Replace width: \{novowels}0

will rename "Makefile" to "Mkfl" etc.

The following builtin modifiers are provided:

    - U               Upcase a string
    - L               Downcase a string
    - uri_decode      Convert "%28" to "(" etc.

When you specify a modifier (in "Replace with:"), one by that name is
first searched in the 'modifiers' table. If none exists, it's assumed to
be a sprintf() modifier. If sprintf() considers it to be invalid syntax,
the string "[INVALID FORMAT]" is returned.

TIPS AND TRICKS
---------------

(1) After renaming files: they'll be marked in the panel so you can call up the
    renamer again to further rename them.

(2) You can rename files within a whole tree (not just in the current directory)
    by first preparing the exhaustive file list either by doing "External
    panelize" or "Find file".

(3) You can sort files into directories + create the directories at the same
    time. E.g., if you have:

      draft101.txt
      draft120.txt
      draft230.txt
      draft231.txt

    You can

      - Pattern: .*?(\d)
      - Replace width: \100/\0

    To arrange the files into the the folders "100" and "200". The folders
    don't have to pre-exist (currently there's a limitation of one nesting;
    this will be lifted once we implement fs.mkdir_p()).

(4) **In the editor: You may mark a block before calling up Visual Replace
    to operate only on these lines.**

(5) In the editor: You can, possibly in combination with the previous trick,
    add/remove indentation or comment markers. E.g.:

    - type "^" as the pattern and "    " as the replacement string.
    - type "^    " as the pattern and "" as the replacement string.

(6) In the editor: Sometimes the app might seem sluggish when we type search
    strings. That's because, for Visual Replace, the "Global" checkbox is on
    by default. So when "Pattern" is empty it will actually match between
    *every two bytes*.

    If this bothers you, check off "Global". Or type "^" as the
    pattern: this will match just in the start of line.

    (A global empty pattern will also ruin Unicode characters in the
    display. It's not really a bug: every byte in the UTF-8 sequence will
    be shown separately.)

(7) The dialog is (by default) modaless. So you can switch to the panel or
    editor if you need to check out something there.
