/**
 * This file extends Lua's C API. It also handles compatibility
 * issues between the different Lua versions.
 *
 * #Include this file when you want to use Lua's API. It pulls in Lua's
 * headers.
 */
#ifndef MC__LUA_CAPI_H
#define MC__LUA_CAPI_H

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

extern lua_State *Lg;           /* the Lua VM */

/* ------------------------------- Scalars -------------------------------- */

gboolean luaMC_pop_boolean (lua_State * L);
lua_Integer luaMC_pop_integer (lua_State * L);
int luaMC_get_sign (lua_State * L, int idx);
gboolean luaMC_is_int_eq (lua_State * L, int idx, int val);
gboolean luaMC_optboolean (lua_State * L, int idx, gboolean def_val);

/**
 * Use lua_pushi() to push potentially huge integers. It supports
 * integers larger than 32 bits.
 *
 * Why?
 *
 * - We can't use lua_pushinteger(), because on older Luas it's typically
 *   limited to 32 bits.
 * - We shouldn't use lua_pushnumber() because on newer Lua (5.3+) it results
 *   in a double and printed with floating point.
 *
 * This macro, lua_pushi(), solves the problem by selecting the appropriate
 * function.
 *
 * As for small integers:
 *
 * The question is whether lua_pushinteger() is more efficient than
 * lua_pushi(). In practice it is NOT. In theory, on older Luas,
 * lua_pushinteger() purportedly could be made to be more efficient than
 * lua_pushi (where the latter uses lua_pushnumber); see [1].
 *
 * So:
 * - For numbers you know are small, use lua_pushinteger() to make purists happy.
 * - In any other case, or in the slightest doubt, use lua_pushi().
 *
 * [1] http://stackoverflow.com/questions/24184614/why-should-we-use-lua-pushinteger
 */
#ifdef HAVE_LUA_ISINTEGER
/* Lua 5.3+ */
#  if SIZEOF_LUA_INTEGER <= 4   /* sanity check */
#    error "Your Lua engine was compiled with integer type too small to represent huge numbers."
#  endif
#  define lua_pushi lua_pushinteger
#else
/* Older Luas */
#  if SIZEOF_LUA_NUMBER <= 4    /* sanity check */
#    error "Your Lua engine was compiled with number type too small to represent huge numbers."
#  endif
#  define lua_pushi lua_pushnumber
#endif

/**
 * Use luaL_opti() and luaL_checki() for reading potentially huge integers.
 *
 * Using them for reading small integers ('int's) doesn't have any performance penalty.
 */
#ifdef HAVE_LUA_ISINTEGER
/* Lua 5.3+ */
#  define luaL_opti luaL_optinteger
#  define luaL_checki luaL_checkinteger
#else
/* Older Luas */
#  define luaL_opti luaL_optnumber
#  define luaL_checki luaL_checknumber
#endif

/* ------------------------------- Strings -------------------------------- */

void luaMC_pushstring_and_free (lua_State * L, char *s);
const char *luaMC_tolstring (lua_State * L, int idx, size_t * len);
int /* estr_t */ luaMC_pushlstring_conv (lua_State * L, const char *s, size_t len, GIConv conv);

/* ------------------------------- Tables --------------------------------- */

void luaMC_new_weak_table (lua_State * L, const char *what /* k, v, kv */ );
void luaMC_enable_table_gc (lua_State * L, int index);

/* ---------------------------- Table accessors --------------------------- */

void luaMC_rawgetfield (lua_State * L, int index, const char *key);
void luaMC_rawsetfield (lua_State * L, int index, const char *key);
void luaMC_raw_append (lua_State * L, int index);
void luaMC_setflag (lua_State * L, int index, const char *fname, gboolean value);
void luaMC_registry_settable (lua_State * L, const char *table_name);
void luaMC_registry_gettable (lua_State * L, const char *table_name);
gboolean luaMC_getglobal2 (lua_State * L, const char *name1, const char *name2);
void luaMC_search_table (lua_State * L, int tindex);

/* ------------------------------- Userdata ------------------------------- */

void *luaMC_newuserdata (lua_State * L, size_t size, const char *tname);
void *luaMC_newuserdata0 (lua_State * L, size_t size, const char *tname);
void *luaMC_checkudata__unsafe (lua_State * L, int index, const char *tname);
gboolean luaMC_get_stash (lua_State * L, int index);

/* ------------------------------ Functions ------------------------------- */

void luaMC_pingmeta (lua_State * L, int index, const char *method_name);
void luaMC_register_system_callback (lua_State * L, const char *name, int idx);
gboolean luaMC_get_system_callback (lua_State * L, const char *name);
const char *luaMC_get_function_name (lua_State * L, int level, gboolean keep_underscore);
gboolean luaMC_pcall (lua_State * L, int nargs, int nresults);

/* -------------- Stuff potentially missing from Lua 5.3+ ----------------- */

