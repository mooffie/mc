/**

A canvas is an object that holds methods by which you can draw on the
screen.

Tip: Programmers experienced in other environments may loosely think of
it as a "device context" (Windows) or "graphics context" (Java).

There are several ways you can get your hands on a canvas. One uncommon
way (but the first we cover because it's the easiest to demonstrate) is
to ask the @{tty.get_canvas|tty} module to give you a canvas. This
canvas encompasses the whole area of the screen:

    keymap.bind('C-y', function()

      local c = tty.get_canvas()

      c:set_style(tty.style("white, red"))
      c:fill_rect(4, 2, 30, 5)
      c:draw_box(4, 2, 30, 5)
      c:goto_xy(10, 4)
      c:draw_string(T"Hello world!")

    end)


The other way to get a canvas is to ask a widget --any widget-- to
@{~mod:ui*widget:get_canvas|give you one}. Such canvas encompasses only
the area of the widget. Here's an example showing this in an on_draw
event of a @{ui.Custom|custom widget}:

    local function test()

      local marquee = ui.Custom{cols=30, rows=5}

      marquee.on_draw = function(self)

        local c = self:get_canvas()

        c:set_style(tty.style("white, red"))
        c:erase()
        c:goto_xy(2, 2)
        c:draw_string(T"Hello world!")

      end

      ui.Dialog()
        :add(marquee)
        :add(ui.DefaultButtons())
        :run()

    end

    keymap.bind('C-y', test)

## Behind the scenes

Internally, a canvas is just an object whose sole attributes are the
coordinates of a rectangle on the screen. It holds no other state.

The only abstraction a canvas (in MC) provides to the programmer is its
local coordinates: When you do `c:goto_xy(0, 0)` (to go to the canvas'
top-left corner), the canvas translates it into absolute screen
coordinates and hand them to a lower-level function that actually does
the job.

The canvas does nothing more than that. Specifically, **it doesn't clip drawing
operations**. If you pass it coordinates and measures that go past its width or
height, or are negative, it won't care: the drawing will occur "outside" the
canvas.

## Virtual vs physical screen

All drawings (and cursor positioning) are done to a *virtual* screen. This
virtual screen, during MC's event loop, is then copied out to the *physical*
screen. This topic is discussed in the @{~mod:tty#Drawing|tty} module. Usually,
with a few exceptions mentioned in the previous link, you don't need to be
aware of this fact.

@classmod ui.Canvas

*/
#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"         /* because of "ui-impl.h" */

#include "lib/tty/tty.h"
#include "lib/tty/color.h"      /* tty_setcolor() */
#include "lib/lua/capi.h"
#include "lib/lua/ui-impl.h"    /* mc_lua_ui_meta_name(), create_widget_metatable() */

#include "../modules.h"

#include "ui-canvas.h"


#define DEBUG_CANVAS 1

/*
 * The Lua userdata.
 */
typedef struct
{
    int x, y;
    int cols, rows;
#if DEBUG_CANVAS
    int serial_number;
#endif
} Canvas;

#define LUA_TO_CANVAS(L, i) ((Canvas *) luaMC_checkudata__unsafe (L, i, "canvas"))

/**
 * We currently read coordinates with luaL_checkint. This will raise an
 * exception (on Lua 5.3+) if the user feeds us a fraction. If we decide
 * we want to be lenient we can change this to luaL_checknumber here.
 */
#define luaMC_checkcoord luaL_checkint

/**
 * Creates a new canvas object, on the Lua stack.
 */
void
luaUI_new_canvas (lua_State * L)
{
    Canvas *c;

    c = luaMC_newuserdata0 (L, sizeof (Canvas), mc_lua_ui_meta_name ("Canvas"));
#if DEBUG_CANVAS
    {
        static int serial_number = 0;
        c->serial_number = ++serial_number;
    }
#endif
}

/**
 * Sets the dimensions of a canvas object.
 */
void
luaUI_set_canvas_dimensions (lua_State * L, int index, int x, int y, int cols, int rows)
{
    Canvas *c;

    c = LUA_TO_CANVAS (L, index);
    c->x = x;
    c->y = y;
    c->cols = cols;
    c->rows = rows;
}

/**
 * Draws a string, at the cursor position.
 *
 * @function draw_string
 * @args (s)
 */
