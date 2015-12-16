--[[

Provides git-related fields.

Installation:

    require('samples.fields.git')
    -- or see later, under "Performance issues".

Then, for example, you may use the following format:

    half type name | size | perm | gitstatus | gitdate | gitauthor | gitmessage

And the following mini-format:

    half type name:20 | gitcommit:10 | gitmessage

The provided fields:

  - gitstatus    fast     (do 'git help status' to learn about the meaning of the letters.)

  - gitdate      slow
  - gitauthor    slow
  - gitmessage   slow
  - gitcommit    slow

Performance issues:

As for the gitstatus field:

This field is generally fast. You can make it even faster by asking the
module not to report ignored files (with "!!"). You do this thus:

    require('samples.fields.git').mark_ignored = false

As for the "slow" fields:

One you use a single "slow" field you can use all of them without incurring
further loss of performance.

If you're conscious about performance, you can enable and disable the
"slow" fields with a hotkey (alternatively, see the "snapshots" tip below):

    local gitf = require('samples.fields.git')
    gitf.enabled = false  -- start disabled.

    ui.Panel.bind('C-f g e', function(pnl)
      gitf.enabled = true
      pnl:reload()
    end)

    ui.Panel.bind('C-f g d', function(pnl)
      gitf.enabled = false
      pnl:reload()
    end)

Currently, when these "slow" fields are enabled, they're calculated anew
whenever the directory is loaded into the panel. It's actually quite
easy to enhance this code to make their cache last longer (e.g., by
using panel::<<flush>> or <<ui::restored>> instead of panel::<<load>>).
That's something we should certainly do if it turns out people are
using these fields.


---------------------------------------------------------------------

Tip:

Use the "snapshots" module to save your custom format and restore it
whenever you wish. You can have one snapshot to "disable" the git fields
and another to "enable" them.

]]

local git = require('samples.libs.git')

local is_installed = git.is_installed()

local M = {

  is_installed = is_installed,  -- so code require()ing this module can know.

  -- Whether to enable the "slow" fields.
  enabled = true,

  -- Whether to mark ignored files (with "!!"). Turn this off for
  -- better performance.
  mark_ignored = true,

}

local features = nil

local function detect_features(dir)
  if not features then
    features = {
      -- Check if '--ignored' is supported (purportedly a git 1.7.x+ feature. See SO #466764)
      has_ignored_option = M.mark_ignored and git.try_command(dir, 'git status -z --ignored -- .')
    }
  end
end

--
-- Prepares the string for display.
--
local function DSP(s)
  if is_installed then
    -- When we're disabled we show a dot (.) so the user doesn't think
    -- there's a bug.
    return s or (M.enabled and "" or ".")
  else
    return "!"  -- indicate that git isn't installed.
  end
end

------------------------- status field (fast) ------------------------------

-- Note: M.enabled doesn't affect this field.

local git_stat_cache = {}

local function get_git_stats(dir)
  if not is_installed then
    return {}
  end
  if not git_stat_cache[dir] then
    -- Remove "--ignored" if you don't want ignored files to be marked as such.
    -- Add "-u no" if you want it to be faster. See "git status" man page.
    if git.under_git_control(dir) then
      detect_features(dir)
      git_stat_cache[dir] = git.status_summary(dir, features.has_ignored_option and '--ignored' or '')
    else
      git_stat_cache[dir] = {}
    end
  end
  return git_stat_cache[dir]
end

ui.Panel.bind('<<load>>', function(pnl)
  git_stat_cache[pnl.dir] = nil
end)

ui.Panel.register_field {
  id = "gitstatus",
  title = N"Status (git)",
  default_width = 2,
  render = function(fname, stat, width, info)
    local git_stats = get_git_stats(info.dir)
    return DSP(git_stats[fname] or '')
  end,
}

----------------------- overview fields (slow) -----------------------------

local git_overview_cache = {}

local function get_git_overview(dir)
  if not git_overview_cache[dir] then
    -- manual page says to use "--first-parent" but it seems it's not that helpful.
    git_overview_cache[dir] = git.under_git_control(dir) and git.dir_overview(dir, "--no-merges") or {}
  end
  return git_overview_cache[dir]
end

ui.Panel.bind('<<load>>', function(pnl)
  git_overview_cache[pnl.dir] = nil
end)

local function git_overview_field(dir, fname, field)
  if not is_installed or not M.enabled then
    return nil
  end
  local git_overview = get_git_overview(dir)
  if git_overview[fname] then
    return git_overview[fname][field]
  end
end

ui.Panel.register_field {
  id = "gitauthor",
  title = N"Author (git)",
  render = function(fname, stat, width, info)
    return DSP(git_overview_field(info.dir, fname, 'author'))
  end,
}

ui.Panel.register_field {
  id = "gitmessage",
  title = N"Message (git)",
  expands = true,
  render = function(fname, stat, width, info)
    return DSP(git_overview_field(info.dir, fname, 'message'))
  end,
}

local format_interval_tiny = require("utils.text").format_interval_tiny

ui.Panel.register_field {
  id = "gitdate",
  title = N"When (git)",
  default_width = 4,
  default_align = 'right',
  render = function(fname, stat, width, info)
    local timestamp = git_overview_field(info.dir, fname, 'date')
    return DSP(timestamp and format_interval_tiny(os.time() - timestamp))
  end,
}

ui.Panel.register_field {
  id = "gitcommit",
  title = N"Commit ID (git)",
  render = function(fname, stat, width, info)
    return DSP(git_overview_field(info.dir, fname, 'commit'))
  end,
}

----------------------------------------------------------------------------

return M
