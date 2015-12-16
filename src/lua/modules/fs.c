/**
 * Filesystem access.
 *
 * [info]
 *
 * Unless otherwise noted, most functions here return a triad on error. By
 * wrapping calls to such functions in @{assert} you achieve the "throw
 * exceptions on errors" programming style.
 *
 * [/info]
 *
 * [tip short]
 *
 * See also the higher-level @{~mod:mc#operations|file operations} in the
 * @{mc} module.
 *
 * [/tip]
 *
 * @module fs
 */

#include <config.h>

#include <stdlib.h>             /* realpath() (by way of mc_realpath(), which may be just be a macro alias.) */
#include <time.h>               /* time() */
#include <errno.h>

#include "lib/global.h"
#include "lib/vfs/vfs.h"
#include "lib/vfs/utilvfs.h"    /* vfs_mkstemps() */
#include "lib/util.h"           /* mc_realpath(),  unix_error_string() */
#include "lib/lua/capi.h"

#include "src/filemanager/filenot.h"    /* my_mkdir() */

#include "../modules.h"

#include "fs.h"


/* ------------------------- Utility functions ---------------------------- */

static void
luaFS_push_error_message (lua_State * L, int error_num, const char *filename)
{
    /* We can't use g_strerror(). Its doc says "Returns a UTF-8
     * string" whereas we need the locale's encoding. */
    if (filename)
        lua_pushfstring (L, "%s: %s", filename, unix_error_string (error_num));
    else
        lua_pushstring (L, unix_error_string (error_num));
}

/**
 * Pushes an error triad.
 */
int
luaFS_push_error (lua_State * L, const char *filename)
{
    lua_pushnil (L);
    luaFS_push_error_message (L, errno, filename);
    lua_pushinteger (L, errno);
    return 3;
}

int
luaFS_push_error__by_idx (lua_State * L, int filename_index)
{
    const vfs_path_t *vpath;

    vpath = luaFS_check_vpath (L, filename_index);

    lua_pushnil (L);
    luaFS_push_error_message (L, errno, vpath->str);
    lua_pushinteger (L, errno);
    return 3;
}

/**
 * Pushes the result of a common C I/O function. Either 'true' to signify
 * success, or a triad on error.
 */
int
luaFS_push_result (lua_State * L, int result, const char *filename)
{
    if (result != -1)
    {
        /* Indicate success. */
        lua_pushboolean (L, TRUE);
        return 1;
    }
    else
        return luaFS_push_error (L, filename);
}

/* ------------------------------------------------------------------------ */

/**
 * Changes a file's permission bits.
 *
 *    fs.chmod("/path/to/file", tonumber("666", 8))
 *
 * @function chmod
 * @args (path, mode)
 */
static int
l_chmod (lua_State * L)
{
    const vfs_path_t *vpath;
    mode_t mode;

    int result;

    vpath = luaFS_check_vpath (L, 1);
    mode = luaL_checki (L, 2);

    result = mc_chmod (vpath, mode);

    return luaFS_push_result (L, result, vpath->str);
}

static int
do_link (lua_State * L, gboolean symbolic)
{
    const vfs_path_t *vpath1;
    const vfs_path_t *vpath2;

    int result;

    vpath1 = luaFS_check_vpath_ex (L, 1, TRUE);
    vpath2 = luaFS_check_vpath (L, 2);

    if (symbolic)
        result = mc_symlink (vpath1, vpath2);
    else
        result = mc_link (vpath1, vpath2);

    return luaFS_push_result (L, result, vpath1->str);
}

/**
 * Creates a hard-link.
 *
 * @function link
 * @args (oldpath, newpath)
 */
static int
l_link (lua_State * L)
{
    return do_link (L, FALSE);
}

/**
 * Creates a symbolic link.
 *
 * @function symlink
 * @args (oldpath, newpath)
 */
static int
l_symlink (lua_State * L)
{
    return do_link (L, TRUE);
}

