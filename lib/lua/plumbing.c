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

#include "capi.h"
#include "capi-safecall.h"
#include "utilx.h"              /* E_() */

#ifdef HAVE_LUAJIT
#include <luajit.h>             /* LUAJIT_VERSION */
#endif

#include "plumbing.h"


/* The path of the bootstrap file, relative to mc_lua_system_dir(). */
#define BOOTSTRAP_FILE "modules/core/_bootstrap.lua"

static gboolean ui_is_ready = FALSE;
static gboolean lua_core_found = FALSE;

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
mc_lua_system_dir (void)
{
    static const char *dir = NULL;

    if (dir == NULL)
    {
        /* getenv()'s returned pointer may be overwritten (by next getenv) or
         * invalidated (by putenv), so we make a copy with strdup(). */
        if ((dir = g_strdup (g_getenv (MC_LUA_SYSTEM_DIR__ENVAR))) == NULL)
            dir = MC_LUA_SYSTEM_DIR;    /* Defined in Makefile.am. It already has MC_LUA_API_VERSION embedded. */
    }

    return dir;
}

/**
 * Where user scripts are stored.
 */
const char *
mc_lua_user_dir (void)
{
    static const char *dir = NULL;

    if (dir == NULL)
    {
        if ((dir = g_strdup (g_getenv (MC_LUA_USER_DIR__ENVAR))) == NULL)
            dir = g_build_filename (mc_config_get_data_path (), "lua-" MC_LUA_API_VERSION, NULL);
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
                   "to the Lua folder by the %s environment variable."),
                 mc_lua_system_dir (), MC_LUA_SYSTEM_DIR__ENVAR);
    }

    /* Inform scripts that want to know about this. */
    mc_lua_trigger_event ("ui::ready");

    return TRUE;
}

/**
 * Initializes the Lua VM.
 */
void
mc_lua_init (void)
{
    Lg = luaL_newstate ();
    luaL_openlibs (Lg);
    /* The following line causes code in the 'src' tree to open our C modules. */
    mc_event_raise (MCEVENT_GROUP_LUA, "init", NULL);
    mc_event_add (MCEVENT_GROUP_CORE, "ui_is_ready", ui_is_ready_handler, NULL, NULL);
}

/**
 * Loads the core, and then the system & user scripts.
 */
void
mc_lua_load (void)
{
    /* Load core. */
    lua_core_found = (luaMC_safe_dofile (Lg, mc_lua_system_dir (), BOOTSTRAP_FILE) != LUA_ERRFILE);

    /* Trigger the loading of system & user scripts. */
    mc_lua_trigger_event ("core::loaded");

    g_assert (lua_gettop (Lg) == 0);    /* sanity check */
}

void
mc_lua_shutdown (void)
{
    lua_close (Lg);
    Lg = NULL;                  /* For easier debugging, in case somebody tries to use Lua after shutdown. */
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

gboolean
mc_lua_ui_is_ready (void)
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
mc_lua_script_result_t
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
    g_assert (offs <= argc);

    /* Push argv onto the stack, as a table. */
    luaMC_push_argv (L, argv + offs, TRUE);

    /* Add to that table, at index #0, the script name. */
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
