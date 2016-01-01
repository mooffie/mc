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

#include "lib/global.h"
#include "lib/lua/capi.h"
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

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg internal_lib[] = {
    { "register_system_callback", l_register_system_callback },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_internal (lua_State * L)
{
    luaL_newlib (L, internal_lib);
    return 1;
}