/**
 * Deletes a file.
 *
 * See also the high-level @{mc.rm}.
 *
 * @function unlink
 * @args (path)
 */
static int
l_unlink (lua_State * L)
{
    const vfs_path_t *vpath;

    int result;

    vpath = luaFS_check_vpath (L, 1);

    result = mc_unlink (vpath);

    return luaFS_push_result (L, result, vpath->str);
}

/**
 * Reads a symbolic link.
 *
 * @function readlink
 * @args (path)
 */
static int
l_readlink (lua_State * L)
{
    const vfs_path_t *vpath;

    char link_target[MC_MAXPATHLEN];
    int len;

    vpath = luaFS_check_vpath (L, 1);

    len = mc_readlink (vpath, link_target, sizeof (link_target));       /* We don't need to do "- 1" */

    if (len > 0)
    {
        lua_pushlstring (L, link_target, len);
        return 1;
    }
    else
        return luaFS_push_error (L, vpath->str);
}

/**
 * Renames a file.
 *
 * See also the high-level @{mc.mv}, which can move files across devices.
 *
 * @function rename
 * @args (oldpath, newpath)
 */
static int
l_rename (lua_State * L)
{
    const vfs_path_t *vpath1;
    const vfs_path_t *vpath2;

    int result;

    vpath1 = luaFS_check_vpath (L, 1);
    vpath2 = luaFS_check_vpath (L, 2);

    result = mc_rename (vpath1, vpath2);

    return luaFS_push_result (L, result, vpath1->str);
}

/**
 * Creates a directory.
 *
 * @function mkdir
 *
 * @param path
 * @param[opt] perm Optional. The permission with which to create the new
 *   directory. Defaults to 0777. This will be clipped by the umask.
 */
static int
l_mkdir (lua_State * L)
{
    const vfs_path_t *vpath;
    mode_t mode;

    int result;

    vpath = luaFS_check_vpath (L, 1);
    mode = luaL_opti (L, 2, 0777);

    result = mc_mkdir (vpath, mode);

    return luaFS_push_result (L, result, vpath->str);
}

/**
 * Sets a file's timestamps.
 *
 * @function utime
 * @param path
 * @param[opt] modification_time Timestamp. Defaults to now.
 * @param[opt] last_access_time Timestamp. Defaults to now.
 */
static int
l_utime (lua_State * L)
{
    const vfs_path_t *vpath;
    struct utimbuf times;

    time_t now = time (NULL);
    int result;

    vpath = luaFS_check_vpath (L, 1);
    times.modtime = luaL_opti (L, 2, now);
    times.actime = luaL_opti (L, 3, now);

    /* Note: Libc's utime(2) does accept NULL as the second argument, but,
     * judging by FISH's fish_utime(), it's not safe to surprise a VFS
     * class with a NULL. */

    result = mc_utime (vpath, &times);

    return luaFS_push_result (L, result, vpath->str);
}

/**
 * Changes a file's ownership.
 *
 * @function chown
 * @param owner id. Leave empty (or -1) to not change this ID.
 * @param group id. Leave empty (or -1) to not change this ID.
 */
static int
l_chown (lua_State * L)
{
    const vfs_path_t *vpath;
    uid_t owner;
    gid_t group;

    int result;

    vpath = luaFS_check_vpath (L, 1);
    owner = luaL_opti (L, 2, -1);
    group = luaL_opti (L, 3, -1);

    result = mc_chown (vpath, owner, group);

    return luaFS_push_result (L, result, vpath->str);
}

/**
 * Creates a special (or ordinary) file
 *
 * @function mknod
 * @args (path, mode, dev)
 */
static int
l_mknod (lua_State * L)
{
    const vfs_path_t *vpath;
    mode_t mode;
    dev_t dev;

    int result;

    vpath = luaFS_check_vpath (L, 1);
    mode = luaL_checki (L, 2);
    dev = luaL_checki (L, 3);

    result = mc_mknod (vpath, mode, dev);

    return luaFS_push_result (L, result, vpath->str);
}

