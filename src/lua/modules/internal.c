/**
 * The Bureau of Internal Affairs.
 *
 * This module groups functions that are for the core's internal use.
 *
 * Note-short: This module in not intended for end-users.
 *
 * @internal
 * @module internal
 */

#include <config.h>

#include <sys/types.h>
#include <unistd.h>             /* usleep() */

#include "lib/global.h"
#include "lib/lua/capi.h"
#include "lib/lua/plumbing.h"   /* mc_lua_request_restart() */
#include "lib/lua/utilx.h"

#include "../modules.h"


/**
 * Registers a Lua function at the C side.
 *
 * This is the primary means by which we plug Lua into MC.
 *
 * For example, on the Lua side we do:
 *
 *    require "internal".register_system_callback("ping", function(...)
 *      print("ping!", ...)
 *      return 666
 *    end)
 *
 * ...and on the C side:
 *
 *    if (luaMC_get_system_callback (Lg, "ping")) {
 *      lua_pushstring (Lg, "whatever");
 *      lua_pushstring (Lg, "you");
 *      lua_pushstring (Lg, "want");
 *      if (luaMC_safe_call (Lg, 3, 1)) {
 *        printf ("I got %d in return\n", lua_tointeger (Lg, -1));
 *        lua_pop (Lg, 1);
 *      }
 *    }
 *
 * @function register_system_callback
 * @args (slot_name, function)
 */
static int
l_register_system_callback (lua_State * L)
{
    /* This is to guard against typos. E.g., `rsc("whatever", tbl.non_existent)`
     * would fail. An unintended consequence is that we can't pass 'nil'. */
    luaL_checktype (L, 2, LUA_TFUNCTION);

    luaMC_register_system_callback (L, luaL_checkstring (L, 1), 2);
    return 0;
}

/**
 * Exposed as devel.enable_table_gc(). See documentation there.
 */
static int
l_enable_table_gc (lua_State * L)
{
    luaL_checktype (L, 1, LUA_TTABLE);
    luaL_argcheck (L, luaL_getmetafield (L, 1, "__gc"), 1,
                   E_
                   ("The table doesn't have a metatable, or its metatable doesn't have a '__gc' field."));
    luaMC_enable_table_gc (L, 1);

    /* Convenience: return the table itself. */
    lua_settop (L, 1);          /* In case the user provided (needless) extra args. */
    return 1;
}

/**
 * Requests that the Lua engine be restarted.
 *
 * This should be called from a key handler (i.e., @{keymap.bind}) because
 * the C side checks for the request right after a key press was handled.
 *
 * Typically it's installed in @{git:core/_bootstrap.lua} thus:
 *
 *    keymap.bind('C-x l', function()
 *      require('internal').request_lua_restart()
 *    end)
 *
 * @function request_lua_restart
 */
static int
l_request_lua_restart (lua_State * L)
{
    (void) L;
    mc_lua_request_restart ();
    return 0;
}

/**
 * Sleeps for a certain time (milliseconds).
 *
 * Note: End-users: don't use this function. You'll never have to. It stops
 * the whole application. Use @{timer|timers} instead.
 *
 * It may be used to simulate long tasks during testing.
 *
 * @function _sleep
 * @args (msec)
 */
static int
l_sleep (lua_State * L)
{
    useconds_t msec = luaL_checki (L, 1);
    usleep (msec * 1000);
    return 0;
}

/**
 * Whether Lua is being restarted.
 *
 * Returns **true** in the time period between the events
 * @{~mod:globals*core::before-restart} and
 * @{~mod:globals*core::after-restart}.
 *
 * @function is_restarting
 */
static int
l_is_restarting (lua_State * L)
{
    lua_pushboolean (L, mc_lua_is_restarting ());
    return 1;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg internal_lib[] = {
    { "register_system_callback", l_register_system_callback },
    { "enable_table_gc", l_enable_table_gc },
    { "_sleep", l_sleep },
    { "request_lua_restart", l_request_lua_restart },
    { "is_restarting", l_is_restarting },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_internal (lua_State * L)
{
    luaL_newlib (L, internal_lib);
    return 1;
}
