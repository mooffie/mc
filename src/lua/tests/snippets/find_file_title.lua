--[[

A user asked about making the Find File result/progress dialog show
the glob pattern and the search string in its title:

    http://www.midnight-commander.org/ticket/3453

Here's a solution.

]]

local search_data = nil

ui.Dialog.bind('<<submit>>', function(dlg)

  if dlg.text == T'Find File' then
    local lbl = dlg:find_label(T'Content:')
    if lbl then  -- It's the query dialog.
      search_data = {
        content = dlg:find('Input', lbl).text,
        do_search_content = dlg:find('Input', lbl).enabled,  -- Or we can do `dlg:find('Checkbox', lbl).checked`.
        glob = dlg:find('Input', assert(dlg:find_label(T'File name:'))).text,
      }
    end
  end

end)

ui.Dialog.bind('<<open>>', function(dlg)

  if dlg.text == T'Find File' and search_data then
    if not dlg:find('Input') then  -- It's the result dialog.
      if search_data.do_search_content then
        dlg.text = T"Find File: '%s' Content: '%s'":format(search_data.glob, search_data.content)
      else
        dlg.text = T"Find File: '%s'":format(search_data.glob)
      end
      dlg:refresh(true)  -- @todo: make Dialog:set_text redraw the dialog.
    end
  end

end)

-- Helper.
function ui.Dialog.meta:find_label(text)
  return self:find('Label', function(l) return l.text == text end)
end
