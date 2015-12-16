-- This is a more elaborated version of the code example given in the documentation for ui.Panel.marked.

--[[

Searches within *.mht files.

We deliberately search only in the first 1024 bytes of the files. A MIME
header is small. The files themselves are often 2-10 MB in size, so this
is a huge time saver.

]]

ui.Panel.bind("C-x plus c", function(pnl)

  local needle = prompts.input(T"Mark MHT files containing the following string in their first 1024 bytes:",
    -1, nil, "mark-by-contents")

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
