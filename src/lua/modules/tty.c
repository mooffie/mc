/**
 * Terminal-related facilities.
 *
 * @module tty
 */

#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"         /* mc_refresh(), do_refresh() */
#include "lib/tty/key.h"        /* lookup_key*() */
#include "lib/tty/color.h"
#include "lib/tty/color-internal.h"     /* tty_color_get_index_by_name(), tty_color_pair_t */
#include "lib/skin.h"           /* mc_skin_color_get(), mc_skin_get() */
#include "lib/strutil.h"        /* str_*() */
#include "lib/lua/capi.h"
#include "lib/lua/plumbing.h"   /* mc_lua_ui_is_ready() */
#include "lib/lua/utilx.h"

#include "../modules.h"
#include "ui-canvas.h"          /* luaUI_new_canvas() */

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
long
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
 * See use example at @{ui.Custom:on_key}.
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
 * Checks that the terminal is idle. That is, that there are no pending
 * keyboard events.
 *
 * This function can be used, for example, to early exist lengthy tasks
 * (I/O, painting) and thereby collapsing them into a final one, when
 * the terminal becomes idle again.
 *
 * EXPERIMENTAL
 *
 * The "debounce" technique (see samples/screensavers/utils.lua) already
 * answers this need, and it seems to be better because we don't need to
 * wonder how we'll be notified when the terminal becomes idle.
 *
 * While this functionality has merit in C, it doesn't seem to have any
 * in the higher-level APIs we provide through Lua.
 *
 * So, for the time being, tty.is_idle() is "undocumented". If somebody
 * can demonstrate that it is useful (from Lua), we'll make it official.
 * Otherwise we'll remove it.
 */
static int
l_is_idle (lua_State * L)
{
    lua_pushboolean (L, is_idle ());
    return 1;
}

/**
 * @section end
 */

/**

Drawing and Refreshing the Screen.

It's useful to know a bit about how things are drawn on the screen,
especially if you're programming with @{timer|timers}.

MC is a **curses** application. In such applications drawing (others may
call it "painting") is made to a *virtual* screen, which is simply a
memory buffer in the program. This virtual screen is then written out to
the *physical* screen.

Info: This two-stage process helps curses minimize the amount of data
transferred to the physical screen. Only the smallest region (usually a
rectangle) in the virtual screen that actually differs from the contents
of the physical screen is written out.

Likewise in Lua. Any function (or method) dealing with the screen
belongs to one, and one only, of the stages.

Functions belonging to the drawing stage have "**redraw**" in their
names. They don't affect the physical screen, only the virtual one.
We'll call this **the drawing stage**.

Functions belonging to the second stage, which affects the physical
screen, have "**refresh**" in their names. We'll call this **the refresh stage**.

Here's a summary of the functions (or method) dealing with the screen:

### The drawing stage

- @{~mod:ui*widget:redraw}

- @{~mod:ui*dialog:redraw}

- @{~mod:ui*dialog:redraw_cursor}
  > Positioning the cursor is just like a drawing operation: it occurs
  in the *virtual* screen, and doesn't show on the physical screen
  unless one of the refresh stage functions is called.

- @{tty.redraw}

### The refresh stage

- @{tty.refresh}
  > Copies the virtual screen onto the physical one.

- @{~mod:ui*dialog:refresh}
  > A utility function that also positions the cursor.

### When to call which function?

You may feel overwhelmed by the many functions you have at your hands.
Don't feel so.

In normal code you won't need to call any of them. When you set a
property of some widget, its :redraw() method will be called
automatically. Then, as part of MC's event loop, @{tty.refresh} will be
called. So the screen will be updated appropriately without your explicit
intervention.

On the other hand, when using a @{ui.Custom} you have to call its
:redraw() yourself whenever its state changes in a way that affects its
display because only you know when this happens.

### Working with timers

We explained that you normally don't need to call @{tty.refresh}
yourself as this is done automatically. One exception, however, is when
working with timers. If your timed function affects the display (for
example, if it updates some widget, as  in `label.text = "new label"`)
then you need to call @{tty.refresh} (or @{~mod:ui*dialog:refresh})
yourself to refresh the screen:

    timer.set_timeout(function()
      label.text = label.text .. "!"
      dlg:refresh()
      -- dialog:refresh() is like tty.refresh() except that
      -- it also puts the cursor at the focused widget. Had
      -- we called tty.refresh() instead, the cursor would have
      -- appeared at the last widget to draw itself (the label).
    end, 1000)

    -- another example:

    timer.set_timeout(function()
      alert('hi')
      tty.refresh()
    end, 1000)

The reason for this is the way MC's event loop works. Here's a schema of
it:

<pre>
event_loop:
  repeat:
&nbsp;   (A) while there's no keyboard or mouse events:
&nbsp;         execute timers
&nbsp;   (B) get keyboard or mouse event
&nbsp;   (C) process the event
&nbsp;   (D) position the cursor at the focused widget
&nbsp;   (E) refresh the screen
</pre>

When our timer function returns, MC still sits there waiting
(loop **(A)**) for a keyboard (or mouse) event. Step **(E)**
isn't arrived at, and hence the screen isn't refreshed. That's
why we need to refresh the screen explicitly from our timer function.

[info]

The previous paragraph gave a "schema" of MC's event loop. Here's an
overview of the actual C code, for interested programmers:

[expand]

    dlg_run() {
      dlg_init() {
        dlg_redraw()
      }
      frontend_dlg_run() {
        while (dlg->state == DLG_ACTIVE) {
          update_cursor(dlg)
          event = tty_get_event() {
            mc_refresh()
            while (no keyboard or mouse event) {
              execute pending timeouts
            }
            read event
          }
          dlg_process_event(dlg, event)
        }
      }
    }

(You'll notice that, in the `while` loop, steps **(D)** and **(E)**
actually are the first to happen, but that's insignificant.)

[/expand]

[/info]

@section drawing

*/


