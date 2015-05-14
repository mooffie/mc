--[[

Makes the Home key jump from 1st column to 1st non-whitespace, and vice versa.

Idea taken from:

    http://www.midnight-commander.org/ticket/1480
    "Home key behavior in editor"

]]

local function on_space(edt)  -- Are we standing on a whitespace? (but not on EOL)
  return edt.current_char:match "%s" and edt.current_char ~= "\n"
end

ui.Editbox.bind("home", function(edt)
  edt:command((edt.cursor_col == 1 and on_space(edt)) and "WordRight" or "Home")
end)

ui.Editbox.bind("S-home", function(edt)
  edt:command((edt.cursor_col == 1 and on_space(edt)) and "MarkToWordEnd" or "MarkToHome")
end)

--[[

For anybody who's curious--
Here's how to implement this functionality without using command():

    ui.Editbox.bind("home", function(edt)
      if edt.cursor_xoffs == 1 then
        local indent = edt.line:match "^%s*"
        edt.cursor_xoffs = indent:len() + 1
      else
        edt.cursor_xoffs = 1
      end
    end)

    -- Those who have done their Lua homeworks know we can also do:
    --   edt.cursor_xoffs = edt.line:match "^%s*()"

]]
