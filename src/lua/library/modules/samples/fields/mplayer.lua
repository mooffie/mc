--[[

Multimedia fields.

Installation:

  require('samples.fields.mplayer')

Available fields:

  - mp_duration     (your may want to embed is as "mp_duration:5" to save on columns, if your movies/songs are short.)
  - mp_height
  - mp_width
  - mp_bitrate      (shows video/audio bitrate (in kbit/s).)

NOTE:

Since invoking mplayer can be time-consuming, the data is "aggressively"
cached: you must reload the panel explicitly (C-r) to clear it. So if
you add new media files, or renames them, you won't see their data till
you hit C-r.

]]

local mplayer = require('samples.libs.mplayer')

local is_installed = mplayer.is_installed()

----------------------------------- cache ------------------------------------

local mplayer_cache = {}

local function get_mplayer_cache(dir)
  if not mplayer_cache[dir] then
    -- We can't run op-sys commands on non-local filesystem (e.g., inside archives).
    if fs.VPath(dir):is_local() and is_installed then
      mplayer_cache[dir] = mplayer.get_movies_stats(dir)
    else
      mplayer_cache[dir] = {}
    end
  end
  return mplayer_cache[dir]
end

-- Note: we use <<flush>> instead of <<load>>, for efficiency. The
-- implication is that users need to explicitly clear the cache (C-r).
ui.Panel.bind('<<flush>>', function(pnl)
  mplayer_cache[pnl.dir] = nil
  -- Alternatively, we could clear the entire cache here.
end)

local function get_movie_stats(dir, fname)
  local db = get_mplayer_cache(dir)
  return db[fname] or {}
end

------------------------------------------------------------------------------

-- Prepares the string for display.
local function DSP(s)
  if is_installed then
    return s
  else
    return "!"  -- indicate that mplayer isn't installed.
  end
end

local function format_duration(seconds)
  local hours, mintes, seconds = math.floor(seconds/3600), math.floor(seconds/60) % 60, seconds % 60
  if hours == 0 then
    return ("%d:%02d"):format(mintes, seconds)
  else
    return ("%d:%02d:%02d"):format(hours, mintes, seconds)
  end
end

local function get_field(dir, fname, field_name)
  local stats = get_movie_stats(dir, fname)
  return stats[field_name]
end

local function compare_field(dir, fname1, fname2, field_name)
  local stats1 = get_movie_stats(dir, fname1)
  local stats2 = get_movie_stats(dir, fname2)
  return (stats1[field_name] or 0) - (stats2[field_name] or 0)
end

ui.Panel.register_field {
  id = "mp_duration",
  title = N"&Duration (mplayer)",
  sort_indicator = N"sort|dur",
  default_width = 7,
  default_align = "right~",
  render = function(fname, _, _, info)
    local seconds = get_field(info.dir, fname, "LENGTH")
    return DSP(seconds and format_duration(seconds))
  end,
  sort = function(fname1, _, fname2, _, info)
    return compare_field(info.dir, fname1, fname2, "LENGTH")
  end,
}

ui.Panel.register_field {
  id = "mp_height",
  title = N"He&ight of video (mplayer)",
  sort_indicator = N"sort|ht",
  default_width = 4,
  default_align = "right~",
  render = function(fname, _, _, info)
    return DSP(get_field(info.dir, fname, "VIDEO_HEIGHT"))
  end,
  sort = function(fname1, _, fname2, _, info)
    return compare_field(info.dir, fname1, fname2, "VIDEO_HEIGHT")
  end,
}

ui.Panel.register_field {
  id = "mp_width",
  title = N"Width of video (mplayer)",
  sort_indicator = N"sort|wd",
  default_width = 4,
  default_align = "right~",
  render = function(fname, _, _, info)
    return DSP(get_field(info.dir, fname, "VIDEO_WIDTH"))
  end,
  sort = function(fname1, _, fname2, _, info)
    return compare_field(info.dir, fname1, fname2, "VIDEO_WIDTH")
  end,
}

local function get_bitrates(dir, fname)
  return
    (get_field(dir, fname, "VIDEO_BITRATE") or 0),
    (get_field(dir, fname, "AUDIO_BITRATE") or 0)
end

ui.Panel.register_field {
  id = "mp_bitrate",
  title = N"&Bitrate (mplayer)",
  sort_indicator = N"sort|br",
  default_width = 8,
  default_align = "right~",
  render = function(fname, _, _, info)
    local vid, aud = get_bitrates(info.dir, fname)
    vid = (vid ~= 0 and math.floor(vid/1000))
    aud = (aud ~= 0 and math.floor(aud/1000))
    if vid and aud then
      return vid .. "/" .. aud
    else
      return vid or aud
    end
  end,
  sort = function(fname1, _, fname2, _, info)
    local vid1, aud1 = get_bitrates(info.dir, fname1)
    local vid2, aud2 = get_bitrates(info.dir, fname2)
    return (vid1 + aud1) - (vid2 + aud2)
  end,
}

return {
  is_installed = is_installed,
}
