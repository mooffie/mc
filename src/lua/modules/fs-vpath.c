/**

The internal representation of a pathname.

Pathnames are usually represented in source code, and configuration files,
by simple strings. For example:

    local my_image_file = "/tmp/pictures.rar/urar://london/big ben.jpg"

Internally, however, MC represents all pathnames as a
@{git:vfs/path.h|C structure called vfs_path_t}

Note-short: The VPath Lua class represents this C structure.

This structure breaks down a pathname into its components. So, for
example, the above pathname is represented internally as the following
structure:

```lua
{
  path = {
    {
      path = "/tmp/pictures.rar",
      vfs_class_name = "localfs"
    },
    {
      path = "london/big ben.jpg",
      vfs_class_name = "extfs",
      vfs_prefix = "urar"
    }
  },
  relative = false,
  str = "/tmp/pictures.rar/urar://london/big ben.jpg"
}
```

You can see this structure by doing:

    devel.view( fs.VPath(my_image_file):extract() )

@{~mod:fs*VPath|fs.VPath()} is a function (a "constructor") that
converts a path string to a VPath object.

[ignore]

Let's inspect a more complex path:

    local my_diff_file = "sh://john:pokemon@www.typo.co.il/tmp/uClibc-snapshot.tar.bz2/utar://uClibc/extra/config/kconfig-to-uclibc.patch.gz/patchfs://config/lxdialog/menubox.c.diff"

doing

    devel.view( fs.VPath(my_diff_file):extract() )

...gives:

```lua
{
  path = {
    {
      path = "/home/mooffie",
      vfs_class_name = "localfs"
    },
    {
      host = "www.typo.co.il",
      password = "pokemon",
      path = "tmp/uClibc-snapshot.tar.bz2",
      user = "john",
      vfs_class_name = "fish",
      vfs_prefix = "sh"
    },
    {
      path = "uClibc/extra/config/kconfig-to-uclibc.patch.gz",
      vfs_class_name = "tarfs",
      vfs_prefix = "utar"
    },
    {
      path = "config/lxdialog/menubox.c.diff",
      vfs_class_name = "extfs",
      vfs_prefix = "patchfs"
    }
  },
  relative = false,
  str = "/home/mooffie/sh://john:pokemon@www.typo.co.il/tmp/uClibc-snapshot.tar.bz2/utar://uClibc/extra/config/kconfig-to-uclibc.patch.gz/patchfs://config/lxdialog/menubox.c.diff"
}
```

The first path element points to "/home/mooffie". This happened to be the
cwd when fs.VPath() was called. You can tell fs.VPath() to construct a
relative path to get rid of this element.

[/ignore]

Tip: You can pass a VPath to any function that accepts a path. E.g., you
can do either `fs.chdir("/")` or `fs.chdir(fs.VPath("/"))`.

@noqualifier
@classmod fs.VPath

*/

#include <config.h>

#include "lib/global.h"
#include "lib/vfs/vfs.h"
#include "lib/lua/capi.h"
#include "lib/lua/utilx.h"

#include "../modules.h"

#include "fs.h"


/*
 * The Lua userdata.
 */
typedef struct
{
    gboolean has_stash;
    vfs_path_t *vpath;
} lua_vpath_t;

/* ------------------------- Pushing a vpath ------------------------------ */

/**
 * This function doesn't clone the vpath, so pass it only vpaths you
 * yourself have allocated.
 */
static void
luaFS_push_vpath__without_cloning (lua_State * L, vfs_path_t * vpath)
{
    lua_vpath_t *userdata;

    userdata = luaMC_newuserdata (L, sizeof (lua_vpath_t), "fs.VPath");
    userdata->has_stash = FALSE;
    userdata->vpath = vpath;
}

void
luaFS_push_vpath (lua_State * L, const vfs_path_t * vpath)
{
    luaFS_push_vpath__without_cloning (L, vfs_path_clone (vpath));
}

/* ---------------------- Checking out a vpath ---------------------------- */

