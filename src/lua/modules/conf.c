/**
 * Configuration.
 *
 * Gives information about how MC is configured.
 *
 * @module conf
 */

#include <config.h>

#include "lib/global.h"
#include "lib/mcconfig.h"       /* mc_config_get_*() */
#include "lib/lua/capi.h"
#include "lib/lua/plumbing.h"

#include "../modules.h"


/**
 * Directories.
 *
 * This table contains paths of directories where MC-related configuration
 * and data are stored.
 *
 * @field user_config Location of user configuration.
 * @field user_data Location of user data.
 * @field user_cache Location of user cache.
 * @field user_lua Location of user Lua scripts.
 * @field system_config Location of system configuration.
 * @field system_data Location of system data.
 * @field system_lua Location of system Lua scripts.
 *
 * @table dirs
 */
static void
build_dirs_table (lua_State * L)
{
    lua_newtable (L);

    lua_pushstring (L, mc_config_get_path ());
    lua_setfield (L, -2, "user_config");

    lua_pushstring (L, mc_config_get_data_path ());
    lua_setfield (L, -2, "user_data");

    lua_pushstring (L, mc_config_get_cache_path ());
    lua_setfield (L, -2, "user_cache");

    lua_pushstring (L, mc_lua_user_dir ());
    lua_setfield (L, -2, "user_lua");

    lua_pushstring (L, mc_global.sysconfig_dir);
    lua_setfield (L, -2, "system_config");

    lua_pushstring (L, mc_global.share_data_dir);
    lua_setfield (L, -2, "system_data");

    lua_pushstring (L, mc_lua_system_dir ());
    lua_setfield (L, -2, "system_lua");
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg conf_lib[] = {
    /* No functions are currently defined in this module. */
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_conf (lua_State * L)
{
    luaL_newlib (L, conf_lib);

    build_dirs_table (L);
    lua_setfield (L, -2, "dirs");

    return 1;
}
