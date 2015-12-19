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
 * Features.
 *
 * This table contains booleans that tell whether some MC feature was
 * compiled in, or not.
 *
 * @field editbox Has internal editor.
 * @field diff Has diff viewer.
 * @field charset Has charset support.
 *
 * @table features
 */
static void
build_features_table (lua_State * L)
{
    lua_newtable (L);

#ifdef USE_INTERNAL_EDIT
    lua_pushboolean (L, TRUE);
#else
    lua_pushboolean (L, FALSE);
#endif
    lua_setfield (L, -2, "editbox");

#ifdef USE_DIFF_VIEW
    lua_pushboolean (L, TRUE);
#else
    lua_pushboolean (L, FALSE);
#endif
    lua_setfield (L, -2, "diff");

#ifdef HAVE_CHARSET
    lua_pushboolean (L, TRUE);
#else
    lua_pushboolean (L, FALSE);
#endif
    lua_setfield (L, -2, "charset");
}

/**
 * Lua API features.
 *
 * This table is similar to the @{features} table except that it deals with Lua
 * API features. This is actually a versioning mechanism: if MC's developers
 * introduce some feature, during the lifetime of one major version, they can
 * declare it in this table and your module can check for it thus:
 *
 *    assert(conf.features.api.a_fabulous_feature_i_need, E"I need this fabulous feature you don't have!")
 *
 * It is expected that this mechanism be used by internal MC code only. User
 * code can rely on the version number embedded in Lua directories. All
 * features declared in this table should be removed once the version number
 * increments.
 *
 * @table features.api
 */
static void
build_features_api_table (lua_State * L)
{
    lua_newtable (L);

    /* Just for demonstration: */
    lua_pushboolean (L, TRUE);
    lua_setfield (L, -2, "a_fabulous_feature_i_need");
}

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

/**
 * Returns the full path of some "configuration file".
 *
 * Note: This is an interface to C's @{git:mcconfig/paths.c|mc_config_get_full_path()}.
 * It is a temporary(?) solution to the problem of finding pathnames in MC's zoo.
 *
 * Example:
 *
 *    -- Opens the "Directory hotlist" textual database in the editor.
 *    keymap.bind('M-pgdn', function()
 *      mc.edit(conf.path 'hotlist')
 *    end)
 *
 * @function path
 * @param name The short file name (see @{git:mcconfig/paths.c|mc_config_files_reference[]};
 *   note that the PATH_SEP_STR used there is always "/").
 */
static int
l_conf_path (lua_State * L)
{
    lua_pushstring (L, mc_config_get_full_path (luaL_checkstring (L, 1)));
    return 1;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg conf_lib[] = {
    { "path", l_conf_path },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_conf (lua_State * L)
{
    luaL_newlib (L, conf_lib);

    build_features_table (L);
    {
        build_features_api_table (L);
        lua_setfield (L, -2, "api");
    }
    lua_setfield (L, -2, "features");

    build_dirs_table (L);
    lua_setfield (L, -2, "dirs");

    return 1;
}
