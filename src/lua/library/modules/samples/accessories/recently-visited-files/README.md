"Recently visited files"
------------------------

This dialog shows files from 3 sources:

(1) Files you're currently editing. They have '*' in front.

(2) Files you're currently editing in other MC processes. They have '!' in front.

    (Shown only if you enable the 'samples.editbox.locking' module.)

(3) Files you've recently visited (that is, edited or viewed).

    (Shown only if you enable the "Save file position" option in the editor
    configuration. This keeps a files history in ~/.local/share/mc/filepos.)

You may also inject your own files to the list. See "Tips".


Keyboard
--------

The keys <up>, <down>, <pgup>, <pgdn> are forwarded to the listbox
no matter which widget has the focus. This lets you easily
browse the list even while you're typing something into the
"Quick filter" field.

CAVEAT: This feature may confuse you. It gives you an impression the
listbox has the focus and then you're caught by surprise when <home>
or <end> or find-as-you-type don't work. To make these work,
move the focus to the listbox first (by pressing <tab>).


Quick filter
------------

It does what you think it does.

CAVEAT: the string you type here is remembered and used next time you call
up this dialog. You may forget this fact and wonder why some files you're
currently editing don't show up in the list. If this bothers you, there are
two ways to solve this:

You can either instruct the app to never filter out files that are currently
being edited:

    require('samples.accessories.recently-visited-files').dont_filter_edited = true

Or you can make the app not remember the string:

    keymap.bind('M-pgup', function()
      require('samples.editbox.recently-visited-files').last_filter = nil  -- *** this does the trick! **
      require('samples.editbox.recently-visited-files').run()
    end)


Tips
----

You may provide a function to alter the file list.

For example, you may use this feature to inject all the files in
your project to the list. Or to add there the files from ~/.vim_mru_files
(Vim) or ~/.local/share/recently-used.xbel (GEdit, among others).

Here's how to alter the list to show the PIDs that have the files
locked (=edited).

    require('samples.accessories.recently-visited-files.db').alter_db = function (db)
      for _, rec in ipairs(db) do
        if rec.value.lock then
          rec[1] = rec[1] .. ' <' .. rec.value.lock.pid .. '>'
        end
      end
    end
    -- See a comment in the 'db' module explaining the structure of db.

(In combination with 'set-xterm-title' module, where the PID is shown in
the title, this can be a nice usability improvement for people
having many MC instances open simultaneously.)


Known issues
------------

When you open a document and then ask to restart Lua (when inside the
editor), you'll get an error message saying "You may not restart Lua from
a dialog, or a window, opened by Lua." This is because the functions used to
call up the editor (mc.edit() and dialog:focus()) don't "return" outright but
start an event loop. This is not a bug. To solve the problem, simply switch
out of the window and then (optionally) switch back to it (that is,
press M-{, M-}). You'll then be able to restart. Again: this is not a bug.
