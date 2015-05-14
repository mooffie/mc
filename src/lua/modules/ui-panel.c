/**
 * A panel widget is the central component in MC's display. It lists files.
 *
 * Note: A pane has four modes: it may display a tree, a quick-view,
 * one file's information, or file listing. When we speak of a "panel" we
 * always refer to the **file listing** mode.)
 *
 * @classmod ui.Panel
 */

#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"

#include "src/setup.h"          /* panels_options */
#include "src/filemanager/panel.h"
#include "src/filemanager/midnight.h"   /* view_listing (via layout.h) */
#include "src/filemanager/panelize.h"   /* do_external_panelize() */

#include "../capi.h"
#include "../modules.h"
#include "ui-impl.h"
#include "fs.h"


/* See comment for LUA_TO_BUTTON, in ui.c */
#define LUA_TO_PANEL(L, i) ((WPanel *) luaUI_check_widget (L, i))

/* Our own flavor of midnight.c:update_dirty_panels(). */
static void
redraw_dirty_panel (WPanel * panel)
{
    if (panel->dirty)
        widget_redraw (WIDGET (panel));
}

/**
 * General methods.
 * @section panel-general
 */

/**
 * The panel's directory.
 *
 *    -- Insert the panel's directory name into the command line.
 *    ui.Panel.bind("f16", function(pnl)
 *      local ipt = ui.current_widget("Input")
 *      if ipt then
 *        ipt:insert(pnl.dir)
 *      end
 *    end)
 *
 *    -- This is a better version of the above, which works for
 *    -- any input line.
 *    ui.Input.bind("f16", function(ipt)
 *      -- When using mcedit there are no panels, hence the "and" check below.
 *      ipt:insert(ui.Panel.current and ui.Panel.current.dir or "")
 *    end)
 *
 *    -- An even better version!
 *    ui.Input.bind("f16", function(ipt)
 *      ipt:insert(fs.current_dir())
 *    end)
 *
 * Note: To change the panel's directory you can do either
 * `pnl.dir = '/whatever'` or `pnl:set_dir('/whatever')` (the former being
 * syntactic sugar for the latter). The latter lets you inspect the return
 * value to see if the operation was successful.
 *
 * See also @{vdir}.
 *
 * @attr dir
 * @property rw
 */
static int
l_panel_get_dir (lua_State * L)
{
    lua_pushstring (L, LUA_TO_PANEL (L, 1)->cwd_vpath->str);
    return 1;
}

/**
 * The panels directory (as vpath).
 *
 * @attr vdir
 * @property rw
 */
static int
l_panel_get_vdir (lua_State * L)
{
    luaFS_push_vpath (L, LUA_TO_PANEL (L, 1)->cwd_vpath);
    return 1;
}

static int
l_panel_set_vdir (lua_State * L)
{
    WPanel *panel;
    const vfs_path_t *new_dir;

    panel = LUA_TO_PANEL (L, 1);
    new_dir = luaFS_check_vpath (L, 2);

    lua_pushboolean (L, do_panel_cd (panel, new_dir, cd_exact));

    /*
     * Changing a panel's dir also calls mc_chdir(). So if we change the "other"
     * panel's dir, the current panel's dir will no longer be the current dir. As
     * a result the user will see error messages about non existing files.
     *
     * So we refocus the current panel to trigger re-chdir() to the current
     * panel's dir.
     */
    if (current_panel && current_panel != panel)
        dlg_select_widget (current_panel);

    redraw_dirty_panel (panel);
    return 1;
}

/**
 * Reloads the panel.
 *
 * (An operation also known as "rescan" or "reread" in MC.)
 *
 * Currently, because of some deficiency in MC's API, this method reloads
 * _both_ panels.
 *
 * Info: You may alternatively do `pnl.dialog:command "reread"`; it reloads the
 * "current" panel only. But it might be that it's the "other" panel you want
 * reloaded.
 *
 * @method reload
 */
