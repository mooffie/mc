-- -*- Lua -*-

--[[

We use ldoc to produce our documentation. The file you're looking at is
the configuration for ldoc.

However, you need to use my own fork of ldoc, as it has two features not
yet merged into the official ldoc. Get it from:

    https://github.com/mooffie/LDoc

Then (after you set it up), launch ldoc from this directory (so it can
see 'config.ld') with:

    ldoc --unsafe

]]

local append = table.insert

dir = "html"  -- output directory.

project = "mc^2"

-- Where git links point to:
local git_repository_base = 'https://github.com/mooffie/mc/blob/lua-4.8.14-port/'

-- Where ticket links point to:
local bug_tracker_base = 'http://www.midnight-commander.org/ticket/'

local LDIR = "../../library/modules/core/" -- Lua files.
local CDIR = "../../modules/"              -- C files.
local GDIR = "../../doc/guide/"            -- "user guide" files.
local RDIR = "../../doc/"                  -- documents "root" dir.

print(_VERSION)

topics = {
  GDIR .. '10-getting-started.md',
  GDIR .. '15-samples.md',
  GDIR .. '20-extending-mc.md',
  GDIR .. '25-working-with-files.md',
  GDIR .. '30-fields.md',
  GDIR .. '35-filesystems.md',
  GDIR .. '40-user-interface.md',
  GDIR .. '60-standalone.md',
  GDIR .. '80-installation.md',
  GDIR .. '90-general.md',
  GDIR .. '95-other.md',

  RDIR .. 'FRONTPAGE.md',
  RDIR .. 'HACKING.md',
  RDIR .. 'REVIEWERS.md',
  RDIR .. 'WHY.md',
  RDIR .. 'HISTORY.md',
  RDIR .. 'SCREENSHOTS.md',
  RDIR .. 'TICKETS-SOLVED.md',
}

file = {

  -- If a module description, or a section description, appears in two files,
  -- it's the first that's taken. Additionally, ldoc sorts sections in the
  -- order it encounters them in whatever file. So the order here does matter!

  CDIR .. 'tty.c',
  LDIR .. 'tty.lua',

  CDIR .. 'ui.c',
  LDIR .. 'ui.lua',
  LDIR .. 'ui/gc.lua',
  LDIR .. 'ui/scaffolding.lua',
  LDIR .. 'ui/popup.lua',

  CDIR .. 'regex.c',
  LDIR .. 'regex.lua',

  CDIR .. 'ui-editbox.c',
  LDIR .. 'ui/editbox.lua',

  CDIR .. 'ui-panel.c',
  LDIR .. 'ui/panel.lua',

  CDIR .. 'ui-viewer.c',

  CDIR .. 'locale.c',

  CDIR .. 'prompts.c',
  LDIR .. 'prompts.lua',

  CDIR .. 'conf.c',

  LDIR .. 'timer.lua',
  CDIR .. 'timer.c',

  CDIR .. 'mc.c',
  LDIR .. 'mc.lua',

  CDIR .. 'os.c',

  LDIR .. 'string.lua',

  CDIR .. 'internal.c',

  LDIR .. 'fields.lua',

  CDIR .. 'fs.c',
  LDIR .. 'fs.lua',

  CDIR .. 'fs-filedes.c',
  CDIR .. 'fs-dir.c',

  LDIR .. 'fs/file.lua',

  CDIR .. 'fs-statbuf.c',

  CDIR .. 'fs-vpath.c',

  LDIR .. 'fs/glob.lua',

  LDIR .. 'luafs.lua',
  LDIR .. 'luafs/shortcuts.lua',
  LDIR .. 'luafs/panel.lua',

  LDIR .. 'devel.lua',
  LDIR .. 'devel/log.lua',
  LDIR .. 'devel/ensure.lua',

  LDIR .. 'utils/text.lua',
  CDIR .. 'utils-text.c',

  LDIR .. 'utils/text/transport.lua',
  CDIR .. 'utils-text-transport.c',

  LDIR .. 'utils/magic.lua',

  LDIR .. 'utils/table.lua',

  CDIR .. 'utils-bit32.c',
  
  LDIR .. 'globals.lua',

  LDIR .. 'keymap.lua',

  LDIR .. 'event.lua',

  CDIR .. 'ui-custom.c',

  CDIR .. 'ui-canvas.c',
  LDIR .. 'ui/canvas.lua',
}

