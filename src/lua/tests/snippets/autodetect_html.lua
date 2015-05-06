--[[

Auto-detects HTML files.

It does this by looking for a closing HTML tag in the first 1024 bytes.

This snippet was taken from the documentation for ui.Editbox.syntax.

]]

ui.Editbox.bind('<<load>>', function(edt)
  if not edt.syntax then
    if edt:sub(1,1024):find '</' then
      edt.syntax = "HTML File"
    end
  end
end)
