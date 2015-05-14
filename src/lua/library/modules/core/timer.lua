---
-- Schedule code to run at some point in the future or in intervals.
--
-- Most of the functions here use the same name and semantics of the
-- corresponding JavaScript functions. The resemblance goes much deeper:
-- JavaScript in a browser and MC are both non-threaded applications and
-- they use exactly the same model to implement this feature: it's the
-- event loop which fires the timers. So if you're already familiar with
-- timers in JavaScript, consider yourself familiar with timers in MC as
-- well.
--
-- @module timer

local timer = require("c.timer")

------------------------------------------------------------------------------
-- A queue for storing the callbacks and the time they're scheduled to run at.

local queue = (function()

  -- Bugs in handling the queue may cause MC to waste CPU cycles, so
  -- we make the queue an opaque structure to eliminate the possibility
  -- of programmers messing with its internal structure.

  local queue = {}

  local function add(record)
    local when = record.when
    local position = #queue + 1

    for i = 1, #queue do
      if queue[i].when > when then
        position = i
        break
      end
    end

    table.insert(queue, position, record)
    timer._set_next_timeout(queue[1].when)
  end

  local function remove_by_fn(fn)
    for i = #queue, 1, -1 do
      if queue[i].fn == fn then
        table.remove(queue, i)
      end
    end
    timer._set_next_timeout(queue[1] and queue[1].when)
  end

  local function has_ready()
    return #queue > 0 and queue[1].when <= timer.now()
  end

  local function pop()
    local record = queue[1]
    table.remove(queue, 1)
    timer._set_next_timeout(queue[1] and queue[1].when)
    return record
  end

  local function show()
    devel.view(queue)
  end

  return {
    add = add,
    remove_by_fn = remove_by_fn,
    has_ready = has_ready,
    pop = pop,
    show = show,
  }

end)()

------------------------------------------------------------------------------

---
-- Schedules code to run once in the future.
--
-- Example:
--
--    -- Edit /etc/fstab in 5 seconds.
--    timer.set_timeout(function() mc.edit('/etc/fstab') end, 5000)
--
-- As in JavaScript in a browser, there's [no guarantee](http://ejohn.org/blog/how-javascript-timers-work/)
-- about the exact time your function will be called.
--
-- @param fn The function to schedule.
-- @param delay How many milliseconds in the future to schedule it to.
-- This can be zero or negative if you want to run it as soon as possible.
--
function timer.set_timeout(fn, delay)
  assert_arg_type(1, fn, "function")
  assert_arg_type(2, delay, "number")

  if delay < 1 then
    -- We get rid of negative numbers in case in the future we'll use
    -- 'unsigned' on the C side.
    --
    -- We also get rid of zero: on the very first call time.new() returns 0,
    -- and if the delay we're asking for is zero, we end up scheduling something
    -- to run at time 0 which on the C side is a sentry value meaning 'nothing
    -- is scheduled to run.'
    delay = 1
  end

  -- We floor the 'delay' to make sure it's integer. Why? Since on the C side
  -- this number is stored as an integer (say, '10'), then if on the Lua side
  -- it's kept as a float (say, '10.3'), then the C side, seeing a smaller
  -- number, is going to trigger the Lua side 0.3 time units earlier than
  -- needed (and the Lua side, seeing no ready timeout, will warn of 'Timer
  -- internal error').
  local when = timer.now() + math.floor(delay)

  queue.add({ when = when, fn = fn })
end

---
-- Cancels a pending timeout.
--
-- Note: unlike in JavaScript, here you simply pass back the closure fed
-- to @{set_interval}. (This makes implementing facilities like @{debounce}
-- trivial.)
function timer.clear_timeout(fn)
  queue.remove_by_fn(fn)
end

local function execute_ready_timeouts()
  if queue.has_ready() then
    queue.pop().fn()
  else
    alert(E"Timer internal error: nothing is ready on the queue. If you see this message, please report a bug.")
  end
end

require('internal').register_system_callback("timer::execute_ready_timeouts", execute_ready_timeouts)


---
-- Schedules code to run repeatedly.
--
-- Example:
--
--    local itrvl = timer.set_interval(function()
--                    counter.text = counter.text + 1
--                  end, 100)
--
-- The function returns an object having the following methods:
--
-- - stop() - cancels the ticking.
-- - resume() - restarts the ticking.
-- - stopped - a read-only property telling us whether it's ticking.
-- - toggle() - calls either stop() or resume().
--
-- See a complete example in @{git:ui_setinterval.lua}.
--
-- @param fn The function to schedule.
-- @param delay How many milliseconds to wait between invocations.
function timer.set_interval(fn, delay)

  local function wrapper()
    timer.set_timeout(wrapper, delay)
    fn()
  end

  local o = {

    stopped = true,

    stop = function(self)
      timer.clear_timeout(wrapper)
      self.stopped = true
      return self -- So we can do "itvl = timer.set_interval(...):stop()".
    end,

    resume = function(self)
      if self.stopped then
        timer.set_timeout(wrapper, delay)
        self.stopped = false
      end
    end,

    toggle = function(self)
      if self.stopped then self:resume() else self:stop() end
    end

  }

  o:resume()

  return o
end

---
-- A variation of `set_timeout`.
--
-- See explanation for debounce [on the internet](http://google.com/search?q=debounce+javascript).
--
-- In GUI applications it's common to perform some action as the user types
-- something. For example, you may want to update search results while the user
-- types the query. A naive approach would be to do (assuming an
-- @{~mod:ui!input:on_change|Input} widget):
--
--    query.on_change = function()
--      do_search()
--    end
--
-- However, this might make the interface sluggish. A better approach is:
--
--    query.on_change = timer.debounce(function()
--      do_search()
--    end, 500)
--
-- See another example at @{~mod:ui.Panel*ui.Panel:select-file|<<select-file>>}.
--
-- @function debounce
-- @args (fn, delay)
--
function timer.debounce(fn, delay)
  -- Hey, it turns out our set_timout(), unlike in JavaScript, doesn't
  -- accept args to pass to the function. We can very easily add that
  -- feature there, but since we've managed to write so much code without
  -- it, it proves that it's not a critical feature. The less, the better.
  -- So we implement a workaround here instead. Maybe we'll revisit this
  -- decision in the future.
  local args = {}
  local wrapper = function()
    fn(table.unpack(args))
  end
  return function(...)
    args = {...}
    timer.clear_timeout(wrapper)
    timer.set_timeout(wrapper, delay)
  end
end


function timer.show()  -- debugging.
  queue.show()
end

return timer
