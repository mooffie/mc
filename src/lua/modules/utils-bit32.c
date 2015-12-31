/**
 * Bit operations.
 *
 * This module implements some of the functions in Lua 5.2's
 * [bit32 module](http://www.lua.org/manual/5.2/manual.html#6.7). Since that
 * module isn't shipped with Lua 5.1 and 5.3, the following module is a
 * portable replacement.
 *
 * Info-short: Only a handful of functions are implemented. More may be added
 * if the need arises.
 *
 * @module utils.bit32
 */

#include <config.h>

#include "lib/global.h"
#include "lib/lua/capi.h"

#include "../modules.h"


/**
 * Bitwise or.
 *
 * see Lua's [bit32.bor](http://www.lua.org/manual/5.2/manual.html#pdf-bit32.bor)
 *
 * @function bor
 * @args (...)
 */
static int
l_bor (lua_State * L)
{
    int i = lua_gettop (L);
    guint32 acc = 0;
    while (i > 0)
    {
        acc |= (guint32) luaL_checkunsigned (L, i);
        --i;
    }
    lua_pushunsigned (L, acc);
    return 1;
}

/**
 * Bitwise and.
 *
 * see Lua's [bit32.band](http://www.lua.org/manual/5.2/manual.html#pdf-bit32.band)
 *
 * @function band
 * @args (...)
 */
static int
l_band (lua_State * L)
{
    int i = lua_gettop (L);
    /* Note: Calling band() with no arguments returns 0xffffffff for
     * compatibility with Lua 5.2's standard library. */
    guint32 acc = ~(guint32) 0;
    while (i > 0)
    {
        acc &= (guint32) luaL_checkunsigned (L, i);
        --i;
    }
    lua_pushunsigned (L, acc);
    return 1;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg utils_bit32_lib[] = {
    { "bor", l_bor },
    { "band", l_band },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_utils_bit32 (lua_State * L)
{
    luaL_newlib (L, utils_bit32_lib);
    return 1;
}