-- There are other formatters (e.g., 'markdown') and there are subtle
-- differences among them. Let's stick to 'discount' because it was
-- used during the development so we know all its idiosyncrasies.
format = 'discount'

--[[

If you have trouble with lxsh, see:

  https://github.com/xolox/lua-lxsh/issues/5   "Problem with new LPeg"

  luarocks remove --local --force lpeg
  luarocks install --local lpeg 0.10

]]
--pretty='lxsh'

user_keywords = { 'T', 'Q', 'N', 'import_from', 'abort', 'abortive', 'alert', 'declare' }

-- ldoc doesn't recognize error(). We fix it here:
require('ldoc.builtin.globals').functions.error = true

kind_names = { topic='Guide' }
merge = true
no_space_before_args = true
sort = true
manual_url 'http://www.lua.org/manual/5.2/manual.html'

-- Without the following, modules/classes won't be sorted on the index page. They will
-- appear in the order specified here in the 'file' table.
--
-- https://github.com/stevedonovan/LDoc/issues/144
--
sort_modules=true

style="!pale"

-- NOTE: tag names cannot contain underscores!
custom_tags = {
  { 'callback', hidden = true },
  { 'property', hidden = true },
  { 'explicitargs', hidden = true },
  { 'qualifier', hidden = true },
  { 'event', hidden = true },
  { 'pseudo', hidden = true },
  { 'internal', hidden = true },
  { 'noqualifier', hidden = true },
}

-- We can mark all items as "@function", but that wouldn't be very organized,
-- so we create some aliases:
alias('method', 'function')
alias('attr', 'function')
alias('moniker', 'function')  -- A general tag for when other aliases don't make sense.

-- The tag itself is called "explicitargs" because using "args" in the code of this
-- Lua file may confuse the reader (b/c ldoc already has "args" property). But to save
-- the user typing, we alias it to "args".
alias('args', 'explicitargs')

------------------------------ Unix man links --------------------------------
--
-- Links of the form @{fopen(3)}.
--

local upat = "http://man7.org/linux/man-pages/man%d/%s.%d.html"

-- Code taken from ldoc's manual (but: we allow "-" in name (as in "git-status"), and the URL above was updated).
custom_see_handler('^([%w_-]+)%((%d)%)$',function(name,section)
    local url = upat:format(section,name,section)
    local name = name .. '(' .. section .. ')'
    return name, url
end)

-------------------------------- Git links -----------------------------------
--
-- Links of the form @{git:partial/path/to/file.c}.
--
-- See 'git_repository_base' at the top of this file for the URL used.
--

local git_files = nil

local function list_git_files()
  local f = io.popen('git ls-tree --full-tree -r -t --name-only HEAD')
  local txt = f:read('*a')
  f:close()
  return require 'pl.stringx'.splitlines(txt)
end

