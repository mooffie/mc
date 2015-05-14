/**
 * An object holding various attributes of a file. Returned by @{fs.stat},
 * @{~mod:ui.Panel*ui.Panel:current|ui.Panel:get_current}, and others.
 *
 * Tip: This object is a wrapper around C's @{stat(2)|struct stat}. The
 * name of the class derives from the name such variables are often given in
 * C.
 *
 * @noqualifier
 * @classmod fs.StatBuf
 */

#include <config.h>

#include <stdio.h>
#include <time.h>               /* time() */

#include "lib/global.h"
#include "lib/vfs/vfs.h"

#include "../capi.h"
#include "../modules.h"
#include "../utilx.h"

#include "fs.h"


#define DEFAULT_BLKSIZE  4096

static const char *valid_fields[] = {
    "dev", "ino", "mode", "nlink", "uid", "gid", "rdev",
    "size", "blksize", "blocks", "atime", "mtime", "ctime",
    /* These are pseudo: */
    "type", "perm",
    NULL
};

/**
 * Time of last modification.
 * @field mtime
 */

/**
 * Time of last status change.
 * @field ctime
 */

/**
 * Time of last access.
 *
 * (On modern systems <a
 * href="http://en.wikipedia.org/wiki/Stat_(system_call)#Criticism_of_atime">its
 * meaning is somewhat altered</a> for performance reasons.)
 *
 * @field atime
 */

/**
 * ID of device containing file.
 * @field dev
 */

/**
 * inode number.
 * @field ino
 */

/**
 * Permission bits **plus** file-type bits.
 *
 * Since it's not trivial to decipher this field in Lua, it's broken down
 * for you into two "easy" fields: `perm` and `type`.
 *
 * The "easy" fields work in the other direction too: When you need to
 * @{luafs.stat|conjure up a StatBuf} you can provide only the "easy"
 * field(s) (if both an "easy" field and `mode` are given, the "easy" field
 * takes precedence).
 *
 * @field mode
 */

/**
 * The type of the file.
 *
 * It's one of:
 *
 * - "regular"
 * - "directory"
 * - "link"
 * - "socket"
 * - "fifo"
 * - "character device"
 * - "block device"
 *
 * @field type
 */

/**
 * The permission bits of the file.
 *
 * @field perm
 */

/**
 * Number of links.
 * @field nlink
 */

/**
 * User ID of owner.
 * @field uid
 */

/**
 * Group ID of owner.
 * @field gid
 */

/**
 * Device ID (if special file).
 * @field rdev
 */

/**
 * File size.
 * @field size
 */

/**
 * Preferred block size for filesystem I/O.
 * @field blksize
 */

/**
 * Number of 512B blocks allocated.
 * @field blocks
 */

static void
invalid_field_error (lua_State * L, const char *field)
{
    char *list;

    list = g_strjoinv (", ", (char **) valid_fields);
    lua_pushfstring (L, E_ ("Unknown field '%s'. Should be one of: %s."), field, list);
    g_free (list);

    lua_error (L);
}

/* Note the use of lua_pushi() to support huge integers. */
#define ON_FIELD(name) if (STREQ (field, #name)) { lua_pushi (L, sb->st_ ## name); }

#define ON_FIELD_PUSH_ZERO(name) if (STREQ (field, #name)) { lua_pushinteger (L, 0); }

/**
 * Pushes a single statbuf field onto the Lua stack.
 */

