/**
 * This file extends Lua's C API. It also handles compatibility
 * issues between the different Lua versions.
 *
 * The functions here are mostly utility functions that make it easier
 * to do common tasks.
 *
 * We follow "luaL"'s example by prefixing our functions' names with
 * "luaMC".
 *
 * These functions are *independent* of MC. Please keep it this way (if
 * you want a function to use any of MC's services, put it in the
 * appropriate module, e.g., module/fs.h, modules/tty.h, etc.
 */

#include <config.h>

#include <stdio.h>

#include "lib/global.h"
#include "lib/strutil.h"        /* for implementing luaMC_pushlstring_conv()  */

#include "utilx.h"              /* E_() */

#include "capi.h"


lua_State *Lg;                  /* the Lua VM */

/* ----------------------------- Scalars ---------------------------------- */

gboolean
luaMC_pop_boolean (lua_State * L)
{
    gboolean b;

    b = lua_toboolean (L, -1);
    lua_pop (L, 1);
    return b;
}

lua_Integer
luaMC_pop_integer (lua_State * L)
{
    lua_Integer i;

    i = lua_tointeger (L, -1);
    lua_pop (L, 1);
    return i;
}

/**
 * A sign() function.
 *
 * Return -1, 0, or 1.
 */
int
luaMC_get_sign (lua_State * L, int idx)
{
#ifdef HAVE_LUA_ISINTEGER
    /* For Lua 5.3 */

    /* We can't use lua_tonumber() outright because if the number
     * is an integer it may not have a precise 'double' representation
     * and our -1/0/1 conversion may not be correct. */

    if (lua_isinteger (L, idx))
    {
        lua_Integer num = lua_tointeger (L, idx);
        return (num < 0) ? -1 : (num > 0);
    }
#endif

    {
        lua_Number num = lua_tonumber (L, idx);
        return (num < 0) ? -1 : (num > 0);
    }
}

/**
 * Whether an element is a number equal to some integer.
 */
gboolean
luaMC_is_int_eq (lua_State * L, int idx, int val)
{
    return (lua_type (L, idx) == LUA_TNUMBER && lua_tointeger (L, idx) == val);
}

/**
 * Used seldom, when 'nil' doesn't mean 'false' but really a missing value.
 */
gboolean
luaMC_optboolean (lua_State * L, int idx, gboolean def_val)
{
    return lua_isnoneornil (L, idx) ? def_val : lua_toboolean (L, idx);
}

/* ------------------------------- Strings -------------------------------- */

/**
 * Like lua_pushstring, but also g_free() the string.
 */
void
luaMC_pushstring_and_free (lua_State * L, char *s)
{
    lua_pushstring (L, s);
    g_free (s);
}

/* Like luaL_tolstring(), but doesn't push a value onto the stack. */
const char *
luaMC_tolstring (lua_State * L, int idx, size_t * len)
{
    idx = lua_absindex (L, idx);

    if (lua_isnone (L, idx))
        return "";

    LUAMC_GUARD (L);
    lua_getglobal (L, "tostring");
    lua_pushvalue (L, idx);
    lua_call (L, 1, 1);
    lua_replace (L, idx);
    LUAMC_UNGUARD (L);

    return lua_tolstring (L, idx, len);
}

/**
 * Like lua_pushlstring() but also converts the encoding of the string.
 *
 * It's OK for 'conv' to be INVALID_CONV (we won't crash).
 */
int                             /* estr_t */
luaMC_pushlstring_conv (lua_State * L, const char *s, size_t len, GIConv conv)
{
    GString *buffer;
    estr_t conv_result;

    buffer = g_string_new ("");

    if (conv != INVALID_CONV)
    {
        g_iconv (conv, NULL, NULL, NULL, NULL); /* Reset its state. */
        conv_result = str_nconvert (conv, s, len, buffer);      /* @todo: will the 'size_t -> int' cast cause trouble? */
    }
    else
    {
        conv_result = ESTR_FAILURE;
    }

    lua_pushlstring (L, buffer->str, buffer->len);
    g_string_free (buffer, TRUE);

    return conv_result;
}

/* ------------------------------- Tables --------------------------------- */