static int
l_panel_reload (lua_State * L)
{
    WPanel *panel;

    panel = LUA_TO_PANEL (L, 1);

    (void) panel;

    /* This updates both panels. That's the only non low-level public function
     * available to us. */
    update_panels (UP_RELOAD, UP_KEEPSEL);
    /* We don't use panel_reload() directly: it doesn't keep the selected file,
     * and it doesn't send VFS_SETCTL_FLUSH to the VFS. */

    do_refresh ();
    return 0;
}

/**
 * Whether the listing is "panelized".
 *
 * [info]
 *
 * Under the @{git:panel.h|hood}, `panelized` is merely a flag set on a
 * panel that tells MC not to reload the listing. Setting (or clearing) this
 * flag has no other consequence. Specifically: it won't cause a reload (if
 * that's your intention (which only you know) you'll have to call @{reload}
 * yourself).
 *
 * See a comment in @{filter_by_fn} demonstrating the usefulness of this
 * property.
 *
 * [/info]
 *
 * @attr panelized
 * @property rw
 */
static int
l_panel_get_panelized (lua_State * L)
{
    lua_pushboolean (L, LUA_TO_PANEL (L, 1)->is_panelized);
    return 1;
}

static int
l_panel_set_panelized (lua_State * L)
{
    WPanel *panel;
    gboolean enable;

    panel = LUA_TO_PANEL (L, 1);
    enable = lua_toboolean (L, 2);

    panel->is_panelized = enable;

    widget_redraw (WIDGET (panel));     /* So that the "Panelize" indicator appears. */
    return 0;
}


/**
 * External panelize.
 *
 * Populates the panel with the output of a shell command.
 *
 *    -- Filters ("panelizes", to be exact) the panel to only
 *    -- the files with the same extension as the current file.
 *    -- Files in subfolders too are shown.
 *
 *    ui.Panel.bind('C-a', function(pnl)
 *
 *      local orig_current = pnl.current
 *      local extension = pnl.current:match '.*(%..*)' or ''
 *
 *      pnl:external_panelize(('find . -name "*"%q -print'):format(extension))
 *
 *      -- Restore the cursor to the file we've been standing on originally:
 *      pnl.current = orig_current
 *
 *    end)
 *
 * @method external_panelize
 * @args (command)
 */
static int
l_panel_external_panelize (lua_State * L)
{
    WPanel *panel;
    const char *command;

    panel = LUA_TO_PANEL (L, 1);
    command = luaL_checkstring (L, 2);

    /* do_external_panelize() works on the current panel only. So
     * we have to select (aka focus) our panel in case it's not the current.
     * @FIXME: do_external_panelize() should be fixed to work on any panel. */
    dlg_select_widget (WIDGET (panel));

    /* @FIXME: do_external_panelize() should accept 'const char *'. */
    do_external_panelize (const_cast (char *, command));

    widget_redraw (WIDGET (panel));
    return 0;
}

/**
 * The filter.
 *
 * A shell pattern determining the files to show. Set it to **nil** if
 * you want to clear the filter. Example:
 *
 *    ui.Panel.bind('C-y', function(pnl)
 *      pnl.filter = '*.c'
 *    end)
 *
 * [note]
 *
 * MC has two _filter_ bugs:
 *
 * - When the filter is the empty string (`""`), the panel header won't give
 *   an indication that a filter is active.
 * - When the "Shell patterns" option is off, the filter string will still be
 *   interpreted as a shell pattern instead of a regex.
 *
 * Additionally, a filter doesn't affect a panelized panel.
 *
 * [/note]
 *
 * @attr filter
 * @property rw
 */
static int
l_panel_set_filter (lua_State * L)
{
    set_panel_filter_to (LUA_TO_PANEL (L, 1), g_strdup (luaL_optstring (L, 2, "*")));
    return 0;
}

static int
l_panel_get_filter (lua_State * L)
{
    lua_pushstring (L, LUA_TO_PANEL (L, 1)->filter);    /* NULL-safe */
    return 1;
}

