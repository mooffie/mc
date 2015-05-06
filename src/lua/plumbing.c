/*
 * Holds functions that plug Lua and MC together.
 *
 * This file contains only high-level functions. None of them accepts a
 * lua_State argument (if it does, it means it's low level and belongs in
 * capi[-safecall].c, not here).
 */

#include <config.h>

#include <stdio.h>

#include "lib/global.h"
#include "lib/mcconfig.h"       /* mc_config_get_data_path() */
#include "lib/event.h"
#include "lib/widget.h"         /* message(), Widget */
#include "lib/util.h"           /* Q_() */

#include "capi.h"
#include "capi-safecall.h"
#include "modules.h"            /* mc_lua_open_c_modules() */
#include "modules/ui-impl.h"    /* luaUI_push_widget() */
#include "utilx.h"              /* E_() */

#ifdef HAVE_LUAJIT
#include <luajit.h>             /* LUAJIT_VERSION */
#endif

#include "plumbing.h"


/* The path of the bootstrap file, relative to mc_lua_system_dir(). */
#define BOOTSTRAP_FILE "modules/core/_bootstrap.lua"

static gboolean ui_is_ready = FALSE;
static gboolean restart_requested = FALSE;      /* Have we been requested to restart Lua? */
static gboolean lua_core_found = FALSE;
static gboolean is_restarting = FALSE;

/* -------------------------- Meta information ---------------------------- */

const char *
mc_lua_engine_name (void)
{
#ifdef HAVE_LUAJIT
    return LUAJIT_VERSION;
#else
    return LUA_RELEASE;
#endif
}

/**
 * Where system scripts are stored.
 */
const char *
mc_lua_system_dir ()
{
    static const char *dir = NULL;
    if (!dir)
    {
        /* getenv()'s returned pointer may be overwritten (by next getenv) or
         * invalidated (by putenv), so we make a copy with strdup(). */
        if (!(dir = g_strdup (g_getenv ("MC_LUA_SYSTEM_DIR"))))
            dir = MC_LUA_SYSTEM_DIR;
    }
    return dir;
}

/**
 * Where user scripts are stored.
 */
const char *
mc_lua_user_dir ()
{
    static const char *dir = NULL;
    if (!dir)
    {
        if (!(dir = g_strdup (g_getenv ("MC_LUA_USER_DIR"))))
            dir = g_build_filename (mc_config_get_data_path (), "lua", NULL);
    }
    return dir;
}

/* ----------------------------- Start/stop ------------------------------- */

/* "ui is ready" event handler */
static gboolean
ui_is_ready_handler (const gchar * event_group_name, const gchar * event_name,
                     gpointer init_data, gpointer data)
{
    (void) event_group_name;
    (void) event_name;
    (void) init_data;
    (void) data;

    ui_is_ready = TRUE;

    mc_lua_replay_first_error ();

    if (!lua_core_found)
    {
        message (D_ERROR, _("Lua error"),
                 _("I can't find the Lua core scripts. Most probably you haven't\n"
                   "installed MC correctly.\n"
                   "\n"
                   "Did you remember to do \"make install\"? This will create the folder\n"
                   "%s and populate it with some scripts.\n"
                   "\n"
                   "Alternatively, if you don't wish to install MC, you may point me\n"
                   "to the Lua folder by the MC_LUA_SYSTEM_DIR environment variable."),
                 mc_lua_system_dir ());
    }

    return TRUE;
}

/**
 * Initializes the Lua VM.
 */
void
mc_lua_init ()
{
    Lg = luaL_newstate ();
    luaL_openlibs (Lg);

    mc_lua_open_c_modules ();
    mc_event_add (MCEVENT_GROUP_DIALOG, "ui_is_ready", ui_is_ready_handler, NULL, NULL);
}

/**
 * Loads the core, and then the system & user scripts.
 */
void
mc_lua_load ()
{
    /* Load core. */
    lua_core_found = (luaMC_safe_dofile (Lg, mc_lua_system_dir (), BOOTSTRAP_FILE) != LUA_ERRFILE);

    /* Trigger the loading of system & user scripts. */
    mc_lua_trigger_event ("core::loaded");

    g_assert (lua_gettop (Lg) == 0);    /* sanity check */
}

/**
 * Handles the complexity caused by shutting off the VFS before Lua.
 */
void
mc_lua_before_vfs_shutdown ()
{
    mc_lua_trigger_event ("core::before-vfs-shutdown");
}

void
mc_lua_shutdown ()
{
    lua_close (Lg);
    Lg = NULL;                  /* For easier debugging, in case somebody tries to use Lua after shutdown. */
}

gboolean
mc_lua_is_restarting ()
{
    return is_restarting;
}

static void
restart ()
{
    is_restarting = TRUE;
    mc_lua_trigger_event ("core::before-restart");
    mc_lua_shutdown ();

    mc_lua_init ();
    mc_lua_load ();
    mc_lua_trigger_event ("core::after-restart");
    is_restarting = FALSE;
}

/**
 * A mechanism letting scripts restart Lua.
 *
 * It is exposed to Lua as 'internal.request_lua_restart()' (see
 * documentation there).
 */
void
mc_lua_request_restart ()
{
    restart_requested = TRUE;
}

/**
 * Restarts Lua, if a script asked us to.
 */