/**
 * Redraws all the screen's contents.
 *
 * All the dialogs on screen are redrawn, from the bottom to the top.
 *
 * Note: You'll hardly ever need to use this function yourself. This documentation
 * entry exists because this function is used, once, in the implementation
 * of the @{ui} module: It's used to redraw the screen after a dialog box
 * is closed. Except for achieving some "pyrotechnics", as demonstrated below,
 * there's little to no reason to use this function.
 *
 *    keymap.bind('C-y', function()
 *      local dlg = ui.Dialog()
 *      local btn = ui.Button(T"Move this dialog to the right")
 *      btn.on_click = function()
 *        dlg:set_dimensions(dlg.x + 1, dlg.y)
 *        tty.redraw() -- comment this out to see what happens.
 *      end
 *      dlg:add(btn):run()
 *    end)
 *
 * @function redraw
 */
static int
l_redraw (lua_State * L)
{
    (void) L;
    do_refresh ();
    return 0;
}

/**
 * Refreshes the screen.
 *
 * This copies the *virtual* screen onto the *physical* one.
 *
 * Info-short: Only the regions that are known to differ from the target are
 * copied.
 *
 * @function refresh
 */
static int
l_refresh (lua_State * L)
{
    (void) L;
    mc_refresh ();
    return 0;
}

/**
 * Returns a @{ui.Canvas|canvas object} encompassing the whole screen.
 *
 * This lets you draw on the screen. Alternatively you can use the
 * @{~mod:ui*widget:get_canvas|:get_canvas()} method of a widget if you're
 * interested in its limited screen area.
 *
 * @function get_canvas
 */
static int
l_get_canvas (lua_State * L)
{
    /* Search for a cached canvas object. */
    lua_getfield (L, LUA_REGISTRYINDEX, "_tty_canvas");

    if (lua_isnil (L, -1))
    {
        /* If not found, create a new canvas, */
        luaUI_new_canvas (L);
        /* ...and cache it, for the next call: */
        lua_pushvalue (L, -1);
        lua_setfield (L, LUA_REGISTRYINDEX, "_tty_canvas");
    }

    luaUI_set_canvas_dimensions (L, -1, 0, 0, COLS, LINES);
    return 1;
}

/**
 * @section end
 */

/* ------------------------------ Utilities ------------------------------- */

/**
 * Several functions necessitates the UI. They call this function to emit
 * a useful and uniform error message.
 */

