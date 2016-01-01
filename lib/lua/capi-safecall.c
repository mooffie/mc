/**
 * Provides functions for running Lua code.
 *
 * It handles errors occurring in such code.
 */

#include <config.h>

#include <stdio.h>

#include "lib/global.h"

#include "capi.h"
#include "utilx.h"              /* E_() */

#include "capi-safecall.h"


/* ------------------------- Displaying errors ---------------------------- */

static void
display_error (lua_State * L)
{
    const char *error_message;

    error_message = lua_tostring (L, -1);
    if (error_message)
        fprintf (stderr, E_ ("LUA EXCEPTION: %s\n"), error_message);
}

/* -------------------------- Running Lua code ---------------------------- */

static void
handle_error (lua_State * L)
{
    if (!lua_isstring (L, -1))
    {
        /* We don't know how to display non-string exceptions. */
        lua_pop (L, 1);
        lua_pushstring (L, E_ ("(error object is not a string)"));
    }
    display_error (L);

    lua_pop (L, 1);             /* the error */
}

/**
 * "Safely" calls a Lua function.
 *
 * This function catches any exceptions and displays them nicely to the
 * user.
 *
 * You can think of it as a fancy version of lua_pcall().
 */
gboolean
luaMC_safe_call (lua_State * L, int nargs, int nresults)
{
    gboolean success;

    LUAMC_GUARD (L);

    success = luaMC_pcall (L, nargs, nresults);

    if (!success)
        handle_error (L);

    LUAMC_UNGUARD_BY (L, success ? (-1 - nargs + nresults) : (-1 - nargs));

    return success;
}

/**
 * Executes a script file.
 *
 * Returns 0 on success, or some other error code; most notables:
 *
 * LUA_ERRFILE   - can't open file.
 * LUA_ERRSYNTAX - syntax error.
 * LUA_ERRRUN    - runtime error.
 */
int
luaMC_safe_dofile (lua_State * L, const char *dirname, const char *basename)
{
    char *filename;
    gboolean error;

    filename = g_build_filename (dirname, basename, NULL);
    error = luaL_loadfile (L, filename);
    g_free (filename);

    if (error)
    {
        handle_error (L);
        return error;
    }
    else
    {
        /* Note: LUA_OK (0) isn't defined in Lua 5.1. So we use "0". */
        return luaMC_safe_call (L, 0, 0) ? 0 : LUA_ERRRUN;
    }

    /* An alternative implementation is to have a Lua C function that does
     * `loadfile(#1)()`, push that function, and call it with luaMC_safe_call().
     * As it turns out, the above solution is a bit shorter. */
}