/* Creates a weak table. */
void
luaMC_new_weak_table (lua_State * L, const char *what /* k, v, kv */ )
{
    lua_newtable (L);           /* the table itself. */
    lua_newtable (L);           /* its meta table. */
    lua_pushstring (L, what);
    lua_setfield (L, -2, "__mode");
    lua_setmetatable (L, -2);
}

/*
 * __gc support:
 */

#ifdef HAVE_LUA_GETFENV         /* detects Lua 5.1 */

static int
l_gcenabler_gc (lua_State * L)
{
    lua_getfenv (L, 1);
    luaMC_pingmeta (L, -1, "__gc");
    return 0;
}

/**
 * Enables __gc for a table, for Lua 5.1 (and LuaJIT)
 *
 * We do this by adding to the table a userdata whose __gc calls that
 * table's gc.
 *
 * (Here's a description of a flavor that uses a weak table:
 * http://lua-users.org/lists/lua-l/2002-11/msg00248.html )
 */
void
luaMC_enable_table_gc (lua_State * L, int index)
{
    index = lua_absindex (L, index);

    /* Create a userdata. */
    lua_newuserdata (L, 1);

    /* Make the table the environment of the userdata. */
    lua_pushvalue (L, index);
    lua_setfenv (L, -2);

    /* Install a metatable for the userdata, with a __gc field. */
    lua_newtable (L);
    lua_pushcfunction (L, l_gcenabler_gc);
    lua_setfield (L, -2, "__gc");
    lua_setmetatable (L, -2);

    /* Finally, make the userdata a member of the table. */
    luaMC_rawsetfield (L, index, "__gc_enabler__");
}

#else /* for Lua 5.2+ */

void
luaMC_enable_table_gc (lua_State * L, int index)
{
    index = lua_absindex (L, index);

    /* Re-assign the meta, in case the __gc entry was added after
     * calling setmetatable(). */
    if (lua_getmetatable (L, index))
        lua_setmetatable (L, index);
}

#endif

/* ---------------------------- Table accessors --------------------------- */

/**
 * Like lua_getfield() but raw.
 */
void
luaMC_rawgetfield (lua_State * L, int index, const char *key)
{
    index = lua_absindex (L, index);
    lua_pushstring (L, key);
    lua_rawget (L, index);
}

/**
 * Like lua_setfield() but raw.
 */
void
luaMC_rawsetfield (lua_State * L, int index, const char *key)
{
    index = lua_absindex (L, index);
    lua_pushstring (L, key);
    lua_insert (L, -2);
    lua_rawset (L, index);
}

/**
 * Appends the top element to a sequence.
 */
void
luaMC_raw_append (lua_State * L, int index)
{
    lua_rawseti (L, index, lua_rawlen (L, index) + 1);
}

/**
 * Utility: Like lua_setfield(), but for booleans only.
 */
void
luaMC_setflag (lua_State * L, int index, const char *fname, gboolean value)
{
    index = lua_absindex (L, index);
    lua_pushboolean (L, value);
    lua_setfield (L, index, fname);
}

/**
 * A utility function. Just like lua_gettable(), but accepts a table name
 * instead of its index.
 *
 * Pseudo:
 *
 *    k = stack.pop()
 *    stack.push( registry[table_name][k] )
 */
void
luaMC_registry_gettable (lua_State * L, const char *table_name)
{
    lua_getfield (L, LUA_REGISTRYINDEX, table_name);
    lua_insert (L, -2);
    lua_gettable (L, -2);
    lua_remove (L, -2);
}

/**
 * A utility function. Just like lua_settable(), but accepts a table name
 * instead of its index.
 *
 * Pseudo:
 *
 *    registry[table_name][ stack[-2] ] = stack[-1]
 *    stack.pop(2)
 */
void
luaMC_registry_settable (lua_State * L, const char *table_name)
{
    lua_getfield (L, LUA_REGISTRYINDEX, table_name);
    lua_insert (L, -3);
    lua_settable (L, -3);
    lua_pop (L, 1);
}

/**
 * Like lua_getglobal() but works on two levels. E.g., to fetch `math.pow`
 * you do `luaMC_getglobal2 (L, "math", "pow")`.
 */
