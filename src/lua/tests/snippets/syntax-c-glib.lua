--[[

Improved syntax highlighting for C.

It colors up some GLib identifiers.

]]

ui.Editbox.bind('<<load>>', function(edt)

  if edt.syntax ~= 'C Program' and edt.syntax ~= 'C/C++ Program' then
    return
  end

  local styles = {
    typename = tty.style 'yellow',
    api      = tty.style 'magenta,,bold',
    special  = tty.style 'white',
  }

  local function typename(name)  edt:add_keyword(name, styles.typename)   end
  local function api(name)       edt:add_keyword(name, styles.api)        end
  local function special(name)   edt:add_keyword(name, styles.special)    end

  typename 'gboolean'
  typename 'gchar'
  typename 'gpointer'

  api 'g_new'
  api 'g_new0'
  api 'g_free'

  special 'TRUE'
  special 'FALSE'

end)