/**
 * @section end
 */

/**
 * Marking and unmarking files
 *
 * @section
 */

/**

  This empty section comes here to circumvent an ldoc problem: we want
  "Static panel functions" to appear last. So we have to exhaust all
  other sections before arriving at it.

*/

/**
 * The view.
 * @section panel-view
 */

/* Taken from configure_panel_listing(). It's how a panel is updated after
 * some display setting changes. */
static void
update_view (WPanel * panel)
{
    set_panel_formats (panel);
    widget_redraw (WIDGET (panel));     /* configure_panel_listing() does do_refresh(), which is an overkill. */
}

/**
 * Whether to show a custom format for the mini status.
 *
 * Boolean.
 *
 * @attr custom_mini_status
 * @property rw
 */
static int
l_get_custom_mini_status (lua_State * L)
{
    lua_pushboolean (L, LUA_TO_PANEL (L, 1)->user_mini_status);
    return 1;
}

static int
l_set_custom_mini_status (lua_State * L)
{
    WPanel *panel;
    gboolean enable;

    panel = LUA_TO_PANEL (L, 1);
    enable = lua_toboolean (L, 2);

    /* Taken from configure_panel_listing(). */
    panel->user_mini_status = enable;

    update_view (panel);
    return 0;
}

/**
 * Custom format for the mini status.
 *
 * When @{custom_mini_status} is enabled, this property is the format to use.
 *
 *    ui.Panel.bind('C-y', function(pnl)
 *      pnl.custom_mini_status = true
 *      pnl.custom_mini_status_format = "half type name:20 | gitcommit:10 | gitmessage"
 *    end)
 *
 * Info: MC keeps track of **four** custom mini-status formats: one per each
 * @{list_type}. This @{custom_mini_status_format} property reflects the one
 * belonging to the list_type currently in use.
 *
 * @attr custom_mini_status_format
 * @property rw
 */
static int
l_get_custom_mini_status_format (lua_State * L)
{
    WPanel *panel;

    panel = LUA_TO_PANEL (L, 1);

    lua_pushstring (L, panel->user_status_format[panel->list_type]);
    return 1;
}

static int
l_set_custom_mini_status_format (lua_State * L)
{
    WPanel *panel;
    const char *format;

    panel = LUA_TO_PANEL (L, 1);
    format = luaL_checkstring (L, 2);

    /* Taken from configure_panel_listing(). */
    g_free (panel->user_status_format[panel->list_type]);
    panel->user_status_format[panel->list_type] = g_strdup (format);

    update_view (panel);
    return 0;
}

/**
 * The list type.
 *
 * How files are listed. It is one of "full", "brief", "long", or "custom".
 * For "custom", the format is specified with @{custom_format}.
 *
 * Info: "custom" is entitled "User defined" in MC's interface. In our API we
 * use the word "custom", rather than "user", because the latter isn't too
 * clear when it appears in names of the other properties.
 *
 * @attr list_type
 * @property rw
 */
static int
l_set_list_type (lua_State * L)
{
    static const char *const lt_names[] = { "full", "brief", "long", "custom", NULL };
    static const int lt_types[] = { list_full, list_brief, list_long, list_user };

    WPanel *panel;
    int list_type;

    panel = LUA_TO_PANEL (L, 1);
    list_type = lt_types[luaL_checkoption (L, 2, NULL, lt_names)];

    /* Taken from configure_panel_listing(). */
    panel->list_type = list_type;

    update_view (panel);
    return 0;
}

static int
l_get_list_type (lua_State * L)
{
    WPanel *panel = LUA_TO_PANEL (L, 1);

    const char *lt;
    switch (panel->list_type)
    {
        /* *INDENT-OFF* */
        case list_full:  lt = "full";   break;
        case list_brief: lt = "brief";  break;
        case list_long:  lt = "long";   break;
        case list_user:  lt = "custom"; break; /* Not "user". See rationale in ldoc. */
        default:         lt = "unknown";
        /* *INDENT-ON* */
    }
    lua_pushstring (L, lt);
    return 1;
}

