/**

Regular expressions.

The standard Lua library provides a handful of functions to deal with
strings using "patterns". Lua patterns, however, aren't as powerful as
the Regular Expressions many programmers have come to expect.

To fill this void, we also provide real, Perl-compatible regular
expressions (henceforth: PCRE) for you to use in your Lua code. The API
for this facility mimics the standard Lua API so you don't need to learn
anything new. These regex-compatible functions have `p_` prefixed to
their names. They're also available under the _regexp_ namespace without
this prefix.

For example, instead of:

    local first, last = s:match "(%w+) (%w+)"
    -- also available as:
    -- local first, last = string.match(s, "(%w+) (%w+)")

do:

    local first, last = s:p_match "(\\w+) (\\w+)"
    -- also available as:
    -- local first, last = regex.match(s, "(\\w+) (\\w+)")

for the PCRE version.

[tip]

You can use Lua's _long literal_ string syntax to make your regular
expressions more readable: you won't have to escape your backslashes
then. For example, the previous line of code would look like:

    local first, last = s:p_match [[(\w+) (\w+)]]

[/tip]

## Specifying regular expressions

There are three ways to specify a regular expression:

__(1)__ As a *string*:

[indent]

    if file_extension:p_match "jpe?g" then ...

[/indent]

__(2)__ As a *table* whose first element is a string and whose second
element is a flags string:

[indent]

    if file_extension:p_match {"jpe?g","i"} then ...

[info]

The flags string may contain any of these letters (the order doesn't matter):

"i" Case insensitive matching.

"u" Enable UTF-8 handling (makes `...` match three characters, not three
bytes, and `\w` match non-English too).

"x" Extended regexp, which means you can use whitespaces and comments for
readability.

"s" Makes dot match newline as well.

"m" Makes `^` and `$` match newline boundaries as well.

For a regex that uses "smx", see @{git:luafs_markdown.lua}.

[/info]

[/indent]

__(3)__ As a *compiled* regex object:

[indent]

    local picture = regex.compile {"jpe?g","i"}
    ...
    if file_extension:p_match(picture) then ...

Note: Using a string (or a table) instead of a compiled regex isn't
inefficient: the string is compiled and kept in an internal cache. The
next time you use the string the cache will be examined and the compiled
regex be pulled out. This cache lookup, however, has some cost which you
can save, especially in tight loops, by supplying the compiled regex
directly.

[/indent]

@module regex
*/

#include <config.h>

#include "lib/global.h"
#include "lib/lua/capi.h"
#include "lib/lua/utilx.h"

#include "../modules.h"

/*
 * Note: MC, starting with 4.8.14, requires GLib 2.14+, so we know we do have regex support.
 */

/*
 * The Lua userdata.
 */
typedef struct
{
    GRegex *handle;
} LuaRegex;

typedef long flags_t;

/* By default regex patterns are compiled as non UTF-8. (The user may override
 * this by specifying the "u" flag.) We may wish to revisit this decision later on. */
#define DEFAULT_REGEX_FLAGS G_REGEX_RAW

/* The following only affects split(), not tsplit(). */
#define MAX_SPLIT_TOKENS 12

/* -------------------------------- Cache --------------------------------- */

/* The maximum number of compiled regex objects to keep in the cache. */
#define REGEX_CACHE_MAX  128

/* How many regex objects are currently held in the cache? */
static int regex_cache_size = 0;

/* Empty (or initialize) the cache. */
static void
regex_cache__clear (lua_State * L)
{
    lua_newtable (L);
    lua_setfield (L, LUA_REGISTRYINDEX, "regex.cache");
    regex_cache_size = 0;
}

/* To be called whenever you add an item to the cache. */
static void
regex_cache__bump_size (lua_State * L)
{
    ++regex_cache_size;
    if (regex_cache_size > REGEX_CACHE_MAX)
        regex_cache__clear (L);
}

/* -------------------------------- Flags --------------------------------- */

