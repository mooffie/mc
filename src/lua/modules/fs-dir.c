/**
 * Directory-related functions.
 *
 * @module fs
 */

#include <config.h>

#include <stdio.h>

#include "lib/global.h"
#include "lib/vfs/vfs.h"
#include "lib/lua/capi.h"

#include "../modules.h"
#include "fs.h"                 /* get_vpath_argument() */


static int l_dir_next (lua_State * L);
static int l_opendir (lua_State * L);

/**
 * Iterates over files in a directory.
 *
 * Raises an error if the directory could not be read (e.g., doesn't exist
 * or no read permission).
 *
 *    for file in fs.files("/home/mooffie")
 *      print(file)
 *    end
 *
 * See also @{dir}, @{glob}, @{opendir}.
 *
 * @function files
 * @args (path)
 */
static int
l_files (lua_State * L)
{
    lua_pushcfunction (L, l_dir_next);
    if (l_opendir (L) == 3)
    {
        /* The error message is the 2'nd in the triad. */
        lua_pop (L, 1);
        lua_error (L);
    }
    return 2;
}

/**
 * Returns a directory's contents.
 *
 * Returns a list of all the files in a directory. On error, returns a triad.
 *
 *    local files = fs.dir("/home/mooffie") or {}
 *
 * See also @{files}, @{glob}.
 *
 * @function dir
 * @args (path)
 */
static int
l_dir (lua_State * L)
{
    vpath_argument *vpath;
    DIR *dir;

    vpath = get_vpath_argument (L, 1);
    dir = mc_opendir (vpath->vpath);
    destroy_vpath_argument (vpath);

    if (!dir)
        return luaFS_push_error__by_idx (L, 1);

    lua_newtable (L);
    {
        struct dirent *ent;
        int i = 1;

        while ((ent = mc_readdir (dir)))
        {
            if (!DIR_IS_DOT (ent->d_name) && !DIR_IS_DOTDOT (ent->d_name))
            {
                lua_pushstring (L, ent->d_name);
                lua_rawseti (L, -2, i++);
            }
        }
    }

    mc_closedir (dir);
    return 1;
}

typedef struct
{
    DIR *dir;
    gboolean include_dot_dot;
} dir_obj_t;

/**
 * Opens a directory for reading.
 *
 * Note-short: This is a relatively low-level function. It's easier to just
 * use @{files}.
 *
 * On success, returns a "directory handle" object that has two methods:
 *
 * * `next()`, which returns a file name and inode number (or **nil** when
 * it arrives at the end).
 *
 * * `close()`, which may be used to prematurely close
 * the directory. It gets automatically called for you when a `:next()`
 * returns nil or when the object gets garbage collected.
 *
 * On error, returns a triad.
 *
 *    local dirh, error_message = fs.opendir("/home/mooffie")
 *    if not dirh then
 *      print("Sorry, I can't show you your files. Error: " .. error_message)
 *    else
 *      print("The first 10 files:")
 *      for i = 1, 10 do
 *        print(dirh:next())
 *      end
 *      dirh:close()
 *    end
 *
 *    -- A much shorter variation of the above:
 *    local dirh = assert(fs.opendir("/home/mooffie"))
 *    for file in dirh.next, dirh do
 *      print(file)
 *    end
 *
 * See also @{files}, @{dir}, @{glob}.
 *
 * @function opendir
 * @args (path)
 */
static int
l_opendir (lua_State * L)
{
    vpath_argument *vpath;
    dir_obj_t *dir_obj;

    vpath = get_vpath_argument (L, 1);

    dir_obj = luaMC_newuserdata (L, sizeof (dir_obj_t), "fs.DIR");
    dir_obj->dir = mc_opendir (vpath->vpath);
    dir_obj->include_dot_dot = FALSE;

    destroy_vpath_argument (vpath);

    if (!dir_obj->dir)
        return luaFS_push_error__by_idx (L, 1);
    else
        return 1;
}

static int
l_dir_close (lua_State * L)
{
    dir_obj_t *dir_obj;

    dir_obj = luaMC_checkudata__unsafe (L, 1, "fs.DIR");

    if (dir_obj->dir)
    {
        mc_closedir (dir_obj->dir);
        dir_obj->dir = NULL;
    }

    return 0;
}

static int
l_dir_next (lua_State * L)
{
    dir_obj_t *dir_obj;
    struct dirent *ent;

    dir_obj = luaMC_checkudata__unsafe (L, 1, "fs.DIR");

    if (dir_obj->dir)
    {
        /* Skip '.' and '..' */
        do
            ent = mc_readdir (dir_obj->dir);
        while (ent && !dir_obj->include_dot_dot
               && (DIR_IS_DOT (ent->d_name) || DIR_IS_DOTDOT (ent->d_name)));

        if (ent)
        {
            lua_pushstring (L, ent->d_name);
            lua_pushi (L, ent->d_ino);
            return 2;
        }
        else
        {
            /* Close immediately to save on resources; don't wait for GC. */
            l_dir_close (L);
        }
    }

    return 0;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg fslib[] = {
    { "opendir", l_opendir },
    { "dir", l_dir },
    { "files", l_files },
    { NULL, NULL }
};

static const struct luaL_Reg fsdirlib[] = {
    { "next", l_dir_next },
    { "close", l_dir_close },
    { "__gc", l_dir_close },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_fs_dir (lua_State * L)
{
    luaMC_register_metatable (L, "fs.DIR", fsdirlib, TRUE);
    lua_pop (L, 1);             /* we don't need this metatable */
    luaL_newlib (L, fslib);
    return 1;
}