vfs_path_t *
luaFS_check_vpath_ex (lua_State * L, int index, gboolean relative)
{
    lua_vpath_t *userdata;

    index = lua_absindex (L, index);

    /* If the item is already a VPath, return it. */
    if ((userdata = luaL_testudata (L, index, "fs.VPath")) != NULL)
    {
        return userdata->vpath;
    }
    /* Else: if the item is a string, convert it to VPath.
     *
     * Note: We don't use lua_isstring(). In the Lua world numbers are
     * "strings" but we don't want to accept numbers as valid pathnames
     * because they're more likely file descriptors (fed to us by error)
     * than genuine file names.
     */
    else if (lua_type (L, index) == LUA_TSTRING)
    {
        /* We mimic the semantics of lua_tostring(): We replace the string
         * on the Lua stack with a VPath object. Because the pointer is now
         * on the Lua stack, the programmer won't need to handle it (free())
         * himself: the garbage collector handles this.
         */
        const char *str = lua_tostring (L, index);
        vfs_path_t *vpath;

        vpath = vfs_path_from_str_flags (str, relative ? VPF_NO_CANON : VPF_NONE);
        luaFS_push_vpath__without_cloning (L, vpath);
        lua_replace (L, index);

        return vpath;
    }
    else
    {
        luaL_typerror (L, index, "pathname");
    }
    return NULL;                /* We won't ever arrive here. */
}

vfs_path_t *
luaFS_check_vpath (lua_State * L, int index)
{
    return luaFS_check_vpath_ex (L, index, FALSE);
}

/* ------------------------------------------------------------------------ */

/**
 * An array of path elements.
 *
 * The full path is broken into "path element"s, which are stored in this
 * array. Each path element belongs to a different filesystem.
 *
 * A path element contains the following fields:
 *
 * - path: The substring of the full path belonging to this filesystem (this
 *   field, unfortunately, has the same name as that of the array
 *   itself; don't let this confuse you).
 * - vfs_prefix: The @{luafs.prefix|prefix} of the filesystem (**nil** for the @{is_local|local} filesystem).
 * - vfs_class_name: The name of the module implementing the filesystem.
 * - user, password, host, port: The components of paths like
 *   `ftp://joe:password@hostname.net:8192/`.
 *
 * @field path
 */

/*
 * A more technical explanation for the note above, intended for C
 * programmers:
 *
 * MC won't parse user/password/host/etc fields in paths of LuaFS
 * filesystems. That's because LuaFS doesn't have the VFS_S_REMOTE flag set
 * on it. LuaFS doesn't want this flag because then all Lua filesystems'
 * paths will be treated as "internet" paths. This is not desired for most
 * filesystems (b/c their first path component will be treated as "host").
 *
 * MC should be fixed so VFS_S_REMOTE is associated with individual
 * filesystems (that is, prefixes), not to whole modules (that is,
 * vfs_class).
 */

/**
 * Whether the vpath is relative or absolute.
 * @field relative
 */

/**
 * A string representation of the vpath.
 * @field str
 */

static void
extract_vpath_element (lua_State * L, const vfs_path_element_t * path_element)
{
    lua_newtable (L);

    lua_pushstring (L, path_element->path);
    lua_setfield (L, -2, "path");

    lua_pushstring (L, path_element->vfs_prefix);
    lua_setfield (L, -2, "vfs_prefix");

    if (path_element->user != NULL)
    {
        lua_pushstring (L, path_element->user);
        lua_setfield (L, -2, "user");
    }
    if (path_element->password != NULL)
    {
        lua_pushstring (L, path_element->password);
        lua_setfield (L, -2, "password");
    }
    if (path_element->host != NULL)
    {
        lua_pushstring (L, path_element->host);
        lua_setfield (L, -2, "host");
    }
    if (path_element->ipv6)
    {
        lua_pushboolean (L, path_element->ipv6);
        lua_setfield (L, -2, "ipv6");
    }
    if (path_element->port != 0)
    {
        lua_pushinteger (L, path_element->port);
        lua_setfield (L, -2, "port");
    }
    if (path_element->class != NULL && path_element->class->name != NULL)
    {
        lua_pushstring (L, path_element->class->name);
        lua_setfield (L, -2, "vfs_class_name");
    }
#ifdef HAVE_CHARSET
    if (path_element->encoding != NULL)
    {
        lua_pushstring (L, path_element->encoding);
        lua_setfield (L, -2, "encoding");
    }
#endif
}