/* Raise error with the message contained in a GError. Also calls g_error_feee(). */
static int
raise_error (lua_State * L, GError * error)
{
    lua_pushstring (L, error->message);
    g_error_free (error);
    return luaL_error (L, "%s", lua_tostring (L, -1));
}

static flags_t
parse_flags (lua_State * L, const char *flags_string, flags_t flags)
{
    const char *c = flags_string;
    while (*c)
    {
        switch (*c)
        {
        case 'i':
            flags |= G_REGEX_CASELESS;
            break;
        case 'u':
            /* GLib doesn't have a flag for enabling UTF-8: it's enabled by default.
               It only has a flag for disabling it (G_REGEX_RAW), which we now undo. */
            flags &= ~G_REGEX_RAW;
            break;
        case 'x':
            flags |= G_REGEX_EXTENDED;
            break;
        case 'o':
            flags |= G_REGEX_OPTIMIZE;
            break;
        case 's':
            flags |= G_REGEX_DOTALL;
            break;
        case 'm':
            flags |= G_REGEX_MULTILINE;
            break;
        default:
            return luaL_error (L, E_ ("Invalid regex flag '%c'."), *c);
        }
        ++c;
    }
    return flags;
}

/**
 * Converts a flags string (e.g., "sm", "u", ...) to PCRE's codes.
 */
static flags_t
luaMC_checkflags (lua_State * L, int index)
{
    flags_t flags = DEFAULT_REGEX_FLAGS;

    if (index != 0 && !lua_isnoneornil (L, index))
        flags = parse_flags (L, luaL_checkstring (L, index), flags);

    return flags;
}

/* ---------------------------- Compilation ------------------------------- */

/**
 * The function that actually compiles a pattern.
 */
static void
luaMC_pushregex (lua_State * L, const char *pattern, flags_t flags)
{
    LuaRegex *re;
    GError *error = NULL;

    re = luaMC_newuserdata (L, sizeof (LuaRegex), "regex.Regex");

    re->handle = g_regex_new (pattern, flags, 0, &error);

    if (error != NULL)
        raise_error (L, error);
}

/**
 * Given a regex pattern (its index) and its flags (its index), either
 * compiles a regex object or returns a previously cached one.
 *
 * Either way, it leaves a regex object at the top of the stack.
 */
static void
create_regex_or_cached (lua_State * L, int index_pattern, int index_flags)
{
    const char *pattern;
    flags_t flags;

    pattern = luaL_checkstring (L, index_pattern);
    flags = luaMC_checkflags (L, index_flags);

    /*
     * The following code can be expressed using this pseudo:
     *
     *   local key = pattern .. ":" .. flags
     *   if cache[key] then
     *     return cache[key]
     *   else
     *     local new = compile_regex(pattern, flags)
     *     cache[key] = new
     *     return new
     *   end
     */

    LUAMC_GUARD (L);

    lua_getfield (L, LUA_REGISTRYINDEX, "regex.cache");
    lua_pushvalue (L, index_pattern);
    lua_pushliteral (L, ":");
    lua_pushi (L, flags);
    lua_concat (L, 3);
    lua_pushvalue (L, -1);      /* Duplicate this key in case we'll need to write to the cache. */
    lua_gettable (L, -3);

    if (!lua_isnil (L, -1))
    {
        /* Yes, the regex is in the cache. */

        /*
         * The stack now contains:
         *
         * -3   regex.cache
         * -2   pattern .. ":" .. flags
         * -1   userdata
         */

        /* We delete stack[-3 .. -2] */
        lua_remove (L, -2);
        lua_remove (L, -2);

        d_message (("<<returning cached regex>>\n"));

        /* The top of the stack contains the regex. */
    }
    else
    {
        /* No, the regex isn't in the cache. Compile one. */

        lua_pop (L, 1);         /* Delete the nil at the top. */

        luaMC_pushregex (L, pattern, flags);

        lua_pushvalue (L, -1);
        lua_insert (L, -4);

        /*
         * The stack now contains:
         *
         * -4   userdata
         * -3   regex.cache
         * -2   pattern .. ":" .. flags
         * -1   userdata
         */

        g_assert (lua_type (L, -4) == LUA_TUSERDATA);
        g_assert (lua_type (L, -3) == LUA_TTABLE);

        lua_settable (L, -3);   /* Save it to the cache. */
        regex_cache__bump_size (L);
        lua_pop (L, 1);

        d_message (("<<caching a new regex>>\n"));

        /* The top of the stack contains the regex. */
    }

    /* Ensure that the top of the stack contains the regex. */
    g_assert (lua_type (L, -1) == LUA_TUSERDATA);

    /* Ensure the stack has grown by 1 (the regex). */
    LUAMC_UNGUARD_BY (L, 1);
}

