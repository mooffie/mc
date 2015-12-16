--[[

Syntax highlighting for Vala.

We hijack the C# definition, as it's a similar language, and add a few keywords.

]]

ui.Editbox.bind('<<load>>', function(edt)

  if edt.filename and edt.filename:match '%.vala$' then
    edt.syntax = "C# Program"
  else
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

  typename 'var'

  special 'owned'
  special 'unowned'

end)

--[[

Linter configuration. For ideas on how to enhance this, check out:

  - /var/lib/vim/addons/doc/syntastic.txt
  - /usr/share/vim/addons/syntax_checkers/vala/valac.vim

]]
require('samples.editbox.linter').primary_checkers['C# Program'] = {
  prog = 'valac "%s" 2>&1',
  pattern = 'vala:(%d+)'
}
