--[[

Automatically sorts (or unsorts) directories belonging to specific filesystems.

Idea taken from:

    http://www.midnight-commander.org/ticket/3497
    "auto turn off sorting"

...where a user asks to automatically turn off sorting for Commodore
filesystems.

Exercises for the reader:

(1) Make this script operate by directory names (patterns), not (just) by VFS type.
    This would make it useful for:

      http://www.midnight-commander.org/ticket/2719
      "Conditional sort"

(2) Make this script set a complete bunch of attributes, not just 'sort_field'.
    Don't hard-code the names: let them be anything.

]]


local preferred_sort = {
  -- List here all the sorts you want to automatically enable, keyed by the VFS type.
  uc1541 = 'unsorted',
}

-- Remembers the previous sort used. Keyed by the panel.
local previous_sort = {}

-- Remembers the previous VFS type visited. Keyed by the panel.
local previous_prefix = {}


ui.Panel.bind("<<load>>", utils.magic.once(function(pnl)

  -- 'vfs_prefix' holds the VFS type. E.g., "urar", "uzip", "sqlite", or nil for localfs.
  local vfs_prefix = pnl.vdir:last().vfs_prefix

  if vfs_prefix ~= previous_prefix[pnl] then
    -- We're navigating to a different VFS.
    if preferred_sort[vfs_prefix] then
      -- Set the preferred sort for this VFS, but not before saving the old sort.
      previous_sort[pnl] = pnl.sort_field
      pnl.sort_field = preferred_sort[vfs_prefix]
    else
      -- When leaving a VFS, restore the old sort.
      if previous_sort[pnl] then
        pnl.sort_field = previous_sort[pnl]
        previous_sort[pnl] = nil
      end
    end
  end

  previous_prefix[pnl] = vfs_prefix

end))
