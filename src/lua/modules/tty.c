/**
 * Terminal-related facilities.
 *
 * @module tty
 */

#include <config.h>

#include "lib/global.h"
#include "lib/tty/key.h"        /* lookup_key*() */
#include "lib/lua/capi.h"
#include "lib/lua/plumbing.h"   /* mc_lua_ui_is_ready() */
#include "lib/lua/utilx.h"

#include "../modules.h"

#include "tty.h"


/**
 * Keyboard keys.
 *
 * Usually we, as end-users, don't need to handle keys. In a few cases,
 * however, for example when working with a @{ui.Custom}, we want
 * to interact with the keys.
 *
 * A key --for example *q*, *R*, *Control-S*, *F4*, *ESC*-- is represented
 * as a number. We call this number a **keycode**. We, as humans, would
 * like to deal not with such a number but with a descriptive name. We call
 * this name a **keyname**.
 *
 * The TTY module provides us with two functions to deal with keys.
 *
 * The foremost function is `keyname_to_keycode`, which translates a
 * keyname to a keycode. The other function, `keycode_to_keyname`, does the
 * opposite.
 *
 * @section keys
 */

/**
 * Converts Emacs-style keynames to MC style.
 *
 * Users are probably more accustomed to keynames in the prevalent Emacs-style,
 * which is why we deem it important to support this style. This function
 * translates Emacs-style to the style MC recognizes. For example:
 *
 *    "C-M-x"   ->  "ctrl-meta-x"
 *    "c-m-X"   ->  "ctrl-meta-X"
 *    "S-F1"    ->  "shift-F1"
 *    "S-<F1>"  ->  "shift-F1"
 *    "<Up>"    ->  "Up"
 *
 * @FIXME: move this functionality to MC itself.
 */

#define START(str, ch1, ch2) ((str)[0] == ch1 && (str)[1] == ch2)

static char *
emacs_to_mc (const char *name)
{
    const char *p = name;
    GString *mc = g_string_sized_new (32);

    while (*p)
    {
        if (START (p, 'c', '-') || START (p, 'C', '-')) /* alternatively we could do !strncmp (p, "c-", 2) */
        {
            g_string_append (mc, "ctrl-");
            p += 2;
        }
        else if (START (p, 'm', '-') || START (p, 'M', '-'))
        {
            g_string_append (mc, "meta-");
            p += 2;
        }
        else if (START (p, 's', '-') || START (p, 'S', '-'))
        {
            g_string_append (mc, "shift-");
            p += 2;
        }
        else if (*p == '<')
        {
            const char *next_angle = strchr (p, '>');
            if (next_angle)
            {
                g_string_append_len (mc, p + 1, next_angle - p - 1);
                p = next_angle + 1;
            }
            else
            {
                g_string_append (mc, p);        /* slurp till end */
                break;
            }
        }
        else
        {
            const char *next_dash = strchr (p, '-');
            if (next_dash)
            {
                g_string_append_len (mc, p, next_dash - p + 1);
                p = next_dash + 1;
            }
            else
            {
                g_string_append (mc, p);        /* slurp till end */
                break;
            }
        }
    }

    return g_string_free (mc, FALSE);
}

#undef START

/**
 * A wrapper around lookup_key() to make it support Emacs-style keys.
 *
 * Note that MC's lookup_key() gives us a 'long' keycode (for some reason
 * it does "return (long) k") whereas in most places MC treats keycodes
 * as 'int'.
 */
static long
lookup_emacs_key (const char *name, char **label)
{
    long code;
    char *mc_compatible;

    mc_compatible = emacs_to_mc (name);
    code = lookup_key (mc_compatible, label);
    g_free (mc_compatible);

    return code;
}

/**
 * Converts a keyname (the element at index 'name_index') to a keycode.
 *
 * If 'push_name_short' is TRUE, also pushes onto the stack the canonical
 * short name of the key. Otherwise, the stack isn't modified in any way.
 */
static long
luaTTY_check_keycode (lua_State * L, int name_index, gboolean push_name_short)
{
    const char *name;
    long keycode;
    char *name_short;

    /* If it's already a number, we return immediately. Note that in this
     * case, since we don't call lookup_emacs_key(), we don't know the short
     * name, so we make sure the user hasn't asked for it. */
    if (lua_type (L, name_index) == LUA_TNUMBER && !push_name_short)
        return luaL_checki (L, name_index);

    name = luaL_checkstring (L, name_index);

    keycode = lookup_emacs_key (name, push_name_short ? &name_short : NULL);

    if (keycode)
    {
        if (push_name_short)
        {
            lua_pushstring (L, name_short);
            g_free (name_short);
        }
        return keycode;
    }
    else
    {
        return luaL_error (L, _("Invalid key name '%s'"), name);
    }
}

