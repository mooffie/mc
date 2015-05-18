/*
   Virtual File System: Lua filesystems.

   Copyright (C) 1995, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
   2006, 2007, 2009, 2011
   The Free Software Foundation, Inc.

   This file is part of the Midnight Commander.

   The Midnight Commander is free software: you can redistribute it
   and/or modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation, either version 3 of the License,
   or (at your option) any later version.

   The Midnight Commander is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * \file
 * \brief Source: Virtual File System: Lua filesystems
 *
 * This is the C portion of LuaFS, a filesystem which lets end users write
 * filesystems in Lua.
 *
 * The bulk of LuaFS is written in Lua (see 'luafs.lua'). This C portion is
 * just a thin layer that forwards everything to the Lua side.
 */

#include <config.h>

#include <errno.h>

#include "lib/global.h"
#include "lib/vfs/vfs.h"
#include "lib/vfs/gc.h"         /* vfs_rmstamp() etc., debug__vfs_get_stamps() */
#include "lib/event.h"          /* mc_event_add() */

#include "lib/lua/capi.h"
#include "lib/lua/capi-safecall.h"
#include "src/lua/modules.h"
#include "src/lua/modules/fs.h"

#include "luafs.h"

/*** global variables ****************************************************************************/

/*** file scope macro definitions ****************************************************************/

/*** file scope type declarations ****************************************************************/

/*** file scope variables ************************************************************************/

static struct vfs_class vfs_luafs_ops;

static int my_errno;

/*** file scope functions ************************************************************************/

/* ----------------------- Wrapping Lua objects --------------------------- */

/*
 * MC's VFS subsystem handles file handles and directory handles as opaque
 * objects: as 'void *' pointers. (These are the 'void *data' arguments you
 * see in the signatures of some vfs_class callbacks here.)
 *
 * So we need a way to represent arbitrary Lua objects as 'void *', and
 * convert back and forth. The following three functions manage this: We
 * take a Lua object, create an integer reference to it (using luaL_ref()),
 * and malloc() a cell holding just this integer. The cell's address is the
 * 'void *'.
 *
 * (We could alternatively use GINT_TO_POINTER / GPOINTER_TO_INT instead of
 * malloc'ing.)
 */

/* Converts a Lua object (at the top of the stack) to 'void *'. */
static void *
lua_ref_cell__new (lua_State * L)
{
    int *cell = g_new (int, 1);
    *cell = luaL_ref (L, LUA_REGISTRYINDEX);
    return cell;
}

/* Converts 'void *' to a Lua object (placed at the top of the stack). */
static void
lua_ref_cell__push_value (lua_State * L, void *cell)
{
    int idx = *(int *) cell;
    lua_rawgeti (L, LUA_REGISTRYINDEX, idx);
}

/* Disposes of a ref cell. */
static void
lua_ref_cell__dispose (lua_State * L, void *cell)
{
    luaL_unref (L, LUA_REGISTRYINDEX, *(int *) cell);
    g_free (cell);
}

/* --------------------------- errno handling ----------------------------- */

/*
 * We bail out with "Operation not permitted" in the unlikely events of
 * exceptions raised on the Lua side (mostly a result of some programming
 * error).
 */

static int
luafs_failure (void)
{
    my_errno = EPERM;
    return -1;
}

static void *
luafs_failure__ptr (void)
{
    my_errno = EPERM;
    return NULL;
}

/* -------------------------- Callback results ---------------------------- */

/*
 * Functions for handling the results the Lua callbacks return.
 *
 * Lua callbacks return either some value in case of success, or a pair
 * (nil, ERRCODE) in case of error.
 *
 * The following functions, handle_returned_pair() and
 * handle_returned_pair__as_XXX(), translate the aforementioned value into a
 * C value. Their input is the top two stack values (as we have to
 * accommodate for the error pair). They also indicate, in their return
 * value, whether the call was successful or not. Finally, they pop the
 * callback's result off the stack.
 *
 * All functions test for failure with 'lua_isnil(Lg, -1)'. That is, they
 * inspect the second (last) element in the [potential] pair.
 */

