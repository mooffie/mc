/**

Custom widget.

When the none of the @{ui|standard widgets} suits you, you can build
your own custom widget.

You yourself decide how to draw it on the screen and how it will respond
to keyboard events.

For a sample script that uses a custom widget, see @{git:ui_canvas.mcs}.

@classmod ui.Custom

*/
#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"
#include "lib/tty/tty.h"        /* widget_move() */
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
    widget_init (w, 0, 0, 1, 8, custom_callback, NULL, "Custom");
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
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_ui_custom (lua_State * L)
{
    create_widget_metatable (L, "Custom", ui_custom_lib, ui_custom_static_lib, "Widget");
    return 0;                   /* Nothing to return! */
}
