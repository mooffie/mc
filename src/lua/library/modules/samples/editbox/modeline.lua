--[[

Modeline support.

Installation:

    require('samples.editbox.modeline')

Known issues:
-------------

Unfortunately, MC doesn't support "buffer local variables". MC uses
global variables. That is, when the tab size is changed for one window
("buffer"), it's changed for all current windows and for all future
windows.

This sucks. To make it suck less, this plugin unconditionally resets all
definitions to some "defaults" whenever you open a file. Then it
applies the modeline's settings (if exists).

The defaults are stored here in the function defaults(). They override
what you set in your "Editor options" dialog. If you're not comfy with
these defaults, override them in your startup scripts:

    require('samples.editbox.modeline').defaults = function()
      ...
    end

Hard tab vs soft tab
--------------------

Common editors support two TAB settings: (1) the size of the physical
TAB character. (2) the integral size that will ensue when you press the
TAB key (aka "soft tab").

In MC, the "soft tab" can be either the size of the physical character,
or half of it (a feature entitled "fake half tab"). If the modeline asks
for anything else, it won't have an effect.

More info
---------

Succinct information on modelines (with links to vim/emacs ref pages)
can be found here:

    https://www.wireshark.org/tools/modelines.html

Tips
----

- "vim: tw=76" makes the editor dim text beyond the 76'th column.

- "vim: ft=c" (or some other syntax) is useful for plain text files
  as well: you can use it to highlight headers, for example, by starting
  such lines with "#".

]]

local M = {}

M.debug_level = 1

-- A table converting emacs/vim syntax names to that of MC.
-- The keys must be in lowercase.
M.syntax_conversion = {
  cpp = 'c++',                 -- vim
  ['shell-script'] = 'shell',  -- emacs
  sh = 'shell',                -- vim
  scheme = 'lisp',
  autoconf = 'm4',
  troff = 'NROFF Source',
  apache = 'ASPX File',  -- For /etc/apache2/*. The ASPX syntax seems to be close enough.
  -- Feel free to add more, and please mail your changes to us.
}

function M.defaults()
  ui.Editbox.options.tab_size = 8
  ui.Editbox.options.fake_half_tab = true
  ui.Editbox.options.expand_tabs = false
  ui.Editbox.options.wrap_column = 72
  ui.Editbox.options.show_right_margin = false
end

local function process_modeline(edt, mod, is_emacs)

  local function has(needle)
    return mod:p_match([[\b]] .. needle)
  end

  --
  -- Step 1: Parse.
  --

  local syntax = has [[(?:ft|filetype|syn|syntax)=(\w+)]]
                 or has [[(?<!-)[Mm]ode:\s*([^\s;]+)]]  -- the look-behind is to exclude "indent-tabs-mode:"
                 or (is_emacs and has [[^[^\s;]+$]]) -- That's for "-*- perl -*-"

  local textwidth = has [[(?:tw|textwidth)=(\d+)]] or has [[fill-column:\s*(\d+)]]
  local tabstop = has [[(?:ts|tabstop)=(\d+)]] or has [[tab-width:\s*(\d+)]]
  local shiftwidth = has [[(?:sw|shiftwidth|sts|softtabstop)=(\d+)]] or has [[c-basic-offset:\s*(\d+)]]
  local expandtab = has [[((no)?(et|expandtab))\b]] or has [[indent-tabs-mode:\s*(\w+)]]

  -- Convert emacs's "t" and "nil" to vim syntax.
  if expandtab == "t" then
    expandtab = "noet"
  end
  if expandtab == "nil" then
    expandtab = "et"
  end

  if M.debug_level > 1 then
    devel.view {
      syntax = syntax,
      tabstop = tabstop,
      shiftwidth = shiftwidth,
      expandtab = expandtab,
      textwidth = textwidth,
    }
  end

  --
  -- Step 2: Apply.
  --

  if tabstop or shiftwidth then
    tabstop = tabstop or 8
    ui.Editbox.options.tab_size = tabstop

    -- MCEdit doesn't support softtabs. If, and only if, the requested
    -- softtab is half the width of tab, we can simulate it using MC's
    -- fake_half_tab feature.
    if shiftwidth then
      if tabstop / 2 == tonumber(shiftwidth) then
        ui.Editbox.options.fake_half_tab = true
      else
        ui.Editbox.options.fake_half_tab = false
      end
    end
  end

  if expandtab then
    ui.Editbox.options.expand_tabs = not (expandtab:find "^no")
  end

  if textwidth and tonumber(textwidth) > 0 then
    ui.Editbox.options.wrap_column = textwidth
    ui.Editbox.options.show_right_margin = true
  end

  if syntax then
    local canon_syntax = ui.Editbox.search_syntax(
      M.syntax_conversion[syntax:lower()] or syntax
    )
    if not canon_syntax then
      if M.debug_level > 0 then
        alert(T"modeline.lua says:\n\nUnknown syntax '%s' in the modeline":format(syntax))
      end
    else
      edt.syntax = canon_syntax
    end
  end

end

ui.Editbox.bind("<<load>>", function(edt)

  M.defaults()

  local blk = edt:sub(1,1024) .. edt:sub(-1024)
  local is_emacs = false

  local mod = blk:p_match { [[\s
                              (?:vi|vim|ex):\s*
                              (?:set?\s+)?
                              ([^\n]*)]], "x" }
  if not mod then
    mod = blk:p_match [[-\*-\s*(.*?)\s*-\*-]]
          or blk:p_match { [[Local Variables:(.*?)End:]], "s" } -- The manual page insinuates this is case sensitive.
    is_emacs = true
  end

  if mod then
    process_modeline(edt, mod, is_emacs)
  end

end)

return M
