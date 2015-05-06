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

#include "../capi.h"
#include "../plumbing.h"
#include "../modules.h"


/**
 * Features.
 *
 * This table contains booleans that tell whether some MC feature was
 * compiled in, or not.
 *
 * @field luafs Has LuaFS (writing virtual filesystems in Lua).
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

#ifdef ENABLE_VFS_LUAFS
    lua_pushboolean (L, TRUE);
#else
    lua_pushboolean (L, FALSE);
#endif
    lua_setfield (L, -2, "luafs");

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
 * Directories.
 *
 * This table contains paths of directries where MC-related configuration
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
 * It is a temporary (and unsatisfying?) solution to the problem of finding
 * pathnames in MC's zoo.
 *
 * @function path
 * @param name The short file name (see @{git:mcconfig/paths.c|mc_config_files_reference[]}).
 */
static int
l_conf_path (lua_State * L)
{
    /*
     * @todo:
     *
     * Some names, like EDIT_BLOCK_FILE, have 'PATH_SEP' in them. We should
     * convert '/', in names, to PATH_SEP so that users can hardcode
     * their '/'s. The last thing we need is people bothering with '/' vs '\\'
     * in their Lua code. The point of scripting is to make their life easy.
     *
     * ( @todo: add strtr() to utilx.c ? )
     */
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
    lua_setfield (L, -2, "features");

    build_dirs_table (L);
    lua_setfield (L, -2, "dirs");

    return 1;
}
