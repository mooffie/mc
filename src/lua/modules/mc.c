/**
 * High-level Midnight Commander services.
 *
 * @module mc
 */

#include <config.h>

#include "lib/global.h"
#include "lib/vfs/vfs.h"
#include "lib/event.h"          /* mc_event_raise() */
#include "lib/lua/capi.h"
#include "lib/lua/utilx.h"

#include "src/execute.h"        /* shell_execute() */

#include "../modules.h"
#include "tty.h"                /* luaTTY_assert_ui_is_ready() */
#include "fs.h"

/* The following are needed for invoking the editor, viewer, diff: */

#include "src/setup.h"          /* use_internal_view, use_internal_edit */
#include "src/filemanager/cmd.h"        /* view_file_at_line(), view_file(), edit_file_at_line(), do_edit() */
#include "src/filemanager/ext.h"        /* regex_command() */
#include "src/viewer/mcviewer.h"        /* mcview_viewer() */
#ifdef USE_DIFF_VIEW
#include "src/diffviewer/ydiff.h"       /* dview_diff_cmd() */
#endif

/* The following are needed for l_expand_format() */

#include "src/editor/editwidget.h"      /* WEdit type */
#include "src/filemanager/usermenu.h"   /* expand_format() */


/**
 * Applications.
 *
 * @section
 */

/**
 * Launches the viewer.
 *
 * @function view
 * @param path
 * @param[opt] line -- Scroll to this line. Leave empty (or zero) to load saved position.
 * @param[opt] internal -- Boolean. Whether to force using the internal
 *   viewer. Leave empty for user preference.
 * @param[opt] raw -- Boolean.  If set, does not do any fancy pre-processing
 *   (no filtering). Implies "internal".
 */
static int
l_view (lua_State * L)
{
    const vfs_path_t *vpath;
    long line;
    gboolean internal;
    gboolean plain_view;

    luaTTY_assert_ui_is_ready (L);

    /* *INDENT-OFF* */
    vpath      = luaFS_check_vpath (L, 1);
    line       = luaL_optlong (L, 2, 0);  /* 0 = load saved position */
    internal   = luaMC_optboolean (L, 3, use_internal_view);
    plain_view = lua_toboolean (L, 4);
    /* *INDENT-ON* */

    view_file_at_line (vpath, plain_view, internal, line, 0, 0);

    return 0;
}

/**
 * Launches the viewer to view the output of a command.
 *
 *    mc.view_command("ls -la")
 *
 * Another example:
 *
 *    -- Execute the command-line "into" the viewer. Can be useful.
 *    ui.Input.bind("f17", function(ipt)
 *      mc.view_command(ipt.text)
 *    end)
 *
 * @function view_command
 * @param command
 * @param[opt] line
*/

static int
l_view_command (lua_State * L)
{
    const char *command;
    long line;

    luaTTY_assert_ui_is_ready (L);

    command = luaL_checkstring (L, 1);
    line = luaL_optlong (L, 2, 0);

    mcview_viewer (command, NULL, line, 0, 0);

    /* Any code that calls mcview_viewer(), which may end up leaving a modaless
       dialog, has to call dialog_switch_process_pending() afterwards. */
    dialog_switch_process_pending ();

    return 0;
}

/**
 * Launches the editor.
 *
 * Example:
 *
 *    mc.edit('/etc/issue')
 *
 * @function edit
 *
 * @param path
 * @param[opt] line -- Start with the cursor positioned on this line. Leave
 *   empty (or zero) to load saved position.
 * @param[opt] internal -- Boolean. Whether to force using the internal
 *   editor. Leave empty for user preference.
 */
static int
l_edit (lua_State * L)
{
    const vfs_path_t *vpath;
    long line;
    gboolean internal;

    luaTTY_assert_ui_is_ready (L);

    /* *INDENT-OFF* */
    vpath    = luaFS_check_vpath (L, 1);
    line     = luaL_optlong (L, 2, 0);  /* 0 = load saved position */
    internal = luaMC_optboolean (L, 3, use_internal_edit);
    /* *INDENT-ON* */

    /*
     * @FIXME:
     *
     * If line != 0, then file will vanish from `$HOME/.local/share/mc/filepos`
     * (when "Save file position" is enabled) upon existing the editor, if
     * cursor is at beginning of buffer and no bookmarks.
     *
     * Some would suggest that this is the correct behavior, but this
     * does *not* happen when editing via <F4>. Besides, this could be a
     * nice feature on which the following feature request is based:
     *
     *   http://www.midnight-commander.org/ticket/280
     *   http://www.midnight-commander.org/ticket/2733
     */
    edit_file_at_line (vpath, internal, line);

    return 0;
}


#ifdef USE_DIFF_VIEW

/**
 * Launches the diff-viewer.
 *
 * @function diff
 * @args (path1, path2)
 */
