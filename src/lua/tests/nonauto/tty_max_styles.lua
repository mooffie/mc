--[[

There's a limit to the number of styles we can create.

This code tries to exhaust this limit. You'll have to restart MC
afterwards to get rid of these styles.

]]

ui.Editbox.bind('C-y', function(edt)
  for i = 1, 256 do
    edt:bookmark_set(i, tty.style("color" .. i))
  end
end)