static void
luaTTY_assert_ui_is_ready_ex (lua_State * L, gboolean push_only, const char *funcname)
{
    if (!mc_lua_ui_is_ready ())
    {
        const char *msg_without_solution =
            E_ ("You can not use tty.%s() yet, because the UI has not been initialized.");
        const char *msg_with_solution =
            E_ ("You can not use tty.%s() yet, because the UI has not been initialized.\n"
                "One way to solve this problem is to call ui.open() before calling this function.");

        const char *msg =
            (mc_global.mc_run_mode == MC_RUN_SCRIPT) ? msg_with_solution : msg_without_solution;

        if (push_only)
            lua_pushfstring (L, msg, funcname);
        else
            luaL_error (L, msg, funcname);
    }
}

void
luaTTY_assert_ui_is_ready (lua_State * L)
{
    luaTTY_assert_ui_is_ready_ex (L, FALSE, luaMC_get_function_name (L, 0, FALSE));
}

/* ------------------------------------------------------------------------ */

/**
 *
 * Styles.
 *
 * The way a character is displayed on the screen is called a **style**. A
 * style is composed of three things:
 *
 * - Foreground color
 * - Background color
 * - Attributes: underlined, italic, bold and/or reversed.
 *
 * A style happens to be represented internally as a numeric handle. For
 * example, on your system the style **64** may mean "red foreground, green
 * background, italic." We, as humans, don't manipulate such numbers
 * directly but instead use @{style|style()} to convert a human-readable
 * style description to this number.
 *
 * @section style
 */

static void
validate_color_name (lua_State * L, const char *color_name)
{
    if (color_name && tty_color_get_index_by_name (color_name) == -1
        && !STREQ (color_name, "default") && !STREQ (color_name, "base"))
    {
        luaL_error (L, _("Invalid color name '%s'. Perhaps you misspelled it?"), color_name);
    }
}

/**
 * This low-level function is exposed to Lua as "_style" and is wrapped by
 * a higher-level function, "style", written in Lua.
 */
static int
l_style (lua_State * L)
{
    const char *fg;
    const char *bg;
    const char *attrs;

    int pair;

    luaTTY_assert_ui_is_ready (L);

    /* We could use lua_tostring() instead of luaL_checkstring(), as
     * tty_try_alloc_color_pair2() can handle NULL arguments. But we prefer to
     * push all the policy decisions to the Lua side: it, and not the C side,
     * will decide what to do with unspecified values. */
    fg = luaL_checkstring (L, 1);
    bg = luaL_checkstring (L, 2);
    attrs = luaL_checkstring (L, 3);

    validate_color_name (L, fg);
    validate_color_name (L, bg);

    pair = tty_try_alloc_color_pair2 (fg, bg, attrs, FALSE);
    if (pair > 250)
    {
        /*
         * Pheew! The user is probably enjoying himself creating rainbows in
         * the editor.
         *
         * There's a limit to the number of pairs we can allocate.
         * Currently we use some arbitrary number (250), but we should
         * investigate this issue and do something more robust. Pointers: man
         * pages for init_pair (ncurses) and SLtt_set_color (S-Lang). @todo.
         */
        luaL_error (L, E_ ("Too many styles were allocated!"));
    }

    lua_pushinteger (L, pair);
    return 1;
}

/**
 * This low-level function is exposed to Lua as "_skin_style" and is
 * called by the higher-level "style" when needed.
 */
static int
l_skin_style (lua_State * L)
{
    const char *group;
    const char *name;

    luaTTY_assert_ui_is_ready (L);

    group = luaL_checkstring (L, 1);
    name = luaL_checkstring (L, 2);

    lua_pushinteger (L, mc_skin_color_get (group, name));
    return 1;
}

/**
 * Tests for a color terminal.
 *
 * Return **true** if the terminal supports colors, or **false** if it's a
 * monochrome terminal.
 *
 * @function is_color
 */
static int
l_is_color (lua_State * L)
{
    luaTTY_assert_ui_is_ready (L);
    lua_pushboolean (L, tty_use_colors ());
    return 1;
}

/**
 * Tests for a rich color terminal.
 *
 * Return **true** if the terminal supports [256 colors]
 * (http://whiletruecode.tumblr.com/post/13358288098/enabling-256-color-mode-in-ubuntus-bash-terminal)
 * (in this case @{is_color} too will return **true**), or **false** otherwise.
 *
 * @function is_hicolor
 */
