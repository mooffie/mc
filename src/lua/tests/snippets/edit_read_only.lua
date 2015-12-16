--[[

Makes an editbox read-only by pressing C-n.

(Press it again to toggle.)

See also the module 'samples.editbox.access-warning', which automatically
makes the editbox read-only if you have no write access to its file.

Idea taken from:

    http://www.midnight-commander.org/ticket/83
    "editor needs read-only mode"

]]

ui.Editbox.bind('C-n', function(edt)
  require('samples.libs.editbox-read-only')  -- lazy loading.
  edt.read_only = not edt.read_only  -- toggle.
  tty.beep()
end)
