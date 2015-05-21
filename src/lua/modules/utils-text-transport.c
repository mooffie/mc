/**
 * Encoding utilities.
 *
 * @module utils.text.transport
 */

#include <config.h>

#include "lib/global.h"
#include "lib/lua/capi.h"
#include "lib/lua/utilx.h"

#include "../modules.h"


/**
 * Decodes a base64-encoded string.
 *
 * (Example: the module @{git:mht.lua|samples.filesystems.mht} uses this
 * function in its implementation of an [MHT](http://en.wikipedia.org/wiki/MHTML)
 * filesystem.)
 *
 * @function base64_decode
 * @args (s)
 */
static int
l_base64_decode (lua_State * L)
{
    const char *text;

    char *output;
    gsize output_len;

    text = luaL_checkstring (L, 1);

    output = (char *) g_base64_decode (text, &output_len);
    lua_pushlstring (L, output, output_len);
    g_free (output);

    return 1;
}

/**
 * Encodes a string using base64.
 *
 * (You may use the **break_lines** flag to break the lines at 72 columns.
 * Otherwise no line-breaks are used.)
 *
 *    assert(utils.text.transport.base64_encode("earth")
 *             == "ZWFydGg=")
 *
 * @function base64_encode
 * @args (s[, break_lines])
 */
static int
l_base64_encode (lua_State * L)
{
    const char *data;
    size_t len;
    gboolean break_lines;

    data = luaL_checklstring (L, 1, &len);
    break_lines = lua_toboolean (L, 2);

    /*
     * The following was copied from GLib's source code for g_base64_encode()
     * (with a few obvious modifications).
     *
     * We can't use g_base64_encode() directly because it doesn't accept
     * 'break_lines'.
     */
    {
        gchar *out;
        gint state = 0, outlen;
        gint save = 0;

        /* We can use a smaller limit here, since we know the saved state is 0,
           +1 is needed for trailing \0, also check for unlikely integer overflow */
        if (len >= ((G_MAXSIZE - 1) / 4 - 1) * 3)
            luaL_error (L, E_ ("Input too large for Base64 encoding."));

        out = g_malloc ((len / 3 + 1) * 4 + 1);

        outlen = g_base64_encode_step ((const guchar *) data, len, break_lines, out, &state, &save);
        outlen += g_base64_encode_close (FALSE, out + outlen, &state, &save);

        /* The following, of course, is not from GLib's source. */
        lua_pushlstring (L, out, outlen);
        g_free (out);
    }

    return 1;
}

#if GLIB_CHECK_VERSION (2, 16, 0)

/**
 * Calculates the checksum of a string.
 *
 * Note-short: This function is only available if you compile your MC
 * against GLib 2.16 and above.
 *
 * @function hash
 * @param algo The algorithm name: "md5", "sha1", "sha256" or "sha512".
 * @param s The data.
 */
static int
l_hash (lua_State * L)
{
    static const char *const algo_names[] = {
        "md5", "sha1", "sha256", "sha512", NULL
    };
    static GChecksumType algo_values[] = {
        G_CHECKSUM_MD5, G_CHECKSUM_SHA1, G_CHECKSUM_SHA256, G_CHECKSUM_SHA512
    };

    GChecksumType algo;
    const char *data;
    size_t len;

    algo = luaMC_checkoption (L, 1, NULL, algo_names, algo_values);
    data = luaL_checklstring (L, 2, &len);

    luaMC_pushstring_and_free (L, g_compute_checksum_for_data (algo, (const guchar *) data, len));

    return 1;
}

#endif

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg utils_text_transport_lib[] = {
    { "base64_decode", l_base64_decode },
    { "base64_encode", l_base64_encode },
#if GLIB_CHECK_VERSION (2, 16, 0)
    { "hash", l_hash },
#endif
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_utils_text_transport (lua_State * L)
{
    luaL_newlib (L, utils_text_transport_lib);
    return 1;
}
