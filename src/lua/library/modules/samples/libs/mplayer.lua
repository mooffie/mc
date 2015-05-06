--[[

Returns statistics about movie/song files (duration, width, height, bitrate).

Usage:

  local mplayer = require('samples.libs.mplayer')

  devel.view( mplayer.get_movies_stats("/path/to/media/folder/") )

]]

local M = {

  commands = {

    check = 'mplayer',

    -- We redirect stderr to suppress "Estimating duration from bitrate, this may be inaccurate".
    run = "cd %q && mplayer -identify -vo null -ao null -frames 0 -nolirc %s 2>/dev/null",

  },

  -- A glob pattern for locating multimedia files. We need this because
  -- "mplayer *", while automatically detecting media files for us, is slow
  -- and treats also .txt as such.
  --
  -- Please keep this list alphabetically sorted, with audio formats preceding videos.
  glob = '*.{flac,gsm,mp2,mp3,ra,wma,3gp,asf,avi,divx,flv,m4v,mkv,mov,mp4,mpeg,mpg,ogg,ram,rm,rmvb,rv,vob,webm,wmv}',

}

function M.is_installed()
  return require('samples.libs.os').try_program(M.commands.check)
end

M.extractors = {
  FILENAME = {
    is_header = true,
    parser = utils.path.basename,
  },
  LENGTH = {
    parser = math.floor,
  },
  VIDEO_WIDTH = {
    parser = tonumber,
  },
  VIDEO_HEIGHT = {
    parser = tonumber,
  },
  VIDEO_BITRATE = {
    parser = tonumber,
  },
  AUDIO_BITRATE = {
    parser = tonumber,
  },
}

local function noop(x) return x end

local function get_movies_stats__raw(dir, shell_args)

  local command = M.commands.run:format(dir, shell_args)

  devel.log("Running: " .. command)

  local f = io.popen(command)

  local stats = {}

  local function record_info(info)
    if info then
      stats[info.FILENAME] = info
    end
  end

  local info = nil

  for line in f:lines() do
    for name, extractor in pairs(M.extractors) do
      local value = line:match('^ID_' .. name .. '=(.*)')
      if value then
        if extractor.is_header then
          record_info(info)
          info = {}
        end
        info[name] = (extractor.parser or noop)(value)
      end
    end

  end

  record_info(info)

  f:close()

  return stats

end


local List = utils.table.new

function M.get_movies_stats(dir, filenames)
  dir = dir or "."

  if not filenames then
    filenames = List( fs.tglob(dir .. '/' .. M.glob, {nocase=true}) )
      :imap(utils.path.basename)
  end

  if #filenames == 0 then
    -- Don't bother launching mplayer.
    return {}
  end

  local args = List(filenames)
      :imap(function(s) return string.format("%q", s) end)
      :concat(" ")

  return get_movies_stats__raw(dir, args)
end


return M
