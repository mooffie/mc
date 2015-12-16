---
-- Encoding utilities for interaction with web technologies.
--
-- @module utils.text.transport

local M = require("c.utils.text.transport")

---
-- Decodes a [quoted-printable](http://en.wikipedia.org/wiki/Quoted-printable) string.
--
-- @function quoted_printable_decode
-- @args (s)
--
function M.quoted_printable_decode(s)
  return (
    s
      :gsub("=(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
      :gsub("=\r?\n", "")
  )
end

--[[

@todo: Since MC (4.8.15, at the time of this writing) now requires GLib
2.26+, we can replace the following uri_encode/decode functions with
their GLib implementation (which was introduced in GLib 2.16).

]]

---
-- Encodes a string using [percent-encoding](http://en.wikipedia.org/wiki/Percent-encoding).
--
-- That is, it replaces any non ASCII-alphanumeric character (plus dash, underscore,
-- dot, tilde) with percent sign (%) followed by two hex digits.
--
-- Behaves like PHP's [rawurlencode()](http://php.net/manual/en/function.rawurlencode.php)
-- and GLib's [g_uri_escape_string()](https://developer.gnome.org/glib/stable/glib-URI-Functions.html#g-uri-escape-string).
--
-- You may use the **allowed** parameter to list characters that are not to be
-- encoded.
--
-- Example:
--
--    assert(utils.text.transport.uri_encode("/path/to file?", "/")
--             == "/path/to%20file%3F")
--
-- @function uri_encode
-- @args (s[, allowed])
--
function M.uri_encode(s, allowed)
  -- Note: we don't use "%w" as it's locale-dependent.
  return (s:gsub('[^a-zA-Z0-9-_.~]', function(c)
    if allowed and allowed:find(c, 1, true) then
      return c
    else
      return string.format("%%%02X", c:byte())
    end
  end))
end

---
-- Decodes a [percent-encoded](http://en.wikipedia.org/wiki/Percent-encoding) string.
--
-- @function uri_decode
-- @args (s)
--
function M.uri_decode(s)
  return (s:gsub('%%(%x%x)', function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

return M