/**
 * Removes a directory.
 *
 * The directory has to be empty. If it isn't your case, use the high level
 * @{mc.rm} instead.
 *
 * @function rmdir
 * @args (path)
 */
static int
l_rmdir (lua_State * L)
{
    const vfs_path_t *vpath;

    int result;

    vpath = luaFS_check_vpath (L, 1);

    result = mc_rmdir (vpath);

    return luaFS_push_result (L, result, vpath->str);
}

/**
 * Creates a local copy of a file.
 *
 * If the file isn't on the local file system, this function creates a copy
 * of it, in some temporary directory, and returns the path for this copy.
 *
 * Info-short: If the file is already on the local file system, this function
 * returns the path as-is.
 *
 * This functions is needed when you want to execute an operating system
 * command on some arbitrary file. Since the file can reside on some
 * non-local file system, you can't use its path directly. E.g., you can't
 * do the following:
 *
 *    os.execute("wc -l ./archive.tgz/tar://file.txt")
 *
 * Instead, you first call `getlocalcopy` to create a local copy of the file:
 *
 *    local lcl_path = fs.getlocalcopy("./archive.tgz/tar://file.txt")
 *    os.execute("wc -l " .. lcl_path)
 *    fs.ungetlocalcopy("./archive.tgz/tar://file.txt", lcl_path, false)
 *
 * You should also call @{ungetlocalcopy} to cleanup after yourself, as
 * demonstrated here.
 *
 * @function getlocalcopy
 * @args (path)
 */
static int
l_getlocalcopy (lua_State * L)
{
    const vfs_path_t *vpath;
    vfs_path_t *local;

    vpath = luaFS_check_vpath (L, 1);

    local = mc_getlocalcopy (vpath);

    if (local)
    {
        lua_pushstring (L, local->str);
        vfs_path_free (local);
        return 1;
    }
    else
        return luaFS_push_error (L, vpath->str);
}

/**
 * Ungets a local copy.
 *
 * Deletes the local copy obtained by @{getlocalcopy}. If this copy has
 * changed (as per the flag), the local copy is first copied onto the
 * original file.
 *
 * Info-short: If the original file is already on the local file system,
 * this function is a no-op.
 *
 * See example at @{getlocalcopy}.
 *
 * @function ungetlocalcopy
 *
 * @param path The original file
 * @param local_path The local copy
 * @param has_changed Boolean. Has the file changed?
 */
static int
l_ungetlocalcopy (lua_State * L)
{
    const vfs_path_t *vpath;
    const vfs_path_t *local;
    gboolean has_changed;

    int result;

    vpath = luaFS_check_vpath (L, 1);
    local = luaFS_check_vpath (L, 2);
    luaL_checktype (L, 3, LUA_TBOOLEAN);        /* Make it mandatory. */
    has_changed = lua_toboolean (L, 3);

    result = mc_ungetlocalcopy (vpath, local, has_changed);

    return luaFS_push_result (L, result, vpath->str);
}

/**
 * Changes the current directory.
 *
 * [info]
 *
 * MC knows about 3 directories: the left panel's, the right panel's, and
 * the current directory. The latter is transient: it usually gets reset to
 * one of the panel's while the user works with them. If you want the
 * directory change to have a more permanent nature, change the
 * @{ui.Panel.dir|panel's direcory} instead of using fs.chdir().
 *
 * [/info]
 *
 * @function chdir
 * @args (path)
 */
static int
l_chdir (lua_State * L)
{
    const vfs_path_t *vpath;

    int result;

    vpath = luaFS_check_vpath (L, 1);

    result = mc_chdir (vpath);

    return luaFS_push_result (L, result, vpath->str);
}

