--[[

A user asked about making the Find File result/progress dialog show
the glob pattern and the search string in its title:

    http://www.midnight-commander.org/ticket/3453

Here's a solution.

]]

local search_data = nil

ui.Dialog.bind('<<submit>>', function(dlg)

  if dlg.text == T'Find File' and dlg:find_label(T'Content:') then  -- It's the query dialog.
    search_data = {
      content = dlg:find_labeled_input(T'Content:').text,
      glob = dlg:find_labeled_input(T'File name:').text,
    }
  end

end)

ui.Dialog.bind('<<open>>', function(dlg)

  if dlg.text == T'Find File' and not dlg:find_label(T'Content:') then  -- It's the result dialog.
    if search_data then
      if search_data.content ~= '' then
        dlg.text = T"Find File: '%s' Content: '%s'":format(search_data.glob, search_data.content)
      else
        dlg.text = T"Find File: '%s'":format(search_data.glob)
      end
    end
  end

end)


--
-- Helpers
--

function ui.Dialog.meta:find_label(text)
  return self:find('Label', function(l) return l.text == text end)
end

function ui.Dialog.meta:find_labeled_input(text)
  return self:find('Input', assert(self:find_label(text)))
end