/**
 * Custom format for the listing.
 *
 * When @{list_type} is set to "custom", this property specifies the format
 * to use.
 *
 *    ui.Panel.bind('C-y', function(pnl)
 *      pnl.list_type = "custom"
 *      pnl.custom_format = "half type name | size | perm | gitstatus | gitdate | gitauthor | gitmessage"
 *    end)
 *
 * The syntax of the format string is:
 * 
 *    all              := panel_format? format
 *    panel_format     := [full|half] [1|2]
 *    format           := one_format | format , one_format
 *
 *    one_format       := align FIELD_ID [opt_width]
 *    align            := [<=>]
 *    opt_width        := : size [opt_expand]
 *    width            := [0-9]+
 *    opt_expand       := +
 *
 * (Let us all give thanks to the anonymous programmer, blessed be he, who put
 * this comment in @{git:src/filemanager/panel.c}.)
 *
 * @attr custom_format
 * @property rw
 */
static int
l_set_custom_format (lua_State * L)
{
    WPanel *panel;
    const char *format;

    panel = LUA_TO_PANEL (L, 1);
    format = luaL_checkstring (L, 2);

    /* Taken from configure_panel_listing(). */
    g_free (panel->user_format);
    panel->user_format = g_strdup (format);

    update_view (panel);
    return 0;
}

static int
l_get_custom_format (lua_State * L)
{
    lua_pushstring (L, LUA_TO_PANEL (L, 1)->user_format);
    return 1;
}

/**
 * The field by which to sort.
 *
 *    -- Toggle between two sorts.
 *    ui.Panel.bind('C-y', function(pnl)
 *      if pnl.sort_field == "name" then
 *        pnl.sort_field = "size"
 *      else
 *        pnl.sort_field = "name"
 *    end)
 *
 * @attr sort_field
 * @property rw
 */

static int
l_get_sort_field (lua_State * L)
{
    lua_pushstring (L, LUA_TO_PANEL (L, 1)->sort_field->id);
    return 1;
}

static int
l_set_sort_field (lua_State * L)
{
    WPanel *panel;
    const char *id;

    const panel_field_t *field;

    panel = LUA_TO_PANEL (L, 1);
    id = luaL_checkstring (L, 2);

    field = panel_get_field_by_id (id);

    if (!field)
        luaL_error (L, _("Unknown field '%s'"), id);
    if (!field->sort_routine)
        luaL_error (L, _("Field '%s' isn't sortable"), id);

    panel_set_sort_order (panel, field);

    redraw_dirty_panel (panel);
    return 0;
}

/**
 * Whether to reverse the sort.
 *
 *    ui.Panel.bind('C-y', function(pnl)
 *      pnl.sort_reverse = not pnl.sort_reverse
 *    end)
 *
 * @attr sort_reverse
 * @property rw
 */

static int
l_get_sort_reverse (lua_State * L)
{
    lua_pushboolean (L, LUA_TO_PANEL (L, 1)->sort_info.reverse);
    return 1;
}

static int
l_set_sort_reverse (lua_State * L)
{
    WPanel *panel;
    gboolean reverse;

    panel = LUA_TO_PANEL (L, 1);
    reverse = lua_toboolean (L, 2);

    panel->sort_info.reverse = reverse;
    panel_re_sort (panel);

    redraw_dirty_panel (panel);
    return 0;
}

/**
 * @section end
 */

/**
 * Low-level methods.
 *
 * These methods aren't intended for use by end-users. These are methods
 * upon which higher-level methods are built.
 *
 * [info]
 *
 * A note to MC developers: these methods are implemented in C. Higher-level
 * methods are implemented in Lua. This lets us experiment easily in
 * designing the public API.
 *
 * [/info]
 *
 * @section panel-lowlevel
 */

