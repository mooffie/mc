/**

Custom widget.

When the none of the @{ui|standard widgets} suits you, you can build
your own custom widget.

You yourself decide how to draw it on the screen and how it will respond
to keyboard and mouse events.

For a sample script that uses a custom widget, see @{git:ui_canvas.mcs}.

Tip: There are two ways to use ui.Custom. You can instantiate it and use
it outright, as shown on these pages, or you can @{ui.subclass|subclass}
it. Subclassing is especially useful when you want your widget to be
reusable.

@classmod ui.Custom

*/
#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"
#include "lib/tty/tty.h"        /* tty_print_string() */
#include "lib/tty/color.h"      /* tty_setcolor() */
#include "lib/lua/capi.h"
#include "lib/lua/ui-impl.h"    /* luaUI_*() */

#include "../modules.h"

#include "ui-custom.h"

/**

GUI toolkits customarily have two classes to manage roll-your-own
widgets: a custom widget class, and a GC class. We name ours "Custom"
and "Canvas" respectively. Other toolkits name them differently:

  Toolkit       Custom widget name    GC name
  --------      ------------------    -------
  wxWidgets     wxControl             wxDC
  Android       View                  Canvas
  Java AWT      Canvas                Graphics
  Java SWT      Canvas                GC
  HTML 5        <canvas>              CanvasRenderingContext2D (via canvas.getContext("2d"))

*/

typedef struct
{
    Widget widget;
    struct {
      gboolean capture;
      int last_buttons_down;
    } mouse;
} WCustom;

#define WCUSTOM(x) ((WCustom *) (x))

/* See comment for LUA_TO_BUTTON, in ui.c */
#define LUA_TO_CUSTOM(L, i) (WCUSTOM (luaUI_check_widget (L, i)))

/**
 * Misc event handlers
 * @section
 */

/**
 * Draw handler.
 *
 * This is where you draw the contents of your widget. Typically you fetch a
 * @{ui.Canvas|canvas} object and use its drawing methods:
 *
 *    wdg.on_draw = function(self)
 *      local c = self:get_canvas()
 *      c:erase()
 *      c:draw_string("hi!")
 *    end
 *
 * See more examples in the page on @{ui.Canvas}.
 *
 * Right before this handler is called the current style is set to MC's
 * normal dialog color (appropriate for the active @{ui.colorset|colorset})
 * and the cursor is positioned at the widget's top-left corner.
 *
 * @method on_draw
 * @args (self)
 * @callback
 */

/**
 * Cursor positioning handler.
 *
 * This handler is called to position the cursor. It is only called for
 * widgets that have the @{on_focus|focus}.
 *
 *    wdg.on_cursor = function()
 *      wgt:get_canvas():goto_xy(point.x, point.y)
 *    end
 *
 *    -- To make our widget focusable, we must also do:
 *    wdg.on_focus = function() return true end
 *
 * You'll always want to implement this handler for focusable widgets
 * or else the cursor will remain at its last arbitrary position.
 *
 * @method on_cursor
 * @args (self)
 * @callback
 */

/**
Keypress handler.

This is where you respond to a key pressed when your widget has the focus.

The handler gets as argument the *keycode*. It should return **true** if
the key was handled.

    local K_LEFT = tty.keyname_to_keycode('left')
    local K_RIGHT = tty.keyname_to_keycode('right')
    ...

    wgt.on_key = function(self, keycode)
      if keycode == K_LEFT then
        pos.x = pos.x - 1
      elseif keycode == K_RIGHT then
        pos.x = pos.x + 1
      ...
      else
        return false
      end

      self:redraw()
      return true
    end

The above bulky code can be made to look more friendly:

    local K = utils.magic.memoize(tty.keyname_to_keycode)

    wgt.on_key = function(self, keycode)

      if keycode == K'left' then
        pos.x = pos.x - 1
      elseif keycode == K'right' then
        pos.x = pos.x + 1
      elseif keycode == K'up' then
        pos.y = pos.y - 1
      elseif keycode == K'down' then
        pos.y = pos.y + 1
      else
        return false
      end

      self:redraw()
      return true
    end

Or you can use a dispatch table:

    local K = utils.magic.memoize(tty.keyname_to_keycode)

    local navigation = {
      [K'left'] = wgt.go_left,
      [K'right'] = wgt.go_right,
      [K'up'] = wgt.go_up,
      [K'down'] = wgt.go_down,
    }

    wgt.on_key = function(self, keycode)
      if navigation[keycode] then
        navigation[keycode](self)
        self:redraw()
        return true
      end
    end

[info]

More examples for handling keys:

- A dialog's on_key -- @{git:accessories/find-as-you-type.lua},
  @{git:apps/visren/dialog.lua}.

- A canvas's on_key or on_hotkey --
  @{git:tests/nonauto/ui_canvas.mcs|tests/ui_canvas.mcs},
  @{git:screensavers/simplest.lua}, @{git:games/blocks/dialog.lua}.

[/info]

[tip]

If you want to know a key's name, temporarily turn your key handler
into:

    wgt.on_key = function(self, k)
      alert(tty.keycode_to_keyname(k))
      return true
    end

Note that @{tty.keycode_to_keyname} returns two names. The second --due
to the way multiple values are passed around in Lua-- will be displayed
as the @{prompts.alert|alert}'s title.

[/tip]

@method on_key
@args (self, keycode)
@callback
*/

