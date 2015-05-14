--[[

Sanitizing text.

A user asks how to get rid of special characters in Input widgets.[1]

His request seems wacky, but it's actually not an uncommon scenario: we
sometimes wish to copy a file to a media whose filesystem doesn't
support special characters and we need to "sanitize" the filename first.

let's see how this can be done.

[1] Idea taken from:

    http://www.midnight-commander.org/ticket/2397
    "Auto replace wrong symbols"

]]

--
-- First, we define a sanitation function:
--
local function sanitize(s)
  -- Note: you can switch to :p_gsub() if you need the more powerful regular expressions.
  return s
    -- Let's remove some undesired characters:
    :gsub('["]', '')
    -- and convert others to spaces:
    :gsub('[:*/\\]', ' ')
    -- and some others to dashes:
    :gsub('[|]', '-')
    -- and squash spaces:
    :gsub(' +', ' ')
    -- and trim:
    :gsub('^ +', '')
    :gsub(' +$', '')
end

--
-- Next, we make Input widgets run it on, for example, 'C-c s'.
--
-- This lets us use the feature on the Rename dialog, the Mkdir one, etc.
-- It even works on the command line (under the panels).
--
ui.Input.bind('C-c s', function(ipt)
  ipt.text = sanitize(ipt.text)
end)

--
-- But the user asks for it to run automatically on the Mkdir dialog!
--
-- No sweat. Here's the solution:
--
ui.Dialog.bind('<<open>>', function(dlg)
  if dlg.text == T'Create a new Directory' then
    local ipt = assert(dlg:find('Input'))
    ipt.text = sanitize(ipt.text)
  end
end)

--
-- But what if we have gazillion of files whose filenames we need to sanitize?
-- No sweat. We can use our "Visual Rename" app to mass rename files. We
-- register our function with it:
require('samples.apps.visren.search').modifiers.sanitize = sanitize
-- Now, type ".*" into the pattern and "\{sanitize}0" into the
-- replacement sting!
--

--
-- We can also sanitize the highlighted text in the editor. This is
-- left as an exercise to the reader.
--
