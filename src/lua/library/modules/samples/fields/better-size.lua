--[[

MC's size field is sometimes hard to read as it doesn't put commas (or
other locale convention) in the numbers. This module fixes this.

Installation:

    require('samples.fields.better-size')

That's all.

]]

local format_size = require("utils.text").format_size

ui.Panel.register_field {
  id = "size",
  title = N"&Size",
  sort_indicator = N"sort|s",
  default_width = 8,  -- 1 larger than the official width. That's enough.
  default_align = "right",
  render = function(fname, stat, width)
    if fname == ".." then
      return T"UP--DIR"
    else
      return format_size(stat.size, width, true)
    end
  end,
  sort = "size"
}