/**
 * Global keypress handler.
 *
 * This is where you respond to a key pressed when your widget
 * doesn't necessarily have the focus. (You may alternatively use
 * @{ui.on_key|ui.Dialog:on_key}.)
 *
 * The interface is identical to that of @{on_key}: the handler gets a
 * *keycode*, and should return **true** for handled keys.
 *
 * @method on_hotkey
 * @args (self, keycode)
 * @callback
 */

/**
 * Focus handler.
 *
 * Called when a widget is about to receive the focus. You *must* return **true**
 * here if you want your widget to receive the focus. Otherwise the widget
 * will be skipped over when the user tries to tab to it.
 *
 *    wdg.on_focus = function()
 *      return true
 *    end
 *
 * You will most probably also want to implement @{on_cursor}.
 *
 * @method on_focus
 * @args (self)
 * @callback
 */

/**
 * Unfocus handler.
 *
 * Called when a widget is about to lose the @{on_focus|focus}. If you implement
 * this handler, you *must* return **true** here if you want your widget to lose
 * the focus; otherwise the user won't be able to leave the widget.
 *
 * If you don't implement this handler, it's as if you returned **true**: the
 * user will be able to always leave the widget.
 *
 *    wdg.on_unfous = function()
 *      if some_data_is_missing then
 *        tty.beep()
 *        return false
 *      else
 *        return true
 *      end
 *    end
 *
 * @method on_unfocus
 * @args (self)
 * @callback
 */

/**
 * Invoked when the user does "wgt.on_cursor = ...". We turn on a flag here
 * that tells the system we can position the cursor.
 */
static int
l_custom_set_on_cursor (lua_State * L)
{
    Widget *w = luaUI_check_widget (L, 1);

    luaMC_rawsetfield (L, 1, "on_cursor");
    widget_want_cursor (w, TRUE);

    return 0;
}

static cb_ret_t
custom_callback (Widget * w, Widget * sender, widget_msg_t msg, int parm, void *data)
{
    gboolean method_found;

    switch (msg)
    {
    case MSG_FOCUS:
        /* Returning MSG_HANDLED here is what enables focusing. */
        return call_widget_method (w, "on_focus", 0, NULL);

    case MSG_UNFOCUS:
        {
            cb_ret_t result = call_widget_method (w, "on_unfocus", 0, &method_found);
            /* If the method is not implemented, we pretend it returned 'true'
             * (by return MSG_HANDLED). This way we don't bother our users with
             * implementing this method as it's only seldom that users would want
             * to return 'false' (to disallow leaving a widget). */
            return method_found ? result : MSG_HANDLED;
        }

    case MSG_CURSOR:
        {
            call_widget_method (w, "on_cursor", 0, &method_found);
            return method_found ? MSG_HANDLED : MSG_NOT_HANDLED;
        }

    case MSG_KEY:
        {
            lua_pushinteger (Lg, parm);
            return call_widget_method (w, "on_key", 1, NULL);
        }

    case MSG_HOTKEY:
        {
            lua_pushinteger (Lg, parm);
            return call_widget_method (w, "on_hotkey", 1, NULL);
        }

    case MSG_DRAW:
        {
            /* Color and cursor position are arbitrary at this point,
             * so we reset them to something sane: */

            /* This widget may have been injected into the editor/viewer, whose
             * 'color' pointer is NULL, so we have to guard against this. */
            if (w->owner->color != NULL)
                tty_setcolor (w->owner->color[DLG_COLOR_NORMAL]);
            else
                tty_setcolor (dialog_colors[DLG_COLOR_NORMAL]);
            widget_move (w, 0, 0);

            call_widget_method (w, "on_draw", 0, &method_found);
            return method_found ? MSG_HANDLED : MSG_NOT_HANDLED;
        }

    default:
        return widget_default_callback (w, sender, msg, parm, data);
    }
}

