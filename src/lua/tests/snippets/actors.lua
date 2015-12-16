--[[

When you read novels you sometimes want people's names
highlighted.

Look no further :-)

With this script you can add "Actors:" lines to the first
lines of your novel's text to make that happen. Example:

   Actors: Benedict Brand Corwin Eric Julian Oberon (male)
   Actors: Deirdre Fiona Flora Llewella (female)

It's probably convenient to use this on 256 color terminals
only, where we can pick non-intrusive colors.

]]

ui.Editbox.bind('<<load>>', function(edt)

  local styles = {
    -- By specifying only the foreground color we get the default
    -- background color, which is usually (not always) the editor's
    -- background as well. You may, of course, explicitly specify
    -- the background here.
    male   = tty.style {color='yellow', hicolor='color159'}, -- Bluish
    female = tty.style {color='brown',  hicolor='color219'}, -- Pinkish
    object = tty.style {color='white',  hicolor='color186'}, -- Yellowish
    place  = tty.style {color='green',  hicolor='color120'}, -- Greenish
  }

  for line, i in edt:lines() do
    -- The following "[o]" is a trick to prevent this line from
    -- being recognized as an Actors line.
    local names, gender = line:match "Act[o]rs:(.*)%((.*)%)"
    if names then
      for name in names:gmatch "[^%s,]+" do
        edt:add_keyword(name, abortive(styles[gender], 'missing style ' .. gender), {range='all'})
      end
    end
    if i > 50 then  -- look in 50 first lines only.
      break
    end
  end

end)