gboolean
luaMC_getglobal2 (lua_State * L, const char *name1, const char *name2)
{
    lua_getglobal (L, name1);
    if (!lua_isnil (L, -1))
    {
        lua_getfield (L, -1, name2);
        lua_remove (L, -2);
    }
    return !lua_isnil (L, -1);
}

/**
 * Searches a table's values for an element. The element to search for is
 * given at the top of the stack.
 *
 * It replaces the element (at top of the stack) with its key in the table,
 * or with 'nil' if not found in the table. (In other words, the stack
 * keeps its size.)
 */
void
luaMC_search_table (lua_State * L, int tindex)
{
    LUAMC_GUARD (L);

    int eindex = lua_gettop (L);
    tindex = lua_absindex (L, tindex);

    lua_pushnil (L);
    while (lua_next (L, tindex))
    {
        if (lua_rawequal (L, eindex, -1))
        {
            /* Found. Delete the value; the key is then left at the top of the stack. */
            lua_pop (L, 1);
            goto ok;
        }
        /* Remove value; keep key for next iteration. */
        lua_pop (L, 1);
    }
    lua_pushnil (L);            /* Signal that we've found nothing. */
  ok:
    lua_remove (L, eindex);     /* The element searched. */

    LUAMC_UNGUARD (L);
}

/* ----------------------------- Userdata --------------------------------- */

/**
 * Like lua_newuserdata() but also calls luaL_setmetatable().
 *
 * Warning: if your userdata holds a pointer, and your metatable's __gc frees
 * this pointer, make sure not to run code similar to:
 *
 *    MyData *p = luaMC_newuserdata (L, sizeof(MyData), "myprog.MyData");
 *    ... code which may raise exception ...
 *    p->the_pointer = whatever;
 *
 * In this case, if an exception is raised, your __gc will be called with a
 * garbage address (use luaMC_newuserdata0() instead if it's a likely
 * scenario for you).
 */
void *
luaMC_newuserdata (lua_State * L, size_t size, const char *tname)
{
    void *p;

    p = lua_newuserdata (L, size);
    luaL_setmetatable (L, tname);
    return p;
}

/**
 * Like luaMC_newuserdata(), but also zeros all the bytes.
 */
void *
luaMC_newuserdata0 (lua_State * L, size_t size, const char *tname)
{
    void *p;

    p = lua_newuserdata (L, size);
    memset (p, 0, size);
    luaL_setmetatable (L, tname);
    return p;
}

/**
 * Like luaL_checkudata() but doesn't check for the udata type. So it's faster.
 *
 * The 'tname' doesn't need to be a real metatable name: since it's only used
 * in error messages, you may pick something that users are more likely to
 * understand.
 */
void *
luaMC_checkudata__unsafe (lua_State * L, int index, const char *tname)
{
    void *p;

    p = lua_touserdata (L, index);
    if (p)
        return p;
    else
        return luaL_checkudata (L, index, tname);
}

/**
 * Gets a userdata's stash.
 *
 * "stash", in our lingo, is a table associated with a userdata. Also known
 * as "user value" in Lua 5.2+.
 *
 * If the stash wasn't yet created, it gets created, and TRUE is returned.
 *
 * The first field of the userdata must be a gboolean (for recording the
 * fact of the stash's creation). It's needed because there's otherwise no
 * very efficient way to detect this on Lua 5.1:
 *
 *   http://stackoverflow.com/questions/23797926/how-to-detect-if-a-userdata-has-environment-table
 *
 * see also http://stackoverflow.com/questions/3332448/treating-userdate-like-a-table-in-lua/3332972#3332972
 */
gboolean
luaMC_get_stash (lua_State * L, int index)
{
    gboolean *userdata_has_stash;

    index = lua_absindex (L, index);
    userdata_has_stash = lua_touserdata (L, index);

    if (*userdata_has_stash)
    {
#ifdef HAVE_LUA_GETFENV
        lua_getfenv (L, index);
#else
        lua_getuservalue (L, index);
#endif
        return FALSE;
    }
    else
    {
        lua_newtable (L);
        lua_pushvalue (L, -1);  /* duplicate the table */
#ifdef HAVE_LUA_GETFENV
        lua_setfenv (L, index);
#else
        lua_setuservalue (L, index);
#endif
        *userdata_has_stash = TRUE;
        return TRUE;
    }
}

