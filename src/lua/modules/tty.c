/**
 * Terminal-related facilities.
 *
 * @module tty
 */

#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"         /* mc_refresh(), do_refresh() */
#include "lib/tty/key.h"        /* lookup_key*() */
#include "lib/strutil.h"        /* str_*() */
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
            E_ ("You can not use %s() yet, because the UI has not been initialized.");
        const char *msg_with_solution =
            E_ ("You can not use %s() yet, because the UI has not been initialized.\n"
                "One way to solve this problem is to call ui_open() before calling this function.");

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
 * and columns, in other languages this isn't always so. E.g., diacritic
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

static int                      /* align_crt_t */
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
 *    -- "center or left" means to center if there's enough room, and align
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

    /* @FIXME:
     * str_*_term_trim() crashes on long strings (as pointed out
     * in 'samples/ui/extlabel.lua'). In the meantime:
     */
    if (width > BUF_MEDIUM - 1)
        /* That's the size of the buffer used by str_*_fit_to_term(). */
        luaL_error (L, E_ ("The width may not exceed %d."), BUF_MEDIUM - 1);

    /* @FIXME:
     * MC bug: tty.text_align('abcdefg',5,'center') gives 'abcdefg'.
     * But 'center' really is a weird creature that perhaps shouldn't exist: What's the
     * point in tty.text_align('long long long',5,'center') giving '' ?!
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
 * Whether the terminal is UTF-8 encoded.
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

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg ttylib[] = {
    { "keyname_to_keycode", l_keyname_to_keycode },
    { "keycode_to_keyname", l_keycode_to_keyname },
    { "redraw", l_redraw },
    { "refresh", l_refresh },
    { "text_width", l_text_width },
    { "text_cols", l_text_cols },
    { "text_align", l_text_align },
    { "is_ui_ready", l_is_ui_ready },
    { "get_cols", l_get_cols },
    { "get_rows", l_get_rows },
    { "beep", l_beep },
    { "conv", l_conv },
    { "is_utf8", l_is_utf8 },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_tty (lua_State * L)
{
    luaL_newlib (L, ttylib);
    return 1;
}
