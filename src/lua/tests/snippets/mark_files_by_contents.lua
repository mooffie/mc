ui.Panel.bind("C-x plus c", function(pnl)

  -- Note: Here we deliberately search only in the first 1024 bytes. A MIME header is small.
  -- The files themselves are often 2-10 MB in size, so this is a great time saver.

  local needle = prompts.input(T"Mark MHT files containing the following string in their first 1024 bytes:",
    nil, nil, "mark-by-contents")

  if not needle then
    return
  end

  abortive(needle:find '%S', T"It's not very exciting to search for nothing.")

  pnl:mark(
    prompts.please_wait(T"Searching files",
      function()
        return fs.tglob('*.mht', {conditions={
          function (path) return assert(fs.read(path, 1024)):find(needle, 1, true) end
        }})
      end
    )
  )

end)