#define ON_ERROR_RETURN_N(result, pop_count) \
    do { \
        if (!lua_isnil (Lg, -1)) { \
            my_errno = lua_tointeger (Lg, -1); \
            lua_pop (Lg, pop_count); \
            return result; \
        } \
    } \
    while (0)

#define ON_ERROR_RETURN(result) ON_ERROR_RETURN_N(result, 2)

/*
 * Handle callbacks of the simplest case: the operation either succeeded or failed.
 * Most callbacks are of this type.
 *
 * Returns 0 on success; -1 on error.
 */
static int
handle_returned_pair (void)
{
    ON_ERROR_RETURN (-1);

    lua_pop (Lg, 2);
    return 0;
}

/*
 * Handle callbacks that return a number on success.
 *
 * Returns the number on success; -1 on error.
 */
static lua_Number
handle_returned_pair__as_number (void)
{
    lua_Number result;

    ON_ERROR_RETURN (-1);

    result = lua_tonumber (Lg, -2);
    lua_pop (Lg, 2);
    return result;
}

/*
 * Handle callbacks that return a string on success.
 *
 * It copies the Lua string into the given buffer (without a terminating
 * null byte), and returns the number of bytes copied. Binary-safe. Returns
 * -1 on failure.
 */
static ssize_t
handle_returned_pair__as_string (char *buf, size_t bufsiz)
{
    const char *s;
    size_t s_len;

    ON_ERROR_RETURN (-1);

    s = lua_tolstring (Lg, -2, &s_len);
    lua_pop (Lg, 2);

    if (!s)
    {
        /*
         * We're expecting a Lua string. If we encounter some other type of
         * value, we effectively return an empty string. So, for example, if
         * the callback returned 'nil', it translates into an empty C string.
         *
         * (Note that numbers in Lua are considered strings.)
         */
        return 0;
    }
    else
    {
        s_len = MIN (s_len, bufsiz);
        memcpy (buf, s, s_len);
        return s_len;
    }
}

/*
 * Handle callbacks that return a fs.StatBuf on success.
 *
 * Returns 0 on success; -1 on error.
 */
static int
handle_returned_pair__as_statbf (struct stat *buf)
{
    struct stat *sb;

    ON_ERROR_RETURN (-1);

    sb = luaFS_to_statbuf (Lg, -2);
    g_assert (sb != NULL);      /* This shouldn't happen: The Lua side already raises an exception if a filesystem provides invalid value. */
    memcpy (buf, sb, sizeof (struct stat));

    lua_pop (Lg, 2);
    return 0;
}

/*
 * Handle callbacks that return an arbitrary Lua value.
 */
static void *
handle_returned_pair__as_cellref (void)
{
    ON_ERROR_RETURN (NULL);

    lua_pop (Lg, 1);            /* Pop unused error value. */
    return lua_ref_cell__new (Lg);
}

/* --------------------------------------------------------------------------------------------- */

static void *
luafs_open (const vfs_path_t * vpath, int flags, mode_t mode)
{
    if (luaMC_get_system_callback (Lg, "luafs::open"))
    {
        luaFS_push_vpath (Lg, vpath);
        lua_pushinteger (Lg, flags);    /* Lua name: mc_flags */
        lua_pushinteger (Lg, mode);     /* Lua name: creation_mode */
        lua_pushinteger (Lg, NO_LINEAR (flags));        /* Lua name: posix_flags */

        if (luaMC_safe_call (Lg, 4, 2))
            return handle_returned_pair__as_cellref ();
    }
    return luafs_failure__ptr ();
}

/* --------------------------------------------------------------------------------------------- */

/**
 * For some reason, src/vfs/local/local.c guards against 'data' being NULL in
 * read()/write()/close(). I don't think this is needed (more so when the guard
 * is omitted in lseek()/fstat()), but I'm duplicating that check here.
 */
#define DATA_CHECK() \
    do { if (!data) return -1; } while (0)


