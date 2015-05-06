/**
 * Extra string utilities.
 *
 * Most of this module is written in Lua. See modules/core/utils/text.lua.
 *
 * @module utils.text
 */

#include <config.h>

#include <inttypes.h>           /* uintmax_t */

#include "lib/global.h"
#include "lib/timefmt.h"        /* file_date() */
#include "lib/strutil.h"        /* parse_integer() */
#include "lib/util.h"           /* size_trunc_len() */

#include "src/setup.h"          /* panels_options */

#include "../capi.h"
#include "../modules.h"
#include "../utilx.h"


/**
 * This function is exposed to Lua as "_format_size" and is wrapped by
 * the higher-level "format_size".
 */
static int
l_format_size (lua_State * L)
{
    uintmax_t size;
    int len;

    char buffer[BUF_TINY];

    size = luaL_checki (L, 1);
    len = luaL_checkint (L, 2);

    size_trunc_len (buffer, len, size, 0, panels_options.kilobyte_si);

    lua_pushstring (L, buffer);
    return 1;
}

/**
 * Parses a string denoting size.
 *
 * This is, largely, the inverse of @{format_size}.
 *
 * For example, when given "64M" it returns 67108864.
 *
 *    assert(utils.text.parse_size("64M") == 67108864)
 *    assert(utils.text.parse_size("64MiB") == 67108864)
 *    assert(utils.text.parse_size("64MB") == 64000000)
 *
 * (See another example at @{ui.Panel:mark_by_fn}.)
 *
 * There are a few limitations:
 *
 * - Commas and other localization signs aren't supported.
 * - Only integers are allowed: "1.5GB" isn't valid (do "1500MB" instead).
 *
 * Notable suffixes:
 *
 * - K, M, G, T, ... - These are 1024 powers.
 * - KiB, MiB, GiB, TiB,  ... - ditto.
 * - KB, MB, GB, TB, ... - These are 1000 powers.
 *
 * (You may use "k" instead of "K". Lowercase doesn't work for the other
 * units, though.)
 *
 * @return An integer on success. The pair `(nil, error message)` on error
 * (so you can wrap the call in @{assert} or @{globals.abortive|abortive}).
 *
 * @function parse_size
 * @args (s)
 */
static int
l_parse_size (lua_State * L)
{
    const char *s;

    uintmax_t n;
    gboolean invalid;

    s = luaL_checkstring (L, 1);

    invalid = FALSE;
    n = parse_integer (s, &invalid);

    if (!invalid)
    {
        lua_pushi (L, n);
        return 1;
    }
    else
    {
        lua_pushnil (L);
        lua_pushfstring (L, E_ ("Invalid size \"%s\"."), s);
        return 2;
    }
}

/**
 * Formats a file date the way MC does in panels.
 *
 * This is a wrapper around the C function @{git:lib/timefmt.c|file_date} used
 * by MC in various places.
 *
 * @function format_file_date
 * @param timestamp A Unix timestamp. C.f. the various @{~mod:fs.StatBuf} fields.
 */
static int
l_format_file_date (lua_State * L)
{
    time_t timestamp;

    timestamp = luaL_checki (L, 1);

    lua_pushstring (L, file_date (timestamp));
    return 1;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg utils_text_lib[] = {
    { "_format_size", l_format_size },
    { "parse_size", l_parse_size },
    { "format_file_date", l_format_file_date },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_utils_text (lua_State * L)
{
    luaL_newlib (L, utils_text_lib);
    return 1;
}
