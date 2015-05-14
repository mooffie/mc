--[[

Runs the current word through the following programs:

  * aspell -a   (to spell-check it).
  * wn          (part of WordNet; to show definition).
  * espeak      (to show how it's pronounced).

Installation:

Add the following to your startup scripts:

    ui.Editbox.bind('C-x d', function()
      require('samples.editbox.dictionary').run()
    end)

]]

local function run()

  local edt = assert(ui.current_widget("Editbox"))

  if not edt.current_word then
    abort(T"Please stand on a word")
  end

  local function runcmd(cmd)
    local f = io.popen(cmd:format(edt.current_word), "r")
    local result = f:read('*a')
    f:close()
    return result:match("^%s*(.-)%s*$")  -- trim.
  end

  local dlg = ui.Dialog(T'Word details: "%s"':format(edt.current_word))

  local wrapper = "fmt -s -w " .. (tty.get_cols() - 6)

  -- @todo: Now that we have the 'libs.speller' module we should use it instead!
  local spelling = runcmd("(echo %q | aspell -a | tail -2  | cut -d ':' -f 2 | " .. wrapper .. ") 2>&1")
  dlg:add(ui.Label(T"Spelling: %s":format(spelling == "*" and "OK" or spelling)))

  dlg:add(ui.ZLine(T"Pronunciation"))
  dlg:add(ui.HBox():add(
    ui.Label(runcmd "espeak -q -x %q 2>&1"),
    ui.Button {T"Say it!", on_click = function()
      alert(runcmd "espeak -X %q 2>&1")
    end}
  ))

  dlg:add(ui.ZLine("WordNet"))
  dlg:add(ui.Label(runcmd("(wn %q -over | " .. wrapper .. ") 2>&1")))

  dlg:run()

end

return {
  run = run,
}
