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

#include "capi.h"
#include "capi-safecall.h"

#ifdef HAVE_LUAJIT
#include <luajit.h>             /* LUAJIT_VERSION */
#endif

#include "plumbing.h"


/* The path of the bootstrap file, relative to mc_lua_system_dir(). */
#define BOOTSTRAP_FILE "modules/core/_bootstrap.lua"

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
}

/**
 * Loads the core, and then the user scripts.
 */
void
mc_lua_load (void)
{
    gboolean lua_core_found;

    /* Load core (which in turn loads user scripts). */
    lua_core_found = (luaMC_safe_dofile (Lg, mc_lua_system_dir (), BOOTSTRAP_FILE) != LUA_ERRFILE);

    if (!lua_core_found)
    {
        fprintf (stderr,
                 _("I can't find the Lua core scripts. Most probably you haven't\n"
                   "installed MC correctly.\n"
                   "\n"
                   "Did you remember to do \"make install\"? This will create the folder\n"
                   "%s and populate it with some scripts.\n"
                   "\n"
                   "Alternatively, if you don't wish to install MC, you may point me\n"
                   "to the Lua folder by the %s environment variable.\n"),
                 mc_lua_system_dir (), MC_LUA_SYSTEM_DIR__ENVAR);
    }

    g_assert (lua_gettop (Lg) == 0);    /* sanity check */
}

void
mc_lua_shutdown (void)
{
    lua_close (Lg);
    Lg = NULL;                  /* For easier debugging, in case somebody tries to use Lua after shutdown. */
}
