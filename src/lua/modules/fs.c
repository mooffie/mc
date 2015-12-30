/**
 * Filesystem access.
 *
 * This module will contain file manipulation functions (like chmod(),
 * mkdir(), rename(), stat(), etc.
 *
 * @module fs
 */

#include <config.h>

#include "lib/global.h"
#include "lib/vfs/vfs.h"
#include "lib/lua/capi.h"

#include "../modules.h"

#include "fs.h"


/**
 * Constructs a @{~mod:fs.VPath} object.
 *
 * If *path* is already a VPath object, it's returned as-is.
 *
 * @function VPath
 * @args (path[, relative])
 */
static int
l_vpath_new (lua_State * L)
{
    gboolean relative;

    relative = lua_toboolean (L, 2);

    if (relative)
        (void) luaFS_check_vpath_ex (L, 1, TRUE);
    else
        (void) luaFS_check_vpath (L, 1);

    /* By now, #1 is a vpath (or an error was raised). We return it. */
    lua_pushvalue (L, 1);
    return 1;
}

/* ------------------------------------------------------------------------ */

#define REGC(name) { #name, name }

static const luaMC_constReg fslib_constants[] = {

    /*
     * Flags for VPath:to_str().
     *
     * Note: VPF_NO_CANON and VPF_USE_DEPRECATED_PARSER are used when
     * converting *from* a string, so we don't need them. (VPF_NO_CANON is
     * the "relative" argument to fs.VPath().)
     */
    REGC (VPF_NONE),
    REGC (VPF_RECODE),
    REGC (VPF_STRIP_HOME),
    REGC (VPF_STRIP_PASSWORD),
    REGC (VPF_HIDE_CHARSET),

    {NULL, 0}
};

/* *INDENT-OFF* */
static const struct luaL_Reg fslib[] = {
    { "VPath", l_vpath_new },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_fs (lua_State * L)
{
    luaL_newlib (L, fslib);
    luaMC_register_constants (L, fslib_constants);
    return 1;
}