/**
 * Returns the absolute canonical form of a path. All symbolic links
 * are resolved.
 *
 * This only works for paths in the local file system (the prefix "nonvfs_"
 * is there to remind you of this), and the path has to point to a file that
 * exists. If these two conditions aren't met, **nil** is returned.
 *
 * Tip: If all you want is to resolve "`/./`", "`/../`", and excessive "`/`"s,
 * and the file may not actually exist, use @{VPath} instead.
 *
 * @function nonvfs_realpath
 * @args (path)
 */
static int
l_nonvfs_realpath (lua_State * L)
{
    const vfs_path_t *vpath;
    char resolved_path[PATH_MAX];

    /* The following converts a string to a vpath. We do this because the
     * path may be relative and we need to have it converted to absolute
     * using MC's own notion of 'current directory', which may not be LocalFS,
     * something Libc knows nothing about. */
    vpath = luaFS_check_vpath (L, 1);

    if (vfs_file_is_local (vpath) && mc_realpath (vpath->str, resolved_path) == resolved_path)
    {
        lua_pushstring (L, resolved_path);
        return 1;
    }
    else
        return 0;
}

/**
 * Releases virtual filesystems not in use.
 *
 * Note: You shouldn't need to use this in normal code. This is done
 * automatically by MC (see @{git:core/_bootstrap.lua}).
 *
 * By default only filesystems not used for at least a certain amount of time
 * (typically 60 seconds) are released. By using the __force__ flag you direct
 * MC to release any filesystem not in use.
 *
 * @function _vfs_expire
 * @args ([force])
 */
static int
l_vfs_expire (lua_State * L)
{
    vfs_expire (lua_toboolean (L, 1));
    return 0;
}

/**
 * Converts an error code to a human-readable string.
 *
 * [note]
 *
 * You shouldn't need to use this function. There's not much reason to
 * keep error codes around. The most straightforward way to handle errors
 * is to simply wrap the call to the desired I/O function in @{assert} or
 * @{globals.abort|abort}.
 *
 * If you do want to show error messages yourself, then instead use the
 * 2'nd element of the error triad, as it also includes the the pathname
 * involved (something @{strerror} can't tell you).
 *
 * [/note]
 *
 * @function strerror
 * @param errorcode A numeric code previously returned as the 3'rd element
 *   of a triad.
 */
static int
l_strerror (lua_State * L)
{
    luaFS_push_error_message (L, luaL_checkint (L, 1), NULL);
    return 1;
}

/**
 * This function, for creating a temporary file, is exported to Lua as
 * _mkstemps, and is used by the higher-level wrapper @{temporary_file}.
 */
static int
l_mkstemps (lua_State * L)
{
    const char *prefix;
    const char *suffix;

    vfs_path_t *tmp_vpath = NULL;
    int tmp_fd = -1;

    prefix = luaL_optstring (L, 1, "");
    suffix = luaL_optstring (L, 2, "");

    if (*prefix == '\0')
    {
        /* We have to use *some* prefix or else mc_mkstemps() will
         * create /tmp/mc-${USER}XXXXXX instead of /tmp/mc-${USER}/XXXXXX
         * (because it uses g_strconcat() instead of g_build_filename()). */
        prefix = "lua";
    }

    tmp_fd = vfs_mkstemps (&tmp_vpath, prefix, suffix);
    if (tmp_fd == -1)
        return luaL_error (L, "%s", _("Cannot create temporary file."));

    close (tmp_fd);

    lua_pushstring (L, tmp_vpath->str);
    vfs_path_free (tmp_vpath);
    return 1;
}