static ssize_t
luafs_read (void *data, char *buffer, size_t count)
{
    DATA_CHECK ();

    if (luaMC_get_system_callback (Lg, "luafs::read"))
    {
        lua_ref_cell__push_value (Lg, data);
        lua_pushi (Lg, count);

        if (luaMC_safe_call (Lg, 2, 2))
            return handle_returned_pair__as_string (buffer, count);
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_close (void *data)
{
    DATA_CHECK ();

    if (luaMC_get_system_callback (Lg, "luafs::close"))
    {
        lua_ref_cell__push_value (Lg, data);
        lua_ref_cell__dispose (Lg, data);

        if (luaMC_safe_call (Lg, 1, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static void *
luafs_opendir (const vfs_path_t * vpath)
{
    if (luaMC_get_system_callback (Lg, "luafs::opendir"))
    {
        luaFS_push_vpath (Lg, vpath);

        if (luaMC_safe_call (Lg, 1, 2))
            return handle_returned_pair__as_cellref ();
    }
    return luafs_failure__ptr ();
}

/* --------------------------------------------------------------------------------------------- */

static void *
luafs_readdir (void *data)
{
    static union vfs_dirent vdent;
    static struct dirent *dent = &vdent.dent;

    if (luaMC_get_system_callback (Lg, "luafs::readdir"))
    {
        lua_ref_cell__push_value (Lg, data);

        /* We're allowing for 3 return values: (name, inode, [possible errcode]).
         * Currently, our Lua side never returns an errcode (it's returned in
         * opendir), but maybe in the future.
         */
        if (luaMC_safe_call (Lg, 1, 3))
        {
            ON_ERROR_RETURN_N (NULL, 3);

            if (lua_isnil (Lg, -3))     /* No more entries. */
            {
                lua_pop (Lg, 3);
                return NULL;
            }
            else
            {
                const char *d_name;
                int d_ino;

                d_name = lua_tostring (Lg, -3);
                d_ino = lua_tointeger (Lg, -2);

                g_strlcpy (dent->d_name, d_name, MC_MAXPATHLEN);
                compute_namelen (dent);
                dent->d_ino = d_ino;    /* MC doesn't use this, and VFSs seem not to provide it, but it won't hurt. */

                lua_pop (Lg, 3);
                return dent;
            }
        }
    }
    return luafs_failure__ptr ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_closedir (void *data)
{
    if (luaMC_get_system_callback (Lg, "luafs::closedir"))
    {
        lua_ref_cell__push_value (Lg, data);
        lua_ref_cell__dispose (Lg, data);

        if (luaMC_safe_call (Lg, 1, 2))
            return handle_returned_pair ();

    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_stat (const vfs_path_t * vpath, struct stat *buf)
{
    if (luaMC_get_system_callback (Lg, "luafs::stat"))
    {
        luaFS_push_vpath (Lg, vpath);

        if (luaMC_safe_call (Lg, 1, 2))
            return handle_returned_pair__as_statbf (buf);
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_fstat (void *data, struct stat *buf)
{
    if (luaMC_get_system_callback (Lg, "luafs::fstat"))
    {
        lua_ref_cell__push_value (Lg, data);

        if (luaMC_safe_call (Lg, 1, 2))
            return handle_returned_pair__as_statbf (buf);
    }
    return luafs_failure ();
}

static int
luafs_lstat (const vfs_path_t * vpath, struct stat *buf)
{
    if (luaMC_get_system_callback (Lg, "luafs::lstat"))
    {
        luaFS_push_vpath (Lg, vpath);

        if (luaMC_safe_call (Lg, 1, 2))
            return handle_returned_pair__as_statbf (buf);
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_chmod (const vfs_path_t * vpath, mode_t mode)
{
    if (luaMC_get_system_callback (Lg, "luafs::chmod"))
    {
        luaFS_push_vpath (Lg, vpath);
        lua_pushinteger (Lg, mode);

        if (luaMC_safe_call (Lg, 2, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_chown (const vfs_path_t * vpath, uid_t owner, gid_t group)
{
    if (luaMC_get_system_callback (Lg, "luafs::chown"))
    {
        luaFS_push_vpath (Lg, vpath);
        lua_pushi (Lg, owner);
        lua_pushi (Lg, group);

        if (luaMC_safe_call (Lg, 3, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_utime (const vfs_path_t * vpath, struct utimbuf *times)
{
    if (luaMC_get_system_callback (Lg, "luafs::utime"))
    {
        luaFS_push_vpath (Lg, vpath);
        if (times)
        {
            /* For consistency, the order is that of fs.utime() */
            lua_pushi (Lg, times->modtime);
            lua_pushi (Lg, times->actime);
        }
        else
        {
            time_t now = time (NULL);
            lua_pushi (Lg, now);
            lua_pushi (Lg, now);
        }

        if (luaMC_safe_call (Lg, 3, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_readlink (const vfs_path_t * vpath, char *buf, size_t size)
{
    if (luaMC_get_system_callback (Lg, "luafs::readlink"))
    {
        luaFS_push_vpath (Lg, vpath);

        if (luaMC_safe_call (Lg, 1, 2))
            return handle_returned_pair__as_string (buf, size);
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_unlink (const vfs_path_t * vpath)
{
    if (luaMC_get_system_callback (Lg, "luafs::unlink"))
    {
        luaFS_push_vpath (Lg, vpath);

        if (luaMC_safe_call (Lg, 1, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_symlink (const vfs_path_t * vpath1, const vfs_path_t * vpath2)
{
    if (luaMC_get_system_callback (Lg, "luafs::symlink"))
    {
        luaFS_push_vpath (Lg, vpath1);
        luaFS_push_vpath (Lg, vpath2);

        if (luaMC_safe_call (Lg, 2, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static ssize_t
luafs_write (void *data, const char *buffer, size_t count)
{
    DATA_CHECK ();

    if (luaMC_get_system_callback (Lg, "luafs::write"))
    {
        lua_ref_cell__push_value (Lg, data);
        lua_pushlstring (Lg, buffer, count);

        if (luaMC_safe_call (Lg, 2, 2))
            return handle_returned_pair__as_number ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_rename (const vfs_path_t * vpath1, const vfs_path_t * vpath2)
{
    if (luaMC_get_system_callback (Lg, "luafs::rename"))
    {
        luaFS_push_vpath (Lg, vpath1);
        luaFS_push_vpath (Lg, vpath2);

        if (luaMC_safe_call (Lg, 2, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_chdir (const vfs_path_t * vpath)
{
    if (luaMC_get_system_callback (Lg, "luafs::chdir"))
    {
        luaFS_push_vpath (Lg, vpath);

        if (luaMC_safe_call (Lg, 1, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_mknod (const vfs_path_t * vpath, mode_t mode, dev_t dev)
{
    if (luaMC_get_system_callback (Lg, "luafs::mknod"))
    {
        luaFS_push_vpath (Lg, vpath);
        lua_pushinteger (Lg, mode);
        lua_pushi (Lg, dev);

        if (luaMC_safe_call (Lg, 3, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_link (const vfs_path_t * vpath1, const vfs_path_t * vpath2)
{
    if (luaMC_get_system_callback (Lg, "luafs::link"))
    {
        luaFS_push_vpath (Lg, vpath1);
        luaFS_push_vpath (Lg, vpath2);

        if (luaMC_safe_call (Lg, 2, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();

}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_mkdir (const vfs_path_t * vpath, mode_t mode)
{
    if (luaMC_get_system_callback (Lg, "luafs::mkdir"))
    {
        luaFS_push_vpath (Lg, vpath);
        lua_pushinteger (Lg, mode);

        if (luaMC_safe_call (Lg, 2, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_rmdir (const vfs_path_t * vpath)
{
    if (luaMC_get_system_callback (Lg, "luafs::rmdir"))
    {
        luaFS_push_vpath (Lg, vpath);

        if (luaMC_safe_call (Lg, 1, 2))
            return handle_returned_pair ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

static off_t
luafs_lseek (void *data, off_t offset, int whence)
{
    if (luaMC_get_system_callback (Lg, "luafs::seek"))
    {
        lua_ref_cell__push_value (Lg, data);
        /* For consistency, the order is that of file:seek() -- 'whence' comes
         * first. In contrast to POSIX's lseek(). */
        lua_pushinteger (Lg, whence);
        lua_pushi (Lg, offset);

        if (luaMC_safe_call (Lg, 3, 2))
            return handle_returned_pair__as_number ();
    }
    return luafs_failure ();
}

/* --------------------------------------------------------------------------------------------- */

/*
 * A callback which returns '0' if a path (its prefix, to be exact) is handled
 * by us. '-1' otherwise.
 */
static int
luafs_which (struct vfs_class *me, const char *prefix)
{
    (void) me;

    /* In the future, if we discover that the Lua invocation is a
     * bottleneck --but that's unlikely-- we could have this entirely
     * in C: the Lua portion would register with the C portion all
     * its recognized prefixes. */

    if (luaMC_get_system_callback (Lg, "luafs::which"))
    {
        lua_pushstring (Lg, prefix);

        if (luaMC_safe_call (Lg, 1, 1))
            /* The callback returns 'true' if it recognizes the prefix. */
            return luaMC_pop_boolean (Lg) ? 0 : -1;
    }

    return -1;
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_setctl (const vfs_path_t * vpath, int ctlop, void *arg)
{
    if (luaMC_get_system_callback (Lg, "luafs::setctl"))
    {
        switch (ctlop)
        {
        case VFS_SETCTL_RUN:
            luaFS_push_vpath (Lg, vpath);
            lua_pushstring (Lg, "run");
            lua_pushnil (Lg);
            break;

        case VFS_SETCTL_FLUSH:
            luaFS_push_vpath (Lg, vpath);
            lua_pushstring (Lg, "flush");
            lua_pushnil (Lg);
            break;

        case VFS_SETCTL_FORGET:
            luaFS_push_vpath (Lg, vpath);
            lua_pushstring (Lg, "forget");
            lua_pushnil (Lg);
            break;

        case VFS_SETCTL_STALE_DATA:
            luaFS_push_vpath (Lg, vpath);
            lua_pushstring (Lg, "stale_data");
            lua_pushboolean (Lg, arg != NULL);
            break;

        default:
            return 0;
        }

        if (luaMC_safe_call (Lg, 3, 1))
            /* Note: only the return value for VFS_SETCTL_RUN is meaningful;
             * for the rest it isn't checked by MC. */
            return luaMC_pop_boolean (Lg) ? 1 : 0;
    }
    return 0;
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_errno (struct vfs_class *me)
{
    (void) me;
    return my_errno;
}

/* --------------------------------------------------------------------------------------------- */

static void
luafs_fill_names (struct vfs_class *me, fill_names_f func)
{
    (void) me;

    if (luaMC_get_system_callback (Lg, "luafs::fill_names"))
    {
        if (luaMC_safe_call (Lg, 0, 1))
        {
            /* The top of the stack now contains a table with
             * names (strings). We apply 'func' to each of them. */
            int i = 1;
            const char *name;

            do
            {
                lua_rawgeti (Lg, -1, i++);
                name = lua_tostring (Lg, -1);
                if (name != NULL)
                    func (name);
                lua_pop (Lg, 1);
            }
            while (name != NULL);

            lua_pop (Lg, 1);
        }
    }
}

/* --------------------------------------------------------------------------------------------- */

static vfsid
luafs_getid (const vfs_path_t * vpath)
{
    if (luaMC_get_system_callback (Lg, "luafs::getid"))
    {
        luaFS_push_vpath (Lg, vpath);

        if (luaMC_safe_call (Lg, 1, 1))
            return GINT_TO_POINTER (luaMC_pop_integer (Lg));
    }
    return NULL;
}

/* --------------------------------------------------------------------------------------------- */

static int
luafs_nothingisopen (vfsid id)
{
    if (luaMC_get_system_callback (Lg, "luafs::nothingisopen"))
    {
        lua_pushinteger (Lg, GPOINTER_TO_INT (id));

        if (luaMC_safe_call (Lg, 1, 1))
            return luaMC_pop_boolean (Lg);
    }
    return TRUE;
}

/* --------------------------------------------------------------------------------------------- */

static void
luafs_free (vfsid id)
{
    if (luaMC_get_system_callback (Lg, "luafs::free"))
    {
        lua_pushinteger (Lg, GPOINTER_TO_INT (id));

        luaMC_safe_call (Lg, 1, 0);
    }
}

/* --------------------------------------------------------------------------------------------- */

/*
 * The Lua 'luafs.gc' module. It is used in the Lua portion to communicate
 * with the VFS's GC mechanism.
 *
 * (Should we move this into a separate file, say 'luafs-gc.c'? But we need
 * access to vfs_luafs_ops.)
 */

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

/* --------------------------------------------------------------------------------------------- */

/**
 * A dummy 'vfs_timestamp' event handler that we install.
 *
 * Why? Because vfs_stamp_create() aborts if no such handlers are installed,
 * and as a result the VFS GC mechanism won't work correctly. MC installs these
 * handlers when the panels (the UI) are created (the 'do_nc()' call in
 * src/main.c), but this stage is quite late: we allow Lua code to run
 * before this stage (or even without ever executing that stage; e.g., when
 * using mcscript).
 */
static gboolean
dummy_event_handler (const gchar * event_group_name, const gchar * event_name,
                     gpointer init_data, gpointer data)
{
    (void) event_group_name;
    (void) event_name;
    (void) init_data;
    (void) data;

    return TRUE;
}

/* --------------------------------------------------------------------------------------------- */
/*** public functions ****************************************************************************/
/* --------------------------------------------------------------------------------------------- */

void
init_luafs (void)
{
    mc_event_add (MCEVENT_GROUP_CORE, "vfs_timestamp", dummy_event_handler, NULL, NULL);

    vfs_luafs_ops.name = "luafs";
    vfs_luafs_ops.which = luafs_which;
    vfs_luafs_ops.ferrno = luafs_errno;
    vfs_luafs_ops.open = luafs_open;
    vfs_luafs_ops.read = luafs_read;
    vfs_luafs_ops.write = luafs_write;
    vfs_luafs_ops.lseek = luafs_lseek;
    vfs_luafs_ops.close = luafs_close;
    vfs_luafs_ops.opendir = luafs_opendir;
    vfs_luafs_ops.readdir = luafs_readdir;
    vfs_luafs_ops.closedir = luafs_closedir;
    vfs_luafs_ops.stat = luafs_stat;
    vfs_luafs_ops.lstat = luafs_lstat;
    vfs_luafs_ops.fstat = luafs_fstat;
    vfs_luafs_ops.chmod = luafs_chmod;
    vfs_luafs_ops.chown = luafs_chown;
    vfs_luafs_ops.utime = luafs_utime;
    vfs_luafs_ops.readlink = luafs_readlink;
    vfs_luafs_ops.symlink = luafs_symlink;
    vfs_luafs_ops.link = luafs_link;
    vfs_luafs_ops.unlink = luafs_unlink;
    vfs_luafs_ops.rename = luafs_rename;
    vfs_luafs_ops.chdir = luafs_chdir;
    vfs_luafs_ops.mknod = luafs_mknod;
    vfs_luafs_ops.mkdir = luafs_mkdir;
    vfs_luafs_ops.rmdir = luafs_rmdir;
    vfs_luafs_ops.setctl = luafs_setctl;
    /* GC and session-related callbacks: */
    vfs_luafs_ops.getid = luafs_getid;
    vfs_luafs_ops.nothingisopen = luafs_nothingisopen;
    vfs_luafs_ops.free = luafs_free;
    vfs_luafs_ops.fill_names = luafs_fill_names;
    /* In the future we might want to implement getlocalcopy / ungetlocalcopy.
     * See comment in 'luafs/shortcuts.lua'. */

    vfs_register_class (&vfs_luafs_ops);
}

/* --------------------------------------------------------------------------------------------- */
