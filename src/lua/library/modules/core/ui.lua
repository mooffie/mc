---
-- User Interface
--
-- @module ui

local ui = require("c.ui")

local append = table.insert

------------------------------------------------------------------------------

--
-- Do `require('ui').log_level = 1` in a startup script to enable
-- debugging logs. Currently only the GC mechanism uses the log.
--
ui.log_level = 0

----------------------------------- Widget -----------------------------------

--- Widget methods and properties.
-- @section widget

local WdgtMeta = ui.Widget.meta

function WdgtMeta:map(dlg)
  dlg:map_widget(self)
end

function WdgtMeta:preferred_cols()
  return self:get_cols()
end

function WdgtMeta:preferred_rows()
  return self:get_rows()
end

function WdgtMeta:set_dimensions(x, y, cols, rows)
  self:set_x(x)
  self:set_y(y)
  self:set_cols(cols)
  self:set_rows(rows)
end

function WdgtMeta:is_created_in_c()
  return rawget(self, "__created_in_c__")
end

--
-- This is the method invoked to process constructor arguments. I.e.,
-- when doing ui.Input{"whatever", prop1=x, prop2=666} this method will
-- be handed this table. When doing ui.Input("title"), it will be handed
-- this string.
--
function WdgtMeta:assign_properties(props)

  local err_improper = E"Improper invocation of constructor. Either a title or a table of properties is expected."

  if type(props) == "nil" then
    -- do nothing.
  elseif type(props) == "string" then
    self.text = props
  elseif type(props) == "table" then

    if props.get_x then
      -- Not catching this causes core dump.
      error(err_improper .. "\n" .. E"If you're trying to add widgets to a container, the syntax is container:add(w1, ...), not ui.Container(w1, ...).")
    end

    for k, v in pairs(props) do
      if k == 1 then k = "text" end
      self[k] = v
    end

  else
    error(err_improper)
  end

  return self
end