/* *INDENT-OFF* */
static void
statbuf_push_field (lua_State * L, struct stat *sb, const char *field)
{
    if (STREQ (field, "type")) {
        mode_t mode = sb->st_mode;
        const char *type_name;
             if (S_ISREG (mode))  type_name = "regular";
        else if (S_ISDIR (mode))  type_name = "directory";
        else if (S_ISLNK (mode))  type_name = "link";
        else if (S_ISSOCK (mode)) type_name = "socket";
        else if (S_ISFIFO (mode)) type_name = "fifo";
        else if (S_ISCHR (mode))  type_name = "character device";
        else if (S_ISBLK (mode))  type_name = "block device";
        else                      type_name = "unknown";
        lua_pushstring (L, type_name);
    }
    else if (STREQ (field, "perm")) {
        lua_pushinteger (L, sb->st_mode & ~S_IFMT);
    }
    else ON_FIELD (mode)
    else ON_FIELD (size)
    else ON_FIELD (atime)
    else ON_FIELD (mtime)
    else ON_FIELD (ctime)
    else ON_FIELD (nlink)
    else ON_FIELD (uid)
    else ON_FIELD (gid)
    else ON_FIELD (ino)
    else ON_FIELD (dev)
#ifdef HAVE_STRUCT_STAT_ST_RDEV
    else ON_FIELD (rdev)
#else
    else ON_FIELD_PUSH_ZERO (rdev)
#endif
#ifdef HAVE_STRUCT_STAT_ST_BLKSIZE
    else ON_FIELD (blksize)
#else
    else if (STREQ (field, "blksize")) {
        lua_pushinteger (L, DEFAULT_BLKSIZE);
    }
#endif
#ifdef HAVE_STRUCT_STAT_ST_BLOCKS
    else ON_FIELD (blocks)
#else
    else ON_FIELD_PUSH_ZERO (blocks)
#endif
    else {
        invalid_field_error (L, field);
    }
}
/* *INDENT-ON* */

static mode_t
umask_permissions (mode_t perm)
{
    mode_t mymode;

    mymode = umask (0);
    umask (mymode);

    return perm & ~mymode;
}

/**
 * Pushes a C statbuf onto the Lua stack.
 *
 * (In other words, it converts a C statbuf into a Lua fs.StatBuf.)
 *
 * You may pass a NULL pointer to memset(0) the allocated buffer.
 */
struct stat *
luaFS_push_statbuf (lua_State * L, struct stat *sb_init)
{
    struct stat *sb;

    sb = luaMC_newuserdata (L, sizeof (struct stat), "fs.StatBuf");

    if (sb_init)
        memcpy (sb, sb_init, sizeof (struct stat));
    else
        memset (sb, 0, sizeof (struct stat));

    return sb;
}