/**
 * Checks access permission for a file.
 *
 * This function is an interface to the system's @{access(2)}. See its
 * manual page. It checks the read/write/execute permission bits,
 * or existence, of a file (or directory).
 *
 * [info]
 *
 * Since this function is the kernel's, it doesn't know of MC's VFS. So
 * it won't work for files in archives, sh://, etc. The prefix "nonvfs_"
 * is there to remind you of this.
 *
 * If you *do* pass it a non local VFS path, it will work by calling
 * @{stat}. I.e., it will check for path existence only, ignoring
 * permission bits.
 *
 * [/info]
 *
 * The function returns **true** if access is granted, or a triad
 * otherwise.
 *
 * @function nonvfs_access
 * @param path The pathname.
 * @param mode One of "r", "w", "x", "" (the empty string checks existence, not permission).
 */
static int
l_nonvfs_access (lua_State * L)
{
    static const char *const mode_names[] = { "r", "w", "x", "", NULL };
    static int mode_values[] = { R_OK, W_OK, X_OK, F_OK };

    vpath_argument *vpath;
    int mode;

    struct stat sb;
    int result;

    vpath = get_vpath_argument (L, 1);
    mode = luaMC_checkoption (L, 2, NULL, mode_names, mode_values);
    result =
        vfs_file_is_local (vpath->vpath) ? access (vpath->vpath->str, mode) : mc_stat (vpath->vpath,
                                                                                       &sb);
    destroy_vpath_argument (vpath);

    if (result == -1)
        return luaFS_push_error__by_idx (L, 1);
    else
    {
        lua_pushboolean (L, TRUE);
        return 1;
    }
}

/**
 * Creates a directory and its parents.
 *
 * [info]
 *
 * This is an interface to a function in MC's core which does not support the VFS. So
 * it won't work for nested directories in archives, sh://, etc. The prefix "nonvfs_"
 * is there to remind you of this.
 *
 * This will be fixed in the future.
 *
 * [/info]
 *
 * @function nonvfs_mkdir_p
 * @param path
 * @param[opt] perm Optional. The permission with which to create the new
 *   directory and its parents. Defaults to 0777. This will be clipped by the umask.
 */
static int
l_nonvfs_mkdir_p (lua_State * L)
{
    const vfs_path_t *vpath;
    mode_t mode;

    int result;

    vpath = luaFS_check_vpath (L, 1);
    mode = luaL_opti (L, 2, 0777);

    result = my_mkdir (vpath, mode);

    return luaFS_push_result (L, result, vpath->str);
}

/**
 * Returns the current directory, as a string.
 * @function current_dir
 */
static int
l_current_dir (lua_State * L)
{
    lua_pushstring (L, vfs_get_current_dir ());
    return 1;
}

/**
 * Returns the current directory, as a @{fs.VPath}.
 * @function current_vdir
 */
static int
l_current_vdir (lua_State * L)
{
    luaFS_push_vpath (L, vfs_get_raw_current_dir ());
    return 1;
}

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

/* -------------------------------- stat ---------------------------------- */

static int
do_stat (lua_State * L, gboolean lstat)
{
    vpath_argument *vpath;

    struct stat sb;
    int result;

    vpath = get_vpath_argument (L, 1);
    result = lstat ? mc_lstat (vpath->vpath, &sb) : mc_stat (vpath->vpath, &sb);
    destroy_vpath_argument (vpath);

    if (result == -1)
        return luaFS_push_error__by_idx (L, 1);
    else
        return luaFS_statbuf_extract_fields (L, &sb, 2);
}

/**
 * Returns a file's properties.
 *
 * Returns a @{~mod:fs.StatBuf} object. On error, returns a triad.
 *
 * See also @{lstat}.
 *
 * [info]
 *
 * If you're interested in a couple of fields only, you can fetch them
 * immediately by specifying their names:
 *
 *    if fs.stat("/path/to/file", "type") == "directory" then
 *      alert("This is a directory")
 *    end
 *
 * ...which is more efficient (and shorter) than doing:
 *
 *    if (fs.stat("/path/to/file") or {}).type == "directory" then
 *      alert("This is a directory")
 *    end
 *    -- We added 'or {}' to make it functionally equivalent to
 *    -- the previous code: for the case when stat() fails.
 *
 * [/info]
 *
 * @function stat
 * @args (path[, ...])
 *
 * @param path
 * @param ... Either none, to return a whole @{fs.StatBuf}, or names of
 *   fields to return.
 */
