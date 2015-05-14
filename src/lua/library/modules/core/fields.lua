--[[-

Fields are the columns shown in the filemanager's panels. You can create your
own fields via Lua, as explained in depth in the @{~fields|user guide}.

To create a field you pass a table describing it to 
@{ui.Panel.register_field}:

    ui.Panel.register_field {
      id = "upname",
      title = N"Uppercased name",
      render = function(filename, ...)
        return filename:upper()
      end,
    }

[note]

**The documentation herein describes the keys in this table.**

The `fields` module itself exposes no functions to the end user.

[/note]

A field may serve either, or both, of two roles: showing some data
("rendering"), or sorting by it. The documentation herein is sectioned
into these two roles.

As a quick reference, here's a field that uses all the definition keys:

    ui.Panel.register_field {
      id = "upname",
      title = N"U&ppercased name",  -- Note: "N" instead of "T".

      -- Rendering

      render = function (filename, stat, width, info)
        return filename:upper()
      end,
      default_align = "center or left~",
      default_width = 20,
      expand = true,

      -- Sorting

      sort = function (filename1, stat1, filename2, stat2, info)
        if filename1 > filename2 then
          return 1
        elseif filename1 < filename2 then
          return -1
        else
          return 0
        end
      end,
      sort_indicator = N"sort|up",  -- Note: "N" instead of "Q".
    }


@pseudo
@module fields
]]

local fields = require('c.fields')
local internal = require('internal')

local db = {}

internal.register_system_callback("fields::render_field", function (field_id, ...)

  if not db[field_id] then
    -- While restarting, some Lua code may trigger a screen/panel redraw. The
    -- C side may then ask a previously registered Lua field which isn't yet
    -- loaded (this happens, for example, if not all the user scripts have
    -- been loaded) to draw itself. If this happens, we fail silently.
    if internal.is_restarting() then
      return 'restarting'
    end
  end

  return db[field_id].render(...)
end)

internal.register_system_callback("fields::sort_field", function (field_id, ...)
  return db[field_id].sort(...)
end)

---
-- Mandatory keys.
--
-- The following are keys that you must define.
--
-- @section

---
-- A string uniquely identifying the field.
--
-- This ID is used to refer to this field. For example, using MC's
-- "Listing mode" dialog you embed this ID in the "User defined"
-- @{ui.Panel:custom_format|format string}.
--
-- @attr id
-- @args

---
-- A human readable name for this field.
--
-- It's displayed as the column header near the top of the panel, for
-- renderable fields.
--
-- You may designate a letter in it as a hot key by preceding it with "&". This
-- allows quick activation of sortable fields, in the "Sort order" dialog.
--
-- Since typically little visual space is allotted to this string (it's cropped
-- to the width of the column), make sure to include the gist of the
-- title in the first word already.
--
-- @attr title
-- @args

---
-- Rendering.
--
-- If you want your field to be visible --that is, if it renders some
-- data-- you need only implement the @{render} function. The other, optional
-- keys tweak the field's appearance.
--
-- @section

---
-- A function to render a field.
--
-- The string (or number) this function returns will be shown in the panel.
-- (Returning nothing, or nil, is like returning an empty string.)
--
-- The arguments this function gets:
--
-- - The file's basename.
-- - The file's @{fs.StatBuf|stat},
-- - The field's width on the screen.
-- - A parcel, `info`, with the panel at `info.panel` and the panel's
--   directory at `info.dir` (which is faster than accessing `info.panel.dir`).
--
-- @attr render
-- @args

---
-- The default width for the field.
--
-- If not specified, the width defaults to 6 characters.
--
-- Info-short: The user may override this width by using the "field_id:WIDTH"
-- syntax in the @{ui.Panel:custom_format|format string}.
--
-- @attr default_width
-- @args

---
-- The default alignment for the field.
--
-- Either "left", "right", or "center or left". Append "~" (e.g., "left~") to
-- trim the contents if it's too long. See @{tty.text_align} for details. If
-- not specified, the alignment defaults to "left".
--
-- Info-short: The user may override this alignment by using a special
-- syntax in the @{ui.Panel:custom_format|format string}.
--
-- @attr default_align
-- @args