static int
l_diff (lua_State * L)
{
    const vfs_path_t *vpath1;
    const vfs_path_t *vpath2;

    mc_run_mode_t saved_mode;

    luaTTY_assert_ui_is_ready (L);

    vpath1 = luaFS_check_vpath (L, 1);
    vpath2 = luaFS_check_vpath (L, 2);

    /* @FIXME: dview_diff_cmd() should be refactored. Then we won't need this acrobatics. */
    saved_mode = mc_global.mc_run_mode;
    mc_global.mc_run_mode = MC_RUN_DIFFVIEWER;
    dview_diff_cmd (vpath1->str, vpath2->str);
    mc_global.mc_run_mode = saved_mode;

    return 0;
}

#else

static int
l_diff (lua_State * L)
{
    return luaL_error (L, "%s", _("The diff viewer has not been compiled in."));
}

#endif

/**
 * Launches the help viewer.
 *
 * @function help
 * @param[opt] help_id The name of the section to display. Leave empty for the main section.
 * @param[opt] help_file The path to the help file. Leave empty for the builtin help file.
 */
static int
l_help (lua_State * L)
{
    ev_help_t event_data = { NULL, NULL };

    event_data.node = luaL_optstring (L, 1, NULL);
    event_data.filename = luaL_optstring (L, 2, NULL);

    mc_event_raise (MCEVENT_GROUP_CORE, "help", &event_data);

    return 0;
}

static void
assert_not_standalone (lua_State * L)
{
    if (mc_global.mc_run_mode == MC_RUN_SCRIPT)
        luaL_error (L, "%s", _("This function is not safe to run in standalone mode."));
}

/**
 * "Opens" a document.
 *
 *    -- View a picture. (Note that the file is inside an archive, and
 *    -- there's no problem in that.)
 *    mc.activate("/media/web/pictures.rar/urar://london/big ben.jpg")
 *
 * The short description:
 *
 * Normally, when you hit Enter while standing on a document (e.g., a picture,
 * video file, etc.), MC "opens" it by launching the associated application.
 * That's what this function does.
 *
 * The long description:
 *
 * MC has an "extension file", which is a database that describes how to carry
 * out actions --notably "Open", "View" and "Edit"-- on a file. What this
 * function does is carry out the actions described in that database. By
 * default it carries out the "Open" action, but by supplying the **action**
 * parameter you can carry out any other action.
 *
 * [info]
 *
 * There's a convention in the extension file to capitalize action names. So
 * make sure to type "Edit", not "edit". But if it's editing or viewing you're
 * after, simply use @{mc.edit} or @{mc.view}.
 *
 * [/info]
 *
 * __Returns:__
 *
 * The string "ok", "missing", or "error".
 *
 * @function activate
 * @args (path[, action])
 */
static int
l_activate (lua_State * L)
{
    const vfs_path_t *vpath;
    const char *action;

    /* Standalone: it looks safe (and useful) for Open, but what
     * about Edit and View? */
    assert_not_standalone (L);

    vpath = luaFS_check_vpath (L, 1);
    action = luaL_optstring (L, 2, "Open");

    /* *INDENT-OFF* */
    switch (regex_command (vpath, action)) {
        case 1:  lua_pushliteral (L, "ok");      break;
        case 0:  lua_pushliteral (L, "missing"); break;
        default: lua_pushliteral (L, "error");   break;
    }
    /* *INDENT-ON* */

    return 1;
}

/**
 * Shell.
 *
 * @section
 */

/**
 * Executes a command as if typed at the prompt.
 *
 *    mc.execute("ls -la")
 *
 * If you aren't interested in the visual implications of this function,
 * or if you wish to process the output of the command, then you should
 * use @{os.execute} or @{io.popen} instead.
 *
 * You can use this function even when the prompt isn't visible; e.g.,
 * inside the editor or the viewer. The user is always able to press C-o to
 * see the command's output.
 *
 * [info]
 *
 * If the panel displays a directory of a non-local filesystem, the shell's
 * "current directory" will be a different one, of course. If you want to
 * guard against this, do:
 *
 *    if fs.current_vdir():is_local() then
 *      mc.execute("ls -l")
 *    else
 *      alert(T"Cannot execute commands on non-local filesystems")
 *    end
 *
 * If you do want to execute a shell command on a file on a non-local
 * filesystem, do that with the help of @{fs.getlocalcopy}.
 *
 * [/info]
 *
 * Note-short: Percent-tokens (e.g. "%d/%f") aren't recognized. Use
 * @{expand_format} if you need these.
 *
 * @function execute
 * @args (s)
 */
static int
l_execute (lua_State * L)
{
    luaTTY_assert_ui_is_ready (L);
    shell_execute (luaL_checkstring (L, 1), 0);
    return 0;
}

/**
 * Surprisingly, MC itself doesn't have this utility function. @FIXME.
 */