/**
 * Converts a Lua value to a C regex.
 *
 * The Lua value may be either a regex (userdata), a string (denoting a
 * pattern), or a table (denoting { pattern, flags }),
 *
 * The Lua value is converted in-place if it's not already a regex (so the
 * semantic of this function follows the convention set by lua_tostring/luaL_checkstring).
 */
static LuaRegex *
luaMC_checkregex_ex (lua_State * L, int index, int index_flags)
{
    index = lua_absindex (L, index);
    index_flags = lua_absindex (L, index_flags);

    if (lua_isuserdata (L, index))
    {
        /* It's already a regex object. Return it directly. */
        return luaL_checkudata (L, index, "regex.Regex");
    }
    /* Convert from a string or table: */
    else if (lua_type (L, index) == LUA_TSTRING)
    {
        create_regex_or_cached (L, index, index_flags);
        lua_replace (L, index); /* Override 'index' with the userdata. */
        return lua_touserdata (L, index);
    }
    else if (lua_type (L, index) == LUA_TTABLE)
    {
        lua_rawgeti (L, index, 1);      /* pattern */
        lua_rawgeti (L, index, 2);      /* flags */
        luaMC_checkregex_ex (L, -2, -1);
        lua_pop (L, 1);         /* flags */
        lua_replace (L, index); /* Override 'index' with the userdata. */
        return lua_touserdata (L, index);
    }
    else
    {
        luaL_error (L,
                    E_
                    ("Unrecognized format for regex. A string, table, or compiled regex is expected."));
    }

    return NULL;                /* We never arrive here. */
}

static GRegex *
luaMC_checkregex (lua_State * L, int index)
{
    return luaMC_checkregex_ex (L, index, 0)->handle;
}

/**
 * Compiles a regular expression.
 *
 * The **regex** parameter may be in any of the three forms specified in
 * "Specifying regular expressions". If **regex** is already a compiled
 * regex object, the function simply returns the same object.
 *
 * Note-short: as explained above, you don't *have* to compile your regular
 * expressions.
 *
 * @function compile
 * @qualifier regex
 * @args (regex)
 */
static int
l_compile (lua_State * L)
{
    luaMC_checkregex (L, 1);
    luaMC_checkargcount (L, 1, FALSE);  /* Guard against the user doing `compile(".", "u")` instead of `compile {".", "u"}`. */
    return 1;
}

/* ------------------------------ Matching -------------------------------- */

static void
push_match (lua_State * L, const GMatchInfo * match_info, int num)
{
    luaMC_pushstring_and_free (L, g_match_info_fetch (match_info, num));
}

static int
push_captures (lua_State * L, const GMatchInfo * match_info)
{
    int count = g_match_info_get_match_count (match_info) - 1;  /* "-1" gives the number of captures. */
    int i;

    for (i = 1; i <= count; i++)        /* We start from "1". "0" is the whole match. */
        push_match (L, match_info, i);

    /* 'count' may be negative (in case of error or no match), so we don't
       do "return count". We return the number of push_match() calls. */
    return i - 1;
}

/**
 * The implementation of regex.match() / regex.find().
 */
