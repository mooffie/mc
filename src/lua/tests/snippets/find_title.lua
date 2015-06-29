--[[

A user asked about making the Find File result/progress dialog show
the glob pattern and the search string in its title:

    http://www.midnight-commander.org/ticket/3453

Here's a hackish solution.

]]

local search_data = { content = "", glob = "", do_search_content = false }

function ui.Dialog.meta:find_label(text)
  return self:find('Label', function(l) return l.text == text end)
end

ui.Dialog.bind('<<submit>>', function(dlg)

  if dlg.text == T'Find File' then
    local lbl = dlg:find_label(T'Content:')
    if lbl then  -- it's the query box.
      search_data.content = dlg:find('Input', lbl).text
      search_data.do_search_content = dlg:find('Checkbox', lbl).checked
      search_data.glob = dlg:find('Input', assert(dlg:find_label(T'File name:'))).text
    end
  end

end)

ui.Dialog.bind('<<open>>', function(dlg)

  if dlg.text == T'Find File' then
    if not dlg:find('Input') then  -- it's the result box.
      if search_data.do_search_content then
        dlg.text = T"Find File: '%s' Content: '%s'":format(search_data.glob, search_data.content)
      else
        dlg.text = T"Find File: '%s'":format(search_data.glob)
      end
      dlg:refresh(true)  -- @todo: make Dialog:set_text redraw the dialog.
    end
  end

end)