static int
l_is_hicolor (lua_State * L)
{
    luaTTY_assert_ui_is_ready (L);
    lua_pushboolean (L, tty_use_256colors ());
    return 1;
}

/**
 * Destructures a style.
 *
 * Does the opposite of @{tty.style}. Given a style, returns a table with
 * the fields **fg**, **bg**, **attr** (and their numeric counterparts).
 *
 * You'll not normally use this function. It can be used to implement
 * exotic features like converting an @{ui.Editbox} syntax-highlighted
 * contents into HTML, or creating "screen shots".
 *
 *    ui.Editbox.bind('C-y', function(edt)
 *      devel.view(tty.destruct_style(
 *        edt:get_style_at(edt.cursor_offs)
 *      ))
 *    end)
 *
 * @function destruct_style
 * @args (style)
 */
static int
l_destruct_style (lua_State * L)
{
    int pair;

    tty_color_pair_t *st;

    pair = luaL_checkint (L, 1);

    st = tty_color_pair_number_to_struct (pair);

    if (st)
    {
        lua_newtable (L);

        lua_pushinteger (L, st->ifg);
        lua_setfield (L, -2, "ifg");
        lua_pushstring (L, tty_color_get_name_by_index (st->ifg));
        lua_setfield (L, -2, "fg");

        lua_pushinteger (L, st->ibg);
        lua_setfield (L, -2, "ibg");
        lua_pushstring (L, tty_color_get_name_by_index (st->ibg));
        lua_setfield (L, -2, "bg");

        lua_pushinteger (L, st->attr);
        lua_setfield (L, -2, "iattr");

        lua_newtable (L);
        {
            if ((st->attr & A_BOLD) == A_BOLD)
                luaMC_setflag (L, -1, "bold", TRUE);
            if ((st->attr & A_UNDERLINE) == A_UNDERLINE)
                luaMC_setflag (L, -1, "underline", TRUE);
            if ((st->attr & A_REVERSE) == A_REVERSE)
                luaMC_setflag (L, -1, "reverse", TRUE);
            if ((st->attr & A_BLINK) == A_BLINK)
                luaMC_setflag (L, -1, "blink", TRUE);
#ifdef A_ITALIC
            if ((st->attr & A_ITALIC) == A_ITALIC)
                luaMC_setflag (L, -1, "italic", TRUE);
#endif
        }
        lua_setfield (L, -2, "attr");

        if (st->is_temp)
        {
            /* If you ever memoize this function on the Lua side, make sure
               not to cache is_temp entries: these styles, used for syntax
               highlighting, are disposed of when the editor exists, and their
               indexes are reused. */
            luaMC_setflag (L, -1, "is_temp", TRUE);
        }
    }
    else
    {
        lua_pushnil (L);
    }

    return 1;
}

/**
 * @section end
 */

/**
 * Text handling.
 *
 * @section text
 */

/**
 * Calculates a string's "visual" width.
 *
 * Given a string in the terminal's encoding, returns the amount of columns
 * needed to display it.
 *
 * Info: While in English there's a one-to-one correspondence between characters
 * and columns, in other languages this isn't so. E.g., diactritic
 * characters consume 0 columns and Asian characters consume 2 columns.
 *
 *    assert(tty.text_width 'ンab᷉c᷉d' == 6)
 *
 *    -- ...and now, assuming this is a UTF-8 encoded source file, compare
 *    -- this with string.len(), which is oblivious to characters and
 *    -- their properties:
 *    assert(string.len 'ンab᷉c᷉d' == 13)
 *
 * (If the terminal's encoding isn't UTF-8, this function is identical to
 * @{string.len} (except for handling multiple lines).)
 *
 * if the string contains multiple lines, the width of the widest line is
 * returned. Also returned is the number of lines:
 *
 *    assert(tty.text_width "once\nupon\na time" = 6)
 *    assert(select(2, tty.text_width "once\nupon\na time") = 3)
 *
 * @function text_width
 * @args (s)
 */