/* ------------------------------ Functions ------------------------------- */

/* like luaL_callmeta() but doesn't leave a value on the stack. */
void
luaMC_pingmeta (lua_State * L, int index, const char *method_name)
{
    if (luaL_callmeta (L, index, method_name))
        lua_pop (L, 1);
}

/*
 * For the following two, see ldoc of 'internal.register_system_callback()'.
 */

void
luaMC_register_system_callback (lua_State * L, const char *name, int idx)
{
    lua_pushfstring (L, "__mc_system_callback__%s", name);
    lua_pushvalue (L, idx);
    lua_settable (L, LUA_REGISTRYINDEX);
}

gboolean
luaMC_get_system_callback (lua_State * L, const char *name)
{
    lua_pushfstring (L, "__mc_system_callback__%s", name);
    lua_gettable (L, LUA_REGISTRYINDEX);
    if (lua_isnil (L, -1))
    {
        lua_pop (L, 1);
        return FALSE;
    }
    else
        return TRUE;
}

/**
 * Returns the name of the current function, or of the function 'level'th
 * in the call stack.
 */
const char *
luaMC_get_function_name (lua_State * L, int level, gboolean keep_underscore)
{
    lua_Debug ar;

    if (!lua_getstack (L, level, &ar))
        return "?";

    lua_getinfo (L, "n", &ar);
    if (ar.name == NULL)
        return "?";

    if (!keep_underscore && *ar.name == '_')
        ++ar.name;

    return ar.name;
}

/*
 * lua_pcall() wrapper:
 */

/*
 * The following is equivalent to:
 *
 * function (msg)
 *   return debug.traceback(msg, 2)
 * end
 */
static int
_luaMC_pcall__errfunc (lua_State * L)
{
    luaMC_getglobal2 (L, "debug", "traceback");
    lua_insert (L, -2);
    lua_pushinteger (L, 2);
    lua_call (L, 2, 1);
    return 1;
}

/**
 * Like lua_pcall() except that the message also contains the traceback.
 */
gboolean
luaMC_pcall (lua_State * L, int nargs, int nresults)
{
    int errfunc_idx = lua_gettop (L) - nargs;
    gboolean success;

    lua_pushcfunction (L, _luaMC_pcall__errfunc);
    lua_insert (L, errfunc_idx);

    LUAMC_GUARD (L);

    success = !lua_pcall (L, nargs, nresults, errfunc_idx);

    LUAMC_UNGUARD_BY (L, success ? (-1 - nargs + nresults) : (-1 - nargs + 1));

    lua_remove (L, errfunc_idx);

    return success;
}

/* ---------------------- Stuff missing from Lua 5.1 ---------------------- */

#ifndef HAVE_LUA_ABSINDEX
int
lua_absindex (lua_State * L, int idx)
{
    int top = lua_gettop (L);
    if (idx < 0 && -idx <= top)
        return top + idx + 1;
    else
        return idx;
}
#endif

#ifndef HAVE_LUAL_SETMETATABLE
void
luaL_setmetatable (lua_State * L, const char *tname)
{
    luaL_getmetatable (L, tname);
    lua_setmetatable (L, -2);
}
#endif

#ifndef HAVE_LUAL_GETSUBTABLE
int
luaL_getsubtable (lua_State * L, int idx, const char *name)
{
    idx = lua_absindex (L, idx);
    lua_getfield (L, idx, name);
    if (lua_isnil (L, -1))
    {
        lua_pop (L, 1);
        lua_newtable (L);
        lua_pushvalue (L, -1);
        lua_setfield (L, idx, name);
        return FALSE;
    }
    else
        return TRUE;
}
#endif

#ifndef HAVE_LUAL_TESTUDATA
/* This triviality was copied from Lua 5.2 source code (we have no other code
 * copied from there, so no copyright issues). */
