/**
 * The Lua 'luafs.gc' module. It is used in the Lua portion of LuaFS to
 * communicate with the GC mechanism of the VFS.
 */

#include <config.h>

#include "lib/global.h"
#include "lib/vfs/gc.h"         /* vfs_rmstamp() etc., debug__vfs_get_stamps() */
#include "lib/lua/capi.h"

#include "src/lua/modules.h"

#include "internal.h"


static int
l_stamp (lua_State * L)
{
    int id;

    id = luaL_checkint (L, 1);
    vfs_stamp (&vfs_luafs_ops, GINT_TO_POINTER (id));

    return 0;
}

static int
l_rmstamp (lua_State * L)
{
    int id;

    id = luaL_checkint (L, 1);
    vfs_rmstamp (&vfs_luafs_ops, GINT_TO_POINTER (id));

    return 0;
}

static int
l_stamp_create (lua_State * L)
{
    int id;

    id = luaL_checkint (L, 1);
    vfs_stamp_create (&vfs_luafs_ops, GINT_TO_POINTER (id));

    return 0;
}

/**
 * Show the VFS' stamps.
 *
 * This function is a **debugging aid only**, for programmers working on MC's
 * VFS implementation. It shows the VFS' "stamps". Background information
 * can be found in a comment in 'lib/vfs/gc.c'.
 *
 * Usage example:
 *
 * Enter a TAR archive in a panel. Exit the archive. `require("luafs.gc").get_vfs_stamps()`
 * would now show a "stamp" for this archive. Wait a minute (or do "Free VFSs now"),
 * and the "stamp" would disappear.
 *
 * @function get_vfs_stamps
 */
static int
l_get_vfs_stamps (lua_State * L)
{
    struct vfs_stamping *stamp = debug__vfs_get_stamps ();
    time_t now = time (NULL);
    int i = 1;

    lua_newtable (L);

    while (stamp)
    {
        lua_newtable (L);

        lua_pushstring (L, stamp->v->name);
        lua_setfield (L, -2, "vfs_class_name");

        lua_pushi (L, (long) stamp->id);
        lua_setfield (L, -2, "vfs_id");

        lua_pushi (L, now - stamp->time.tv_sec);
        lua_setfield (L, -2, "seconds_ago");

        lua_rawseti (L, -2, i++);
        stamp = stamp->next;
    }

    return 1;
}

/* --------------------------------------------------------------------------------------------- */

/* *INDENT-OFF* */
static const struct luaL_Reg luafs_gc_lib[] = {
    { "stamp", l_stamp },
    { "rmstamp", l_rmstamp },
    { "stamp_create", l_stamp_create },
    { "get_vfs_stamps", l_get_vfs_stamps },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_luafs_gc (lua_State * L)
{
    luaL_newlib (L, luafs_gc_lib);
    return 1;
}