static int
l_text_width (lua_State * L)
{
    const char *s;

    int cols, lines = 1;

    s = luaL_checkstring (L, 1);

    if (strchr (s, '\n'))
        str_msg_term_size (s, &lines, &cols);
    else
        cols = str_term_width1 (s);

    lua_pushinteger (L, cols);
    lua_pushinteger (L, lines);
    return 2;
}

/**
 * Returns a "visual" substring of a string.
 *
 * Given a string in the terminal's encoding, returns the substring falling
 * within certain screen columns.
 *
 * The arguments to this function are the same as @{string.sub}'s. Indeed, you
 * can think of this function as equivalent to @{string.sub} except that the
 * indices are interpreted to be screen columns instead of bytes.
 *
 * (See discussion at @{tty.text_width}.)
 *
 *    assert(tty.text_cols('ンab᷉c᷉d', 4, 5) == 'b᷉c᷉')
 *
 *    -- ...and now, assuming this is a UTF-8 encoded source file, compare
 *    -- this with string.sub(), which is oblivious to characters and
 *    -- their properties:
 *    assert(string.sub('ンab᷉c᷉d', 4, 5) == 'ab')
 *
 * (If the terminal's encoding isn't UTF-8, this function is identical to
 * @{string.sub}.)
 *
 * Tip: If you want to draw part of a string on screen, use @{ui.Canvas:draw_clipped_string},
 * which does the "hard" calculations for you.
 *
 * @function text_cols
 * @args (s, i [, j])
 */
static int
l_text_cols (lua_State * L)
{
    const char *s;
    int col1;
    int col2;

    int width;

    s = luaL_checkstring (L, 1);
    col1 = luaL_checkint (L, 2);
    col2 = luaL_optint (L, 3, -1);

    if (col1 < 0 || col2 < 0)
        /* We compute the width only when needed. */
        width = str_term_width1 (s);
    else
        width = -1;

    /* Convert Lua indices to C indices. */
    col1 = mc_lua_fixup_idx (col1, width, FALSE);
    col2 = mc_lua_fixup_idx (col2, width, TRUE);

    if (col1 < col2)
    {
        int ch1, ch2;
        const char *p1, *p2;
        int size;

        /* Note the unfortunate names of these two functions: "pos" is used
         * in both but means different things. */

        ch1 = str_column_to_pos (s, col1);
        ch2 = str_column_to_pos (s, col2);

        p1 = s + str_offset_to_pos (s, ch1);
        p2 = s + str_offset_to_pos (s, ch2);

        size = p2 - p1;

        lua_pushlstring (L, p1, size);

        /*
         * @todo?
         *
         * tty.text_cols("aンbc", 3, 4) currently returns "ンb". Ideally, maybe,
         * it should return " b". But perhaps that's too far fetched.
         */
    }
    else
    {
        lua_pushliteral (L, "");
    }

    return 1;
}

int                             /* align_crt_t */
luaTTY_check_align (lua_State * L, int idx)
{
    static const char *const just_names[] = {
        "left", "right", "center", "center or left",
        "left~", "right~", "center~", "center or left~", NULL
    };
    static const align_crt_t just_values[] = {
        J_LEFT, J_RIGHT, J_CENTER, J_CENTER_LEFT,
        J_LEFT_FIT, J_RIGHT_FIT, J_CENTER_FIT, J_CENTER_LEFT_FIT
    };

    return luaMC_checkoption (L, idx, NULL, just_names, just_values);
}

/**
 * Aligns ("justifies") a string.
 *
 * Fits a string to **width** terminal columns by padding it with spaces or
 * trimming it.
 *
 * **align_mode** may be:
 *
 * - "left"
 * - "right"
 * - "center"
 * - "center or left"
 *
 * if the string is wider than **width**, the excess it cut off. You may
 * instead append "~" to the align mode to shorten the string by replacing
 * characters from its middle with a tilde character.
 *
 *    assert(tty.text_align("Alice", 10, "left") == "Alice     ")
 *    assert(tty.text_align("Alice", 10, "right") == "     Alice")
 *    assert(tty.text_align("Alice", 10, "center") == "  Alice   ")
 *
 *    assert(tty.text_align("Alice in Wonderland", 10, "left") == "Alice in W")
 *    assert(tty.text_align("Alice in Wonderland", 10, "left~") == "Alice~land")
 *    assert(tty.text_align("Alice in Wonderland", 10, "center") == "")
 *    -- "center of left" means to center if there's enough room, and align
 *    -- to left otherwise.
 *    assert(tty.text_align("Alice in Wonderland", 10, "center or left")
 *            == "Alice in W")
 *
 *    -- Multiple lines are not supported:
 *    assert(tty.text_align("one\ntwo", 8, "left") == "one.two ")
 *
 * @function text_align
 * @args (s, width, align_mode)
 */
