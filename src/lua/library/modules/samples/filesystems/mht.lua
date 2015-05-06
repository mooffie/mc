--[[

Browse individual components of MHT ("MIME HTML") files.

Installation:

    require('samples.filesystems.mht')

More information:

See http://en.wikipedia.org/wiki/MHTML .

]]

local append = table.insert

local M = {}

local qp_decode, base64_decode, uri_decode = import_from('utils.text.transport', {
  'quoted_printable_decode', 'base64_decode', 'uri_decode' })

--
-- Fixup weird file names.
--
local function prettify_name(fname)

  -- For "Data URI scheme" images we invent some name.
  -- (see http://en.wikipedia.org/wiki/Data_URI_scheme)
  local base64_image_extension = fname:match "^data:image/(.%a+)"
  if base64_image_extension then
    return "image." .. base64_image_extension
  end

  -- For any other filenames, we just url_decode then.
  -- And in case these are URLs, we pick the last component (e.g.,
  -- 'http://...blah/blah.txt?coco' -> 'blah.txt').
  return uri_decode(fname:match ".*/([^?&/]+)" or fname)

end

--
-- Ensure all files have different names by adding a running number to clashes.
--
local function uniquify_name(name, seen)
  local try, i = name, 1
  while seen[try] do
    i = i + 1
    local base, extension = name:match "([^.]*)(.*)"
    try = base .. i .. extension
  end
  seen[try] = true
  return try
end

--
-- Extract the essential fields from MIME headers.
--
local function parse_headers(raw)
  local headers = raw:match ".-\r?\n\r?\n" or raw
  local name = headers and (headers:match "name=\"?([^\r\n\"]+)" or
                            headers:match "[Cc]ontent%-[Ll]ocation:%s*([^\r\n]+)")
                       or "NONAME"
  local encoding = headers and (headers:match "[Cc]ontent%-[Tt]ransfer%-[Ee]ncoding:%s*([%w-]+)")
                           or "8BIT"
  return headers, name, encoding:lower()
end

--
-- Decode a file.
--
local function decode(octets, encoding)
  if encoding == "base64" then
    return base64_decode(octets)
  elseif encoding == "quoted-printable" then
    return qp_decode(octets)
  else
    return octets
  end
end

local mht = {

  prefix = "mht",

  iregex = [[\.mhtl?]],

  readdir = function(session, p)
    return session.sequence
  end,

  stat = function(session, path)
    if session.parts[path] then
      return { size = session.parts[path].decoded_size }
    end
  end,

  file = function(session, path)

    local part = session.parts[path]
    if not part then
      return  -- implicitly return fs.ENOENT
    end

    local octets = assert(fs.read(session.parent_path, part.encoded_size, part.start))

    return decode(octets, part.encoding)

  end,

  open_session = function(session)

    local boundary = assert(fs.read(session.parent_path, 1024)):match "boundary=\"?([^\"\r\n]+)"

    if not boundary then
      abort("This doesn't look like a MHT file; It's missing a 'boundary' field.")
    end
    boundary = "--" .. boundary

    local raw_parts = utils.text.tsplit(
      fs.read(session.parent_path), boundary, nil, true
    )

    --
    -- We build an index of the components and store it in 'session.parts'.
    --
    -- For the benefit of readdir(), we also store the filenames as a list
    -- in 'session.sequence'.
    --

    local parts = {}
    local sequence = {}

    local names_seen = {}
    local start = 0

    for _, raw_part in ipairs(raw_parts) do

      local headers, raw_name, encoding = parse_headers(raw_part)
      local name = uniquify_name(prettify_name(raw_name), names_seen)

      local part = {
        name = name,
        raw_name = raw_name,
        encoding = encoding,
        start = start + headers:len(),
        encoded_size = raw_part:len() - headers:len(),
      }

      -- We can remove this block to save some speed. The files' size
      -- will then be reported as zero.
      do
        local bin = raw_part:sub(headers:len()+1)
        part.decoded_size = decode(bin, part.encoding):len()
      end

      if part.encoded_size > 0 then  -- The last part is empty.
        parts[part.name] = part
        append(sequence, part.name)
      end

      start = start + raw_part:len() + boundary:len()

    end

    session.parts = parts
    session.sequence = sequence

  end,

}

function M.install()
  fs.register_filesystem(mht)
end

M.install()

return M
