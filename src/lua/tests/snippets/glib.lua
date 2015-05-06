--[[

Colors up some GLib identifiers.

]]

ui.Editbox.bind('<<load>>', function(edt)

  if edt.syntax ~= 'C Program' and edt.syntax ~= 'C/C++ Program' then
    return
  end

  local styles = {
    typename = tty.style 'yellow',
    api      = tty.style 'magenta,,bold',
  }

  local function typ(name)  edt:add_keyword(name, styles.typename)   end
  local function api(name)  edt:add_keyword(name, styles.api)        end

  typ 'gboolean'
  typ 'gchar'
  typ 'gpointer'

  api 'g_new'
  api 'g_new0'
  api 'g_free'

end)
