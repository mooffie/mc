--[[

This file contains GC-related stuff.

This is the only place (together with ui-impl.c) where we have "rocket science".

]]
--- @module ui

local ui = require("c.ui")

--[[

GARBAGE COLLECTION OVERVIEW

When widgets are garbage collected:

(1) FOR WIDGETS THAT AREN'T DIALOGS:

If a non-Dialog widget is garbage collected, and was not added yet to a
dialog, we destroy (via MSG_DESTOY) its C counterpart:

  do
    local b = new Button('hi!')
  end

(BTW: this code shows why we use a weak table: had we used a normal
table the widget wouldn't have been GC'ed and we'd be leaking memory on
both the Lua and C sides.)

If the widget, OTOH, was added to a dialog, we do nothing: the dialog
will destroy it when it itself gets destroyed.

(2) FOR DIALOG WIDGETS:

(2a) FOR MODAL DIALOGS:

When it gets garbage-collected we destroy (dlg_destroy) it:

  do
    local dlg = ...
    dlg:add(...)
    dlg:run()
  end

(Destroying the dialog also destroys all the children widgets, on the C
side.)

(2b) FOR MODALESS DIALOGS:

First, let's have a look at some common code:

  do
    local dlg = ...
    dlg.modal = false
    dlg:add(ui.Button{"click me", on_click = function() ... end })
    dlg:run()
  end

Clearly, we can't destroy the dialog when it goes out of scope: this
will destroy the Lua objects and therefore the callback for the button
(stored in the ui.Button Lua object) won't be found.

So for modaless dialog we keep a reference to them in a table. (We create
this reference in dialog:run(), by calling :fixate()) This ensures the
Lua object will be kept alive. When the underlying C dialog is destroyed,
the Lua dialog is notified (via on_desrroy() and removes itself from the
aforementioned table.

(3) FOR LONG LIVING HANDLES:

If a dialog is stored in a global variable, or in a module variable,
it's going to get GC'ed when Lua unloads. In itself there's no problem
in that. The problem is that we unload Lua *after* MC shuts off the VFS
(because VFS' shut off interacts with LuaFS), and the destructor
(dlg_destroy) for a dialog needs the VFS (for saving the history). This
will cause MC to segfault. To solve this problem we GC such dialogs
explicitly in the "core::before-vfs-shutdown" event.

]]

local function DBG(msg)
  if ui.log_level > 0 then
    devel.log(msg)
  end
end

local function DEBUG_HEADER(w, title)
  local s = (w:is_created_in_c() and "C-created " or "") ..
            (w:is_alive() and "alive" or "destroyed") .. " " .. w.widget_type
  DBG(title .. " " .. s)
end

--
-- Because you can't inherit __gc in Lua, the following __gc handlers are
-- re-installed in ui._setup_widget_class(). See comment there.
--

--
-- A __gc handler for all widgets except dialogs.
--
function ui.Widget.meta:__gc()
  DEBUG_HEADER(self, '__gc of')

  if self:is_created_in_c() then
    -- None of our business.
    return
  end

  if self:is_alive() then
    if self:get_dialog() then
      -- It's owned by a dialog. Do nothing: the dialog will destroy it.
      DBG('It is in a dialog, skipping.')
    else
      -- @FIXME: MC "bug": an WInput's MSG_DESROY handler isn't safe to use
      -- when it's not owned by a dialog because it refers to w->owner->event_group.
      if self.widget_type == "Input" then
        return
      end
      DBG(':_destroy()')
      self:_destroy()
    end
  end
end

--
-- A __gc handler for dialogs.
--
function ui.Dialog.meta:__gc()
  DEBUG_HEADER(self, '__gc of')

  if self:is_created_in_c() then
    -- None of our business.
    return
  end

  -- Please keep this handler simple: if you try to access child-widgets you
  -- may resurrect them.

  if self:is_alive() then
    self:_destroy()
  end
end

--
-- The rationale for the following is explained above (search for "before-vfs-shutdown").
--
event.bind("core::before-vfs-shutdown", function()

  DBG("!core::before-vfs-shutdown!")

  -- First, let's get rid of dialog stored in short lived variables:
  for _ = 1, 4 do
    -- For Lua 5.2 we purportedly need to call this twice. For earlier Luas we add 1 or 2 more.
    collectgarbage()
  end

  -- Now let's handle global variables:

  -- Note: we can alternatively just neutralize the __gc (by doing `ui.Dialog.meta.__gc = function() end`),
  -- but that would cause tools like Valgrind to report memory leaks.

  for _, w in pairs(debug.getregistry()["ui.weak"]) do
    -- Widgets are stored in ui.weak twice (userdata->table, table->userdata; see ui-impl.c),
    if type(w) == "table" then  -- so we pick only one of the directions.
      if w.widget_type == "Dialog" then
        w:__gc()
      end
    end
  end

  -- Have we covered all the bases? Unfortunately, no. The following code would
  -- crash MC on exit:
  --
  --   declare('t')
  --   t = setmetatable({}, { __gc = function() alert('hi!') end })
  --
  -- That's, again, because alert() uses a dialog, whose creation requires the
  -- VFS (for loading the history), which had been shut down already.

end)


--- Dialog widget.
-- @section dialog

---
-- Runs the dialog.
--
-- The dialog is displayed. An "event loop" starts which lets the user
-- interact with the dialog till it's dismissed.
--
-- **Returns:**
--
-- As a convenience, this method returns @{dialog.result}. A **nil** is
-- returned (and stored in @{dialog.result}) if the user cancels the dialog
-- (e.g., by pressing ESC).
--
-- See examples at @{button.result} (and elsewhere on this page).
--
-- [info]
--
-- **Modaless dialogs**
--
-- For modaless dialogs, @{dialog:run|:run} returns also when the user
-- switches to another dialog.
--
-- The implication is that for such dialogs you need to put your action in
-- buttons' @{button:on_click|on_click} handlers
--
-- [/info]
--
-- @method dialog:run
function ui.Dialog.meta:run(...)

  ui.__assert_dialog(self)

  if not tty.is_ui_ready() then
    error(E"You can't call dialog:run() when the UI isn't ready.", 2)
  end

  self:map_all() -- Actually add the widgets to the dialog.

  self.result = nil

  -- call the low-level:
  local success = self:_run(...)

  if success and self.result == nil then
    -- if no widget in the dialog handles the ENTER key, the dialog
    -- itself handles it to mean "successful exit". We make sure to pass this information through.
    self.result = true
  end

  if not self:get_modal() then

    if self:get_state() ~= 'closed' then
      -- The modaless dialog hasn't been closed. The user has switched to
      -- some other dialog. We need to keep a reference around to prevent
      -- the dialog from getting garbage collected and destroyed.
      self:fixate()
    end

    -- This is interface to C's dialog_switch_process_pending(). It needs
    -- to be called after running a modaless dialog.
    --
    -- Try the following:
    --
    -- * Have two modaless dialogs: the file manager and an editor.
    -- * Switch to the filemanager.
    -- * Open a Lua modaless dialog.
    -- * Switch directly to the editor.
    --
    -- If we don't call _switch_process_pending(), MC will crash (the
    -- filemanager's run_dlg loop will terminate. This is not a bug in our
    -- Lua code but some voodoo in MC's dialog switching.
    ui.Dialog._switch_process_pending()

  else

    -- If somehow this dialog got fixate()'ed (as when using dialog-drag.lua),
    -- we cancel this. There's no reason to fixate modal Lua dialogs as you
    -- always have a variable pointing to them. Fixating will cause a memory
    -- leak because they won't get GC and therefore C's dlg_destroy() won't
    -- be called.
    self:unfixate()

  end

  -- The dialog has been closed (if it was modal). We now need to redraw
  -- whatever was showing behind the dialog. For this we use tty.redraw().
  --
  -- C programmers don't need to do this because they call dlg_destroy(),
  -- which in its turn redraws the screen. But our Lua toolkit is designed
  -- such that dlg_destroy is called only in the garbage collection stage
  -- to make it possible for the programmer to read data from the widgets.
  -- The implication is that in Lua we need to call redraw() ourselves.
  tty.redraw()

  return self.result
end


--- Widget methods and properties.
-- @section widget

--[[-

Fixates a widget.

Info: This section describes a convenience method that can be used in
some special situations. It is seldom needed. Feel free to ignore this
section unless you're an advanced user.

__Introduction__

The widgets you interact with in Lua are wrappers around "real" C
widgets.

In some situations it can happen that you no longer have a Lua variable
referencing a widget you're interested in. In such cases the Lua wrapper
gets garbage collected. Usually there's no problem in that: it's the
expected behavior. A problem may arise, however, when you store some data
in the Lua wrapper: this data will be lost too.

The `fixate` method prevents the Lua wrapper from being garbage collected
as long as the underlying C widget is still alive. This means that the
next time you get your hands on a wrapper for this widget you'll get the
same old wrapper -- with your precious data on it.

__Example__

Let's have an example. Suppose you want to implement a "read only"
feature for the editor. As a first step you make `C-n` mark an editbox as
read only:

    ui.Editbox.bind('C-n', function(edt)
      alert(T'This editbox is now read-only!')
      edt.data.is_read_only = true
    end)

As the next step you reject keys that occur in such marked editboxes:

    local ESC = tty.keyname_to_keycode 'esc'

    ui.Editbox.bind('any', function(edt, kcode)
      if edt.data.is_read_only and (kcode < 256 and kcode ~= ESC) then
        tty.beep()
      else
        return false  -- Let MC handle this key.
      end
    end)

Will this work? Not quite. The read-only protection will last for a few
seconds only: The Lua wrapper carrying `data.is_read_only` will get
garbage collected at some point, and the `edt` wrapper seen at the
keyboard handler code will be a new one, which doesn't carry
`data.is_read_only`.

To fix our code we need to fixate the wrapper:

    ui.Editbox.bind('C-n', function(edt)
      alert(T'This editbox is now read-only!')
      edt.data.is_read_only = true
      edt:fixate()
    end)

Info: It's trivial to change our system to make widgets "fixated" by
default. Should we? Maybe. Maybe not. In the meantime we should observe
our users to learn what they expect of the system.

@method widget:fixate

@return The widget itself.

]]

do

  local keep_alive = {}

  function ui.Widget.meta:fixate()
    keep_alive[self] = true
    DEBUG_HEADER(self, 'fixating: ' .. tostring(self) .. ':')
    return self
  end

  -- We don't document this. End users won't need to use it.
  function ui.Widget.meta:unfixate()
    if keep_alive[self] then
      DEBUG_HEADER(self, 'un-fixating: ' .. tostring(self) .. ':')
    end
    keep_alive[self] = nil
  end

  function ui.Widget.meta:on_destroy()
    -- (Interestingly, while in Lua 5.1 this code gets executed for
    -- all widgets, in Lua 5.2+ it gets executed for fixated ones
    -- only. It happens to be what we want anyway, but it won't hurt
    -- to figure out the cause.)
    --DBG('%%% I was called.')
    self:unfixate()
  end

end
