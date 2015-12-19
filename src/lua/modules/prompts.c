/**
 * Common dialog boxes.
 *
 * @module prompts
 */

#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"         /* input_dialog(), message() */
#include "lib/lua/capi.h"
#include "lib/lua/plumbing.h"   /* mc_lua_ui_is_ready() */

#include "../modules.h"
#include "tty.h"                /* luaTTY_assert_ui_is_ready() */


#define MC_HISTORY_LUA_DEFAULT      "mc.lua.default"

/**
 * This function is exposed to Lua as "_input" and is wrapped by the
 * higher-level "input".
 *
 * This function is background-safe.
 */
static int
l_input (lua_State * L)
{
    const char *question, *def_text, *title, *history;
    gboolean is_password = FALSE;

    char *answer;

    /* We default to "", not NULLs, as NULLs would crash MC (because strlen()
     * is called on them later). */
    /* *INDENT-OFF* */
    question    = luaL_optstring(L, 1, "");
    def_text    = luaMC_is_int_eq (L, 2, -1) ? INPUT_LAST_TEXT : luaL_optstring(L, 2, "");
    title       = luaL_optstring(L, 3, "");
    history     = luaL_optstring(L, 4, MC_HISTORY_LUA_DEFAULT);
    is_password = lua_toboolean(L, 5);
    /* *INDENT-ON* */

#ifdef ENABLE_BACKGROUND
    if (mc_global.we_are_background)
    {
        /* @FIXME: MC bug: INPUT_PASSWORD and INPUT_LAST_TEXT aren't background
           safe because they can't be marshaled. They aren't real strings and
           input_dialog_help() attempts to pass them to strlen(). */
        is_password = FALSE;

        if (def_text == INPUT_LAST_TEXT)
            def_text = "";
    }
#endif

    answer =
        input_dialog (title, question, history, is_password ? INPUT_PASSWORD : def_text,
                      INPUT_COMPLETE_NONE);
    lua_pushstring (L, answer); /* NULL-safe. */
    g_free (answer);

    return 1;
}

/**
 * Displays a message to the user.
 *
 * Note-short: if you wish to examine a variable's value, use @{devel.view}
 * instead.
 *
 * This function, for the sake of convenience, is also exposed in the global
 * namespace.
 *
 * Tip: This function's name (and that of `confirm`) was taken from the
 *  JavaScript world. `input`'s from Python's.
 *
 * - This function is @{mc.is_background|background}-safe.
 * - You may use this function even when the UI is @{tty.is_ui_ready|not ready}:
 *   the message in this case will be written to stdout.
 *
 * @function alert
 * @args (message[, title])
 */
static int
l_alert (lua_State * L)
{
    const char *text, *title;

    /* We use luaMC_tolstring() here, not lua_tostring(), because the user is
     * like to (improperly) use this function to inspect variables, so we need
     * something that can handle any type: tables, booleans, nils, functions,
     * etc. */
    text = luaMC_tolstring (L, 1, NULL);
    title = luaL_optstring (L, 2, "");

    if (mc_lua_ui_is_ready ())
        message (D_NORMAL, title, "%s", text);
    else
    {
        puts (text);
        puts ("\n");
    }

    return 0;
}

/**
 * Displays a yes/no question to the user.
 *
 * Choosing "yes" returns *true*. Choosing "no", or pressing ESC, returns *false*.
 *
 *    if prompts.confirm(T"Delete this file?") then
 *      mc.rm(file)
 *    end
 *
 * (This function is *not* @{mc.is_background|background}-safe.)
 *
 * @function confirm
 * @args (question[, title])
 */
static int
l_confirm (lua_State * L)
{
    const char *text, *title;

    text = luaL_optstring (L, 1, "");
    title = luaL_optstring (L, 2, "");

    luaTTY_assert_ui_is_ready (L);

    lua_pushboolean (L, !query_dialog (title, text, D_NORMAL, 2, _("&Yes"), _("&No")));

    return 1;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg prompts_lib[] = {
    { "_input", l_input },
    { "confirm", l_confirm },
    { "alert", l_alert },
    { NULL, NULL }
};

static const struct luaL_Reg prompts_global_lib[] = {
    { "alert", l_alert },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_prompts (lua_State * L)
{
    luaMC_register_globals (L, prompts_global_lib);
    luaL_newlib (L, prompts_lib);
    return 1;
}