static int
match_or_find (lua_State * L, gboolean do_find)
{
    const char *subject;
    size_t len;
    GRegex *re;
    int start;

    int return_count;
    GMatchInfo *match_info;

    subject = luaL_checklstring (L, 1, &len);
    re = luaMC_checkregex (L, 2);
    /* glib works with 'int' (aka 'gint') offsets. Feels like an anti-climax.
     * It means we can do with lua[L]_{opt|push}int. But to be stylistically
     * compatible with handling file offsets, lets use lua[L]_{opt|push}i. */
    start = luaL_opti (L, 3, 1);

    /* Lua's string.find() supports a 4'th argument ("plain text") but we do not: */
    luaMC_checkargcount (L, 3, FALSE);

    start = mc_lua_fixup_idx (start, len, FALSE);
    /* glib can handle a 'start' that's past the end of the string.
     * Nevertheless, mc_lua_fixup_idx() ensures this doesn't happen. */

    g_regex_match_full (re, subject, len, start, 0, &match_info, NULL);

    if (g_match_info_matches (match_info))
    {
        if (do_find)
        {
            /* From Lua's manual:
             *
             * "find() returns the indices of s where this occurrence starts and
             * ends [...] If the pattern has captures, then in a successful match
             * the captured values are also returned, after the two indices."
             */
            gint m_start, m_end;
            g_match_info_fetch_pos (match_info, 0, &m_start, &m_end);
            lua_pushi (L, m_start + 1);
            lua_pushi (L, m_end);
            return_count = push_captures (L, match_info) + 2;
        }
        else
        {
            /* From Lua's manual:
             *
             * match() returns the captures from the pattern [...] If pattern
             * specifies no captures, then the whole match is returned."
             */
            return_count = push_captures (L, match_info);
            if (return_count == 0)
            {
                push_match (L, match_info, 0);
                return_count = 1;
            }
        }
    }
    else
    {
        /* Nothing found. */
        lua_pushnil (L);
        return_count = 1;
    }

    g_match_info_free (match_info);

    return return_count;
}

/**
 * Searches in a string.
 *
 * Like @{string.match} but uses a regular expression.
 *
 * @function match
 * @args (s, regex[, init])
 */
static int
l_match (lua_State * L)
{
    return match_or_find (L, FALSE);
}

/**
 * Searches in a string.
 *
 * Like @{string.find} but uses a regular expression.
 *
 * @function find
 * @args (s, regex[, init])
 */
static int
l_find (lua_State * L)
{
    return match_or_find (L, TRUE);
}

static gboolean
eval_cb (const GMatchInfo * match_info, GString * result, gpointer data)
{
    lua_State *L = (lua_State *) data;

    gchar *whole_match;
    int argn;
    const char *cb_result;

    whole_match = g_match_info_fetch (match_info, 0);

    lua_pushvalue (L, 3);       /* The Lua function to call. */
    /*
     * From Lua's manual:
     *
     * "[the] function is called every time a match occurs, with all captured
     * substrings passed as arguments, in order; if the pattern specifies no
     * captures, then the whole match is passed as a sole argument."
     */
    argn = push_captures (L, match_info);
    if (argn == 0)
    {
        lua_pushstring (L, whole_match);
        ++argn;
    }

    lua_call (L, argn, 1);

    cb_result = lua_tostring (L, -1);
    /*
     * From Lua's manual:
     *
     * "If the value returned by the table query or by the function call is a
     * string or a number, then it is used as the replacement string; otherwise,
     * if it is false or nil, then there is no replacement (that is, the
     * original match is kept in the string)."
     */
    if (cb_result)
        g_string_append (result, cb_result);
    else
        g_string_append (result, whole_match);
    lua_pop (L, 1);

    g_free (whole_match);
    return FALSE;               /* GLib's manual: "FALSE to continue the replacement process, TRUE to stop it. */
}

static int
gsub_by_callback (lua_State * L, const char *subject, size_t len, GRegex * re)
{
    luaMC_pushstring_and_free (L, g_regex_replace_eval (re, subject, len, 0, 0, eval_cb, L, NULL));
    return 1;
}

