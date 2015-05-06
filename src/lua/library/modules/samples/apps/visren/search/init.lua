--[[

A search/replace library.

Usage example:

    local create_search_context = require('samples.apps.visren.search').create_search_context

    local ctx = create_search_context('pcre', true, false, true)

    assert(ctx:set_pattern("\\w+"))
    ctx:set_template("[\\0]")
    ctx:set_buffer("...under a tree by the river?")
    print(ctx:replace())    -- "...[under] [a] [tree] [by] [the] [river]?"

Using a "modifier":

    require('samples.apps.visren.search').modifiers.rev = function(s)
      return s:reverse()
    end

    ctx:set_template("\\{rev}0")
    print(ctx:replace())    -- "...rednu a eert yb eht revir?"

]]

local append = table.insert

local M = {}

local available_plugins = {
  'pcre',
  -- 'rex',  -- No longer used.
  'glob',
  'lua',
}

local SearchContextMeta = {}
SearchContextMeta.__index = SearchContextMeta;

---
-- Sets the search pattern.
--
-- Returns _true_ on success, or the pair (false, error_emssage) if the
-- pattern is malformed.
--
function SearchContextMeta:set_pattern(raw_pattern)
  local compiled, errmsg = self.plugin.compile_re(raw_pattern, self.is_case_sensitive, self.is_utf8)
  if compiled then
    self.pattern = compiled
    return true
  else
    self.pattern = nil
    return false, errmsg
  end
end

function SearchContextMeta:has_pattern()
  return self.pattern
end

---
-- Sets the replacement template.
--
-- This is what to replace the matches with when doing replace().
--
function SearchContextMeta:set_template(raw_template)
  self.template = self.plugin.compile_template(raw_template)
end

---
-- Sets the text on which searches will be performed.
--
function SearchContextMeta:set_buffer(raw_buffer)
  self.buffer = raw_buffer
end

---
-- Executes a find().
--
-- It behaves just like string.find().
--
function SearchContextMeta:find(idx)
  return self.plugin.find(self.buffer, self.pattern, idx)
end

---
-- Tells us whether we have a match.
--
-- This is like executing :find(), but, depending on the plugin, it could be
-- more efficient because captures aren't returned.
--
function SearchContextMeta:does_match()
  return self.plugin.does_match(self.buffer, self.pattern)
end


---------------------------- Search functionality ----------------------------

---
-- This function is, very vaguely, like gmatch()
--

function SearchContextMeta:parts_iter()
  return coroutine.wrap(function () self:parts() end)
end

function SearchContextMeta:parts()

  local s = self.buffer
  local r = self.pattern
  local is_global = self.is_global
  local plugin = self.plugin

  local function unpack_(a, b, ...)
    return a, b, {...}
  end

  local prev_stop = 0
  local prev_was_zero_length_match = false

  while true do
    local start, stop, captures = unpack_(plugin.find(s, r, prev_stop + 1 + (prev_was_zero_length_match and 1 or 0)))
    if not start then
      break
    end
    coroutine.yield(s:sub(prev_stop + 1, start - 1), false) -- till the match.
    coroutine.yield(s:sub(start, stop), true, captures) -- the match itself.
    prev_stop = stop

    -- We need to handle zero-length matches (ZLM). To understand what
    -- these are, run the following in your shell:
    --
    --   ruby -e 'print "abcd".gsub(/q*/, "[\\0]")'
    --
    -- See "Advancing After a Zero-Length Regex Match" at:
    --   http://www.regular-expressions.info/zerolength.html
    --
    -- There are three ways to cope with ZLM. We're using the "the simplest
    -- solution" mentioned in that article.
    --
    -- When we encounter a ZLM we make the next find() start one character
    -- later (otherwise we loop forever). Unfortunately, it's one *byte* really,
    -- not *character*. So we may land in the middle of a UTF-8 char. If our
    -- search-plugin is UTF-8-aware it will throw an exception. This issue (ZLM
    -- + middle of UTF-8) isn't common, so it's not worth losing sleep over.
    --
    -- Note:
    -- =====
    -- It's worth mentioning that `sed` uses the 3rd method (titled "The JGsoft
    -- engine" in that article), which is quite useful. See also:
    --   http://stackoverflow.com/questions/20744716/why-does-this-regex-run-differently-in-sed-than-in-perl-ruby/20752872
    --
    prev_was_zero_length_match = (stop < start)

    if prev_was_zero_length_match then
      -- Handle a bug in Lua 5.1: `("one"):find("a*", 100)` doesn't return nil.
      if start > s:len() then
        break
      end
    end

    if not is_global then
      break
    end
  end

  coroutine.yield(s:sub(prev_stop + 1), false) -- till the end of the string.
end

--------------------------- Replace functionality ----------------------------

M.modifiers = {

  -- Some useful "builtin" modifiers:

  U = string.upper,
  L = string.lower,
  uri_decode = function(s)
    return utils.text.transport.uri_decode(s)
  end,
}

local function exec_template(source, template, captures)

  captures[0] = source

  local function trans(modifier, ord)
    if modifier and modifier ~= "" then
      local fn = M.modifiers[modifier]
      if fn then
        local ok, s = pcall(fn, captures[ord] or "")
        return tostring(s)
      else
        local ok, s = pcall(string.format, "%" .. modifier, captures[ord] or "")
        return ok and s or "[INVALID FORMAT]"
      end
    else
      return (captures[ord] or "")
    end
  end

  local s = template

  -- We do two :gsub() because Lua's patterns aren't powerful enough. We'd better
  -- switch to regex.gsub().
  s = s:gsub('\\(%b{})(%d)', function(modifier_, ord)
    local modifier = modifier_:sub(2,-2):gsub('^%%', '')
    return trans(modifier, tonumber(ord))
  end)
  s = s:gsub('\\(%d)', function(ord)
    return trans(nil, tonumber(ord))
  end)

  return s
end

---
-- Returns a string with all matched patterns replaced by the template.
--
function SearchContextMeta:replace()
  local result = {}

  assert(self.template, E"Please set a replacement template first.")

  for sub, match, captures in self:parts_iter() do
    if match then
      append(result, exec_template(sub, self.template, captures))
    else
      append(result, sub)
    end
  end

  return table.concat(result)
end

function SearchContextMeta:replace__as_segments()
  local result = {}

  assert(self.template, E"Please set a replacement template first.")

  for sub, match, captures in self:parts_iter() do
    if match then
      append(result, { source=sub, target=exec_template(sub, self.template, captures) } )
    else
      append(result, sub)
    end
  end

  return result
end

---------------------------- Module-level functions ------------------------

local function load_plugin(plugin_name)
  return require('samples.apps.visren.search.plugins.' .. plugin_name)
end

function M.create_search_context(plugin_name, is_utf8, is_case_sensitive, is_global)
  local ctx = {
    plugin = load_plugin(plugin_name),
    is_utf8 = is_utf8,
    is_case_sensitive = is_case_sensitive,
    is_global = is_global,
    pattern = nil,
    template = nil,
  }
  return setmetatable(ctx, SearchContextMeta)
end

function M.get_menu()
  local menu = {}
  for _, name in ipairs(available_plugins) do
    append(menu, { load_plugin(name).title, value=name })
  end
  return menu
end

return M