/* --------------------------- Mouse features ----------------------------- */

/**
 * Mouse event handlers.
 *
 * For a sample script that uses mouse events, see @{git:ui_canvas_mouse.mcs}.
 *
 * @section mouse
 */

/**
 * Mouse down handler.
 *
 * Called when a mouse button is pressed down inside the widget.
 *
 *    wgt.on_mouse_down = function()
 *      wgt:focus()
 *    end
 *
 * The **buttons** table reports which buttons are pressed after the event.
 * Valid button names are "left", "middle", "right".
 *
 * **count** indicates whether this is part of a double-click or
 * triple-click. It is either "single", "double", or "triple".
 *
 * Note: This handler is blind to the mouse wheel. If you're interested in
 * the wheel, see @{on_mouse_scroll_up} and @{on_mouse_scroll_down}.
 *
 * [info]
 *
 * There are a few subtle implementation differences between GPM and xterm:
 *
 * [expand]
 *
 * - Several buttons may be pressed simultaneously, but when using xterm
 * (as opposed to GPM) only one button will be indicated (in **buttons**)
 * as pressed.
 *
 * - When using GPM, **count** will show "double" as soon as you press the
 * button (for the second time). When using xterm, however, "double" is
 * indicated a tad later: when you release the button. (However, since
 * you'll be using @{on_click}, as you should, you don't need to be aware
 * of this issue.)
 *
 * - "triple" is supported only on GPM, not xterm.
 *
 * [/expand]
 *
 * [/info]
 *
 * @method on_mouse_down
 * @args (self, x, y, buttons, count)
 * @callback
 */

/**
 * Mouse click handler.
 *
 * Called when a mouse button is pressed down **and then released** inside
 * the widget. According to conventions, this is the desired sequence before
 * taking an action in a UI application. E.g., firing a button's action or
 * changing a checkbox state should be done in @{on_click}, not in
 * @{on_mouse_down}.
 *
 *    wgt.on_click = function()
 *      os.execute('firefox')
 *    end
 *
 * **buttons** reports the button that was clicked:
 * 
 *    wgt.on_click = function(self, x, y, buttons, count)
 *      if buttons.left and count == 'double' then
 *        alert(T'You double-clicked the left button.')
 *      else
 *    end
 *
 * Info: The system first tries to call "on_mouse_click" and if it's
 * missing only then it calls "on_click". This way the widget's author can
 * reserve "on_click" for end-user supplied actions (this stems from our
 * decision to @{~mod:ui*button:on_click|not use the name "on_action"}).
 *
 * @method on_click
 * @args (self, x, y, buttons, count)
 * @callback
 */

/**
 * Mouse scroll down handler.
 *
 * Called when the mouse wheel is rotated towards the user.
 *
 *    wgt.on_mouse_scroll_down = function()
 *      wgt.top_line = wgt.top_line + 1
 *      wgt:redraw()
 *    end
 *
 * @method on_mouse_scroll_down
 * @args (self, x, y)
 * @callback
 */

/**
 * Mouse scroll up handler.
 *
 * Called when the mouse wheel is rotated away from the user.
 *
 *    wgt.on_mouse_scroll_up = function()
 *      wgt.top_line = wgt.top_line - 1
 *      wgt:redraw()
 *    end
 *
 * @method on_mouse_scroll_up
 * @args (self, x, y)
 * @callback
 */

