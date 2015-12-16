--[[

Ticker.

Allocates an area on the screen (above or below the panels) and displays
in it the output of some shell command, or the contents of some text
file. It updates itself every X seconds. You can display more than one
ticker.

Installation:

    local ticker = require('samples.accessories.ticker')

    ticker.new {
      command = "dmesg | tail -n 4",  -- The shell command whose output provides the data.
      lines = 4,                      -- Number of lines to display.
      interval = 30*1000,             -- (default.) Update every 30 seconds.
      region = "north",               -- (default.) Or "south".
    }

the source of the data comes from the 'command' field, as shown above,
but it can also come from a 'file':

    ticker.new {
      file = "/path/to/file/to/read/data/from.txt",
      ...
    }

or you can can provide a function, 'get_data', to supply the data. For
example, here's how to implement a clock:

    ticker.new {
      get_data = function() return os.date() end,
      lines = 1,
      interval = 1*1000,  -- update the clock every second.
      region = "south",
    }

or... you can provide a function, 'update', to update the label yourself.
This is only useful if you want to do something fancy with the label:

    ticker.new {
      update = function(label)
        label.text = os.date()
        label.style = tty.style(os.time() % 2 == 1 and 'white, red' or 'white, green')
      end,
      lines = 1,
      interval = 1*1000,  -- update the clock every second.
      region = "south",
    }

To change the colors of the text, use 'style':

    ticker.new {
      ...
      style = "white, green",
      ...
    }

...or affect the default style of all tickers with:

    local ticker = require('samples.accessories.ticker')
    ticker.default_style = { color = 'magenta, black', hicolor = 'color209, color52' }

Known issues:

If you change the skin, the tickers will appear in "random" color. Restart
Lua to fix this.

]]

local docker = require('samples.libs.docker')
require('samples.ui.extlabel')

local M = {
  default_style = "help._default_",
  default_lines = 4,
  default_align = "left",
  default_region = "north",
  default_command = "dmesg | tail -n 4",
  default_interval = 30*1000,  -- How often, in milliseconds, to read the data and update the display.
}

local function get_data(opts)
  if opts.file then
    return assert(fs.read(opts.file))
  else
    local f = io.popen(opts.command)
    local output = f:read("*a")
    f:close()
    return output
  end
end

local function create_label(opts)
  return ui.ExtLabel {
    text = "-starting-",
    style = tty.style(opts.style),
    align = opts.align,
    rows = opts.lines,
  }
end

function M.new(opts)

  assert(type(opts) == 'table')

  opts.style    = opts.style    or M.default_style
  opts.lines    = opts.lines    or M.default_lines
  opts.align    = opts.align    or M.default_align
  opts.region   = opts.region   or M.default_region
  opts.command  = opts.command  or M.default_command
  opts.interval = opts.interval or M.default_interval
  opts.get_data = opts.get_data or get_data
  opts.update   = opts.update   or function (label, opts) label.text = opts.get_data(opts) end

  local label

  docker.register_widget(opts.region, function()
    label = create_label(opts)
    return label
  end)

  local function tick()
    if label then
      opts.update(label, opts)
      docker.refresh()
    end
  end

  -- set_interval() will first fire in 'opts.interval' milliseconds but we
  -- also want to fire it right now so we call tick() at the start. The reason
  -- we wrap it in queue() is because we want to postpone this first tick() too
  -- till the UI is available.
  ui.queue(function()
    tick()
    timer.set_interval(tick, opts.interval)
  end)

end

return M