/**
 * Extracts a vpath into the table at the top of the stack.
 *
 * It builds a Lua table that mimics the vfs_path_t C structure.
 *
 * So, assuming this table is named "p", it would look like:
 *
 *  p.str
 *  p.path[1].user
 *  ...
 *
 */
static void
extract_vpath (lua_State * L, const vfs_path_t * vpath)
{
    int vpath_element_index;

    lua_pushboolean (L, vpath->relative);
    lua_setfield (L, -2, "relative");

    lua_pushstring (L, vpath->str);
    lua_setfield (L, -2, "str");

    /* Create a "path" table field, but leave it on the stack. */
    lua_newtable (L);
    lua_pushvalue (L, -1);
    lua_setfield (L, -3, "path");

    /* Populate the "path" table. */
    for (vpath_element_index = 0; vpath_element_index < vfs_path_elements_count (vpath);
         vpath_element_index++)
    {
        extract_vpath_element (L, vfs_path_get_by_index (vpath, vpath_element_index));
        lua_rawseti (L, -2, vpath_element_index + 1);
    }

    lua_pop (L, 1);             /* Pop the "path" table. */
}

static void
luaFS_get_vpath_stash (lua_State * L, int index)
{
    if (luaMC_get_stash (L, index))
    {
        /* The stash has just been created. Populate it. */

        const vfs_path_t *vpath;

        vpath = luaFS_check_vpath (L, index);
        d_message (("--vpath::EXTRACT--\n"));
        extract_vpath (L, vpath);
    }
}

/*
 * Implements the __gc hook.
 */
static int
l_vpath_gc (lua_State * L)
{
    vfs_path_t *vpath;

    vpath = luaFS_check_vpath (L, 1);
    vfs_path_free (vpath);
    return 0;
}

/**
 * Determines whether a vpath points to the local filesystem.
 *
 * Tip: It's somewhat like doing `vpath:last().vfs_class_name == "localfs"`,
 * but more efficient.
 *
 * @method is_local
 */
static int
l_vpath_is_local (lua_State * L)
{
    vfs_path_t *vpath;

    vpath = luaFS_check_vpath (L, 1);
    lua_pushboolean (L, vfs_file_is_local (vpath));
    return 1;
}

/**
 * Returns the vpath with the last path element removed.
 *
 * If there's only a single path element, it is not removed: a copy of the
 * original vpath is returned.
 *
 * @method parent
 */
static int
l_vpath_parent (lua_State * L)
{
    vfs_path_t *vpath, *parent;

    vpath = luaFS_check_vpath (L, 1);

    parent = vfs_path_clone (vpath);
    vfs_path_remove_element_by_index (parent, -1);
    luaFS_push_vpath__without_cloning (L, parent);
    return 1;
}

/*
 * Implements the __index hook.
 *
 * Interpret any unrecognized method call as some VPath
 * property ('str', 'relative', 'path').
 */
static int
l_vpath_index (lua_State * L)
{
    const int VPATH_IDX = 1;
    const int KEY_IDX = 2;

    d_message (("vpath::get\n"));

    lua_getmetatable (L, VPATH_IDX);
    lua_pushvalue (L, KEY_IDX);
    lua_rawget (L, -2);

    if (!lua_isnil (L, -1))
    {
        /* The property was found in the meta table */
        return 1;
    }
    else
    {
        /* Property isn't there. Get it from the stash. */
        luaFS_get_vpath_stash (L, VPATH_IDX);
        lua_pushvalue (L, KEY_IDX);
        lua_rawget (L, -2);
        return 1;
    }
}

/**
 * Returns the last path element.
 *
 * Tip-short: Equivalent to `vpath.path[#vpath.path]`.
 *
 * @method last
 */