static int
l_canvas_draw_string (lua_State * L)
{
    (void) LUA_TO_CANVAS (L, 1);

    tty_print_string (luaL_checkstring (L, 2));

    return 0;
}

#define canvas_move(c, _y, _x) tty_gotoyx ((c)->y + (_y), (c)->x + (_x))

/**
 * Positions the cursor.
 *
 * @function goto_xy
 * @args (x, y)
 */
static int
l_canvas_goto_xy (lua_State * L)
{
    Canvas *c;
    int x, y;

    c = LUA_TO_CANVAS (L, 1);
    x = luaMC_checkcoord (L, 2);
    y = luaMC_checkcoord (L, 3);

    canvas_move (c, y, x);

    return 0;
}

/**
 * Positions the cursor.
 *
 * This method differs from @{goto_xy} in that the coordinates here are
 * one-based. That is, point `(1,1)` is the top-left cell. In all the other
 * canvas methods the coordinates are zero-based (meaning that `(0,0)` is the
 * top-left cell).
 *
 * Use this method where one-based coordinates would make your code clearer.
 *
 * @function goto_xy1
 * @args (x, y)
 */
static int
l_canvas_goto_xy1 (lua_State * L)
{
    Canvas *c;
    int x, y;

    c = LUA_TO_CANVAS (L, 1);
    x = luaMC_checkcoord (L, 2);
    y = luaMC_checkcoord (L, 3);

    canvas_move (c, y - 1, x - 1);

    return 0;
}

/**
 * Gets the cursor position.
 *
 * @function get_xy
 */
static int
l_canvas_get_xy (lua_State * L)
{
    Canvas *c;

    int x, y;

    c = LUA_TO_CANVAS (L, 1);

    tty_getyx (&y, &x);
    x -= c->x;
    y -= c->y;

    lua_pushinteger (L, x);
    lua_pushinteger (L, y);

    return 2;
}

/**
 * Draws a box.
 *
 * The interior of the box isn't filled. Only the frame is drawn.
 *
 * If `use_double_lines` is `true`, double-line characters are used. (If
 * your skin does not define these characters, you won't notice any
 * difference.)
 *
 * @function draw_box
 * @args (x, y, cols, rows[, use_double_lines])
 */
static int
l_canvas_draw_box (lua_State * L)
{
    Canvas *c;
    int x, y, cols, rows;
    gboolean use_double_lines;

    c = LUA_TO_CANVAS (L, 1);

    x = luaMC_checkcoord (L, 2);
    y = luaMC_checkcoord (L, 3);
    cols = luaMC_checkcoord (L, 4);
    rows = luaMC_checkcoord (L, 5);
    use_double_lines = lua_toboolean (L, 6);

    tty_draw_box (c->y + y, c->x + x, rows, cols, !use_double_lines);
    return 0;
}

/*
 * There's already tty_fill_region() but it doesn't support Unicode.
 */
static void
fill_rect (int x, int y, int cols, int rows, const char *ch)
{
    int x2, y2;
    int row, col;

    x2 = x + cols;
    y2 = y + rows;

    for (row = y; row < y2; row++)
    {
        tty_gotoyx (row, x);
        for (col = x; col < x2; col++)
            tty_print_string (ch);
    }
}

/**
 * Fills a rectangle.
 *
 * By default the space character is used to fill the region. You may
 * override this using the 'filler' argument.
 *
 * @function fill_rect
 * @args (x, y, cols, rows[, filler])
 */
static int
l_canvas_fill_rect (lua_State * L)
{
    Canvas *c;
    int x, y, cols, rows;
    const char *filler;

    c = LUA_TO_CANVAS (L, 1);

    x = luaMC_checkcoord (L, 2);
    y = luaMC_checkcoord (L, 3);
    cols = luaMC_checkcoord (L, 4);
    rows = luaMC_checkcoord (L, 5);
    filler = luaL_optstring (L, 6, " ");

    fill_rect (c->x + x, c->y + y, cols, rows, filler);
    return 0;
}