/**
 * Converts a keyname to a keycode.
 *
 * Throws an exception if the keyname is invalid.
 *
 * @function keyname_to_keycode
 * @args (keyname)
 */
static int
l_keyname_to_keycode (lua_State * L)
{
    long keycode;

    keycode = luaTTY_check_keycode (L, 1, TRUE);
    lua_pushi (L, keycode);
    lua_insert (L, -2);         /* Switch the top two elements. */

    /*
     * We also return the key's name. In case there are several ways to name a
     * key, the key name we return here is closer to the user's intention than
     * the one l_keycode_to_keyname() returns. This also lets us get away with
     * bugs in MC (see tests/auto/key_bugs.lua) which l_keycode_to_keyname()
     * is susceptible to.
     */

    return 2;
}

/**
 * Converts a keycode to a keyname.
 *
 * Throws an exception if the keycode is invalid.
 *
 * Returns two values: the key's "short" name, and its "long" name.
 *
 * @function keycode_to_keyname
 * @args (keycode)
 */
static int
l_keycode_to_keyname (lua_State * L)
{
    char *name_long = NULL;
    char *name_short = NULL;
    long keycode;

    keycode = luaL_checki (L, 1);

    name_long = lookup_key_by_code (keycode);
    if (name_long)
        lookup_key (name_long, &name_short);

    if (name_long && name_short)
    {
        lua_pushstring (L, name_short);
        lua_pushstring (L, name_long);
        g_free (name_long);
        g_free (name_short);
        return 2;
    }
    else
    {
        g_free (name_long);
        g_free (name_short);
        return luaL_error (L, _("Invalid key code '%d'"), keycode);
    }
}

/**
 * @section end
 */

/* ------------------------------ Utilities ------------------------------- */

/**
 * Several functions necessitates the UI. They call this function to emit
 * a useful and uniform error message.
 */

void
luaTTY_assert_ui_is_ready (lua_State * L)
{
    if (!mc_lua_ui_is_ready ())
    {
        luaL_error (L,
                    E_ ("You can not use %s() yet, because the UI has not been initialized."),
                    luaMC_get_function_name (L, 0, FALSE));
    }
}

/* ------------------------------------------------------------------------ */

/**
 * Misc functions
 *
 * @section misc
 */

/**
 * Whether the UI is ready.
 *
 * It tells us if *curses* has taken control of the terminal. This is when you
 * can use dialog boxes.
 *
 * [info]
 *
 * The terminal can be in one of two states:
 *
 * - When MC just starts, the terminal is in the so-called
 *   [cooked](http://en.wikipedia.org/wiki/Cooked_mode) mode. It's the mode
 *   most Unix command-line utilities work in, where the terminal behaves
 *   like a line-printer.
 *
 *   Indent: This is also the initial state for @{~standalone|standalone mode}.
 *
 * - Soon afterwards *curses* (or *slang*) takes control of the terminal.
 *   The application gets control of the whole area of the screen and
 *   displays its data in dialog boxes.
 *
 * _The second state is when we say "the UI is ready", or "UI mode". The first
 * state is "non-UI mode"._
 *
 * Note: When MC loads your @{~started#first|user scripts} it does this very early,
 * still in non-UI mode. This is why you can't call functions like `tty.style`
 * at the top-level of your user scripts.
 *
 * [/info]
 *
 * @function is_ui_ready
 */

static int
l_is_ui_ready (lua_State * L)
{
    lua_pushboolean (L, mc_lua_ui_is_ready ());
    return 1;
}

/**
 * Sounds a beep.
 *
 * @function beep
 */
static int
l_beep (lua_State * L)
{
    (void) L;

    tty_beep ();
    return 0;
}

/**
 * @section end
 */

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg ttylib[] = {
    { "keyname_to_keycode", l_keyname_to_keycode },
    { "keycode_to_keyname", l_keycode_to_keyname },
    { "is_ui_ready", l_is_ui_ready },
    { "beep", l_beep },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_tty (lua_State * L)
{
    luaL_newlib (L, ttylib);
    return 1;
}
