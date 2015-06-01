--[[

Frontend for the scanner.

By default it uses scanimage(1) (SANE) and convert(1) (ImageMagick) to do
its job.

Installation:

    ui.Panel.bind('C-x S', require('samples.frontends.scanimage').run)
    -- Note: it's an upper S, not lower s. Lower s triggers "Symbolic link".

Or, if you want to customize things:

    local scanner = require('samples.frontends.scanimage')
    ui.Panel.bind('C-x S', scanner.run)
    scanner.command = ...
    scanner.defaults.res = 300
    scanner.defaults.additional_convert = '-rotate 90'
    table.insert(scanner.ext, 'pdf')

]]

local M = {

  -- The command to use.
  command = "scanimage --mode %s --resolution %s %s | convert %s - %q",
  -- Tip: if the command only works as root, it's a permission problem. Check
  -- out the permission bits of the device (/dev/whatever) and make sure you're
  -- a member of its group (sudo adduser $USER whatevergroup).

  mode = {
    { T'&Color', value='Color' },
    { T'&Gray', value='Gray' },
    { T'&Lineart', value='Lineart' },
  },

  res = {
    75, {"&100", value=100}, {"1&50", value=150}, 200, 300, 600, 1200,
    -- Alas, MC doesn't support alt-digits as hotkeys, because:
    -- * lib/tty/key.c has "Convert escape-digits to F-keys".
    -- * Even if it wasn't the case, lib/widget/dialog.c does g_ascii_isalpha(),
    --   not g_ascii_isalnum().
  },

  ext = {
    { '&jpg', value='jpg' },
    { '&png', value='png' },
  },

  defaults = {
    filename = "noname",
    additional_scan = "",
    additional_convert = "",
    res = 100,
  },

}

------------------------------------------------------------------------------
--
-- Finds the last number in a string and increments it by 1:
--
--   "file54a" -> "file55a"
--
-- If no number is found, appends "2":
--
--   "file" -> "file2"
--
local function bump_number(s)
  local pos, num, tail = s:match '()(%d+)(%D*)$'
  if pos then
    return s:sub(1, pos - 1) .. (math.floor(num) + 1) .. tail
  else
    return s .. "2"
  end
end

------------------------------------------------------------------------------
--
-- Runs a command, notifying the user of any error.
--
local function run_command(original_cmd)

  -- "Successful Exit" idea stolen from linter.lua. See explanation there.
  -- We'll change this once we have io.popen3 (or io.capture3).
  local cmd = ("( %s ) 2>&1 && echo Successful Exit"):format(original_cmd)

  local f = io.popen(cmd, "r")
  local output = f:read("*a")
  f:close()

  if not output:find("Successful Exit") then
    alert(T"Could not run the command:\n\n%s\n\nOutput:\n\n%s":format(original_cmd, output))
  end

end

------------------------------------------------------------------------------
--
-- Does the actual scanning.
--
local function scan(opts)
  local output = opts.filename .. "." .. opts.ext
  if fs.stat(output) and not prompts.confirm(T"File %s exists. Overwrite?":format(output)) then
    return
  end
  local cmd = M.command:format(opts.mode, opts.res, opts.additional_scan, opts.additional_convert, output)
  prompts.please_wait(cmd, function()
    run_command(cmd)
  end)
  if ui.Panel.current then  -- We don't have a panel when running as mcscript.
    ui.Panel.current:reload()  -- Show the new file.
  end
end

------------------------------------------------------------------------------
--
-- The UI.
--
function M.run()

  local dlg = ui.Dialog{T'Scan image'}

  local filename = ui.Input{text=M.defaults.filename, cols=25, expandx=true, history='scan-filename'}

  local mode = ui.Radios()
  -- Note: We can't do: ui.Radios{items=..., value=...} because hash keys aren't ordered
  -- and we can't ensure items= executes before value=.  @todo: mention this in ldoc.
  mode.items = M.mode
  mode.value = M.defaults.mode

  local res = ui.Radios()
  res.items = M.res
  res.value = M.defaults.res

  local ext = ui.Radios()
  ext.items = M.ext
  ext.value = M.defaults.ext

  local additional_scan = ui.Input{text=M.defaults.additional_scan, expandx=true, history='scan-additional-scan'}

  local additional_convert = ui.Input{text=M.defaults.additional_convert, expandx=true, history='scan-additional-convert'}

  dlg:add(
    ui.HBox():add(
      ui.VBox{expandy=true}:add(
        ui.Groupbox(T"Output filename"):add(
          filename,
          ui.Button{T"&Bump number",on_click=function()
            filename.text = bump_number(filename.text)
            -- We don't want the focus to move to the button. That's because we
            -- want a subsequent ENTER to trigger the scanning. So we focus the
            -- filename. But this handler (on_click) is called *before* the
            -- button gets the focus, so we have to delay the re-focusing.
            timer.set_timeout(function() filename:focus() dlg:refresh() end, 0)
          end}
        ),
        ui.Groupbox(T"Extension"):add(ext),
        ui.Groupbox(T"Additional convert(1) args"):add(additional_convert),
        ui.Groupbox(T"Additional scanimage(1) args"):add(additional_scan)
      ),
      ui.VBox():add(
        ui.Groupbox(T"Mode"):add(mode),
        ui.Groupbox(T"Resolution (DPI)"):add(res)
      )
    ),
    ui.Buttons():add(
      ui.OkButton(T"G&o!"),
      ui.CancelButton()
    )
  )

  if dlg:run() then
    local opts = {
      filename = filename.text,
      additional_scan = additional_scan.text,
      additional_convert = additional_convert.text,
      ext = ext.value,
      mode = mode.value,
      res = res.value,
    }
    M.defaults = opts  -- Save for next time.
    scan(opts)
  end

end

------------------------------------------------------------------------------

return M