static int
gsub_by_template (lua_State * L, const char *subject, size_t len, GRegex * re)
{
    const char *template;

    template = luaL_checkstring (L, 3);
    luaMC_pushstring_and_free (L, g_regex_replace (re, subject, len, 0, template, 0, NULL));
    return 1;
}

/**
 * Performs a global search/replace on a string.
 *
 * Like @{string.gsub} but uses a regular expression.
 *
 * @function gsub
 * @args (s, regex, repl)
 */
static int
l_gsub (lua_State * L)
{
    const char *subject;
    size_t len;
    GRegex *re;

    subject = luaL_checklstring (L, 1, &len);
    re = luaMC_checkregex (L, 2);

    /* Lua's string.gsub() supports a 4'th argument (number of replacements) but we do not: */
    luaMC_checkargcount (L, 3, FALSE);

    if (lua_isstring (L, 3))
        return gsub_by_template (L, subject, len, re);
    else if (lua_isfunction (L, 3))
        return gsub_by_callback (L, subject, len, re);
    else
        return luaL_typerror (L, 3, "string/function");
}

static int
split (lua_State * L, gboolean return_table)
{
    const char *subject;
    size_t len;
    GRegex *re;
    int max_tokens;

    gchar **result;

    subject = luaL_checklstring (L, 1, &len);
    re = luaMC_checkregex (L, 2);
    max_tokens = luaL_optint (L, 3, -1);

    if (!return_table)
    {
        /* Don't blow out the stack. */
        if (max_tokens < 1)
            max_tokens = MAX_SPLIT_TOKENS;
        else
            max_tokens = min (max_tokens, MAX_SPLIT_TOKENS);
    }

    result = g_regex_split_full (re, subject, len, 0, 0, max_tokens, NULL);

    if (return_table)
        lua_newtable (L);

    /* Block exists just to keep variables more tidy. */
    {
        int count = 0;
        gchar *token = result[0];

        while (token)
        {
            if (return_table)
            {
                lua_pushstring (L, token);
                lua_rawseti (L, -2, count + 1);
            }
            else
            {
                lua_pushstring (L, token);
            }
            token = result[++count];
        }

        g_strfreev (result);

        return return_table ? 1 : count;
    }
}

/**
 * Splits a string.
 *
 * If __regex__ contains captures, these are returned as well.
 *
 *    local s = "flavor = sweet"
 *    local name, value = s:p_split "\\s*=\\s*"
 *
 * Use __limit__ to set the maximum number of fields returned. The maximum
 * possible value for __limit__ is 12; use @{tsplit} instead if this maximum
 * restricts you.
 *
 * @function split
 * @args (s, regex[, limit])
 */
static int
l_split (lua_State * L)
{
    return split (L, FALSE);
}

/**
 * Splits a string into a table.
 *
 * Like @{split} but the results are returned as a table. There's no
 * restriction on __limit__.
 *
 * @function tsplit
 * @args (s, regex[, limit])
 */
static int
l_tsplit (lua_State * L)
{
    return split (L, TRUE);
}

/*
 * Garbage collector for a regex.
 */
static int
l_regex_gc (lua_State * L)
{
    GRegex *re;

    d_message (("__gc of regex\n"));

    re = luaMC_checkregex (L, 1);
    /* 're' might be NULL in one case only: if the regex fails to compile; see luaMC_pushregex */
    if (re != NULL)
        g_regex_unref (re);

    return 0;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg regex_class_lib[] = {
    { "__gc", l_regex_gc },
    { NULL, NULL }
};

static const struct luaL_Reg regex_lib[] = {
    { "compile", l_compile },
    { "match", l_match },
    { "find", l_find },
    { "gsub", l_gsub },
    { "split", l_split },
    { "tsplit", l_tsplit },
    /* Should we have a clear_cache() Lua function too? (calling regex_cache__clear())
     * No reason to, probably. */
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_regex (lua_State * L)
{
    regex_cache__clear (L);

    luaMC_register_metatable (L, "regex.Regex", regex_class_lib, FALSE);
    lua_pop (L, 1);             /* we don't need this metatable */
    luaL_newlib (L, regex_lib);
    return 1;
}