static int
l_text_align (lua_State * L)
{
    const char *s;
    int width;
    align_crt_t align;

    s = luaL_checkstring (L, 1);
    width = luaL_checkint (L, 2);
    align = luaTTY_check_align (L, 3);

    if (width > BUF_MEDIUM - 1)
        /* That's the size of the buffer used by str_*_fit_to_term(). */
        luaL_error (L, E_ ("The width may not exceed %d."), BUF_MEDIUM - 1);

    /* @FIXME:
     * MC bug: tty.text_align('abcdefg',5,'center') gives 'abcdefg'.
     * But 'center' really is a weird creature that perhaps shouldn't exist: What's the
     * point in tty.text_align('long long long',5,'center') giving '' ?!
     */

    /* @FIXME:
     * As pointed out in 'samples/ui/extlabel.lua', str_*_term_trim() crashes
     * on long strings :-(
     */

    lua_pushstring (L, str_fit_to_term (s, width, align));
    return 1;
}

/**
 * @section end
 */

/**
 * Misc functions
 *
 * @section misc
 */

/**
 * Whether the UI is ready.
 *
 * Tells us if *curses* has taken control of the terminal. This is when you
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
 * at the top-level of your user scripts, and why doing `local dlg = ui.Dialog()`
 * there (at the top-level) will result in a "black and white" dialog.
 *
 * [/info]
 *
 * @function is_ui_ready
 */

/*
 * Note: it's in the 'tty' module, not in 'ui', because doing ui.is_ready()
 * would autoload the UI module, something that isn't necessary in non-UI
 * apps.
 */
static int
l_is_ui_ready (lua_State * L)
{
    lua_pushboolean (L, mc_lua_ui_is_ready ());
    return 1;
}

/**
 * This low-level function is exposed to Lua as "_skin_get" and is wrapped by
 * a higher-level function, "skin_get", written in Lua.
 */
static int
l_skin_get (lua_State * L)
{
    const char *group;
    const char *name;
    const char *def;

    luaTTY_assert_ui_is_ready (L);

    group = luaL_checkstring (L, 1);
    name = luaL_checkstring (L, 2);
    def = lua_tostring (L, 3);  /* Optional. */

    luaMC_pushstring_and_free (L, mc_skin_get (group, name, def));

    return 1;
}

/**
 * Returns the terminal width, in characters.
 *
 * @function get_cols
 */
static int
l_get_cols (lua_State * L)
{
    luaTTY_assert_ui_is_ready (L);      /* @todo: It would be nice to have this function work regardless of UI state. */
    lua_pushinteger (L, COLS);
    return 1;
}

/**
 * Returns the terminal height, in lines.
 *
 * @function get_rows
 */