/**
 * Mouse drag handler.
 *
 * Called when the mouse pointer, after a mouse button was pressed down
 * inside the widget, is moved (either inside or outside the widget).
 *
 *    local function test2()
 *
 *      local wgt = ui.Custom{cols=80, rows=5}
 *
 *      local function draw_point(x, y)
 *        local c = wgt:get_canvas()
 *        c:set_style(tty.style('white, red'))
 *        c:goto_xy(x, y)
 *        c:draw_string('*')
 *      end
 *
 *      wgt.on_mouse_down = function(self, x, y, buttons, count)
 *        draw_point(x, y)
 *      end
 *
 *      wgt.on_mouse_drag = function(self, x, y, ...)
 *        -- If we remove these checks we'll be able to draw outside the widget.
 *        if x >= 0 and x < self.cols and y >= 0 and y < self.rows then
 *          draw_point(x, y)
 *        end
 *      end
 *
 *      ui.Dialog():add(wgt):run()
 *
 *    end
 *
 * @method on_mouse_drag
 * @args (self, x, y, buttons)
 * @callback
 */

/**
 * Mouse move handler.
 *
 * Note: MC doesn't currently support this event (see
 * [here](http://stackoverflow.com/a/5970472/1560821) for a start). Only
 * mouse @{on_mouse_drag|dragging} is supported.
 *
 * @method on_mouse_move
 * @args (self, x, y)
 * @callback
 */

/**
 * Mouse up handler.
 *
 * Called when a mouse button, that was pressed down inside the widget,
 * is now released (either inside or outside the widget).
 *
 * **buttons** reports the button that was released.
 *
 * @method on_mouse_up
 * @args (self, x, y, buttons, count)
 * @callback
 */

/**
 * @section end
 */

/*
 * For details on the C mouse API, see MC's lib/tty/mouse.h, or GPM's
 * excellent 'info' manual:
 *
 *    http://www.fifi.org/cgi-bin/info2www?(gpm)Event+Types
 */

static void
ev_buttons_to_table (lua_State * L, Gpm_Event * event)
{
    lua_newtable (L);

    if (event->buttons & GPM_B_LEFT)
        luaMC_setflag (L, -1, "left", TRUE);
    if (event->buttons & GPM_B_MIDDLE)
        luaMC_setflag (L, -1, "middle", TRUE);
    if (event->buttons & GPM_B_RIGHT)
        luaMC_setflag (L, -1, "right", TRUE);
    if (event->buttons & GPM_B_UP)
        luaMC_setflag (L, -1, "up", TRUE);
    if (event->buttons & GPM_B_DOWN)
        luaMC_setflag (L, -1, "down", TRUE);
}

static const char *
ev_count (Gpm_Event * event)
{
    if (event->type & GPM_DOUBLE)
        return "double";
    else if (event->type & GPM_TRIPLE)
        return "triple";
    else
        return "single";
}

static int
push_ev_args (lua_State * L, Gpm_Event * event, Widget * w)
{
    lua_pushinteger (L, event->x - w->x - 1);
    lua_pushinteger (L, event->y - w->y - 1);
    ev_buttons_to_table (L, event);
    lua_pushstring (L, ev_count (event));

    /* How many values we pushed. Make sure to update this if you change the above. */
    return 4;
}

/**
 * Like call_widget_method(), but intended for the cases when you're
 * only interested to know if the method returned an explicit false.
 *
 * Returns FALSE if, and only if, the method returned explicit false.
 * Returns TRUE in all other cases (including method not found).
 */
static gboolean
call_abortive_widget_method (Widget * w, const char *method_name, int nargs,
                             gboolean * method_found)
{
    gboolean explicit_false;

    call_widget_method_ex (w, method_name, nargs, NULL, method_found, FALSE);
    explicit_false = (lua_type (Lg, -1) == LUA_TBOOLEAN && !lua_toboolean (Lg, -1));
    lua_pop (Lg, 1);
    return !explicit_false;
}

