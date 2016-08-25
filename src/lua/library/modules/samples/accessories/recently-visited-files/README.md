"Recently visited files"
------------------------

This dialog lists files from 3 sources:

(1) Files you're currently editing or viewing. They have '*' or 'v',
    respectively, in front.

(2) Files you're currently editing in other MC processes. They have '!' in front.

    >> Shown only if you enable the 'samples.editbox.locking' module.

(3) Files you've recently visited (that is, edited or viewed).

    >> Shown only if you've enabled file history tracking.
       You do this as follows:

       * For the editor:
           Enable the "Save file position" option in the editor.
       * For the viewer:
           Add "mcview_remember_file_position=1" to your 'ini' file.

       This keeps a files history in ~/.local/share/mc/filepos.

You may also inject your own files to the list. See "Tips".


Keyboard
--------

The keys `<up>`, `<down>`, `<pgup>`, `<pgdn>` are forwarded to the
listbox no matter which widget has the focus. This lets you easily browse
the list even while you're typing something into the "Quick filter"
field.

CAVEAT: This feature may confuse you. It gives you an impression the
listbox has the focus and then you're caught by surprise when `<home>` or
`<end>` or find-as-you-type don't work. To make these work, move the
focus to the listbox first (by pressing `<tab>`).


Quick filter
------------

It does what you think it does.

The string you type here is remembered and used next time you call
up this dialog.

By default, files that you're currently editing or viewing (those
prefixed with "*" or "v") aren't filtered out. They always appear in the
list, even if they don't match the filter string. This is intended to
prevent a confusion: you may forget that a filter is active and wonder
why some files you're editing don't show up in the list. Doing otherwise
would also harm the effectiveness of using this dialog as a window
switcher. But if you don't like this behavior --if you want edited files
to get filtered too-- then you can turn off this feature by doing:

    require('samples.accessories.recently-visited-files').do_filter_active_files = true


The "Goto" button
-----------------

Clicking this button (or pressing its shortcut, M-g, which is easier)
takes you to the directory the file is in. This can be such a useful
feature sometimes that it deserved a special item here.


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

Another tip:

You may specify a filter string before calling up the dialog:

    keymap.bind('M-pgup', function()
      require('samples.editbox.recently-visited-files').last_filter = "project_zeta"
      require('samples.editbox.recently-visited-files').run()
    end)


Known issues
------------

When you open an editor/viewer from this dialog and then ask to restart
Lua (when inside the editor/viewer), you'll get an error message saying
"You may not restart Lua from a dialog, or a window, opened by Lua." This
is because the functions used to call up the editor/viewer (mc.edit(),
mc.view() and dialog:focus()) don't "return" outright but start an event
loop. This is not a bug. To solve the problem, simply switch out of the
window and then (optionally) switch back to it (that is, press M-{, M-}).
You'll then be able to restart. Again: this is not a bug.