--- Layout control.
--
-- This property helps in laying out a widget, @{~interface#sizing|as explained}
-- in the user guide.
--
-- @attr widget.expandx
-- @property rw

--- Layout control.
--
-- This property helps in laying out a widget, @{~interface#sizing|as explained}
-- in the user guide.
--
-- @attr widget.expandy
-- @property rw

--- Custom user data.
--
-- A table in which you can store your own data.
--
-- See example at @{dialog:on_validate}.
--
-- [info]
--
-- There's nothing really special in this property. You can store your
-- data in however-named property, but then you'd have to use @{rawset} to
-- bypass the @{utils.magic.vbfy|typo protection}. In other words, this
-- property is just an aid letting you do:
--
--    wgt.data.help_text = "whatever"
--
-- instead of:
--
--    rawset(wgt, "help_text", "whatever")
--
-- [/info]
--
-- @attr widget.data
-- @property rw

function WdgtMeta:set_data(data)
  assert(type(data) == "table" , E"The 'data' property must be a table.")
  rawset(self, "data", data)
end

function WdgtMeta:get_data()
  local data = {}
  rawset(self, "data", data)
  return data
end

WdgtMeta.__allowed_properties = {
  on_destroy = true,
  expandx = true,
  expandy = true,
  on_init = true,
  on_post_key = true, -- Officially available to Dialog only, but the Input widget uses it to simulate on_change.
}

---
-- @section end

----------------------------------- Button -----------------------------------

---Creates a @{~#Button|Button widget}
-- @function Button
-- @args (...)

--- Button widget.
-- @section button

local BtnMeta = ui.Button.meta

-- Called when a button has been clicked.
function BtnMeta:_action()
  -- Currently we name the handler "on_click". We can very easily, if we
  -- want to, alias this name here to "action" (which happens to be a more
  -- common name in the non-JavaScript world).
  if self.on_click then
    self:on_click()
  elseif self.result ~= nil then
    self:get_dialog().result = self.result
    self:get_dialog():close()
  else
    alert(E'!--Programming error: To have this button actually do something, either\nset its on_click handler, or set its "result" peoperty to some non-nil value--!')
  end
end

--[[-
The result value for clicking this button.

Often, after @{dialog:run|running} a dialog, we're interested in
knowing which button was clicked.

While you yourself can keep a track of which button was clicked, by using
the @{button:on_click|on_click} handler, the "result" property offers a
shortcut:

When a button is clicked which has the "result" property set, the
dialog's own "@{dialog.result|result}" property gets set to this value
and the dialog is then closed.

Example:

    keymap.bind('C-f', function()

      local dlg = ui.Dialog(T"Open mode")

      dlg:add(ui.Button{T'Read', result='r'})
         :add(ui.Button{T'Write', result='w'})
         :add(ui.Button{T'Read/Write', result='rw'})

      alert(dlg:run())

      -- You'll usually do:

      --if dlg:run() then
      --  alert("I'll open the file in " .. dlg.result .. " mode")
      --end

      -- Or:

      --local mode = dlg:run()
      --if mode then
      --  alert("I'll open the file in " .. mode .. " mode")
      --end

    end)

The result property is just a shortcut for doing:

    local btn = ui.Button{T'Read/Write', on_click=function(self)
      self.dialog.result = 'rw'
      self.dialog:close()
    end}

Tip: This property's value isn't limited to strings and numbers: it can be
any complex object, including tables.

@attr button.result
@property rw
]]

BtnMeta.__allowed_properties = {
  result = true,
  on_click = true,
}

---
-- @section end

---------------------------------- Checkbox ----------------------------------

--- Creates a @{~#checkbox|Checkbox widget}
-- @function Checkbox
-- @args (...)

local CheckboxMeta = ui.Checkbox.meta

function CheckboxMeta:_action()
  if self.on_change then
    self:on_change()
  end
end

CheckboxMeta.__allowed_properties = {
  on_change = true,
}

---------------------------------- Listbox -----------------------------------

--- Creates a @{~#listbox|Listbox widget}
-- @function Listbox
-- @args (...)

--- Listbox widget.
-- @section listbox

local ListboxMeta = ui.Listbox.meta

function ListboxMeta:init()
  -- A listbox width is 12 columns by default. This is likely not to satisfy the user
  -- so we let it stretch over all the available width.
  self.expandx = true
end

function ListboxMeta:_action()
  if self.on_change then
    self:on_change()
  end
end

--- The selected item.
--
-- @attr listbox.value
-- @property rw

function ListboxMeta:get_value()
  local items = self:get_items() or {}
  local entry = items[self:get_selected_index()]

  return (type(entry) == "table") and (entry["value"] or entry[1])
                                  or   entry
end

function ListboxMeta:set_value(value)
  local items = self:get_items() or {}

  for i, entry in ipairs(items) do
    local entry_value =
                   (type(entry) == "table") and (entry["value"] or entry[1])
                                            or   entry
    if entry_value == value then
      self:set_selected_index(i)
      return
    end
  end

  -- If no such value exists, select the first item.
  self:set_selected_index(1)
end

--- Calculates the widest item.
--
--     lstbx.cols = lstbx:widest_item() + 2
--
-- @method listbox:widest_item
function ListboxMeta:widest_item()
  local max = 0
  local items = self:get_items() or {}
  for _, entry in ipairs(items) do
    local title = (type(entry) == "table") and entry[1] or entry
    max = math.max(max, tty.text_width(title))
  end
  return max
end

-- The user usually sets the selected item before the widget's size is set
-- (as the later is actually done, indirectly, when calling dlg:run()).
-- On the C side, WLisbox.top becomes incorrect once the size is set. We
-- need to cause WListbox to re-calculate WLisbox.top.
function ListboxMeta:on_init()
  local idx = self.selected_index
  if idx ~= 1 then
    self.selected_index = 1
    self.selected_index = idx
  end
end

ListboxMeta.__allowed_properties = {
  on_change = true,
}

---
-- @section end

----------------------------------- Radios -----------------------------------

--- Creates a @{~#radios|Radios widget}
-- @function Radios
-- @args (...)

--- Radios widget.
-- @section radios

local RadiosMeta = ui.Radios.meta

--- The selected item.
--
-- @attr radios.value
-- @property rw

-- Radios and Listboxes have the same api.
RadiosMeta.get_value = ListboxMeta.get_value
RadiosMeta.set_value = ListboxMeta.set_value

function RadiosMeta:_action()
  if self.on_change then
    self:on_change()
  end
end

RadiosMeta.__allowed_properties = {
  on_change = true,
}

---
-- @section end

----------------------------------- Custom -----------------------------------

ui.Custom.meta.__allowed_properties = {
  on_draw = true,
  on_key = true,
  on_hotkey = true,
  on_focus = true,
  on_unfocus = true,
  on_cursor = true,
  -- mouse:
  on_mouse_down = true,
  on_mouse_up = true,
  on_mouse_click = true,
  on_mouse_drag = true,
  on_mouse_move = true,
  on_mouse_scroll_up = true,
  on_mouse_scroll_down = true,
  on_click = true,
}

------------------------------- Dimensionable --------------------------------

-- It's the base class for pseudo widgets.

local DimensionbaleMeta = {}
DimensionbaleMeta.__index = DimensionbaleMeta

function DimensionbaleMeta:get_x()            return self.x or 0        end
function DimensionbaleMeta:get_y()            return self.y or 0        end
function DimensionbaleMeta:get_rows()         return self.rows or 0     end
function DimensionbaleMeta:get_cols()         return self.cols or 0     end

function DimensionbaleMeta:set_x(x)           self.x = x                end
function DimensionbaleMeta:set_y(y)           self.y = y                end
function DimensionbaleMeta:set_rows(rows)     self.rows = rows          end
function DimensionbaleMeta:set_cols(cols)     self.cols = cols          end

DimensionbaleMeta.preferred_cols = DimensionbaleMeta.get_cols
DimensionbaleMeta.preferred_rows = DimensionbaleMeta.get_rows

DimensionbaleMeta.set_dimensions = WdgtMeta.set_dimensions

DimensionbaleMeta.assign_properties = WdgtMeta.assign_properties

----------------------------------- Space ------------------------------------

--- Creates a Space widget.
--
-- A Space widget is just an empty rectangle on the screen. It lets us space
-- out other widgets. You can put it between or before/after widgets.
--
-- Together with the @{expandx} and @{expandy} properties it can also be used
-- to flush other widgets to the right/bottom/center. (See discussion in the
-- @{~interface|user guide}.)
--
-- @function Space
-- @args([cols[, rows])

--- Space
-- @section space

local SpaceMeta = { widget_type = "Space" }
SpaceMeta.__index = SpaceMeta

setmetatable(SpaceMeta, { __index = DimensionbaleMeta }) -- set the parent class.

function ui.Space(a, b)
  local o = { cols = (type(a) == "number") and a or 1,
              rows = (type(b) == "number") and b or 1 }
  setmetatable(o, SpaceMeta)

  -- If the user does 'ui.Space{2,3}' or 'ui.Space{cols=4, rows=7}':
  if type(a) == "table" then
    local props = a
    if props[1] then
      props.cols, props.rows = props[1], props[2]
      props[1], props[2] = nil, nil
    end
    o:assign_properties(props)
  end

  return o
end

function SpaceMeta:map(dlg)
  -- Nothing to do. It's only our dimensions that are important.
end

--------------------------------- Containers ---------------------------------

--- Containers.
--
-- Some widgets -- like @{~#groupbox|Groupbox}, Dialog, @{~#hbox|HBox},
-- @{~#vbox|VBox} -- are containers. They hold other widgets. The following
-- methods are shared by all containers.
--
-- Containers can be nested. This way you can set up
-- @{~interface#layout|complex layouts}.
--
-- @section containers

--- Adds widgets to a container.
--
-- As a convenience, this method returns the container itself; this lets you save some typing.
--
--     dlg:add(w1)
--     dlg:add(w2, w3)
--     dlg:run()
--
-- is the same as:
--
--     dlg:add(w1, w2, w3):run()
--     dlg:add(w1):add(w2):add(w3):run()
--
-- @method container:add
-- @args (widget[, ...])

--- Calculates the preferred width.
--
-- Calculates the width of the container based on its contents.
--
-- See example at `dialog:set_dimensions`.
--
-- @method container:preferred_cols

--- Calculates the preferred height.
--
-- Calculates the height of the container based on its contents.
--
-- @method container:preferred_rows

---
-- @section end

--
-- Utility functions used by containers.
--

-- Sums a property, over an array.
local function sum_prop(prop, ws)
  local sum = 0
  for _, w in ipairs(ws) do
    sum = sum + w[prop](w)
  end
  return sum
end

-- Finds the max properly, over an array.
local function max_prop(prop, ws)
  local max = 0
  for _, w in ipairs(ws) do
    local v = w[prop](w)
    if v > max then
      max = v
    end
  end
  return max
end

-- Adjusts widgets' position, over an array.
local function shift_xy(ws, x, y)
  for _, w in ipairs(ws) do
    w:set_x(w:get_x()+x)
    w:set_y(w:get_y()+y)
  end
end

------------------------------------ HBox ------------------------------------

--- Creates an @{~#hbox|HBox container}
-- @function HBox
-- @args (...)

--- HBox container.
--
-- An HBox is a @{~#containers|container} that helps you to
-- @{~interface#layout|layout widgets}. You add widgets to it using its
-- @{add|:add()} method.
--
-- @section hbox

local HBoxMeta = { widget_type = "HBox" }
HBoxMeta.__index = HBoxMeta

setmetatable(HBoxMeta, { __index = DimensionbaleMeta }) -- set the parent class.

--- The horizontal gap between child widgets.
-- By default it is 1 (one space character).
--
-- @attr hbox.gap
-- @property rw
function ui.HBox(props)
  local o = { children = {}, gap = 1 }
  setmetatable(o, HBoxMeta)
  return o:assign_properties(props)
end

function HBoxMeta:add(...)
  for _, w in ipairs {...} do
    assert(type(w) == "table" and w.set_dimensions, E"You're trying to add a non-widget to a container.")
    append(self.children, w)
  end
  return self
end

function HBoxMeta:preferred_cols()
  return sum_prop('preferred_cols', self.children) + (#self.children - 1) * self.gap
end

function HBoxMeta:preferred_rows()
  return max_prop('preferred_rows', self.children)
end


local filter = require("utils.table").filter

local function calculate_expand_amounts(extra_space, expandables)

  if extra_space <= 0 or #expandables == 0 then
    return {}
  end

  -- How many columns/rows to add to each widget, on average:
  local average_to_add = math.ceil(extra_space / #expandables)
  -- From how many widgets to subtract 1 unit to even things up:
  local to_remove = (average_to_add * #expandables) - extra_space

  local amounts = {}
  for i, w in ipairs(expandables) do
    amounts[w] = average_to_add
    if i <= to_remove then
      amounts[w] = amounts[w] - 1
    end
  end

  return amounts

end

function HBoxMeta:layout()

  local expand_amounts = calculate_expand_amounts(
                              self:get_cols() - self:preferred_cols(),
                              filter(self.children, function(w) return w.expandx end)
                            )

  local x = 0
  for i, w in ipairs(self.children) do

    w:set_dimensions(
      x,
      0,
      w:preferred_cols() + (expand_amounts[w] or 0),
      w.expandy and self:get_rows() or w:preferred_rows()
    )

    x = x + w:get_cols() + self.gap
  end

end

function HBoxMeta:map(dlg)
  self:layout()
  shift_xy(self.children, self:get_x(), self:get_y())
  for _, w in ipairs(self.children) do
    w:map(dlg)
  end
end

function HBoxMeta:set_enabled(bool)
  for _, w in ipairs(self.children) do
    w:set_enabled(bool)
  end
end

---
-- @section end

------------------------------------ VBox ------------------------------------

--- Creates a @{~#vbox|VBox container}
-- @function VBox
-- @args (...)

--- VBox container.
--
-- A VBox is a @{~#containers|container} that helps you to
-- @{~interface#layout|layout widgets}. You add widgets to it using its
-- @{add|:add()} method.
--
-- @section vbox

local VBoxMeta = { widget_type = "VBox" }
VBoxMeta.__index = VBoxMeta

setmetatable(VBoxMeta, { __index = DimensionbaleMeta }) -- set the parent class.

--- The vertical gap between child widgets.
-- By default it is 0 (zero screen rows).
--
-- @attr vbox.gap
-- @property rw
function ui.VBox(props)
  local o = { children = {}, gap = 0 }
  setmetatable(o, VBoxMeta)
  return o:assign_properties(props)
end

VBoxMeta.add = HBoxMeta.add
VBoxMeta.map = HBoxMeta.map
VBoxMeta.set_enabled = HBoxMeta.set_enabled

-- We let our owner (a Groupbox or a Dialog) know if we're holding a
-- solitary listbox. In this case our owner uses no padding and the
-- Listbox's scrollbar sits squat on its frame. It looks beautiful then.
function VBoxMeta:contains_solitary_listbox(...)
  return #self.children == 1 and self.children[1].widget_type == "Listbox"
end

function VBoxMeta:preferred_rows()
  return sum_prop('preferred_rows', self.children) + (#self.children - 1) * self.gap
end

function VBoxMeta:preferred_cols()
  return max_prop('preferred_cols', self.children)
end

function VBoxMeta:layout()

  local expand_amounts = calculate_expand_amounts(
                              self:get_rows() - self:preferred_rows(),
                              filter(self.children, function(w) return w.expandy end)
                            )

  local y = 0
  for _, w in ipairs(self.children) do

    w:set_dimensions(
      0,
      y,
      w.expandx and self:get_cols() or w:preferred_cols(),
      w:preferred_rows() + (expand_amounts[w] or 0)
    )

    y = y + w:get_rows() + self.gap
  end

end

---
-- @section end

---------------------------------- Groupbox ----------------------------------

--- Creates a @{~#groupbox|Groupbox widget}
-- @function Groupbox
-- @args (...)

--- Groupbox widget.
-- @section groupbox

local GrpMeta = ui.Groupbox.meta

--- Horizontal padding.
--
-- The amount of screen columns ("spaces") to reserve on the left and right
-- sides, inside the frame. Defaults to 1. If you want the child widgets to
-- almost "touch" the frame, set it to 0.
--
-- @attr groupbox.padding
-- @property rw

function GrpMeta:init()
  self.client = ui.VBox()
  self.padding = 1

  -- This is one of the few places where we enable 'expandx' by default. We
  -- do this for aesthetic reasons.
  --
  -- We do *not* do this for HBox/VBox: we don't want to force the user to memorize
  -- which widgets have a default 'expandx' and which don't. Zero surprises. Groupbox,
  -- in contrast to HBox/VBox, has a frame, showing its extent, so the user isn't surprised.
  self.expandx = true
end

function GrpMeta:add(...)
  self.client:add(...)

  -- If widgets are added to an already disabled groupbox,
  -- we disable them.
  if not self:get_enabled() then
    self:set_enabled(false) -- (it propagates down.)
  end

  return self
end

function GrpMeta:effective_padding()
  if self.client:contains_solitary_listbox() then
    return 0
  else
    return self.padding
  end
end

function GrpMeta:preferred_rows()
  local tb_border = 1  -- top/bottom border
  return self.client:preferred_rows() + 2 * tb_border
end

function GrpMeta:preferred_cols()
  local lr_border = 1 + self:effective_padding()  -- left/right border
  return math.max(
           self.client:preferred_cols() + 2 * lr_border,
           tty.text_width(self.text or "") + 2
         )
end

function GrpMeta:map(dlg)

  local tb_border = 1  -- top/bottom border
  local lr_border = 1 + self:effective_padding()  -- left/right border

  -- By this time our container has set our dimensions.
  -- Adjust the client's dimensions to occupy the inside.

  self.client:set_dimensions(
    self:get_x() + lr_border,
    self:get_y() + tb_border,
    self:get_cols() - 2 * lr_border,
    self:get_rows() - 2 * tb_border
  )

  dlg:map_widget(self)  -- Why can't we move this line up? Answer: because :map_widget() changes the relative coords into screen coords.
  self.client:map(dlg)
end

do
  local original_set_enabled = GrpMeta.set_enabled
  -- Propagate the enabled/disabled status to the descendants. This feature
  -- lets us group widgets and enable/disable them as one.
  function GrpMeta:set_enabled(bool)
    original_set_enabled(self, bool)
    self.client:set_enabled(bool)
  end
end

GrpMeta.__allowed_properties = {
  client = true,
  padding = true,
}

---
-- @section end

----------------------------------- HLine ------------------------------------

--- Creates an @{~#hline|HLine widget}
-- @function HLine
-- @args (...)

function ui.HLine.meta:init()
  self.expandx = true
end

function ui.HLine.meta:preferred_cols()
  if self:get_through() then
    --
    -- We don't let ZLine affect the preferred_cols() of its containers.
    -- That's because it resizes itself to the dialog's width (see MSG_RESIZE in
    -- lib/widgets/hline.c), which means that every call to Dialog:set_dimensions()
    -- (e.g., when resizing the terminal) would enlarge the dialog. You can see
    -- the problem if you remove this method and do:
    --
    --    keymap.bind('C-y', function()
    --      local dlg = ui.Dialog()
    --      dlg:add(ui.ZLine())
    --      dlg:add(ui.Button{'call set_dimensions', on_click=function() dlg:set_dimensions() end})
    --      dlg:run()
    --    end)
    --
    return 0
  else
    return self:get_cols()
  end
end

----------------------------------- ZLine ------------------------------------

--- Creates a ZLine widget.
--
-- A "ZLine" widget is exactly like an @{~#hline|HLine} widget except that
-- the line stretches all over the way to the dialog's frame. It's therefore
-- a bit more aesthetically pleasing than an @{~#hline|HLine}.
--
-- @function ZLine
-- @args (...)

function ui.ZLine(...)
  local hl = ui.HLine(...)
  hl:set_through(true)
  return hl
end

----------------------------------- Input ------------------------------------

--- Creates a @{~#input|Input widget}
-- @function Input
-- @args (...)

--- Input widget.
-- @section input

local InputMeta = ui.Input.meta

--- Change handler.
--
-- Called when the user modifies the input box' text.
--
-- See example in @{git:ui_inputchange.mcs}.
--
-- @method input:on_change
-- @args (self)
-- @callback
function InputMeta:set_on_change(action)
  -- Unless we use rawset() we'll end up calling this function again,
  -- due to our VB magic.
  rawset(self, 'on_change', action)

  -- The underlying C library doesn't fire an event for us, so we simulate
  -- this event using on_post_key.
  self.on_post_key = action and function(self)
    if self:get_text() ~= self.previous_text then
      self:on_change()
      self.previous_text = self:get_text()
    end
  end
end

function InputMeta:on_init()
  if self.on_change then
    -- This prevents the first keypress from triggering a spurious on_change
    -- event when the text hasn't changed; e.g., when using an arrow key.
    self.previous_text = self:get_text()
  end
end

InputMeta.__allowed_properties = {
  on_change = true,
  previous_text = true,
}

---
-- @section end

---------------------------------- Editbox -----------------------------------

--[[

  because of a limitation in ldoc, we can't place the following documentation
  in the editbox module (ui/editbox.lua) and have it appear on the 'ui' module
  page. So for the time being it's here.

]]

--- Creates an @{ui.Editbox|Editbox widget}.
--
-- You'll usually access an already-existing Editbox (as in the editor),
-- but you can create one yourself. Note, however, that since it was not
-- foreseen by the core developers that this widget would be used outside
-- the editor, it has a few problems when used in that fashion. See
-- @{git:editbox_instance.mcs}.
--
-- @function Editbox
-- @args (...)

----------------------------------- Gauge ------------------------------------

--- Creates a @{~#gauge|gauge widget}
-- @function Gauge
-- @args (...)

----------------------------------- Label ------------------------------------

--- Creates a @{~#label|label widget}
-- @function Label
-- @args (...)

----------------------------------- Dialog -----------------------------------

--- Creates a @{~#Dialog|Dialog box}
-- @function Dialog
-- @args (...)

--- Dialog widget.
-- @section dialog

local DlgMeta = ui.Dialog.meta

--- Horizontal padding.
--
-- This property behaves just like @{groupbox.padding}.
--
-- @attr dialog.padding
-- @property rw

function DlgMeta:init()
  self.client = ui.VBox()
  self.padding = 1
end

function ui.__assert_dialog(obj)  -- This isn't a 'local' function because we call it in gc.lua too.
  if type(obj) ~= "table" or obj.widget_type ~= "Dialog" then
    error(E"You must call this method on a Dialog widget only (perhaps you used '.' instead of ':' ?)", 3)
  end
end

function DlgMeta:add(...)
  ui.__assert_dialog(self)
  self.client:add(...)
  return self
end

function DlgMeta:preferred_rows()
  local tb_border = self:get_compact() and 1 or 2  -- top/bottom border
  return self.client:preferred_rows() + 2 * tb_border
end

function DlgMeta:preferred_cols()
  local lr_border = (self:get_compact() and 1 or 2) + self:effective_padding()  -- left/right border
  return math.max(
           self.client:preferred_cols(),
           tty.text_width(self:get_text() or "")
         ) + 2 * lr_border
end

function DlgMeta:effective_padding()
  if self.client:contains_solitary_listbox() then
    return 0
  else
    return self.padding
  end
end

--
-- Does the layout and the actual insertion of the C widgets to the C dialog.
--
function DlgMeta:map_all()

  if self:get_state() ~= "construct" then
    -- Protect against calling this method again after run() has
    -- been called. We don't support adding widgets after run().
    return
  end

  if self:get_x() == -1 and self:get_y() == -1 then
    self:set_dimensions()
  end

  local tb_border = self:get_compact() and 1 or 2  -- top/bottom border
  local lr_border = (self:get_compact() and 1 or 2) + self:effective_padding()  -- left/right border

  self.client:set_dimensions(
    lr_border,
    tb_border,
    self:get_cols() - 2 * lr_border,
    self:get_rows() - 2 * tb_border
  )

  self.client:map(self)

end

--- Explicitly sets the dialog's dimensions.
--
-- Call this method if you wish to explicitly position or size the
-- dialog. Usually you shouldn't be interested in this method as the
-- dialog by default will be decently positioned (centered on the screen).
--
-- You may omit `x` and/or `y`: if you do, they will be calculated such that
-- the dialog will be centered on the screen.
--
-- You may omit `cols` and/or `rows`: if you do, they will be calculated based
-- on the dialog's contents (therefore, in this case, make sure to call this
-- method after you've already added all the widgets to the dialog.)
--
--     local dlg = ui.Dialog()
--     dlg:add(ui.Label('Hi there!'))
--     -- push the dialog to the extreme right of the screen:
--     dlg:set_dimensions(tty.get_cols() - dlg:preferred_cols(), nil)
--     dlg:run()
--
-- To "maximize" a dialog, do:
--
--     dlg:set_dimensions(nil, nil, tty.get_cols(), tty.get_rows() - 2)
--
-- Tip-short: This function returns the dialog itself, thereby allowing
-- for "fluent API".
--
-- Note-short: A fifth argument, _send_msg_resize_, makes the dialog
-- receive a `MSG_RESIZE` message. For advanced users only.
--
-- @method dialog:set_dimensions
-- @args ([x], [y], [cols], [rows])

function DlgMeta:set_dimensions(x_, y_, cols_, rows_, send_msg_resize)
  self.simply_positioned = not (x_ or y_ or cols_ or rows_)

  cols_ = cols_ or self:preferred_cols()
  rows_ = rows_ or self:preferred_rows()

  -- The following duplicates (not with great fidelity) the logic in dialog.c:dlg_set_size().
  -- See ui_dialog_tryup.lua for more information.
  x_ = x_ or math.floor((tty.get_cols() - cols_) / 2)
  y_ = y_ or math.floor(math.max((tty.get_rows() - rows_) / 2 - 2, 1))

  self:_set_dimensions(x_, y_, cols_, rows_, send_msg_resize)

  -- If we change the position when the dialog is already
  -- showing, we need to repaint the dialog.
  if self:get_state() == 'active' then
    self:redraw()
    -- Note, however, that self:redraw() doesn't repaint the dialogs
    -- underneath (you can call use tty.redraw() to do that).
  end

  return self  -- Allow for "fluent API".
end

-- The default on_resize handler. It centers the dialog onscreen (unless
-- the user explicitly positioned the dialog, in which case this handler
-- does nothing.) The user may override this.
function DlgMeta:on_resize()
  if self.simply_positioned then
    self:set_dimensions()
  end
end

-- The default implementation for the on_title handler.
function DlgMeta:on_title()
  return self:get_text()
end

--- Updates the cursor on the physical screen.
--
-- This is just a shorthand for calling
-- @{redraw_cursor|:redraw_cursor()} and then @{tty.refresh}. It is
-- implemented thus:
--
--    function ui.Dialog.meta:refresh(do_redraw)
--      if do_redraw then
--        self:redraw()
--      else
--        self:redraw_cursor()
--      end
--      tty.refresh()
--    end
--
-- @method dialog:refresh
-- @args ([do_redraw])
function DlgMeta:refresh(do_redraw)
  if do_redraw then
    self:redraw()
  else
    self:redraw_cursor()
  end
  tty.refresh()
end

--[[

The following handler, which is called when the user cancels the dialog
(that is, presses ESC), fixes a subtle issue with on_valiate handlers.

Typically, the programmer would want to validate fields only if the user
has clicked some positive button. The 'result' property tells us whether
this is the case. However, pressing ESC ("canceling the dialog") in
itself doesn't set the 'result' (it gets set much later, when :run()
returns, and this happens after on_validate), not even to 'nil', and
therefore it may contain some value from a previous button press. So we
clear 'result' here, just before on_validate gets called.

See on_validate's documentation for sample code.

]]
function DlgMeta:on_cancel()
  self.result = nil
end

function DlgMeta:popup(...)
  return require('ui.popup').popup(self, ...)
end

--[[-

Finds a widget among the children.

This is a convenience interface for @{mapped_children}.

There are three criteria to search by. Each is optional, and the order
doesn't matter:

- _wtype_ - the widget type (a string).

- _predicate_ - a function testing a widget and returning
**true** if it matches.

- _from_ - either a number, meaning to return the n'th widget found, or a
widget, meaning to start searching after this widget (in the tabbing
order).

If no widget matches the criteria, **nil** is returned.

Examples:

    dlg:find('Input')  -- find the first Input widget.
    dlg:find('Input', 2)  -- find the second one.
    dlg:find('Checkbox', function(w) return w.text == T'&Fake half tabs' end)  -- find the checkbox with that label.
    dlg:find('Checkbox', dlg:find('Groupbox', 2))  -- find the first checkbox inside the second groupbox.

[note]

There's _no reason_ to use @{find} with dialogs you create in Lua because
you can simply store the desired widgets in variables, which you can
refer to later. @{find} is useful when you want to interact with dialogs
created by MC itself.

[/note]

See also @{gmatch}.

@method dialog:find
@args ([wtype,] [predicate,] [from])

]]
function DlgMeta:_find(wtype, pred, start_i, start_w, callback)

  local i = 1
  local seen = false

  for _, w in ipairs(self:get_mapped_children()) do

    local match_wtype = true
    local match_pred = true

    if wtype then
      match_wtype = (w.widget_type == wtype)
    end

    if pred then
      match_pred = match_wtype and pred(w)
    end

    if match_wtype and match_pred then
      if start_i then
        if i >= start_i then
          if not callback(w) then return end
        end
        i = i + 1
      elseif start_w then
        if seen then
          if not callback(w) then return end
        end
      else
        if not callback(w) then return end
      end
    end

    if w == start_w then
      seen = true
    end

  end

end

function DlgMeta:_find_varargs(callback, ...)

  local wtype, pred, start_i, start_w

  for _, arg in ipairs{...} do
    if type(arg) == 'string' then
      wtype = arg
    elseif type(arg) == 'number' then
      start_i = arg
    elseif type(arg) == 'table' then
      start_w = arg
    elseif type(arg) == 'function' then
      pred = arg
    elseif type(arg) ~= 'nil' then
      error(E"Invalid argument to :find()")
    end
  end

  self:_find(wtype, pred, start_i, start_w, callback)

end

function DlgMeta:find(...)
  local found = nil
  self:_find_varargs(function(w)
    found = w
    return false  -- don't look further.
  end, ...)
  return found
end

---
-- Finds widgets among the children.
--
-- Like @{find}, but iterates over _all_ the matched children.
--
-- See example at @{Dialog.screens}.
--
-- @method dialog:gmatch
-- @args ([wtype,] [predicate,] [from])
--
function DlgMeta:gmatch(...)

  local found = {}

  self:_find_varargs(function(w)
    append(found, w)
    return true  -- keep searching.
  end, ...)

  local i = 1

  return function()
    local w = found[i]
    i = i + 1
    return w
  end

end

---
-- Holds the "result" of @{dialog:run|running} the dialog. This value
-- has no meaning except the one you yourself give it.
--
-- This value is conveniently returned by @{dialog:run|:run}, but you can
-- access it directly any time.
--
-- See example at @{button.result}.
--
-- @attr dialog.result
-- @property rw

DlgMeta.__allowed_properties = {
  client = true,
  padding = true,
  result = true,
  simply_positioned = true,
  on_key = true,
  on_post_key = true,
  on_validate = true,
  on_resize = true,
  on_title = true,
  on_draw = true,
  on_help = true,
}

------------------------------- Stock buttons --------------------------------

---
-- Stock buttons.
--
-- @section

--[[-

Creates a container for buttons.

When the default OK/Cancel buttons that
@{DefaultButtons|DefaultButtons()} creates don't satisfy you, you'll
want to create the buttons yourself. You can add them to the dialog in
however manner you wish, but for uniformity and conformity it's
recommended that you use this container. It displays the buttons
centered horizontally with a line separating them from the preceding
widgets. Example:

    local dlg = ui.Dialog()

    dlg:add(ui.Label(T"The target file exists. What to do?"))

    dlg:add(ui.Buttons():add(
      ui.Button{T"&Skip", result="skip"},
      ui.Button{T"&Overwrite", result="overwrite"},
      ui.Button{T"H&elp", on_click=function() alert "hi" end},
      ui.CancelButton()
    ))

    dlg:run()

Tip: The container is not limited to just buttons. E.g., we could have
added `ui.Space()`, in the code above, before the cancel button
to separate it visually from the main buttons.

[info]

The function accepts an optional first argument that tells it whether
to drop the horizontal line. Use it when you're adding a second (or
third etc.) line of buttons:

    dlg:add(ui.Buttons():add( ...first line of buttons... ))
    dlg:add(ui.Buttons(true):add( ...second line... ))

Remember: some terminals are limited in width so do break your buttons
into several lines if there are many of them.

[/info]

Tip: This container has a method, `repack()`, which you can use to
re-layout the buttons after changing the text of one of them (and
hence its size) during runtime.

@function Buttons

]]

function ui.Buttons(skip_zline)
  local hbox = ui.HBox()
  local this = ui.VBox({ expandx = true })
  if not skip_zline then
    this:add(ui.ZLine())
  end
  this:add(
    ui.HBox({ expandx = true }):add(ui.Space { expandx = true }, hbox, ui.Space { expandx = true })
  )
  this.add = function(self, ...)
    -- delegate to the inner HBox, which contains the buttons.
    hbox:add(...)
    return self
  end
  -- If you ever change a button's title after it was mapped, call this method to re-layout things.
  this.repack = function(dlg)
    hbox:layout()
    local dlg = hbox.children[1]:get_dialog()
    shift_xy(hbox.children, dlg:get_x() + hbox:get_x(), dlg:get_y() + hbox:get_y())
    dlg:refresh(true)
  end
  return this
end

--- Creates an "OK" button.
--
-- Typically you'd use this function only if @{DefaultButtons} doesn't suit
-- your needs.
--
-- [info]
--
-- This function is implemented thus:
--
--    function ui.OkButton(props)
--      return ui.Button { T"&OK", result = "ok", type = "default" }:assign_properties(props)
--    end
--
-- [/info]
--
-- You can use the optional `props` argument to change the default label:
--
--    ui.Buttons():add(
--      ui.OkButton(T"G&o!"),
--      ui.CancelButton()
--    )
--
-- @function OkButton
-- @args ([props])

function ui.OkButton(props)
  return ui.Button { T"&OK", result = "ok", type = "default" }:assign_properties(props)
end

--- Creates a "Cancel" button.
--
-- Typically you'd use this function only if @{DefaultButtons} doesn't suit
-- your needs. See example at @{Buttons}.
--
-- [info]
--
-- This function is implemented thus:
--
--    function ui.CancelButton(props)
--      return ui.Button { T"&Cancel", result = false }:assign_properties(props)
--    end
--
-- [/info]
--
-- @function CancelButton
-- @args ([props])

function ui.CancelButton(props)
  return ui.Button { T"&Cancel", result = false }:assign_properties(props)
end

--- Creates an "Ok" and "Cancel" buttons.
--
-- You're expected to add this to any normal dialog you create. Example:
--
--    local dlg = ui.Dialog()
--
--    dlg:add(ui.Label(T"Give me the head of Alfredo Garcia!"))
--
--    dlg:add(ui.DefaultButtons())
--
--    dlg:run()
--
-- [info]
--
-- This function is implemented thus:
--
--    function ui.DefaultButtons()
--      return ui.Buttons():add(ui.OkButton(), ui.CancelButton())
--    end
--
-- [/info]
--
-- @function DefaultButtons

function ui.DefaultButtons()
  return ui.Buttons():add(ui.OkButton(), ui.CancelButton())
end

---
-- @section end

------------------------- Misc module-level functions -------------------------

---
-- Enters UI mode.
--
-- Makes the terminal enter @{tty.is_ui_ready|UI mode}, where dialogs can be
-- displayed.
--
-- This function can be called in @{~standalone|standalone} mode only. See
-- there for details.
--
-- Note: At the time of this writing, there's no `ui.close()`. That is,
-- once you enter UI mode you cannot go back to "line printer" mode.
--
function ui.open()

  if not mc.is_standalone() then
    error(E[[
You may call ui.open() only in standalone ('mcscript') mode.

If you call it because you need to use a UI-dependant function
(like tty.style()), then simply rearrange your code to call it
when the UI is ready.
]])
  end

  if not tty.is_ui_ready() then
    coroutine.yield("continue")
  end

end

--[[

Currently, we can't have ui.close().

That's because we shutdown Lua (in main.c) *before* the tty. We also
can't make Lua live much longer because the VFS shuts down even before,
and that's a subsystem the end-user surely would want to use.

To sum it up: MC's setup/shutdown code needs to be revamped first.

  function ui.close()
    if tty.is_ui_ready() then
      coroutine.yield("continue")
    end
  end

]]

require('utils.magic').setup_autoload(ui)

--[[-

Returns the current widget.

The "current widget" is the widget that has the focus, in the active
dialog box.

    -- A useful debugging aid.
    keymap.bind('F11', function()
      devel.view(ui.current_widget())
    end)

    -- An interesting way to close the active dialog.
    keymap.bind('F12', function()
      local wgt = ui.current_widget()
      if wgt then
        wgt.dialog:close()
      end
      -- Or we could just do ui.Dialog.top:close()
    end)

Tip: The widget doesn't need to have been created in Lua. There's no
distinction between widgets created in Lua to widgets created by MC itself.

The function may return **nil** if there's no current widget or if the
widget doesn't have a Lua counterpart. For example, if the pull-down
menus are active, **nil** is returned.

The optional string argument **widget_type** makes the function return
the widget only if the widget is of the specified type (otherwise **nil**
is returned). While it's trivial to do this check in Lua, it's more
efficient to have @{current_widget} do it.

[info]

When you're using the filemanager, it's the @{ui.Panel|panel} which has
the focus there and therefore is what considered the *current widget*.
The command input line, albeit showing the caret, isn't really in focus.

@{current_widget} knows about this MC idiosyncrasy and provides you with
a little convenience device: if you specify an "Input" *widget_type*, the
command input line will be returned, even though it isn't technically the
current widget.

[/info]

@function current_widget
@args ([widget_type])

]]

-- current_widget() is implemented in the 'mc' module because it knows
-- about MC's idiosyncrasies. See comment there.
ui.autoload('current_widget', {'mc', '_current_widget'})

---------------------------- Load rest of module -----------------------------

require('ui.gc')
require('ui.scaffolding')

for _, klass_name in ipairs {
      "Button", "Checkbox", "Custom", "Dialog", "Gauge", "Groupbox",
      "HLine", "Input", "Label", "Listbox", "Radios", "Viewer"
    } do
  ui._setup_widget_class(klass_name)  -- defined in 'ui.scaffolding'
end

--
-- Load widgets defined elsewhere.
--
-- Note that we can't autoload these. Nor can we autoload the 'ui' module
-- itself. Why? Because of code like the following:
--
--   * pnl = ui.current_widget()
--   * c = wgt:to_canvas()
--   * event.bind("Panel::load")   -- in contrast to `ui.Panel.bind('<<load>>')`
--
-- Such code doesn't reference ui.Panel, ui.Canvas, or even 'ui' (the last
-- case), so we don't have a lever on which the auto-loading mechanism can
-- hang.
--

require('ui.canvas')
require('ui.panel')

if conf.features.editbox then
  require('ui.editbox')
else
  -- We don't have to do the following. It's just to give a better error message
  -- than the confusing "attempt to index a nil value (field 'Editbox')".
  ui.autoload('Editbox', function()
    error(E"The Editbox support hasn't been compiled in. You must compile MC with the internal editor to use this feature.", 3)
  end)
end

--
-- Lastly, we VBfy the base class.
--
-- This is not mandatory. It just makes it possible (e.g., in
-- snippets/dialog_mover.lua) to write `wgt.x = wgt.x + 1` instead of
-- `wgt:set_x(...)`.
--
-- We do this after loading 'panel.lua' and 'editbox.lua' because if the
-- property protection is activated sooner, those two files will generate
-- exceptions (which we could solve by moving the _setup_widget_class()
-- calls to the the top of these files as it'd make the protection mechanism
-- correctly recognize those objects as metatables (see "is_instance" in
-- 'magic.lua').
--
ui._setup_widget_class("Widget")

------------------------------------------------------------------------------

return ui