/**
 * Gets the index of the current ("selected") file.
 *
 * @method _get_current_file_index
 */
static int
l_panel_get_current_file_index (lua_State * L)
{
    lua_pushinteger (L, LUA_TO_PANEL (L, 1)->selected + 1);
    return 1;
}

/**
 * Sets the the current ("selected") file, by index.
 *
 * @method _set_current_file_index
 * @args (i)
 */
static int
l_panel_set_current_file_index (lua_State * L)
{
    WPanel *panel;
    int i;

    panel = LUA_TO_PANEL (L, 1);
    i = luaL_checkint (L, 2) - 1;

    panel->selected = i;
    select_item (panel);

    redraw_dirty_panel (panel);
    return 0;
}

/**
 * Gets meta information about a file.
 *
 * Multiple values are returned. See @{ui.Panel:current|current} for details.
 *
 * @method _get_file_by_index
 * @param i index
 * @param skip_stat Whether to return a nil instead of the @{fs.StatBuf|StatBuf} (for efficiency).
 */
static int
l_panel_get_file_by_index (lua_State * L)
{
    WPanel *panel;
    int i;
    gboolean skip_stat;

    panel = LUA_TO_PANEL (L, 1);
    i = luaL_checkint (L, 2) - 1;
    skip_stat = lua_toboolean (L, 3);

    if (i < panel->dir.len)
    {
        file_entry_t *fe;

        fe = &panel->dir.list[i];

        lua_pushstring (L, fe->fname);
        if (!skip_stat)
            luaFS_push_statbuf (L, &fe->st);
        else
            lua_pushnil (L);
        lua_pushboolean (L, fe->f.marked);
        lua_pushboolean (L, i == panel->selected);
        lua_pushboolean (L, fe->f.stale_link);
        lua_pushboolean (L, fe->f.dir_size_computed);
        /* How many values we pushed. Make sure to update this if you change the above. */
        return 6;
    }
    else
        return 0;
}

/**
 * Gets the number of files in the panel.
 *
 * @method _get_max_index
 */
static int
l_panel_get_max_index (lua_State * L)
{
    lua_pushinteger (L, LUA_TO_PANEL (L, 1)->dir.len);
    return 1;
}

/**
 * Changes the mark status of a file.
 *
 * Note: For efficiency, this function doesn't redraw the widget. After
 * you're done marking the files you want, call :redraw() yourself.
 *
 * @method _mark_file_by_index
 * @param i index
 * @param mark Boolean. Whether to mark or unmark the file.
 */
static int
l_panel_mark_file_by_index (lua_State * L)
{
    WPanel *panel;
    int i;
    gboolean mark;

    panel = LUA_TO_PANEL (L, 1);
    i = luaL_checkint (L, 2) - 1;
    mark = lua_toboolean (L, 3);

    do_file_mark (panel, i, mark);

    return 0;
}

/*
 * Removes an entry from the panel. used by pnl:_remove().
 */
static void
panel_remove_entry (WPanel * panel, int i)
{
    dir_list dir = panel->dir;

    if (i < 1 || i >= panel->dir.len)
        return;

    g_free (dir.list[i].fname);

    memmove (&dir.list[i], &dir.list[i + 1], sizeof dir.list[0] * (panel->dir.len - i - 1));

    /* @todo: we should also update panel->marked and and panel->total. */

    panel->dir.len--;

    if (panel->selected > i || panel->selected == panel->dir.len)
        panel->selected--;
}

/**
 * Removes a file.
 *
 * Removes a file from the listing (not from disk, of course), by its index.
 *
 * This can be used to implement filtering.
 *
 * (The panel is not redrawn --for efficiency-- as it's assumed you might
 * want to remove multiple files. You have to call :redraw() yourself.)
 *
 * @method _remove
 * @param i index
 */
static int
l_panel_remove (lua_State * L)
{
    WPanel *panel;
    int i;

    panel = LUA_TO_PANEL (L, 1);
    i = luaL_checkint (L, 2);

    panel_remove_entry (panel, i - 1);

    return 0;
}

