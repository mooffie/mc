--[[

Warns you when you don't have write access to the file you're editing.

It also makes the editbox read-only.

Installation:

    require('samples.editbox.access-warning')

]]

require('samples.ui.extlabel')
local docker = require('samples.libs.docker-editor')

docker.register_widget('south', function(dlg)

  local read_only_edt = dlg:find('Editbox', function(edt)
    return edt.filename and not fs.nonvfs_access(edt.filename, 'w')
  end)

  if read_only_edt then

    require('samples.libs.editbox-read-only')  -- Lazy-load the 'read_only' property.
    read_only_edt.read_only = true

    return ui.ExtLabel {
      text = T"Warning!\nYou don't have write permission to this file!",
      rows = 2,  -- The text is 2 lines.
      align = "center or left",
      style = tty.style('error._default_'),
    }

  end

end)
