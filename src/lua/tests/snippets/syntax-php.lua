--[[

Improved Syntax highlighting for PHP.

This is temporary till we fix the official 'php.syntax' to include the
keywords mentioned here.

]]

ui.Editbox.bind('<<load>>', function(edt)

  if edt.syntax ~= "PHP Program" then
    return
  end

  local styles = {
    typename = tty.style 'white',
    api      = tty.style 'yellow',
    special  = tty.style 'white',
    keyword  = tty.style 'magenta,,bold',
  }

  local function typename(name)  edt:add_keyword(name, styles.typename)   end
  local function api(name)       edt:add_keyword(name, styles.api)        end
  local function special(name)   edt:add_keyword(name, styles.special)    end
  local function kwd(name)       edt:add_keyword(name, styles.keyword)    end

  kwd 'endif'
  kwd 'endwhile'
  kwd 'endfor'
  kwd 'endforeach'
  kwd 'endswitch'

  kwd 'use'
  kwd 'namespace'

  kwd 'try'
  kwd 'catch'
  kwd 'throw'
  kwd 'finally'

  api '__construct'

  special 'public'
  special 'private'
  special 'protected'
  special 'instanceof'

  -- Typecasts and PHP7's hinting.
  typename 'string'
  typename 'int'

end)