static int
custom_mouse_event (Gpm_Event * event, void *data)
{
    Widget *w = WIDGET (data);
    WCustom *cust = WCUSTOM (data);

    gboolean in_widget;
    const char *method = NULL;
    gboolean abort = FALSE;
    gboolean run_click = FALSE;

    in_widget = mouse_global_in_widget (event, w);

    /*
     * Checks commented with "* forced *" show places where mouse.capture is
     * normally FALSE unless the programmer explicitly turned it on (via
     * "wgt.mouse.capture = true"). If we ever remove this feature, we can
     * also remove these checks.
     */

    if (event->type & GPM_DOWN)
    {
        if (in_widget || cust->mouse.capture /* forced */ )
        {
            if (event->buttons & GPM_B_UP)
                method = "on_mouse_scroll_up";
            else if (event->buttons & GPM_B_DOWN)
                method = "on_mouse_scroll_down";
            else
            {
                /* Handle normal buttons: anything but the mouse wheel's.
                 *
                 * (Note that turning on capturing for the mouse wheel
                 * buttons doesn't make sense as they don't generate a
                 * mouse_up event, which means we'd never get uncaptured.)
                 */
                cust->mouse.capture = TRUE;

                cust->mouse.last_buttons_down = event->buttons;
                method = "on_mouse_down";
            }
        }
    }
    else if (event->type & GPM_UP)
    {
        /* We trigger the on_mouse_up event even when !in_widget. That's
         * because, for example, a paint application should stop drawing
         * lines when the button is released even outside the canvas. */
        if (cust->mouse.capture)
        {
            cust->mouse.capture = FALSE;
            method = "on_mouse_up";
            if (in_widget)
                run_click = TRUE;

            /*
             * When using xterm, event->buttons reports the buttons' state
             * after the event occurred (meaning that event->buttons is zero,
             * because the mouse button is now released). When using GPM,
             * however, that field reports the button(s) that was released.
             *
             * The following makes xterm behave effectively like GPM:
             */
            if (!event->buttons)
                event->buttons = cust->mouse.last_buttons_down;
        }
    }
    else if (event->type & GPM_DRAG)
    {
        if (cust->mouse.capture)
            method = "on_mouse_drag";
    }
    else if (event->type & GPM_MOVE)
    {
        if (in_widget || cust->mouse.capture /* forced */ )
            method = "on_mouse_move";
    }

    if (method)
    {
        abort = !call_abortive_widget_method (w, method, push_ev_args (Lg, event, w), NULL);

        if (run_click)
        {
            /*
             * First we try "on_mouse_click", then "on_click". See rationale
             * in ldoc for on_click.
             */
            if (!call_abortive_widget_method (w,
                                              widget_method_exists (w, "on_mouse_click")
                                              ? "on_mouse_click" : "on_click",
                                              push_ev_args (Lg, event, w), NULL))
                abort = TRUE;
        }
    }

    return (method && !abort) ? MOU_NORMAL : MOU_UNHANDLED;
}

/**
 * Our Lua API makes it possible for the user to do virtually anything
 * conventional with the mouse.
 *
 * If the user wants to do unconventional things, we give him all the power
 * C programmers have by exposing two devices:
 *
 * (1) The user can make the system hand him mouse events occurring
 *     *outside* the widget by doing `wgt.mouse_captue = true`.
 *
 * (2) The user can return 'false' from any Lua mouse handler to tell the
 *     system the custom widget hasn't handled the event.
 *
 * Currently, we don't ldoc-document any of these devices unless somebody
 * demonstrates that unconventional mouse handling is anyhow useful.
 *
 * One case where it could be useful is in drag-and-drop that's initiated in
 * a widget which isn't our widget. Without the above devices, on_mouse_drag
 * would only work for drags started inside our widget. But who gives a hoot
 * about drag-and-drop in console apps anyway?
 */
static int
l_custom_set_mouse_capture (lua_State * L)
{
    WCustom *cust;

    cust = LUA_TO_CUSTOM (L, 1);
    cust->mouse.capture = lua_toboolean (L, 2);

    return 0;
}

/* ------------------------------------------------------------------------ */

gboolean
is_custom (Widget * w)
{
    return w->callback == custom_callback;
}

static Widget *
custom_constructor (void)
{
    WCustom *c;
    Widget *w;

    c = g_new0 (WCustom, 1);

    w = WIDGET (c);
    widget_init (w, 0, 0, 1, 8, custom_callback, custom_mouse_event, "Custom");
    widget_want_cursor (w, FALSE);
    widget_want_hotkey (w, TRUE);

    return w;
}

static int
l_custom_new (lua_State * L)
{
    luaUI_push_widget (L, custom_constructor (), FALSE);
    return 1;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg ui_custom_static_lib[] = {
    { "_new", l_custom_new },
    { NULL, NULL }
};

static const struct luaL_Reg ui_custom_lib[] = {
    { "set_on_cursor", l_custom_set_on_cursor },
    { "set_mouse_capture", l_custom_set_mouse_capture },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_ui_custom (lua_State * L)
{
    create_widget_metatable (L, "Custom", ui_custom_lib, ui_custom_static_lib, "Widget");
    return 0;                   /* Nothing to return! */
}