static int
l_get_rows (lua_State * L)
{
    luaTTY_assert_ui_is_ready (L);
    lua_pushinteger (L, LINES);
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

Encodings.

Whenever you output a string to the terminal --for example, when you
pass it to a function like alert() or to widgets like ui.Label,
ui.Listbox-- you should convert it first to the terminal's encoding.

This is the result of not living in a perfect world: The file you're
editing, or a string you read from some data file, may be of a different
encoding than your terminal's. For example, your terminal's encoding may
be UTF-8 whereas your data may be encoded in ISO-8859-8.

This isn't really an issue on modern systems where everything is encoded
in UTF-8. It'd be legitimate for you, therefore, to decide to ignore
this issue --especially if you're the only user of your script.
Nevertheless, you should at least be aware of this issue in order to
support your user-base.

There are two ways to convert a string to the terminal's encoding:

__(1)__ When you know the string's encoding, use @{tty.conv}:

    -- Displaying the contents of a ISO-8859-8 encoded file.
    local s = assert(fs.read('data_file.txt'))
    alert(tty.conv(s, 'iso-5589-8'))

__(2)__ When the string originates in some widget like @{ui.Editbox},
which keeps its data encoded independently of the terminal, use the
widget's @{ui.Editbox:to_tty|:to_tty} method:

    alert('The current word is ' .. edt:to_tty(edt.current_word))

(In the example above we could've used instead the *hypothetical* code
`tty.conv(edt.current_word, edt.encoding)` but an @{ui.Editbox} doesn't
keep the name of its encoding.)

@section encodings

*/

/**
 * Converts a string to the terminal's encoding.
 *
 * See example in the discussion above.
 *
 * @function conv
 * @param s The string to convert.
 * @param encoding_name The string's encoding name. Like "ISO-8859-8",
 *   "KOI8-R", etc. This name is case-insensitive. If the encoding name
 *   is unknown to the system, an exception will be raised.
 */
static int
l_conv (lua_State * L)
{
    const char *s;
    size_t len;
    const char *from_enc;

    GIConv conv;

    s = luaL_checklstring (L, 1, &len);
    from_enc = luaL_checkstring (L, 2);

    conv = str_crt_conv_from (from_enc);
    if (conv == INVALID_CONV)
        return luaL_error (L, E_ ("Unknown encoding '%s'"), from_enc);
    (void) luaMC_pushlstring_conv (L, s, len, conv);
    /* We don't care about ESTR_PROBLEM/ESTR_FAILURE: we deem it natural that
     * terminal conversion won't preserve all the data. */
    str_close_conv (conv);

    return 1;
}

/**
 * Tests for a UTF-8 encoded terminal.
 *
 * See example in @{skin_get}.
 *
 * @function is_utf8
 */
static int
l_is_utf8 (lua_State * L)
{
    /*
     * We don't use 'mc_global.utf8_display': We want this function to be
     * available to Lua code running early, before the UI is ready.
     * 'mc_global.utf8_display' is initialized in load_setup(), which is
     * called relatively late, after mc_lua_load().
     *
     * This is not a critical feature, but it's nice to have.
     */

    /*
     * UPDATE: Starting with MC 4.8.12 (commit ad5246c), load_setup() _is_
     * called early. However, it doesn't seem to set mc_global.utf8_display
     * to a correct value. It seems that it's check_codeset() that does the
     * job. But the latter _is_ called late.
     */

    static int is_utf8 = -1;

    if (is_utf8 == -1)
        is_utf8 = (str_length ("\xD7\x90") == 1);

    lua_pushboolean (L, is_utf8);
    return 1;
}

/**
 * @section end
 */

/**
 * A Lua function to produce a suitable error message if the UI isn't
 * ready.
 *
 * We could do this in pure Lua, of course. But we want uniformity: we want
 * Lua functions and C functions to print the same message.
 */
static int
l_generate_error_message (lua_State * L)
{
    const char *funcname;

    funcname = luaL_checkstring (L, 1);

    if (!mc_lua_ui_is_ready ())
    {
        luaTTY_assert_ui_is_ready_ex (L, TRUE, funcname);
        return 1;
    }
    else
        return 0;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg ttylib[] = {
    { "keyname_to_keycode", l_keyname_to_keycode },
    { "keycode_to_keyname", l_keycode_to_keyname },
    { "is_idle", l_is_idle },
    { "redraw", l_redraw },
    { "refresh", l_refresh },
    { "get_canvas", l_get_canvas },
    { "_style", l_style },
    { "_skin_style", l_skin_style },
    { "is_color", l_is_color },
    { "is_hicolor", l_is_hicolor },
    { "destruct_style", l_destruct_style },
    { "text_width", l_text_width },
    { "text_cols", l_text_cols },
    { "text_align", l_text_align },
    { "is_ui_ready", l_is_ui_ready },
    { "_skin_get", l_skin_get },
    { "get_cols", l_get_cols },
    { "get_rows", l_get_rows },
    { "beep", l_beep },
    { "conv", l_conv },
    { "is_utf8", l_is_utf8 },
    { "_generate_error_message", l_generate_error_message },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_tty (lua_State * L)
{
    luaL_newlib (L, ttylib);
    return 1;
}