/*
 * The following conversion functions my be missing from Lua 5.3+ (depending
 * on some COMPAT macro's presence). So we define them here.
 *
 * They may be implemented either as functions or macros, hence the double check.
 */

#if !defined(HAVE_LUA_PUSHUNSIGNED) && !defined(lua_pushunsigned)
#define lua_pushunsigned lua_pushi
#endif

#if !defined(HAVE_LUAL_CHECKUNSIGNED) && !defined(luaL_checkunsigned)
#define luaL_checkunsigned(L, i) ((guint32) luaL_checkinteger (L, i))
#endif

#if !defined(HAVE_LUAL_CHECKINT) && !defined(luaL_checkint)
#define luaL_checkint(L, n) ((int) luaL_checkinteger (L, n))
#endif

#if !defined(HAVE_LUAL_CHECKLONG) && !defined(luaL_checklong)
#define luaL_checklong(L, n) ((long) luaL_checkinteger (L, n))
#endif

#if !defined(HAVE_LUAL_OPTINT) && !defined(luaL_optint)
#define luaL_optint(L, n, d) ((int) luaL_optinteger (L, n, d))
#endif

#if !defined(HAVE_LUAL_OPTLONG) && !defined(luaL_optlong)
#define luaL_optlong(L, n, d) ((long) luaL_optinteger (L, n, d))
#endif

/* ---------------------- Stuff missing from Lua 5.1 ---------------------- */

#ifndef HAVE_LUA_ABSINDEX
int lua_absindex (lua_State * L, int idx);
#endif

#ifndef HAVE_LUAL_SETMETATABLE
void luaL_setmetatable (lua_State * L, const char *tname);
#endif

#ifndef HAVE_LUAL_GETSUBTABLE
int luaL_getsubtable (lua_State * L, int idx, const char *name);
#endif

#ifndef HAVE_LUAL_TESTUDATA
void *luaL_testudata (lua_State * L, int ud, const char *tname);
#endif

#ifndef luaL_newlib
void luaL_newlib (lua_State * L, const luaL_Reg * l);
#endif

/* Lua 5.1 and 5.2+ have different ways to calc len, so we standardize on 5.2+'s. */
#ifndef HAVE_LUA_RAWLEN
#define lua_rawlen lua_objlen
#endif

#ifndef HAVE_LUAL_SETFUNCS
#define luaL_setfuncs(L, l, n) (luaL_register (L, NULL, l))
#endif

/* --------------------- Borrowings from Lua 5.1 -------------------------- */

#ifndef HAVE_LUAL_TYPERROR
int luaL_typerror (lua_State * L, int narg, const char *tname);
#endif

/* ---------------- Registering modules/functions/constants --------------- */

typedef struct luaMC_constReg
{
    const char *name;
    int value;
} luaMC_constReg;

void luaMC_register_constants (lua_State * L, const luaMC_constReg * l);
void luaMC_register_globals (lua_State * L, const luaL_Reg * l);
void luaMC_register_metatable (lua_State * L, const char *tname, const luaL_Reg * l,
                               gboolean create_index);
void luaMC_requiref (lua_State * L, const char *modname, lua_CFunction openf);

/* -------------------------- Programming aids ---------------------------- */

#define luaMC_checkoption(L, n, def, names, values) values[ luaL_checkoption (L, n, def, names) ]

/**
 * luaMC_push_option() is the opposite of luaMC_checkoption().
 *
 * It's a macro because the type of 'val' and 'values' isn't known.
 */
#define luaMC_push_option(L, val, fallback, names, values) \
    do { \
        int i; \
        for (i = 0; names[i] != NULL; i++) \
            if (values[i] == val) { \
                lua_pushstring (L, names[i]); \
                break; \
            } \
        if (names[i] == NULL) \
            lua_pushstring (L, fallback); \
    } while (0)

off_t mc_lua_fixup_idx (off_t idx, off_t len, gboolean endpoint);
void luaMC_checkargcount (lua_State * L, int count, gboolean is_method);

/*
 * Use LUAMC_GUARD() and LUAMC_UNGUARD() to make sure your code's pushes and
 * pops are balanced.
 *
 * (To prevent the 'indent' program from messing things up, put a semicolon
 * after both macros. With LUAMC_GUARD() we even manage to force you to do
 * this.)
 */

#define LUAMC_GUARD(L)    \
    { \
        int __top = lua_gettop (L)

#define LUAMC_UNGUARD(L)    \
        if (lua_gettop (L) != __top) { \
            g_error ("Lua stack error: I started at %d, but now am at %d", __top, lua_gettop (L)); \
        } \
    }

#define LUAMC_UNGUARD_BY(L, by)    \
        if (lua_gettop (L) != __top + (by)) { \
            g_error ("Lua stack error: I started at %d, but now am at %d", __top, lua_gettop (L)); \
        } \
    }

#endif /* MC__LUA_CAPI_H */