static char *
expand_format__string (const char *template, WEdit * edit_widget, gboolean do_quote)
{
    GString *buf = g_string_sized_new (32);
    const char *p = template;

    while (*p)
    {
        if (*p != '%')
            g_string_append_c (buf, *p);
        else
        {
            char *s;

            s = expand_format (edit_widget, *(++p), do_quote);
            g_string_append (buf, s);
            g_free (s);
        }

        if (*p)                 /* Protect against '%' at end of string. */
            p++;
    }

    return g_string_free (buf, FALSE);
}

/**
 * Expands a format string.
 *
 * A "format string" is a text with some embedded percent-tokens in it.
 *
 *    ui.Panel.bind("f16", function(pnl)
 *      mc.execute(mc.expand_format("echo You are standing on %f"))
 *    end)
 *
 *    ui.Editbox.bind("f16", function(edt)
 *      alert(mc.expand_format("You're editing a file of type %y.", edt, true))
 *    end)
 *
 * For a list of the available tokens, see @{git:usermenu.c|src/filemanager/usermenu.c:expand_format()}.
 *
 * Note: While this function seems useful, there's not much reason to use it
 * as you have the power of a programming language and can access a panel's
 * (and editbox') properties directly.
 *
 * @function expand_format
 * @args (s, [editbox], [dont_quote])
 */
static int
l_expand_format (lua_State * L)
{
    const char *template;
    Widget *w;
    gboolean dont_quote;

    /* expand_format() may not be safe on standalone mode. It does
     * name_quote() on a NULL, which triggers strlen(NULL). Whatever,
     * this function is probably useless for standalone mode to begin
     * with, as there are no panels. */
    assert_not_standalone (L);

    template = lua_tostring (L, 1);
    w = NULL; /* @todo */
    dont_quote = lua_toboolean (L, 3);

    luaMC_pushstring_and_free (L, expand_format__string (template, (WEdit *) w, !dont_quote));

    return 1;
}

/**
 * Quotes a filename to be used by the shell.
 *
 * This is like @{utils.text.shell_quote}, with the following differences
 * which make it more suitable for quoting filenames to be used on the
 * command line:
 *
 * - If the string begins with "-", the function precedes it with "./" (so
 * that it won't be mistaken, by the program you'll be handing it to, for
 * an option name).
 *
 * - If the `quote_percent` flag is **true**, replaces "%" with "%%" (as this
 * char, undoubled, is processed by MC's command line).
 *
 * Example:
 *
 *    -- Inserts the currently selected filename into the command line.
 *
 *    ui.Panel.bind('C-enter', function(pnl)
 *      local ipt = ui.current_widget('Input')
 *      if ipt then  -- it may be toggled off.
 *        ipt:insert( mc.name_quote(pnl.current) .. ' ' )
 *      end
 *    end)
 *
 * @function name_quote
 * @args (s, [quote_percent])
 */
static int
l_name_quote (lua_State * L)
{
    const char *s;
    gboolean quote_percent;

    s = luaL_checkstring (L, 1);
    quote_percent = lua_toboolean (L, 2);

    luaMC_pushstring_and_free (L, name_quote (s, quote_percent));
    return 1;
}

/**
 * Misc.
 *
 * @section
 */

/**
 * Whether we're a background process.
 *
 * Info: MC is capable of copying and moving files in the background: it
 * _forks_ and does the I/O in a separate process. This is of no
 * consequence to a Lua programmer except when one's
 * @{~filesystem|writing a filesystem}: you cannot use the UI in a
 * background process, except for a few facilities marked explicitly as
 * "safe" on the @{prompts} page. E.g., you can use @{prompts.get_password}
 * to read a password but you cannot generally construct more complex dialogs.
 *
 * @function is_background
 */
static int
l_is_background (lua_State * L)
{
#ifdef ENABLE_BACKGROUND
    lua_pushboolean (L, mc_global.we_are_background);
#else
    lua_pushboolean (L, FALSE);
#endif
    return 1;
}

/**
 * Whether we're running in @{~standalone|standalone} mode.
 *
 * That is, whether we're running via the 'mcscript' binary (or using
 * the `--script` or `-L` switches).
 *
 * In this mode MC runs a Lua script and then exits.
 *
 * See the @{~standalone|user guide}.
 *
 * @function is_standalone
 */
static int
l_is_standalone (lua_State * L)
{
    lua_pushboolean (L, mc_global.mc_run_mode == MC_RUN_SCRIPT);
    return 1;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg mclib[] = {
    { "view", l_view },
    { "view_command", l_view_command },
    { "edit", l_edit },
    { "diff", l_diff },
    { "help", l_help },
    { "activate", l_activate },
    { "execute", l_execute },
    { "expand_format", l_expand_format },
    { "name_quote", l_name_quote },
    { "is_background", l_is_background },
    { "is_standalone", l_is_standalone },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_mc (lua_State * L)
{
    luaL_newlib (L, mclib);
    return 1;
}