---
-- Whether to allocate any extra space in the panel to the field.
--
-- @attr expands
-- @args

---
-- Sorting
--
-- If you want your field to be sortable
-- you need only set the @{sort} key.
--
-- @section

---
-- A function to compare two files.
--
-- It should return a positive number, zero, or negative number, depending on
-- which of the two files is greater.
--
-- Or, instead of providing your own function, you can "borrow" a sort of a
-- built-in field by putting its ID here (one of: "name", "version",
-- "extension", "size", "mtime", "atime", "ctime", "inode", "unsorted").
--
-- The arguments this function gets:
--
-- - The 1st file's basename.
-- - The 1st file's @{fs.StatBuf|stat}.
-- - The 2nd file's basename.
-- - The 2nd file's @{fs.StatBuf|stat}.
-- - A parcel, `info`, described @{render|earlier}.
--
-- Note: At the time of this writing, sorting isn't fully implemented:
-- directories and normal files will be mixed, and "reverse" sort isn't
-- supported.
--
-- @attr sort
-- @args

---
-- A short string identifying the sort. It will be displayed at the panel's
-- top-left corner to remind the user of the active sort field.
--
-- @attr sort_indicator
-- @args

local DEFAULT_FIELD_WIDTH = 6

-- The following is exposed as ui.Panel.register_field()
function fields.register_field(info)
  assert(info.id, E"You must provide an 'id' key")
  assert(info.title, E"You must provide a 'title' key")

  fields._register_field(
    info.id,
    info.title,
    info.sort_indicator or "",
    info.default_width or DEFAULT_FIELD_WIDTH,
    info.expands,
    info.default_align or "left",
    info.render,
    info.sort
  )

  db[info.id] = info
end

--------------------------------- Restart-related code -----------------------------------

-- A brute-force method to seeing if a field is one of "name", "version", "size", etc.
local function is_builtin_sort(id)
  local passed = pcall(function()
    fields.register_field {
      id = "dummy",
      title = "dummy",
      sort = id,
    }
  end)
  return passed
end

event.bind("core::before-restart", function()

  -- On the C side, a panel keeps a pointer to the sort field
  -- (WPanel.sort_info.sort_field). After restarting Lua, this field may no
  -- longer be defined. Or its memory offset (in the panel.c:panel_fields
  -- array) may change.
  --
  -- So accessing such pointer will crash MC. The solution: we turn off the
  -- sort field if it's not a built-in sort (meaning: it's a Lua field).

  local rogue_field = nil

  local function unsort_panel(pnl)
    if pnl and not is_builtin_sort(pnl.sort_field) then
      rogue_field = pnl.sort_field
      pnl.sort_field = "name"
    end
  end

  unsort_panel(ui.Panel.left)
  unsort_panel(ui.Panel.right)

  if rogue_field then
    alert(E"Your sort field (%s) has been disabled. Please enable it after restart.":format(rogue_field))
  end

end)

event.bind("core::after-restart", function()

  -- On the C side, a panel keeps a list (WPanel.format) of structures (format_e)
  -- describing the fields it displays. This list is the result of parsing the
  -- "format" string.
  --
  -- During Lua's restart some fields may have been re-defined, and some
  -- removed, so we need the C side to re-build the list. We do this by
  -- re-setting the "list_type" property. This property (and a few others) calls
  -- the set_panel_formats() C function, which re-parses the format string.

  local function reparse_format(pnl)
    if pnl then
      -- We need set_panel_formats() to be called twice. When set_panel_formats()
      -- sees a missing field in the format string it reverts to the default
      -- format string ("User supplied format looks invalid, reverting to
      -- default"). But it doesn't *parse* this new string. That's why need the
      -- second call.
      pnl.list_type = pnl.list_type
      pnl.list_type = pnl.list_type
    end
  end

  reparse_format(ui.Panel.left)
  reparse_format(ui.Panel.right)

end)

------------------------------------------------------------------------------------------

return fields