/**

Sets the current style.

You feed this method a value @{tty.style} returned.

Unless your drawing code is executing within @{ui.Custom:on_draw}, then
right after you create a canvas object the current style is effectively
random (it's the last style used by anybody), so calling this method is
often one of the first things you would do.

In these documents the following formula is commonly used in code snippets:

      c:set_style(tty.style(...))

However, this has two drawbacks. First, the call to @{tty.style} is
somewhat costly and should better be cached. Second, such code doesn't make
it easy for end-users to customize the styles.

You can solve this by storing the styles in a table.

In other words, instead of:

    marquee.on_draw = function(self)

      local c = self:get_canvas()

      c:goto_xy(0, 0)
      c:set_style(tty.style("white, red"))
      c:draw_string(T"Why did the chicken cross the road?")

      c:goto_xy(0, 1)
      c:set_style(tty.style("white, blue"))
      c:draw_string(T"To get to the other side.")

    end)

Do:

    local styles = nil

    local function init_styles()
      styles = {
        question = tty.style("white, red"),
        answer = tty.style("white, blue"),
      }
    end

    marquee.on_draw = function(self)

      if not styles then
        init_styles()
      end

      local c = self:get_canvas()

      c:goto_xy(0, 0)
      c:set_style(styles.question)
      c:draw_string(T"Why did the chicken cross the road?")

      c:goto_xy(0, 1)
      c:set_style(styles.answer)
      c:draw_string(T"To get to the other side.")

    end)

    event.bind('ui::skin-change', function()
      styles = nil
    end)

(This code doesn't yet deliver the promised end-user customizability.
That's because this snippet isn't a module and therefore users don't have
a way to "reach" into it. See the @{~sample|sample} modules for how to do
this.)

@function set_style
@args (style_idx)

*/
static int
l_canvas_set_style (lua_State * L)
{
    (void) LUA_TO_CANVAS (L, 1);

    tty_setcolor (luaL_checkint (L, 2));
    return 0;
}

/**
 * Gets the canvas' distance from the left edge of the screen.
 *
 * (You'll seldom use this method because all coordinates fed to the
 * canvas' methods are local to the canvas; no explicit translation
 * arithmetic is needed.)
 *
 * @function get_x
 */
static int
l_canvas_get_x (lua_State * L)
{
    lua_pushinteger (L, LUA_TO_CANVAS (L, 1)->x);
    return 1;
}

/**
 * Gets the canvas' distance from the top of the screen.
 *
 * See also @{get_x}.
 *
 * @function get_y
 */
static int
l_canvas_get_y (lua_State * L)
{
    lua_pushinteger (L, LUA_TO_CANVAS (L, 1)->y);
    return 1;
}

/**
 * Gets the canvas' width.
 *
 * @function get_cols
 */
static int
l_canvas_get_cols (lua_State * L)
{
    lua_pushinteger (L, LUA_TO_CANVAS (L, 1)->cols);
    return 1;
}

/**
 * Gets the canvas' height.
 *
 * @function get_rows
 */
static int
l_canvas_get_rows (lua_State * L)
{
    lua_pushinteger (L, LUA_TO_CANVAS (L, 1)->rows);
    return 1;
}

#if DEBUG_CANVAS
static int
l_canvas_get_serial (lua_State * L)
{
    lua_pushinteger (L, LUA_TO_CANVAS (L, 1)->serial_number);
    return 1;
}
#endif

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg ui_canvas_lib[] = {
    { "draw_string", l_canvas_draw_string },
    { "goto_xy", l_canvas_goto_xy },
    { "get_xy", l_canvas_get_xy },
    { "goto_xy1", l_canvas_goto_xy1 },
    { "set_style", l_canvas_set_style },
    { "fill_rect", l_canvas_fill_rect },
    { "draw_box", l_canvas_draw_box },
#if DEBUG_CANVAS
    { "get_serial", l_canvas_get_serial },
#endif
    { "get_x", l_canvas_get_x },
    { "get_y", l_canvas_get_y },
    { "get_cols", l_canvas_get_cols },
    { "get_rows", l_canvas_get_rows },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_ui_canvas (lua_State * L)
{
    /*
     * We can just use luaMC_register_metatable(), but
     * create_widget_metatable() creates some useful scaffoldings for us:
     * programmers would be able to edit the metatable via ui.Canvas.meta.
     */
    create_widget_metatable (L, "Canvas", ui_canvas_lib, NULL, NULL);
    return 0;                   /* Nothing to return! */
}