custom_see_handler('^git:(.*)', function(fname)

  if not git_files then
    git_files = list_git_files()
  end

  local matches = git_files:filter(function(gf)
    return gf == fname or (gf:sub(-fname:len()-1) == '/' .. fname)
  end)

  assert(#matches ~= 0, "No file matching @{git:" .. fname .. "} was found in the GIT repository")
  assert(#matches == 1, "Too many files matching @{git:" .. fname .. "}: " .. matches:join(", "))

  return fname, git_repository_base .. matches[1]

end)

-------------------------------- Ticket links --------------------------------
--
-- Links of the form @{1234}.
--
-- See 'bug_tracker_base' at the top of this file for the URL used.
--

custom_see_handler('^(%d+)$', function(id)
  return '#' .. id, bug_tracker_base .. id
end)

------------------------------- Fuzzy links ----------------------------------
--
-- They let us link to guide pages based on substring in the filename,
-- and to sections based, again, on a substring. This way we can later
-- change the target's text a bit without breaking the links.
--
--   @{~fuzzy#fuzzy}        or  @{~mod:module#fuzzy}
--   @{~fuzzy*item_name}
--   @{~fuzzy!anchor}
--

local function fuzzy_match(hay, needle)
  local case_sensitive = needle:find '[A-Z]'
  local function simplify(s)
    return (case_sensitive and s or s:lower()):gsub('[^a-zA-Z]', ' '):gsub(' +', ' ')
  end
  hay = simplify(hay)
  needle = simplify(needle)
  return hay:find(needle, 1, true)
end

local function find_section(mod, needle)
  local found = nil
  for name, sect in pairs(mod.sections.by_name) do
    if fuzzy_match(name, needle) then
      if found then
        error(("Both %q and %q match the fuzzy string %q"):format(found.name or found.display_name, name, needle))
      end
      found = sect
    end
  end
  return found
end

local function find_module(mods, needle)
  if needle:find '^mod:' then
    -- explicit name.
    local name = needle:sub(5)
    for _, mod in ipairs(mods) do
      if mod.name == name then
        return mod
      end
    end
  else
    local found = nil
    for _, mod in ipairs(mods) do
      if mod.type == 'topic' then
        if fuzzy_match(mod.name, needle) then
          if found then
            error(("Both %q and %q match the fuzzy string %q"):format(found.name, mod.name, needle))
          end
          found = mod
        end
      end
    end
    return found
  end
end

local function module_title(mod)
  local title
  if mod.type == 'topic' then
    title = mod.body:match('(%w[^\n]+)')
  end
  return title or mod.name
end

custom_see_handler('^~(.*)', function(fuzzy_query)

  -- ldoc doesn't tell us the module we belong to, see we fetch this
  -- info "magically":

  local _, self = debug.getlocal(3,1)  -- Ends up at ldoc.lua:process_see_reference().
  assert(type(self) == 'table' and self.type, "I can't figure out the currently processed module")

  local ldoc = require 'ldoc.doc'.ldoc
  local mods = ldoc.modules

  --------- end of magic --------------

  local mod_fuzz = nil
  --
  -- Three different ways to specify the target:
  --
  -- - fuzzy section title (#)
  -- - exact item name (*)
  -- - explicit anchor (!)
  --
  local sect_fuzz = nil
  local item_name = nil
  local explicit_anchor = nil

  do
    local a, type, b = fuzzy_query:match('(.*)([#*!])(.*)')
    if a then
      if type == "#" then
        mod_fuzz, sect_fuzz = a, b
      elseif type == "*" then
        mod_fuzz, item_name = a, b
      else
        mod_fuzz, explicit_anchor = a, b
      end
    else
      mod_fuzz = fuzzy_query
    end
  end

  local mod, sect

  if mod_fuzz == "" then
    mod = self
  else
    mod = assert(find_module(mods, mod_fuzz), "Can't fuzzy-find module " .. mod_fuzz)
  end

  local function section_anchor()
    if mod.type == 'topic' then
      return sect.name
    else
      return ldoc.no_spaces(sect.display_name)
    end
  end

  if sect_fuzz then
    sect = assert(find_section(mod, sect_fuzz), "Can't fuzzy-find section " .. sect_fuzz)
  end

  if item_name then
    assert(mod.items.by_name[item_name], "Fuzzy-see: Can't find the item " .. item_name)
    explicit_anchor = item_name
  end

  if mod then
    if explicit_anchor then
      return explicit_anchor, ldoc.ref_to_module(mod) .. '#' .. explicit_anchor
    elseif sect then
      return sect.display_name, ldoc.ref_to_module(mod) .. '#' .. section_anchor()
    else
      return module_title(mod), ldoc.ref_to_module(mod)
    end
  else
    return 'NOT FOUND', 'NOT FOUND'
  end

end)

------------------------------- Fix the HTML ---------------------------------
--
-- ldoc's output is far from perfect. We need to fix a few things.
--

local __html_id = 1

postprocess_html = function(s, item)

  --[[
  -- debugging:
  if (some condition) then
    local ldoc = require 'ldoc.doc'.ldoc
    local mods = ldoc.modules
    pvsc(mods)
  end
  ]]

  ----------------------------------------------------------------------------

  -- Fix links containing '+'.
  s = s:gsub('%%2B', '+')

  -----------------------------------------------------------------------------

  -- For parameters that have no descriptions, mark them as such so in
  -- the CSS we don't print ":" after their names.
  s = s:gsub([[(<li><span class="parameter)(">[%w_]+</span>%s*</li>)]], "%1 without-description %2")

  -----------------------------------------------------------------------------

  -- Inject our own CSS.
  local level = item and "../" or "" -- the index page (item == nil) is at the top dir already.
  s = s:gsub('</head>', '    <link rel="stylesheet" href="' .. level .. 'mc.css" type="text/css" />\n%0')

  -----------------------------------------------------------------------------

  -- Inject ~/.ldoc-extra-include.html, for things that can't be shipped with LGPL software.
  do
    local path = assert(os.getenv('HOME')) .. '/.ldoc-extra-include.html'
    if require 'pl.path'.exists(path) then
      s = s:gsub('</head>', function()
        return  require 'pl.utils'.readfile(path) .. '</head>'
      end)
    end
  end

  -----------------------------------------------------------------------------

  --
  -- Support BBCode-style tags like [note], [tip], ...
  --

  -- Note: we can't end the pattern with "</p>" (we use "\n\n" instead)
  -- because ldoc's markup.lua:markdown_processor() removes it (explaining
  -- this by saying "We will add our own paragraph tags, if needed").
  --
  -- UNFORTUNATELY, at the end of an item there's a </div>, not an "\n". So
  -- don't use "Note:" and end of items. Use BBCode tags instead.

  s = s:gsub('<p>%s*Note:(.-)\n\n', '<p> [note]</p>\n<p>%1<p> [/note]</p>\n')
  s = s:gsub('<p>%s*Note%-short:(.-)\n\n', '<p> [note short]</p>\n<p>%1<p> [/note]</p>\n')

  s = s:gsub('<p>%s*Tip:(.-)\n\n', '<p> [tip]</p>\n<p>%1<p> [/tip]</p>\n')
  s = s:gsub('<p>%s*Tip%-short:(.-)\n\n', '<p> [tip short]</p>\n<p>%1<p> [/tip]</p>\n')

  s = s:gsub('<p>%s*Info:(.-)\n\n', '<p> [info]</p>\n<p>%1<p> [/info]</p>\n')
  s = s:gsub('<p>%s*Info%-short:(.-)\n\n', '<p> [info short]</p>\n<p>%1<p> [/info]</p>\n')

  s = s:gsub('<p>%s*Indent:(.-)\n\n', '<p> [indent]</p>\n<p>%1<p> [/indent]</p>\n')

  local valid_tags = {
    note={base_class="message"},
    tip={base_class="message"},
    info={base_class="message"},
    ignore={base_class=""},
    indent={base_class=""},
  }

  -- subst [note], [tip], [note short], etc.
  s = s:gsub('<p>%s*%[(%w+)(%s*[%w ]*)%]</p>', function(tag, extra_classes)
    if valid_tags[tag] then
      return ('<div class="%s %s %s">'):format(
        valid_tags[tag].base_class, tag, extra_classes)
    end
  end)
  -- subst [/note], [/tip], etc.
  s = s:gsub('<p>%s*%[/(%w+)%][^\n]*', function(tag)
    if valid_tags[tag] then
      return '</div>'
    end
  end)

  -----------------------------------------------------------------------------

  local function build_toc(mod)
    local s = {}
    for _, sect in ipairs(mod.sections) do
      append(s, ("<li><a href='#%s'>%s</a></li>"):format(sect.name, sect.display_name))
    end
    return '<h2>Contents</h2><ul>' .. table.concat(s) .. '</ul>'
  end

  -- Move the TOC to the body.
  if s:find('<h2>Contents') then
    local bef, toc, aft = s:match [[(.*)(<h2>Contents</h2>.-</ul>)(.*)]]
    if bef then
      s = bef .. aft  -- remove the TOC.
      -- We want TOC only on topic pages.
      -- Additionally, you can opt out by embedding "skip-doc" in the text.
      if item and item.type == "topic" and not s:find 'skip%-toc' then
        -- ldoc has a "bug": the TOC lists section in the order they're mentioned anywhere.
        -- So it the document has "Events" as last section, but it's mentioned in some module
        -- before, it'd appear first in the TOC! So we build the TOC ourselves.
        toc = build_toc(item)
        local bef, aft = s:match [[(.*<div id="content">)(.*)]]
        s = bef .. '<div id="toc">' .. toc .. '</div>' .. aft -- move it here.
        s = s:gsub('<h2>Contents</h2>', '<h2>Table of Contents</h2>')
      end
    end
  end

  -----------------------------------------------------------------------------

  -- Order the Guide/Classes/Modules on the sidebar consistently.
  -- see https://github.com/stevedonovan/LDoc/issues/127

  local function pluck(what)
    -- We do ".-", not ".*", in case we have a "Modules" section in the text itself.
    local bef, menu, aft = s:match( [[(.-)(<h2>]] .. what .. [[</h2>.-</ul>)(.*)]] )
    s = bef .. aft
    menu = menu:gsub('<li><strong>', '<li class="current"><strong>')
    return menu
  end

  local menu_guide = pluck("Guide")
  local menu_classes = pluck("Classes")
  local menu_modules = pluck("Modules")

  -- We don't want the uppercase files (HACKNIG.md, HISTORY.md, etc.) to
  -- appear in the menu.
  menu_guide = menu_guide:gsub('<li>.-</li>', function(item)
    if item:find '/[A-Z][A-Z]' then
      return ''
    end
  end)

  -- "item" means we're on a non-index page.
  s = s:gsub( item and [[div id="navigation".-</ul>]] or [[div id="navigation".-</h1>]],
              "%0" .. menu_guide .. menu_modules .. menu_classes )

  -----------------------------------------------------------------------------

  -- We often use 'type' in our code snippets as a normal identifier. But
  -- unfortunately it gets prettified as the builtin function. We "undo" this
  -- prettifying, unless it's actually a function call.
  s = s:gsub('(<span class="global">type</span>)(.)', function(type_html, next_html)
    if next_html == '(' then
      return nil
    else
      return 'type' .. next_html
    end
  end)

  -----------------------------------------------------------------------------

  -- When code snippets end in a comment they are shown with extra line. Delete it.
  s = s:gsub('\n</span>\n</pre>', '</span>\n</pre>')

  -----------------------------------------------------------------------------

  -- Allow typing & (as [AMP]).
  s = s:gsub('%[AMP%]', '&')

  -----------------------------------------------------------------------------

  -- In 'topics', the anchors are wrapped in <P>s, which make the :target
  -- CSS not work. We unwrap them.
  s = s:gsub('<p>(<a name="[^"]+"></a>)</p>', "%1")

  -----------------------------------------------------------------------------

  -- Handle mdash issues.

  -- Don't have it in code.
  s = s:gsub('<code>.-</code>', function(code)
    return code:gsub('&mdash;', '--')
  end)

  local warn = false

  if warn then
    for line_with_mdash in s:gmatch('[^\n]*&mdash;%w[^\n]*') do
      print(("Warning: mdashed '--%s'. May be command-line option name."):format(line_with_mdash))
    end
  end

  -- It seems that `this syntax` cannot span over several lines.
  for line_w_problem in s:gmatch('[^\n]*&lt;/?code[^\n]*') do
    error(("Warning: HTML-escaping bug at '%s'."):format(line_w_problem))
  end

  -----------------------------------------------------------------------------

  --
  -- Images and screenshots.
  --

  local img_dir = '../images/'

  s = s:gsub('<p>%[img:(.-)%]</p>', function(ifile)
    return ('<img src="%s" />'):format(img_dir .. ifile)
  end)

  s = s:gsub('<p>%[ss:(.-)%]</p>', function(ifile)
    local thm = ifile:gsub('.png', '_thm.jpg')
    return ([[
      <a href="%s"><img src="%s"></a>
    ]]):format(img_dir .. ifile, img_dir .. thm)
  end)


  s = s:gsub('<p>%[figure%]</p>(.-)<p>%[split%]</p>(.-)<p>%[/figure%]</p>', function(picture, legend)
    return ([[
      <table class="figure">
      <tr>
        <td class="figure">%s</td>
        <td class="legend">%s</td>
      </tr>
      </table>
    ]]):format(picture, legend)
  end)

  ----------------------------------------------------------------------------

  -- Handle [expand].
  --
  -- This is an ugly ad hoc thing. The proper solution is to include a JS script. We're
  -- certainly not going to win a prize for this code.

  s = s:gsub('<p>%s*%[expand%]</p>(.-)<p>%s*%[/expand%]</p>', function(inside)

    local id = 'hidden' .. __html_id
    local getter = 'document.getElementById("' .. id .. '")'

    local btn = ("<p><input type='button' value='  %s  ' onclick='%s' /></p>"):format(
      "Click to expand",
      'this.style.display = "none"; ' .. getter .. '.style.display = "block"'
    )
    local hidden = '<div id="' .. id .. '">' .. inside .. '</div>'
    local after = '<script type="text/javascript">' .. getter .. '.style.display = "none"</script>'

    __html_id = __html_id + 1

    return btn .. hidden .. after

  end)

  -----------------------------------------------------------------------------

  -- Logo.
  s = s:gsub('mc^2', 'mc<sup><small>2</small></sup>')

  -----------------------------------------------------------------------------

  --
  -- ldoc uses "Reference" as title for all pages :-(
  -- We fix this here.
  --

  local function set_title(ttl)
    s = s:gsub('<title>.-</title>', '<title>' .. ttl .. '</title>')
  end

  if item then
    set_title(module_title(item))
  end

  -----------------------------------------------------------------------------

  local front_name = 'Front'

  -- Make FRONTPAGE.md our index.html.
  if item and item.name == 'FRONTPAGE.md' then
    set_title(project)
    s = s:gsub('(<li><a href="../index.html">)Index(</a></li>)', '<li><strong>' .. front_name .. '</strong></li>')
    s = s:gsub('<li class="current">.-</li>', '')
    s = s:gsub('href="../', 'href="')
    s = s:gsub('src="../', 'src="')  -- for [[img:]]
    local target = dir .. "/" .. output .. (ext or ".html")  -- "html/index.html"
    require 'pl.utils'.writefile(target, s)
  else
    s = s:gsub('(<li><a href="../index.html">)Index(</a></li>)', '%1' .. front_name .. '%2')
  end

  -- Make it possible to style the "Other documents" (uppercase files) differently.
  if item and item.name:match '^[A-Z][A-Z]' then
    s = s:gsub('<body>', '<body class="external">')
  end

  -----------------------------------------------------------------------------

  return s
end

----------------------- Fix links to os.* and string.* -----------------------

-- Links such as @{os.execute} will fail because we ourselves implement
-- an 'os' module. So we handle ourselves links to the builtin functions.

local base_lua_href = 'http://www.lua.org/manual/5.1/manual.html#pdf-'

local builtins = [[
os.clock
os.date
os.difftime
os.execute
os.exit
os.getenv
os.remove
os.rename
os.setlocale
os.time
os.tmpname
string.byte
string.char
string.dump
string.find
string.format
string.gmatch
string.gsub
string.len
string.lower
string.match
string.rep
string.reverse
string.sub
string.upper
]]

for fname in builtins:gmatch('%S+') do
  custom_see_handler('^' .. fname .. '$', function(name)
    return name, base_lua_href .. name
  end)
end

------------------------ custom_display_name_handler -------------------------
--
-- Tweak the way item names (and a few other things) are shown.
--

local function base(id)
  return (id:match '.*[.:](.*)') or id
end

custom_display_name_handler = function(item, default_handler)

  ----------------------------------------------------------------------------

  -- We don't want to print "Parameters: ..." when none of the parameters
  -- has description (because the function's signature line already contains
  -- all the info in this case.)
  if item.type == 'function' then
    local has_desc = false
    for name, desc in pairs(item.params.map) do
      if desc ~= "" then
        has_desc = true
      end
    end
    if not has_desc then
      item.params = { map={} }
    end
  end

  if item.type == 'field' then
    if item.params[1] == base(item.name) then
      item.params[1] = nil
    end
  end

  ----------------------------------------------------------------------------

  -- item.display_name is a handy alternative to item.name.

  ---------------------------- @noqualifier ----------------------------------

  if item.type == 'function' or item.type == 'field' then
    if item.module.tags.noqualifier then
      item.display_name = base(item.name)
    end
  end

  ----------------------------- @qualifier -----------------------------------

  -- Do "@qualifier modname" to prepend "modname." to the name.
  -- I don't think this is really needed. We should remove this.
  if item.tags.qualifier then
    item.display_name = item.tags.qualifier[1] .. '.' .. item.name
  end

  --------------------------- @explicitargs ----------------------------------

  -- Do "@explicitargs (a,b,c)" to explicitly set the args.
  item.args = (item.tags.explicitargs and item.tags.explicitargs[1]) or item.args

  ------------------------ @pseudo / @internal -------------------------------

  if item.type == 'module' then
    if item.tags.pseudo or item.tags.internal then
      return '( ' .. default_handler(item) .. ' )'
    end
  end

  -------------------------------- MD ----------------------------------------

  -- For .md files, extract the title from the body.
  if item.type == 'topic' then
    if item.body then
      local title = item.body:match('(%w[^\n]+)')
      if title then
        return title  -- @todo: We need to html-escape this. How can we access ldoc.escape()?
      end
    end
  end

  ----------------------------------------------------------------------------

  if item.type == 'function' and item.tags.property then
    --
    -- @property
    --
    local legend = {
      r = "Read-only property",
      w = "Write-only property",
      rw = "Read/write property",
    }
    return ("%s <span class='property' title='%s'>%s</span>"):format(
               item.name,
               legend[item.tags.property[1]] or "property",
               item.tags.property[1]
             )
              -- Turn 'Panel:dir' into 'Panel.dir': (unfortunately, this
              -- make static functions indistinguishable from properties.)
             :gsub(':', '.')
  elseif item.type == 'function' and item.tags.event then
    --
    -- @event
    --
    local evname = item.name
                     :gsub('::', '!!')
                     :gsub('.*[.:]', '')     -- remove the possible qualifier.
                     :gsub('__event$', '')   -- you may append '__event' if the name is the same as a method's.
                     :gsub('^zzz_', '')      -- you may prepend 'zzz_' to make it sort at the bottom. A temporary kludge till we figure out something better.
                     :gsub('!!', '::')
    return '&lt;&lt;' .. evname .. '&gt;&gt;'
  elseif item.type == 'function' and item.tags.callback then
    --
    -- @callback
    --
    return ('%s<span class="handler-args">%s</span> <span class="handler" title="A handlers is function that\'s called by the system when some event occur.">handler</span>'):format(
        -- (The following was copied from what ldoc.default_display_name does.)
        (item.display_name or item.name) .. (no_space_before_args and "" or " "),
        item.args
      )
      :gsub('%(%)', '')  -- turn 'func()' into 'func'
  end

  ----------------------------------------------------------------------------

  return default_handler(item)
end

------------------------------------------------------------------------------
