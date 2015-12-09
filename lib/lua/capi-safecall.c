/**
 * Running Lua code.
 */

#include <config.h>

#include <stdio.h>

#include "lib/global.h"
#include "lib/widget.h"         /* message() */

#include "capi.h"
#include "plumbing.h"           /* mc_lua_ui_is_ready() */
#include "utilx.h"              /* E_() */

#include "capi-safecall.h"

static const char *first_error = NULL;

/* ------------------------- Displaying errors ---------------------------- */

/*
 * Errors are displayed in a fancy dialog box registered with us from the
 * Lua side (see _bootstrap.lua). If this fancy facility isn't available
 * (e.g., when there's some error in the core itself), we display the
 * errors ourselves using a simple alert box (see display_*__simple()).
 */

/*
 * There are two kinds of errors: normal errors (programming errors),
 * and "benign" errors ("application" errors intended for end-users). The
 * latter we call "aborts" and for them we use a friendly dialog not
 * showing a stack trace (because it isn't really needed).
 */

/**
 * An abort is a table marked with an "abort" property.
 */
static gboolean
luaMC_isabort (lua_State * L, int index)
{
    if (lua_istable (L, index))
    {
        lua_getfield (L, index, "abort");
        return luaMC_pop_boolean (L);
    }
    return FALSE;
}

static void
display_error (lua_State * L, const char *fancy, lua_CFunction simple)
{
    gboolean use_simple = FALSE;

#ifdef ENABLE_BACKGROUND
    if (mc_global.we_are_background)
        use_simple = TRUE;
#endif
    if (!mc_lua_ui_is_ready ())
        use_simple = TRUE;

    if (!use_simple)
    {
        if (luaMC_get_system_callback (L, fancy))
        {
            lua_pushvalue (L, -2);      /* the error object. */
            if (lua_pcall (L, 1, 0, 0))
            {
                lua_pop (L, 1); /* we don't need this new err msg. */
                use_simple = TRUE;
            }
        }
        else
            use_simple = TRUE;
    }

    if (use_simple)
    {
        lua_pushcfunction (L, simple);
        lua_pushvalue (L, -2);  /* the error object. */
        if (lua_pcall (L, 1, 0, 0))
            lua_pop (L, 1);     /* we don't need this new err msg. */
    }
}

static int
display_error__simple (lua_State * L)
{
    const char *error_message;

    error_message = lua_tostring (L, 1);
    if (error_message)
    {
        if (mc_lua_ui_is_ready ())
            message (D_ERROR, _("Lua error"), "%s", error_message);
        else
            fprintf (stderr, E_ ("LUA EXCEPTION: %s\n"), error_message);
    }
    return 0;
}

static int
display_abort__simple (lua_State * L)
{
    const char *error_message;

    lua_getfield (L, 1, "message");
    error_message = lua_tostring (L, -1);
    if (error_message)
    {
        if (mc_lua_ui_is_ready ())
            message (D_NORMAL, _("Abort"), "%s", error_message);
        else
            fprintf (stderr, E_ ("ABORT: %s\n"), error_message);
    }
    return 0;
}

/* -------------------------- Running Lua code ---------------------------- */

static void
record_first_error (lua_State * L)
{
    if (!first_error && lua_isstring (L, -1))
        first_error = g_strdup (lua_tostring (L, -1));
}

static void handle_error (lua_State * L);

/* Errors may occur before the UI is available. In such case they're
 * written to STDERR and the user may not notice them. So we "replay" them
 * when we have a nice UI where the user is sure to see them. */
void
mc_lua_replay_first_error (void)
{
    if (first_error)
    {
        lua_pushstring (Lg, first_error);
        handle_error (Lg);
    }
}

static void
handle_error (lua_State * L)
{
    if (luaMC_isabort (L, -1))
    {
        display_error (L, "devel::display_abort", display_abort__simple);
    }
    else
    {
        if (!lua_isstring (L, -1))
        {
            /* We don't know how to display non-string exceptions. */
            lua_pop (L, 1);
            lua_pushstring (L, E_ ("(error object is not a string)"));
        }
        record_first_error (L);
        display_error (L, "devel::display_error", display_error__simple);
    }

    lua_pop (L, 1);             /* the error */
}

/**
 * "Safely" calls a Lua function. In case of error, an alert is displayed
 * on the screen.
 *
 * There are two ways to call a Lua function: Either in unprotected mode
 * (via lua_call()) or in protected mode (aka "safe", via luaMC_pcall(),
 * which this function conveniently wraps).
 *
 * You'd use unprotected mode (lua_call()) when you're inside a Lua
 * function. That's because the top-level Lua function calling you is
 * _already_ protected. For example, l_gsub() calls a Lua function using
 * lua_call().
 *
 * OTOH, when you are *not* inside a Lua function (but at MC's top-level)
 * you'd use *this* function to call Lua functions. This function catches
 * any exceptions and displays them nicely to the user.
 *
 * WARNING: make sure to pop all the variables returned on the stack when this
 * function returns successfully. You don't want the global stack to fill up.
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
