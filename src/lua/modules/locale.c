/**

Localization.

Use these facilities to enable the localization of your application.

The main facility here is the `T` function. You should prepend a "`T`" to
any string literal in your code intended for human consumption. At
run-time this string will be replaced with a version in the user's
language, if such exists.

Tip: `T` is a normal function. You can use parenthesis for its
invocation, but we encourage the style without ones, as it makes your
code less "noisy". If you dislike this syntax because of its seemingly
alien look, notice that other, popular programming languages [too have
it](http://en.wikipedia.org/wiki/String_literal#Different_kinds_of_strings).

Note: The workflow for the localization of Lua modules is yet to be
decided by the MC community. At the time of this writing, as no such
workflow is yet practiced, `T` is effectively a no-op (unless applied to
strings that happen to be used in MC's C source code), but nevertheless
it's recommended that you use it: this will save you (and others) time
later.

@module locale

*/
#include <config.h>

#include <locale.h>

#include "lib/global.h"
#include "lib/util.h"           /* Q_() */
#include "lib/lua/capi.h"
#include "lib/lua/utilx.h"

#include "../modules.h"


static gboolean numeric_locale_is_posix = FALSE;

/**
 * Global functions.
 *
 * The following functions, for the sake of convenience, are defined in the
 * global namespace. That is, you don't need to prepend them with "locale.".
 *
 * @section
 */

/**
 * Translates a string.

Use it for strings that are intended for humans (as opposed to ones
intended for the machine, like IDs, which don't need translation).

    alert(T"Hello World!")

The string argument should be a *literal*. It can't be a variable
(unless used in tandem with `N`). That's because a tool (a POT
extractor) analyzes the source code itself and extracts all such marked
strings.

For a similar reason you can't concatenate strings like this:

    -- This is wrong!
    alert(T("My name is " .. name .. " and I'm from " .. country))

For "linguistic" reasons neither can you do:

    -- This is wrong!
    alert(T"My name is " .. name .. T" and I'm from " .. country))

Instead you should use @{string.format|:format}, as in:

    -- correct!
    alert(T"My name is %s and I'm from %s":format(name, country))

Tip: C programmers: this function is simply a wrapper for the
[gettext()](http://en.wikipedia.org/wiki/Gettext) function, which is usually
aliased to "_" in C code. One reason we don't use an underscore in Lua is
because it clashes with its `local _, b = somefunc()` idiom (a borrowing
from Perl).

 *
 * @function T
 * @args "string"
 */
static int
l_t (lua_State * L)
{
    lua_pushstring (L, _(luaL_checkstring (L, 1)));
    return 1;
}

/**
 * Marks a string for translation.
 *
 * You'll seldom use this "marker" in your Lua code. A similar marker
 * is frequently used in C programs but scripting languages like Lua don't
 * have the limitations that make this marker a necessity in C.
 *
 * This function is a no-op. It exists only for the benefit of the
 * translation extractor.
 *
 * Use this function when a string is to be stored in some "database" in
 * English and at a later stage translated.
 *
 *    local db = { N"one", N"two", N"three" }
 *    for _, s in ipairs(db) do
 *      print(T(s))
 *    end
 *
 * @function N
 * @args "string"
 */
static int
l_n (lua_State * L)
{
    lua_pushstring (L, luaL_checkstring (L, 1));
    return 1;
}

/**
 * Translates a string, with context.
 *
 * Sometimes the same English source string, especially when it's composed of
 * a single word, has to be translated differently in different contexts.
 * For example, the English word "Open" may be either an adjective
 * describing the state of a file or a verb describing a command to carry
 * out. While in English the two words happen to look the same, this may not
 * be the case in other languages.
 *
 * `Q` is similar to `T` except that it lets you prefix the
 * string with a token ("qualifier", hence the letter Q) to differentiate
 * the contexts. This token is passed down to the POT file so human
 * translators can see it but is removed when the `Q` function actually
 * runs.
 *
 *    local dialog = ui.Dialog(T"DialogTitle|Open")
 *
 * The qualifier is everything till the first "|".
 *
 * @function Q
 * @args "ctx|string"
 */
static int
l_q (lua_State * L)
{
    lua_pushstring (L, Q_ (luaL_checkstring (L, 1)));
    return 1;
}

/**
 * Marks programmer-facing error messages.
 *
 * There are two kinds of error messages: those intended for end-users, which
 * you'd mark with @{T}, and those intended for programmers, which you'd mark
 * with @{E}.
 *
 * We don't want programmers' messages to be translated. That's because
 * programmers may post them on public forums asking for help, and having
 * these messages in Swahili (for example) instead of English will result in
 * (1) developers not being able to help and (2) developers' blood pressure
 * rising.
 *
 * @{E}, therefore, does nothing. It's a "no-op". So, you may ask, why use
 * it at all? To show the reader of the code that a @{T} wasn't omitted by
 * negligence. And, in the future, if we change our policy, @{E} might behave
 * just like @{T}.
 *
 * @function E
 * @args "string"
 */

/**
 * @section end
 */

/**
 * Translates a string, plural version.
 *
 * This function translates a string based on a number, and embeds the
 * number in the string (as per the rules of @{string.format}).
 *
 *    local n = 5
 *    alert(locale.format_plural("%d file", "%d files", n))
 *
 * (See another example at @{ui.Panel:files}.)
 *
 * If the optional **translate_only** argument is *true*, the embedding is
 * skipped. Thus, the following is equivalent to the code above:
 *
 *    alert(locale.format_plural("%d file", "%d files", n, true):format(n))
 *
 * Note-short: The rules of `T` apply here as well: the first two arguments
 * should be literals.
 *
 * @function format_plural
 * @args (singular, plural, n [, translate_only])
 */