static int
l_stat (lua_State * L)
{
    return do_stat (L, FALSE);
}

/**
 * Returns a file's properties.
 *
 * Symbolic links aren't resolved.
 *
 * Returns a @{~mod:fs.StatBuf} object. On error, returns a triad.
 *
 * See also @{stat} for further details.
 *
 * @function lstat
 * @args (path[, ...])
 */
static int
l_lstat (lua_State * L)
{
    return do_stat (L, TRUE);
}

/**
 * Constructs a @{~mod:fs.StatBuf} object.
 *
 * Given a table with fields like "size", "type" etc., this function
 * constructs the corresponding @{~mod:fs.StatBuf} object. For missing
 * fields sane defaults will be picked.
 *
 * Note: End-users won't ever need to use this function. In the one case
 * where end-users do need to @{luafs.stat|conjure up a StatBuf} they can
 * use a table instead.
 *
 * @function StatBuf
 * @args (t)
 */
static int
l_statbuf_new (lua_State * L)
{
    luaFS_check_statbuf (L, 1);
    return 1;
}

/* ------------------------------------------------------------------------ */

#define REGC(name) { #name, name }

static const luaMC_constReg fslib_constants[] = {

    /* Constants used in our Lua core: */
    REGC (O_CREAT),
    REGC (O_WRONLY),
    REGC (O_RDWR),
    REGC (O_RDONLY),
    REGC (O_APPEND),
    REGC (O_TRUNC),
    REGC (O_LINEAR),            /* We don't currently use this. */

    /* Not used by us; a note in 'lib/vfs/vfs.h' says are fine to use: */
    REGC (O_EXCL),
    REGC (O_NOCTTY),
    REGC (O_SYNC),
    /* @FIXME: On my Linux, I need to #include vfs.h before global.h for the
     * following O_NDELAY, or for O_NONBLOCK, to be recognized. Why's that?
     * (BTW, replacing this line with { "O_NDELAY", O_NDELAY } makes the
     * compiler give a more detailed error message. */
    /*REGC (O_NDELAY), */

    /* Seeking. */
    REGC (SEEK_SET),
    REGC (SEEK_CUR),
    REGC (SEEK_END),

    /* Errors. We export only the ones we use. End-users shouldn't need to
     * use any. */
    REGC (ENOENT),
    REGC (EXDEV),
    REGC (EINVAL),
    REGC (EACCES),
    REGC (EBADF),
    REGC (EIO),
    REGC (EROFS),
    REGC (E_NOTSUPP),           /* Defined in 'vfs.h'. "for use in vfs when module does not provide function" */

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
    { "chmod", l_chmod },
    { "link", l_link },
    { "symlink", l_symlink },
    { "unlink", l_unlink },
    { "readlink", l_readlink },
    { "rename", l_rename },
    { "mkdir", l_mkdir },
    { "nonvfs_mkdir_p", l_nonvfs_mkdir_p },
    { "mknod", l_mknod },
    { "rmdir", l_rmdir },
    { "utime", l_utime },
    { "chown", l_chown },
    { "getlocalcopy", l_getlocalcopy },
    { "ungetlocalcopy", l_ungetlocalcopy },
    { "chdir", l_chdir },
    { "_vfs_expire", l_vfs_expire },
    { "nonvfs_realpath", l_nonvfs_realpath },
    { "strerror", l_strerror },
    { "_mkstemps", l_mkstemps },
    { "nonvfs_access", l_nonvfs_access },
    { "current_vdir", l_current_vdir },
    { "current_dir", l_current_dir },
    { "VPath", l_vpath_new },
    { "StatBuf", l_statbuf_new },
    { "stat", l_stat },
    { "lstat", l_lstat },
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