/**
 * Returns various measurements.
 *
 * Returns several values, in this order:
 *
 * - The index of the top file displayed.
 * - The number of screen lines used for displaying files.
 * - The number of columns.
 *
 * @method _get_metrics
 */

/*
 * The following #def was copied from panel.c. @FIXME: remove.
 */

/* This macro extracts the number of available lines in a panel */
#define llines(p) (WIDGET (p)->lines - 3 - (panels_options.show_mini_info ? 2 : 0))

static int
l_panel_get_metrics (lua_State * L)
{
    WPanel *panel;

    panel = LUA_TO_PANEL (L, 1);

    lua_pushinteger (L, panel->top_file + 1);
    lua_pushinteger (L, llines (panel));
    lua_pushinteger (L, panel->split ? 2 : 1);

    return 3;
}

/**
 * @section end
 */

/**
 * Static panel functions.
 *
 * Any of the properties below may return **nil**. E.g., if the left pane is
 * showing a directory tree, @{left} will return **nil**; when running as
 * "mcedit", @{current} will return **nil**. So don't assume the panels exist.
 *
 * @section panel-static
 */
static int
push_panel (lua_State * L, int panel_idx)
{
    /* *INDENT-OFF* */
    luaUI_push_widget (L, (get_display_type (panel_idx) == view_listing ? get_panel_widget (panel_idx) : NULL), TRUE);
    /* *INDENT-ON* */
    return 1;
}

/**
 * The left panel.
 *
 * @attr ui.Panel.left
 * @property r
 */
static int
l_get_left (lua_State * L)
{
    return push_panel (L, 0);
}

/**
 * The right panel.
 *
 * @attr ui.Panel.right
 * @property r
 */
static int
l_get_right (lua_State * L)
{
    return push_panel (L, 1);
}

/**
 * The "current" panel.
 *
 *    -- Insert the panel's dir into the edited text. (tip:
 *    -- replace "Editbox" with "Input" to make it work with
 *    -- any input box.)
 *    ui.Editbox.bind('C-y', function(edt)
 *      -- "<none>" is emitted when using mcedit.
 *      edt:insert(ui.Panel.current and ui.Panel.current.dir or "<none>")
 *    end)
 *
 * @attr ui.Panel.current
 * @property r
 */
static int
l_get_current (lua_State * L)
{
    return push_panel (L, get_current_index ());
}

/**
 * The "other" panel.
 *
 * That's the panel which is not the @{current} one.
 *
 *    ui.Panel.bind('f5', function(pnl)
 *      alert(T"You wanna copy something from here to %s":format(
 *        ui.Panel.other and ui.Panel.other.dir or T"<nowhere>"))
 *    end)
 *
 * @attr ui.Panel.other
 * @property r
 */
static int
l_get_other (lua_State * L)
{
    return push_panel (L, get_other_index ());
}

/**
 * @section end
 */

/**
 * Events
 *
 * @section
 */

/**
 * Triggered after a panel has been painted.
 *
 * You may use this event to add more information to a panel's display.
 *
 *    -- Prints the directory at the panel's bottom.
 *
 *    ui.Panel.bind('<<draw>>', function(pnl)
 *      local c = pnl:get_canvas()
 *      c:set_style(tty.style('yellow, red'))
 *      c:goto_xy(2, pnl.rows - 1)
 *      c:draw_string(pnl.dir)
 *    end)
 *
 * @moniker draw
 * @event
 */

/**
 * Triggered after a directory has been read into the panel.
 *
 * This happens, for example, when you navigate to a new directory, when you
 * return from running a shell command, or when you reload (`C-r`) the panel.
 *
 * You may use this event to clear caches, as
 * @{~fields!clearing-cache|demonstrated} in the user guide. You may also
 * use it, together with @{activate|<<activate>>}, to inform the
 * environment of the current directory.
 *
 *    ui.Panel.bind("<<load>>", function(pnl)
 *      ....
 *    end)
 *
 * @moniker load
 * @event
 */