static int
l_format_plural (lua_State * L)
{
    const char *singular, *plural;
    long n;
    gboolean translate_only;

    singular = luaL_checkstring (L, 1);
    plural = luaL_checkstring (L, 2);
    n = luaL_checklong (L, 3);
    translate_only = lua_toboolean (L, 4);

    /*
     * Ensure the user isn't trying to execute code like:
     *
     *  format_plural("%d file out of %d, from %s", "%d files out of %d, from %s",
     *     n, n_total, "server name")
     *
     * We'll never allow this "feature" because positional arguments may
     * change their order depending on the language.
     */
    luaMC_checkargcount (L, 4, FALSE);
    if (!lua_isnoneornil (L, 4))
        luaL_checktype (L, 4, LUA_TBOOLEAN);

    if (translate_only)
    {
        lua_pushstring (L, ngettext (singular, plural, n));
    }
    else
    {
        lua_getfield (L, 1, "format");
        lua_pushstring (L, ngettext (singular, plural, n));
        lua_pushi (L, n);
        lua_call (L, 2, 1);
    }

    return 1;
}

/* ------------------------- Number formatting ---------------------------- */

static void
_add_commas (char *in, char *out)
{
    char *p, *q;

    /* @FIXME: lib/util.c:size_trunc_sep() already has code for adding
     * commas (and is better: doesn't use strreverse), which we could
     * re-use after factoring it out. */

    g_strreverse (in);
    p = in;
    q = out;
    while (*p)
    {
        *q++ = *p++;
        if (*p && ((p - in) % 3 == 0))
            *q++ = ',';
    }
    *q = '\0';
    g_strreverse (out);
}

static char *
add_commas (double num, int precision)
{
    static char in[BUF_SMALL], out[BUF_SMALL];
    char *fraction = NULL;

    if (precision >= 0)
        sprintf (in, "%.*f", precision, num);
    else
    {
        /*
         * Figure out a sensible precision for this number.
         *
         * Using just "%g" doesn't give too good results: it tends to truncate the
         * number and add 'e' when not needed. "%.14g" is a good workaround (as
         * 'doubles' typically have about 15 significant decimal digits precision),
         * which is also the solution used in other scripting languages; e.g.
         * Ruby (see numeric.c:flo_to_s) and Lua (see luaconf.h:LUA_NUMBER_FMT).
         */
        sprintf (in, "%.14g", num);

        if (strchr (in, 'e'))
            return in;          /* give up */
    }

    fraction = strchr (in, '.');

    if (fraction)
    {
        *fraction = '\0';
        fraction++;
    }

    _add_commas (in, out);

    if (fraction)
    {
        strcat (out, ".");
        strcat (out, fraction);
    }

    return out;
}

static int
format_number__ours (lua_State * L, double num, int precision)
{
    lua_pushstring (L, add_commas (num, precision));
    return 1;
}

#ifdef HAVE_PRINTF_I18N_GROUPING
static int
format_number__clib (lua_State * L, double num, int precision)
{
    char buf[BUF_SMALL];

    if (precision >= 0)
        sprintf (buf, "%'.*f", precision, num);
    else
        sprintf (buf, "%'.14g", num);   /* See comment above. */

    lua_pushstring (L, buf);
    return 1;
}
#endif

/**
 * Formats a number according to the locale.
 *
 * In most English-speaking countries, for example, this means that a comma
 * is added every three digits, and that a period is used as the decimal mark.
 * This is also the case (for this function alone; not as a general rule in
 * the computing world) for the POSIX locale. Other locales have other rules.
 *
 *    -- en_US, or POSIX/C
 *    assert(locale.format_number(1234567.89) == "1,234,567.89")
 *
 *    -- da_DK
 *    assert(locale.format_number(1234567.89) == "1.234.567,89")
 *
 *    -- nl_NL
 *    assert(locale.format_number(1234567.89) == "1234567,89")
 *
 * You may set the number of digits to show after the decimal mark with the
 * optional **precision** argument.
 *
 * @function format_number
 * @args (n[, precision])
 */
static int
l_format_number (lua_State * L)
{
    double num;
    int precision;

    num = luaL_checknumber (L, 1);
    precision = luaL_optint (L, 2, -1);

#ifdef HAVE_PRINTF_I18N_GROUPING
    if (numeric_locale_is_posix)
        /* We want to show commas when in POSIX loale. */
        return format_number__ours (L, num, precision);
    else
        return format_number__clib (L, num, precision);
#else
    return format_number__ours (L, num, precision);
#endif
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg locale_lib[] = {
    { "format_number", l_format_number },
    /* We may expose the following as a global function PL() (for example) if
     * our POT extractor would have some difficulty seeing it otherwise. */
    { "format_plural", l_format_plural },
    { NULL, NULL }
};

static const struct luaL_Reg locale_global_lib[] = {
    { "T", l_t },
    { "N", l_n },
    { "Q", l_q },
    { "E", l_n },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_locale (lua_State * L)
{
    numeric_locale_is_posix = STREQ (setlocale (LC_NUMERIC, NULL), "C")
        || STREQ (setlocale (LC_NUMERIC, NULL), "POSIX");

    luaMC_register_globals (L, locale_global_lib);
    luaL_newlib (L, locale_lib);
    return 1;
}