#define GET_INT_FIELD(name) \
    do { \
        if (!lua_isnumber (L, -1)) { \
          luaL_error (L, E_("field '%s' should be numeric, but instead is %s."), #name, luaL_typename (L, -1)); \
        } \
        sb->st_ ## name = lua_tointeger (L, -1); \
    } while (0)

/**
 * Creates a fs.StatBuf object from a Lua table.
 *
 * Also returns the allocated buffer.
 */

/* *INDENT-OFF* */
static struct stat *
statbuf_from_table (lua_State * L, int idx)
{
    struct stat *sb;

    gboolean has_uid = FALSE;
    gboolean has_gid = FALSE;
    gboolean has_type = FALSE;
    gboolean has_perm = FALSE;
    gboolean has_mode = FALSE;
    gboolean has_nlink = FALSE;
    gboolean is_dir = FALSE;
    gboolean is_link = FALSE;

    idx = lua_absindex (L, idx);

    sb = luaFS_push_statbuf (L, NULL);

    lua_pushnil (L);  /* first key */
    while (lua_next (L, idx) != 0) {
        const char *field;
        if (lua_type (L, -2) != LUA_TSTRING) {
            luaL_error (L, E_("Field name must be a string."));
        }
        field = lua_tostring (L, -2);
        if (STREQ (field, "type")) {
            const char *type;
            if (!lua_isstring (L, -1)) {
                luaL_error (L, E_("Field 'type' must be a string."));
            }
            type = lua_tostring (L, -1);
            /* Clear the effect of a 'mode' field encountered previously: */
            sb->st_mode = sb->st_mode & ~S_IFMT;
            if (STREQ (type, "regular")) {
                sb->st_mode |= S_IFREG;
            }
            else if (STREQ (type, "directory")) {
                sb->st_mode |= S_IFDIR;
                is_dir = TRUE;
            }
            else if (STREQ (type, "link")) {
#ifdef S_IFLINK
                sb->st_mode |= S_IFDIR;
#endif
                is_link = TRUE;
            }
            else if (STREQ (type, "socket")) {
#ifdef S_IFSOCK
                sb->st_mode |= S_IFSOCK;
#endif
            }
            else if (STREQ (type, "fifo")) {
#ifdef S_IFIFO
                sb->st_mode |= S_IFIFO;
#endif
            }
            else if (STREQ (type, "character device")) {
#ifdef S_IFCHR
                sb->st_mode |= S_IFCHR;
#endif
            }
            else if (STREQ (type, "block device")) {
#ifdef S_IFBLK
                sb->st_mode |= S_IFBLK;
#endif
            }
            else luaL_error (L, E_("Invalid type '%s'."), type);
            has_type = TRUE;
        }
        else if (STREQ (field, "perm")) {
            sb->st_mode = (sb->st_mode & S_IFMT) | lua_tointeger (L, -1);
            has_perm = TRUE;
        }
        else if (STREQ (field, "mode")) {
            mode_t mode = lua_tointeger (L, -1);
            mode_t part_type = mode & S_IFMT;
            mode_t part_perm = mode & ~S_IFMT;

            /* We make "mode" of lower precedence than "perm" and "type". */
            if (!has_perm) {
                sb->st_mode |= part_perm;
            }
            if (!has_type) {
                sb->st_mode |= part_type;
            }
            has_mode = TRUE;
        }
        else if (STREQ (field, "ino")) {
            GET_INT_FIELD (ino);
        }
        else if (STREQ (field, "uid")) {
            GET_INT_FIELD (uid);
            has_uid = TRUE;
        }
        else if (STREQ (field, "gid")) {
            GET_INT_FIELD (gid);
            has_gid = TRUE;
        }
        else if (STREQ (field, "nlink")) {
            GET_INT_FIELD (nlink);
        }
        else if (STREQ (field, "size")) {
            GET_INT_FIELD (size);
        }
        else if (STREQ (field, "mtime")) {
            GET_INT_FIELD (mtime);
        }
        else if (STREQ (field, "ctime")) {
            GET_INT_FIELD (ctime);
        }
        else if (STREQ (field, "atime")) {
            GET_INT_FIELD (atime);
        }
        else if (STREQ (field, "dev")) {
            GET_INT_FIELD (dev);
        }
        else if (STREQ (field, "rdev")) {
#ifdef HAVE_STRUCT_STAT_ST_RDEV
            GET_INT_FIELD (rdev);
#endif
        }
        else if (STREQ (field, "blksize")) {
#ifdef HAVE_STRUCT_STAT_ST_BLKSIZE
            GET_INT_FIELD (blksize);
#endif
        }
        else if (STREQ (field, "blocks")) {
#ifdef HAVE_STRUCT_STAT_ST_BLOCKS
            GET_INT_FIELD (blocks);
#endif
        }
        else {
            invalid_field_error (L, field);
        }

        /* Remove 'value'; keep 'key' for next iteration. */
        lua_pop (L, 1);
    }

    /**
     * Fill-in some default values.
     */

    if (!has_uid) {
        sb->st_uid = getuid ();
    }
    if (!has_gid) {
        sb->st_gid = getgid ();
    }

    if (!sb->st_mtime) {
        sb->st_mtime = time (NULL);
    }
    if (!sb->st_ctime) {
        sb->st_ctime = sb->st_mtime;
    }
    if (!sb->st_atime) {
        sb->st_atime = sb->st_mtime;
    }

    if (!has_mode && !has_type) {
        /* Make it a regular file. */
        sb->st_mode |= S_IFREG;
    }

    if (!has_mode && !has_perm) {
      /* Set default access permissions. */
      mode_t perm;

      if (is_link)
          perm = 0777;
      else
          perm = umask_permissions (is_dir ? 0777 : 0666);

      sb->st_mode |= perm;
    }

    if (!has_nlink) {
        sb->st_nlink = 1;
    }

#ifdef HAVE_STRUCT_STAT_ST_BLKSIZE
    if (sb->st_blksize == 0) {
        sb->st_blksize = DEFAULT_BLKSIZE;
    }
#endif

    return sb;
}
/* *INDENT-ON* */

/**
 * Converts a Lua fs.StatBuf, or a Lua table, into a C statbuf.
 *
 * (Has the semantics of lua_checkstring().)
 */
struct stat *
luaFS_check_statbuf (lua_State * L, int idx)
{
    struct stat *sb = NULL;

    if (lua_isuserdata (L, idx))
    {
        sb = luaL_checkudata (L, idx, "fs.StatBuf");
    }
    else if (lua_istable (L, idx))
    {
        sb = statbuf_from_table (L, idx);
        lua_replace (L, idx);
    }
    else
    {
        luaL_argerror (L, idx, E_ ("StatBuf expected (either table or a fs.StatBuf())"));
    }

    return sb;
}

/**
 * Like luaFS_check_statbuf(), but doesn't raise exceptions.
 *
 * (Has the semantics of lua_tostring().)
 *
 * Unlike its 'check' variant, this function doesn't convert a table to
 * a statbuf. It isn't intentional. This function is currently used only
 * in one place, where this issue doesn't matter.
 */
struct stat *
luaFS_to_statbuf (lua_State * L, int idx)
{
    return luaL_testudata (L, idx, "fs.StatBuf");
}

/**
 * A utility function used by stat() and lstat(): it extracts a bunch of
 * fields out of a statbuf, given their names. If no names are given, it
 * returns a whole fs.StatBuf.
 *
 * 'start_index' is where the names start.
 */
int
luaFS_statbuf_extract_fields (lua_State * L, struct stat *sb, int start_index)
{
    int top = lua_gettop (L);

    if (start_index > top)
    {
        luaFS_push_statbuf (L, sb);
        return 1;
    }
    else
    {
        int i;
        for (i = start_index; i <= top; i++)
        {
            const char *field;
            field = luaL_checkstring (L, i);
            statbuf_push_field (L, sb, field);
        }
        return top - start_index + 1;
    }
}

/**
 * Converts a fs.StatBuf to a table.
 *
 * This method extracts each and every field out of a fs.StatBuf, into a
 * table. This is useful for debugging mainly, not for much else.
 *
 *    -- Show the stat() of the current file.
 *    ui.Panel.bind('C-f', function(pnl)
 *      local filename, statbuf = pnl:get_current()
 *      devel.view( statbuf:extract() )
 *    end)
 *
 * @method extract
 */
static int
l_statbuf_extract (lua_State * L)
{
    struct stat *sb;

    const char **field = valid_fields;

    sb = luaFS_check_statbuf (L, 1);

    lua_newtable (L);

    while (*field)
    {
        statbuf_push_field (L, sb, *field);
        lua_setfield (L, -2, *field);
        field++;
    }

    return 1;
}

/**
 * An __index handler for a fs.StatBuf, used for extracting individual fields.
 */
static int
l_statbuf_index (lua_State * L)
{
    struct stat *sb;
    const char *field;

    sb = luaFS_check_statbuf (L, 1);
    field = luaL_checkstring (L, 2);

    if (STREQ (field, "extract"))       /* A special case: the only method we currently support. */
    {
        lua_pushcfunction (L, l_statbuf_extract);
        return 1;
    }

    statbuf_push_field (L, sb, field);
    return 1;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg fsstatlib[] = {
    { "__index", l_statbuf_index },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_fs_statbuf (lua_State * L)
{
    luaMC_register_metatable (L, "fs.StatBuf", fsstatlib, FALSE);
    return 0;                   /* Nothing to return! */
}