static void
check_for_restart ()
{
    if (restart_requested)      /* The script wants us to restart. */
    {
        restart_requested = FALSE;

        /*
         * It's only safe for us to restart Lua when the stack is
         * empty. Why? Imagine any of the following:
         *
         *    keymap.bind('C-y', function()
         *      ui.Dialog():run()
         *      print 'hi'
         *    end)
         *
         *    timer.set_timeout(function()
         *      ui.Dialog():run()
         *      print 'hi'
         *    end, 1000*5)
         *
         * The user hits C-y, or waits for the timer to fire. The stack
         * now can't be empty (because luaMC_safe_call() is in progress).
         * A dialog opens (the empty one) and the user now has a chance
         * (because of the event loop) to hit the key requesting that Lua
         * be restarted. He does this. He closes the dialog. The "old"
         * lua_State now continues to "print 'hi'". But this old lua_State
         * is kaput already, and we crash.
         */
        if (lua_gettop (Lg) == 0)
            restart ();
        else
            /* "Window" in this error message refers to an editor or viewer
             * started by Lua (e.g., by doing mc.edit() or devel.view()). */
            message (D_ERROR | D_CENTER, Q_ ("DialogTitle|Lua"),
                     _
                     ("You may not restart Lua from a dialog, or a window, opened by Lua.\n"
                      "First close, or switch out of, this window."));
    }
}

/* ------------------------------- Runtime -------------------------------- */

/**
 * Called on every key press.
 */
gboolean
mc_lua_eat_key (int keycode)
{
    gboolean consumed = FALSE;

    if (luaMC_get_system_callback (Lg, "keymap::eat"))
    {
        lua_pushinteger (Lg, keycode);

        if (luaMC_safe_call (Lg, 1, 1))
            /* The callback returns 'true' if the key was consumed. */
            consumed = luaMC_pop_boolean (Lg);
        else
            /* If some Lua error stopped the script (an alert will be shown),
             * that's still no reason to revert to the key's default action. */
            consumed = TRUE;

        check_for_restart ();
    }

    return consumed;
}

/**
 * Triggers an event on the Lua side.
 */
void
mc_lua_trigger_event (const char *event_name)
{
    if (luaMC_get_system_callback (Lg, "event::trigger"))
    {
        lua_pushstring (Lg, event_name);
        luaMC_safe_call (Lg, 1, 0);
    }
}

void
mc_lua_trigger_event__with_widget (const char *event_name, Widget * w)
{
    /*
     * main.c uses message() to display some error message boxes. Some of these
     * boxes are displayed before the UI is ready in Lua's opinion
     * (mc_lua_ui_is_ready()), a stage where a user event handler won't be
     * able to use many UI related functions (e.g., tty.style()), so we
     * simply disable triggering UI events at that early stage.
     */
    if (mc_lua_ui_is_ready () && luaMC_get_system_callback (Lg, "event::trigger"))
    {
        lua_pushstring (Lg, event_name);
        luaUI_push_widget (Lg, w, TRUE);
        luaMC_safe_call (Lg, 2, 0);
    }
}

gboolean
mc_lua_ui_is_ready ()
{
    return ui_is_ready;
}

/* --------------------------- mcscript-related --------------------------- */

/*
 * Runs a scripts.
 *
 * This is how 'mcscript' (or 'mc -L') runs a script. (If you're looking
 * for a simple-minded function, use luaMC_safe_dofile() instead.)
 *
 * Return codes:
 *
 * MC_LUA_SCRIPT_RESULT_FINISH - The script run to completion.
 *
 * MC_LUA_SCRIPT_RESULT_ERROR - Some error occurred: script file not found,
 * syntax error, or a runtime exception was raised.
 *
 * MC_LUA_SCRIPT_RESULT_CONTINUE - The execution arrived at some code that
 * wants to use the UI. The execution has stopped and is to be resumed (by
 * calling mc_lua_run_script() again with a NULL filename) when the UI is
 * ready.
 */
int
mc_lua_run_script (const char *pathname)
{
    if (luaMC_get_system_callback (Lg, "mcscript::run_script"))
    {
        lua_pushstring (Lg, pathname);

        if (luaMC_safe_call (Lg, 1, 1))
            return luaMC_pop_boolean (Lg)
                ? MC_LUA_SCRIPT_RESULT_CONTINUE : MC_LUA_SCRIPT_RESULT_FINISH;
        else
            return MC_LUA_SCRIPT_RESULT_ERROR;
    }
    else
    {
        fprintf (stderr, "%s\n",
                 E_
                 ("Internal error: I don't know how to run scripts. The core probably wasn't bootstrapped correctly."));
        return MC_LUA_SCRIPT_RESULT_ERROR;
    }
}

static void
create_argv (lua_State * L, const char *script_path, int argc, char **argv, int offs)
{
    int i;

    lua_newtable (L);

    for (i = offs; i < argc; i++)
    {
        lua_pushstring (L, argv[i]);
        luaMC_raw_append (L, -2);
    }

    lua_pushstring (L, script_path);
    lua_rawseti (L, -2, 0);

    lua_setglobal (L, "argv");
}

/**
 * Exports argv to the Lua side, for user scripts that want to use it.
 *
 * argv[0] gets the script's name. The arguments then follow.
 */
void
mc_lua_create_argv (const char *script_path, int argc, char **argv, int offs)
{
    create_argv (Lg, script_path, argc, argv, offs);
}
