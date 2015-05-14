/**
 * Low-level file I/O.
 *
 * This module groups functions that do file I/O using *descriptors*.
 *
 * Note: End-users don't need to use this module: the @{fs} module provides a
 * higher-level interface to file I/O via @{fs.open}.
 *
 * @internal
 * @module fs.filedes
 */

#include <config.h>

#include "lib/global.h"
#include "lib/vfs/vfs.h"

#include "../capi.h"
#include "../modules.h"
#include "../utilx.h"
#include "fs.h"


#define LUAFS_CLOSED_FD -1

/**
 * Checks a file descriptor out of the Lua stack. We use a special sentry
 * value to represent closed files.
 * @FIXME: We do this because MC's VFS layer has a bug which makes it not
 * recognize invalid filehandles, and thereby crash. (see vfs_bug_crash.lua
 * in the 'tests' folder.)
 */
static int
luaFS_check_fd (lua_State * L, int idx)
{
    int fd;

    fd = luaL_checkint (L, idx);
    if (fd == LUAFS_CLOSED_FD)
        luaL_argerror (L, idx,
                       E_
                       ("This file descriptor was closed; I cannot carry out further operations on it."));

    return fd;
}

/**
 * Opens a file.
 *
 * Returns a numeric file descriptor on success, a triad on error.
 *
 *    local fd = require("fs.filedes").open(
 *                 "/path/to/file",
 *                 utils.bit32.bor(fs.O_WRONLY, fs.O_EXCL),
 *                 tonumber("777", 8)
 *               )
 *
 * @param path   The path
 * @param flags  A bit field. A bitwise "or" of `fs.O_RDONLY`, `fs.O_WRONLY`,
 *   `fs.O_RDWR`, etc. Defaults to `fs.O_RDONLY`.
 * @param mode   When creating a file, the permissions. Defaults to 0666.
 *   This will be clipped by the umask.
 *
 * @function open
 * @args (path, [flags], [mode])
*/
static int
l_open (lua_State * L)
{
    const vfs_path_t *vpath;
    int flags;
    mode_t mode;

    int fd;

    vpath = luaFS_check_vpath (L, 1);
    flags = luaL_optint (L, 2, O_RDONLY);
    mode = luaL_opti (L, 3, 0666);

    fd = mc_open (vpath, flags, mode);

    if (fd != -1)
    {
        lua_pushinteger (L, fd);
        return 1;
    }
    else
        return luaFS_push_error (L, vpath->str);
}

/**
 * Closes a file.
 *
 * @function close
 * @args (fd)
*/
static int
l_close (lua_State * L)
{
    int fd;

    int result;

    fd = luaFS_check_fd (L, 1);

    result = mc_close (fd);

    return luaFS_push_result (L, result, NULL);
}

/**
 * Writes to a file.
 *
 * On success returns the number of bytes written. On error: a triad.
 *
 * @param fd The file descriptor.
 * @param str The string to write.
 *
 * @function write
 * @args (fd, str)
 */
static int
l_write (lua_State * L)
{
    int fd;
    const char *bf;
    size_t bf_len;

    ssize_t count;

    fd = luaFS_check_fd (L, 1);
    bf = luaL_checklstring (L, 2, &bf_len);

    count = mc_write (fd, bf, bf_len);

    if (count >= 0)
    {
        lua_pushi (L, count);
        return 1;
    }
    else
    {
        /* @FIXME: MC's mc_read()/mc_write()/mc_close() should return
         * EBADDESC on bad descriptor. */
        return luaFS_push_error (L, NULL);
    }
}

/**
 * Reads from a file.
 *
 * On success returns the string read (may be an empty string if no data was
 * available; e.g., on EOF), or a triad on error.
 *
 * @param fd The file descriptor.
 * @param count The number of bytes to read.
 *
 * @function read
 * @args (fd, count)
 */
static int
l_read (lua_State * L)
{
    int fd;
    ssize_t count;

    char *bf;

    fd = luaFS_check_fd (L, 1);
    count = luaL_checki (L, 2);

    bf = g_malloc (count);
    count = mc_read (fd, bf, count);

    if (count >= 0)
    {
        /*
         * What to do on EOF?
         *
         *  - luaposix.read() returns an empty string.
         *  - io.file:read() returns nil.
         *
         * We follow the luaposix way.
         */
        lua_pushlstring (L, bf, count);
        g_free (bf);
        return 1;
    }
    else
    {
        g_free (bf);
        return luaFS_push_error (L, NULL);
    }
}

/**
 * Seeks in a file.
 *
 * On success returns the new offset (relative to the beginning of the file);
 * on error a triad.
 *
 * @param fd The file descriptor.
 * @param offset The offset (number).
 * @param whence One of `fs.SEEK_SET`, `fs.SEEK_CUR`, `fs.SEEK_END`.
 *   Defaults to `fs.SEEK_SET`.
 *
 * @function lseek
 * @args (fd, offset, [whence])
 */
static int
l_lseek (lua_State * L)
{
    int fd;
    off_t offset;
    int whence;

    off_t result;

    fd = luaFS_check_fd (L, 1);
    offset = luaL_checki (L, 2);
    whence = luaL_optint (L, 3, SEEK_SET);

    result = mc_lseek (fd, offset, whence);

    if (result >= 0)
    {
        lua_pushi (L, result);
        return 1;
    }
    else
        return luaFS_push_error (L, NULL);
}

/**
 * Stats a file.
 *
 * @param fd The file descriptor.
 * @param ... Either none, to return a whole @{fs.StatBuf}, or names of
 *   fields (rationale explained at @{fs.stat}).
 *
 * @function fstat
 * @args (fd[, ...])
 */
static int
l_fstat (lua_State * L)
{
    int fd;

    struct stat sb;

    fd = luaFS_check_fd (L, 1);

    if (mc_fstat (fd, &sb) == -1)
        return luaFS_push_error (L, NULL);
    else
        return luaFS_statbuf_extract_fields (L, &sb, 2);
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const luaMC_constReg fsfiledeslib_constants[] = {
    { "CLOSED_FD", LUAFS_CLOSED_FD },
    { NULL, 0 }
};

static const struct luaL_Reg fsfiledeslib[] = {
    { "open", l_open },
    { "read", l_read },
    { "write", l_write },
    { "close", l_close },
    { "lseek", l_lseek },
    { "fstat", l_fstat },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_fs_filedes (lua_State * L)
{
    luaL_newlib (L, fsfiledeslib);
    luaMC_register_constants (L, fsfiledeslib_constants);
    return 1;
}