void *
luaL_testudata (lua_State * L, int ud, const char *tname)
{
    void *p = lua_touserdata (L, ud);
    if (p != NULL)
    {                           /* value is a userdata? */
        if (lua_getmetatable (L, ud))
        {                       /* does it have a metatable? */
            luaL_getmetatable (L, tname);       /* get correct metatable */
            if (!lua_rawequal (L, -1, -2))      /* not the same? */
                p = NULL;       /* value is a userdata with wrong metatable */
            lua_pop (L, 2);     /* remove both metatables */
            return p;
        }
    }
    return NULL;                /* value is not a userdata with a metatable */
}
#endif

#ifndef luaL_newlib
void
luaL_newlib (lua_State * L, const luaL_Reg * l)
{
    lua_newtable (L);
    luaL_setfuncs (L, l, 0);
}
#endif

/* --------------------- Borrowings from Lua 5.1 -------------------------- */

#ifndef HAVE_LUAL_TYPERROR
int
luaL_typerror (lua_State * L, int narg, const char *tname)
{
    const char *info =
        lua_pushfstring (L, E_ ("%s expected, got %s"), tname, luaL_typename (L, narg));
    luaL_argerror (L, narg, info);
    return 0;                   /* We never reach here. */
}
#endif

/* ---------------- Registering modules/functions/constants --------------- */

/* Registers constants with the table at top of stack. */
void
luaMC_register_constants (lua_State * L, const luaMC_constReg * l)
{
    while (l->name)
    {
        lua_pushinteger (L, l->value);
        lua_setfield (L, -2, l->name);
        ++l;
    }
}

/**
 * like lua_register() but works for an array of functions.
 */
void
luaMC_register_globals (lua_State * L, const luaL_Reg * l)
{
    while (l->name)
    {
        lua_register (L, l->name, l->func);
        ++l;
    }
}

/**
 * Creates a metatable.
 *
 * Since it's common to have an '__index' field pointing to self, this
 * function also optionally does this for you.
 */
void
luaMC_register_metatable (lua_State * L, const char *tname, const luaL_Reg * l,
                          gboolean create_index)
{
    luaL_newmetatable (L, tname);
    luaL_setfuncs (L, l, 0);
    if (create_index)
    {
        lua_pushvalue (L, -1);
        lua_setfield (L, -2, "__index");
    }
}

/* Like Lua 5.2's luaL_requiref() (but doesn't support its last parameter,
 * which sets a global var.) */
void
luaMC_requiref (lua_State * L, const char *modname, lua_CFunction openf)
{
    LUAMC_GUARD (L);

    g_assert (luaMC_getglobal2 (L, "package", "loaded"));

    lua_pushcfunction (L, openf);
    lua_pushstring (L, modname);
    lua_call (L, 1, 1);

    lua_setfield (L, -2, modname);

    lua_pop (L, 1);             /* package.loaded */

    LUAMC_UNGUARD (L);
}

/* -------------------------- Programming aids ---------------------------- */

/*
 * A utility function: Converts a "Lua index" (1-based; possibly negative)
 * to a "C index" (0-based; positive; endpoint points past the range).
 *
 * (The function uses off_t because it was originally written to handle
 * WEdit, which uses off_t for positions.)
 */
off_t
mc_lua_fixup_idx (off_t idx, off_t len, gboolean endpoint)
{
    if (idx < 0)
        idx = len + idx + 1;

    if (!endpoint)
        --idx;

    if (idx < 0)
        idx = 0;

    if (len != -1)
    {
        /* As a service to the user, we also offer trimming 'idx'. This would
         * ensure, e.g., that we don't point past a C string.
         *
         * If 'len' isn't known, you must pass '-1' to turn this feature off.
         *
         * If this feature ends up not being used, we'd better remove it. */
        if (idx > len)
            idx = len;
    }

    return idx;
}

/**
 * Ensures the function doesn't have more than 'count' arguments.
 *
 * (We don't check for less or equal to 'count': the user may leave off
 * optional arguments.)
 */
void
luaMC_checkargcount (lua_State * L, int count, gboolean is_method)
{
    if (lua_gettop (L) > count)
    {
        if (is_method)
            luaL_error (L, E_ ("Too many arguments for method; only %d expected"), count - 1);
        else
            luaL_error (L, E_ ("Too many arguments for function; only %d expected"), count);
    }
}
