Tickets mc^2 solves
===================

Here's a non exhaustive list of tickets mc^2 can solve.

A "sol" link points to a solution, or to a way of solving.


** NAVIGATION AIDS **

- @{280} and @{2733} (and @{2842}) "Fast switch between recently used files"   @{~shots#recent|sol}
- @{1581} "Tabs, or tab equivalent"   @{~shots#snapshots|sol}, @{git:docker.lua|sol}

** ACCESSORIES **

- @{3088} "Tell current directory to gnome-terminal"  @{git:set-gterm-cwd.lua|sol}
- @{1364} "overly verbose xterm title" @{git:set-xterm-title.lua|sol}
- @{2654} 'history-search-backward'
- @{1636} "hotlist: fast filter"  @{~shots#hotkeys|sol}
- @{1483} "Panel scrollbar" @{git:accessories/scrollbar.lua|sol}
- @{1761} "Clock display"  @{git:clock.lua|sol} @{git:ticker.lua|sol}
- @{1756} "Automatic update of the file list"
- [FC](http://unix.findincity.net/view/635395087004115229213514/midnight-commander-shortcut-keys-for-entries-in-directory-hotlist)
  Hotkeys for the directory hotlist dialog. @{git:hotlist-keys.lua|sol}
- [ML](https://mail.gnome.org/archives/mc-devel/2015-May/msg00055.html)
  @{3469} listboxes and digits. @{git:listbox_AZ.lua|sol}

** EDITOR **

- @{2644} "WordStar keybindings"  @{git:wordstar.lua|sol}
- @{3195} "goto line:column" @{git:goto_line_col.lua|sol}
- @{2421} "highlight occurences of pattern."  @{ui.Editbox:add_keyword|sol}
- @{2875} "super tab" @{git:supertab.lua|sol}
- @{2749} "C-code navigation via cscope"
- @{3068} "Vim's modeline support"  @{~shots#modeline|sol}
- @{322} "when comma is inserted, add space" (joke, but instructive)
- @{1688} "Warn if no write permission" (also @{3163}) @{~shots#warning|sol}
- @{1480} "Home key behavior" @{git:superhome.lua|sol}
- @{400} "multiline search in mcedit"  @{git:search_by_regex.lua|sol}
- @{83} "editor needs read-only mode"  @{git:edit_read_only.lua|sol}

** SORTING **

(In general, see @{~mod:ui.Panel*ui.Panel:sort_field|panel.sort_field}.)

- @{2720} "hotkey to toggle between sort orders"
- @{3031} "Implement natural sort order" @{~fields#overriding|sol}
- @{2698} "sort hotkey"
- @{2719} "Conditional sort" and @{3497} "auto turn off sorting"  @{git:sort_by_filesystem.lua|sol}
- @{2717} "Sort order"  @{~fields#sort|sol}

** MARKING FILES **

(See @{~mod:ui.Panel#marking})

- @{3450} Quickly tag many adjacent files   @{git:mark_wordstar.lua|sol}
- @{2718} "select files by modification date"
- @{2916} "Select / filter by file size"
- @{1879} "restore previous selection"  @{git:restore-selection.lua|sol}
- @{2727} "Mark files to begin/end"
- @{3166} "Selection of Multiple Adjacent Files/Directories"
- @{2492} "select by grep"  @{git:mark_files_by_contents.lua|sol}
- @{3228} "select all files with the same extension as the current file"

** FILTER **

- @{114}  "hide dotfiles in home" @{ui.Panel:filter_by_fn|sol}
- @{2721} "Hotkey to toggle 'Hide none'"
- @{2697} and @{405} "Filter as you type"  @{git:filter-as-you-type.lua|sol1} @{git:visren/init.lua|sol2}
- @{3170} Filtering marked files  @{ui.Panel:filter_by_fn|sol}

** USABILITY OF MOVE/COPY DIALOGS **

- @{1684} "follow renamed file"             @{git:fop_move_jump.lua|sol}
- @{1907} "append filename to 'to:' input box"  @{git:fop_move_tail.lua|sol}
- @{1639} woes with "preserve attributes"        @{git:preserve-attributes.lua|sol}
- @{2486} "Move cursor to copied/moved file after activating panel"
- @{2699} "select only name without extension when renaming"   @{git:fop_move_basename.lua|sol}

** FOLLOW **

- @{2693} "implement 'follow symlink' command"   @{git:follow.lua|sol}
- @{2423} "jump to a destination upon pressing Enter in "Find Files" results panel"  @{git:follow.lua|sol}

** FIELDS **

- @{1852} "Support for ACL?"    @{~fields|sol}
- @{3165} "Display human readable sizes in panels"  @{git:better-size.lua|sol}

** DETACH **

- @{2666} "Start detached"
- @{2651} "Nautilus on Shift+Enter"

** MISC **

- @{3072} "delete to trash"
- @{197} "Generic handling for built-in commands"

** IN THEORY **

May not be possible right now but close:

- @{3130} "Panel Scroll Center"

quickview:

- @{2385} "Information about current file"
- @{2904} "Show extended attributes in Info window"

** UI **

- @{2979} "user friendly bookmark management"
- @{3006} "Unescape, reencode and insert string"
- @{1516} Browser-like 'about:config' dialog to set options
- @{2506} "udisks support" and @{1488} "Mountpoint selector"
- @{1577} "CD/DVD burning"

Frontend for archivers:

- @{2701} (and [GH#19](https://github.com/MidnightCommander/mc/issues/19)) "Compress to format..."
- @{3290} "Universal unpacking"
- @{2700} "Default extract method of compressed files"

** MCSCRIPT **

- @{2147} "create a skin repository"

** USABILITY **

- @{2011} "Warning at the entrance to the archive"
- @{2007} "insert name of the current file prefixed by ./"
- @{2374} "show exact files and free space sizes"              @{git:size-calculator.lua|sol}
- @{3221} "In 'Directory Hotlist' make right button work"      @{git:hotlist_right_as_enter.lua|sol}
- @{2397} "Auto replace wrong symbols when makes a new dir"    @{git:input_sanitize.lua|sol}
- @{2156} "Run editor from viewer"  @{git:viewer_edit.lua|sol}
- @{3453} Show search criteria in Find File result/progress dialog.  @{git:find_file_title.lua|sol}
- @{3493} "Switch 'Local'/'User' buttons on menu selector"     @{git:menu_user_button_focus.lua|sol}
- @{3495} Tweaking widgets default values  @{ui.open__event|sol}
- @{2928} "Indicate read only mode for directories"
- @{3551} "Ctrl+Space does not unselect directories: dangerous"  @{git:safer_dir_size.lua|sol}
- @{2389} "beep_when_finished, beep_when_interrupted"  @{ui.zzz_close__event|sol}, @{~mod:ui*dialog.colorset|sol}

** VFS **

No problem for LuaFS:

- @{2454} "Make reloading extfs contents possible"
- @{2997} "autodetecting files with different extensions"  @{git:luafs/panel.lua|sol} (on_panel_enter)
- @{3186} "Base64 and Quoted-Printable decode"  @{utils.text.transport|sol}
- @{3193} "mtp plugin"
- @{2392} "IMAP FS (MC + IMAP folders)"
- @{2387} "Persistent file mark" (nice!)

Can be solved by adding some hooks:

- @{3} "VFS optimization request"
- @{1640} "descript.ion support"
- @{2468} "Preserve extended attributes while copy"
- @{289} "Copy to temp panel"
- @{1983} "Add btrfs' file clone operation"
- @{3199} "show long operation progress in xterm window title"