/**
 * Triggered when the user reloads (`C-r`) the panel.
 *
 * You may use this event to clear *expensive* caches, as
 * @{~fields!clearing-cache|demonstrated} in the user guide.
 *
 *    ui.Panel.bind("<<flush>>", function(pnl)
 *      ....
 *    end)
 *
 * Info-short: Filesystems have their own @{luafs.flush|flush event}.
 *
 * @moniker flush
 * @event
 */

/**
 * Triggered when a panel becomes the @{ui.Panel.current|current} one.
 * (E.g., as a result of tabbing to it.)
 *
 *    ui.Panel.bind("<<activate>>", function(pnl)
 *      ....
 *    end)
 *
 * Example: The @{git:set-gterm-cwd.lua} script uses this event, together
 * with @{load|<<load>>}, to inform GNOME Terminal of the current
 * directory.
 *
 * @moniker activate
 * @event
 */

/**
 * Triggered when a file is selected in the panel.
 *
 * Note: When we say that a file is "selected" we mean that it becomes the
 * @{ui.Panel:current|current} file. Don't confuse the current file with
 * the @{marked} files: the current file isn't necessarily marked.
 *
 *    -- Read aloud the current filename, after the user
 *    -- rests on it for a second.
 *
 *    local say = timer.debounce(function(text)
 *      -- Note: we run espeak in the background (&) or else
 *      -- we'll be blocked till it finishes voicing the text.
 *      os.execute(('espeak %q &'):format(text))
 *    end, 1000)
 *
 *    ui.Panel.bind("<<select-file>>", function(pnl)
 *      say(pnl.current)
 *    end)
 *
 * @moniker select-file
 * @event
 */

/**
 * @section end
 */

/* *INDENT-OFF* */
static const struct luaL_Reg ui_panel_static_lib[] = {
    { "get_left", l_get_left },
    { "get_right", l_get_right },
    { "get_current", l_get_current },
    { "get_other", l_get_other },
    { NULL, NULL }
};

static const struct luaL_Reg ui_panel_lib[] = {
    { "get_dir", l_panel_get_dir },
    { "set_dir", l_panel_set_vdir },
    { "get_vdir", l_panel_get_vdir },
    { "set_vdir", l_panel_set_vdir },
    { "set_filter", l_panel_set_filter },
    { "get_filter", l_panel_get_filter },
    { "set_panelized", l_panel_set_panelized },
    { "get_panelized", l_panel_get_panelized },
    { "external_panelize", l_panel_external_panelize },
    { "reload", l_panel_reload },
    { "set_list_type", l_set_list_type },
    { "get_list_type", l_get_list_type },
    { "get_custom_format", l_get_custom_format },
    { "set_custom_format", l_set_custom_format },
    { "get_custom_mini_status", l_get_custom_mini_status },
    { "set_custom_mini_status", l_set_custom_mini_status },
    { "get_custom_mini_status_format", l_get_custom_mini_status_format },
    { "set_custom_mini_status_format", l_set_custom_mini_status_format },
    { "set_sort_field", l_set_sort_field },
    { "get_sort_field", l_get_sort_field },
    { "get_sort_reverse", l_get_sort_reverse },
    { "set_sort_reverse", l_set_sort_reverse },
    { "_get_current_file_index", l_panel_get_current_file_index },
    { "_set_current_file_index", l_panel_set_current_file_index },
    { "_get_file_by_index", l_panel_get_file_by_index },
    { "_mark_file_by_index", l_panel_mark_file_by_index },
    { "_get_max_index", l_panel_get_max_index },
    { "_remove", l_panel_remove },
    { "_get_metrics", l_panel_get_metrics },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_ui_panel (lua_State * L)
{
    create_widget_metatable (L, "Panel", ui_panel_lib, ui_panel_static_lib, "Widget");
    return 0;                   /* Nothing to return! */
}