static int
l_vpath_last (lua_State * L)
{
    (void) luaFS_check_vpath (L, 1);    /* Ensure we're called on a VPath. (But I can't imagine how it wouldn't be the case.) */

    luaFS_get_vpath_stash (L, 1);
    lua_getfield (L, -1, "path");
    lua_rawgeti (L, -1, lua_rawlen (L, -1));
    return 1;
}

/**
 * Returns the path field of the last path element.
 *
 * Tip-short: Equivalent to `vpath:tail().path`.
 *
 * @method tail
 */
static int
l_vpath_tail (lua_State * L)
{
    l_vpath_last (L);
    lua_getfield (L, -1, "path");
    return 1;
}

/**
 * Converts a vpath to a string.
 *
 * Accepts an optional _flags_ argument. Example:
 *
 *    local bor = utils.bit32.bor
 *
 *    local function longname(path)
 *      return fs.VPath(path):to_str(bor(fs.VPF_STRIP_HOME, fs.VPF_STRIP_PASSWORD))
 *    end
 *
 * @method to_str
 * @args ([flags])
 */
static int
l_vpath_to_str (lua_State * L)
{
    vfs_path_t *vpath;
    vfs_path_flag_t flags;

    vpath = luaFS_check_vpath (L, 1);
    flags = luaL_opti (L, 2, VPF_NONE);

    luaMC_pushstring_and_free (L, vfs_path_to_str_flags (vpath, 0, flags));

    return 1;
}

/**
 * Converts a vpath to a Lua table.
 *
 * This is for debugging/educational purposes.
 *
 * @method extract
 */
static int
l_vpath_extract (lua_State * L)
{
    (void) luaFS_check_vpath (L, 1);

    luaFS_get_vpath_stash (L, 1);
    return 1;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg fsvpathlib[] = {
    { "__index", l_vpath_index },
    { "__gc", l_vpath_gc },
    { "last", l_vpath_last },
    { "tail", l_vpath_tail },
    { "extract", l_vpath_extract },
    { "is_local", l_vpath_is_local },
    { "parent", l_vpath_parent },
    { "to_str", l_vpath_to_str },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_fs_vpath (lua_State * L)
{
    luaMC_register_metatable (L, "fs.VPath", fsvpathlib, FALSE);
    return 0;                   /* Nothing to return! */
}

/* --------------- Alternative handling of path arguments ----------------- */

/*
 * There are two methods, from a Lua function written in C, to get your
 * hands on a path argument.
 *
 * The straightforward method is to use luaFS_check_vpath(). This is no
 * different than using luaL_checkstring() etc.
 *
 * That method has one drawback: strings are converted to userdata and Lua
 * has to GC them. This is not normally an issue, but if you want to avoid
 * this, especially in functions that may be called a lot (e.g. stat(), as
 * it's called in directory traversal loops), use the following method, of
 * using get_vpath_argument() + destroy_vpath_argument() where the vpath is
 * allocated "on the C side" and therefore also has to be free'd by you,
 * explicitly.
 */

vpath_argument *
get_vpath_argument (lua_State * L, int index)
{
    vpath_argument *arg = NULL;
    lua_vpath_t *userdata;

    /* If the item is already a VPath, return it. */
    if ((userdata = luaL_testudata (L, index, "fs.VPath")) != NULL)
    {
        arg = g_new (vpath_argument, 1);
        arg->vpath = userdata->vpath;
        arg->allocated_by_us = FALSE;
    }
    else if (lua_type (L, index) == LUA_TSTRING)
    {
        const char *str;
        str = lua_tostring (L, index);
        arg = g_new (vpath_argument, 1);
        arg->vpath = vfs_path_from_str (str);
        arg->allocated_by_us = TRUE;
    }
    /* Raise exception. */
    else
    {
        (void) luaFS_check_vpath (L, index);
    }

    return arg;
}

void
destroy_vpath_argument (vpath_argument * arg)
{
    if (arg && arg->allocated_by_us)
    {
        vfs_path_free (arg->vpath);
        g_free (arg);
    }
}
