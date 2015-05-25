/**

User Interface.

The ui module lets you create user interfaces. This subject is covered
in the @{~interface|user manual}.

At the basis of the architecture are widgets. You can create widgets, and
you can also access existing widgets created by MC itself.  This ability
is the one which lets you script the @{ui.Panel|file manager} and the
@{ui.Editbox|editor}.

[tip]

C programmers: You can do in Lua anything practical that you can do in
C. All the benefits of a "scripting" language are at your hands: you
write but the fraction of the code you would in C, and you don't need to
worry about memory leaks and crashes.

[/tip]

As a quick reference, here’s a snippet that uses some common features:

    local function order_pizza()

      local dlg = ui.Dialog(T"Place an order")

      local flavor = ui.Radios()
      flavor.items = {
        'Cheese',
        'Olive',
        'Anchobi',
        'Falafel',
      }

      local with_pepper = ui.Checkbox(T"With pepper")
      local with_ketchup = ui.Checkbox{T"With ketchup", checked=true}

      local send_address = ui.Input()

      dlg:add(
        ui.Label(T"Please fill in the details:"),
        ui.HBox():add(
          flavor,
          ui.Groupbox(T"Spices:"):add(
            with_pepper,
            with_ketchup
          )
        ),
        ui.Label(T"Send it to:"),
        send_address,
        ui.DefaultButtons()
      )

      flavor.on_change = function(self)
        -- It's abominable to add ketchup to Anchobi.
        with_ketchup.enabled = (self.value ~= "Anchobi")
      end

      if dlg:run() then
        alert(T"Great! I'll be delivering the %s pizza to %s!":format(
          flavor.value, send_address.text))
        if with_pepper.checked then
          alert(T"I too love pepper!")
        end
      end

    end

    keymap.bind('C-q', order_pizza)

@module ui
*/

#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"
#include "lib/event.h"          /* mc_event_*() */
#include "lib/skin.h"           /* PMENU_*_COLOR */
#include "lib/util.h"           /* tilde_expand() */
#include "lib/lua/capi.h"
#include "lib/lua/capi-safecall.h"
#include "lib/lua/plumbing.h"
#include "lib/lua/ui-impl.h"    /* luaUI_*() */
#include "lib/lua/utilx.h"
#include "lib/scripting.h"        /* scripting_notify_on_widget_destruction() */

#include "../modules.h"
#include "ui-custom.h"          /* is_custom() */
#include "ui-canvas.h"          /* luaUI_new_canvas() */
#include "tty.h"                /* luaTTY_check_keycode() */


/* ------------------------------- Widget --------------------------------- */

/**
 * Widget methods and properties.
 *
 * "Widget" is the base class for all widgets. All the widgets (buttons,
 * listboxes, dialogs, etc.) inherit the methods and properties listed here.
 *
 * @section widget
 */

#define WDGT_GETTER(name, var) \
    static int \
    l_widget_get_ ## name (lua_State* L) \
    { \
        Widget *w; \
        w = luaUI_check_widget (L, 1); \
        lua_pushinteger (L, w->var); \
        return 1; \
    }

#define WDGT_SETTER(name, var) \
    static int \
    l_widget_set_ ## name (lua_State* L) { \
        Widget *w; \
        w = luaUI_check_widget (L, 1); \
        w->var = luaL_checkint (L, 2); \
        return 0; \
    }

WDGT_GETTER (x, x);
WDGT_SETTER (x, x);

WDGT_GETTER (y, y);
WDGT_SETTER (y, y);

/**
 * The width of the widget, in characters.
 *
 * You usually don't need to set this property: for most widgets it's set
 * according to the widget's preferred dimensions.
 *
 * @attr widget.cols
 * @property rw
 */
WDGT_GETTER (cols, cols);
WDGT_SETTER (cols, cols);

/**
 * The height of the widget, in lines.
 *
 * @attr widget.rows
 * @property rw
 */
WDGT_GETTER (rows, lines);
WDGT_SETTER (rows, lines);

static int
l_widget_init (lua_State * L)
{
    /* Do nothing. Subclasses can override this. */
    (void) L;
    return 0;
}


/**
 * The dialog the widget is in.
 *
 *     closeButton.on_click = function(self)
 *       self.dialog:close()
 *     end
 *
 * (See another example at @{command}.)
 *
 * @attr widget.dialog
 * @property r
 */
static int
l_widget_get_dialog (lua_State * L)
{
    luaUI_push_widget (L, WIDGET (luaUI_check_widget (L, 1)->owner), TRUE);
    return 1;
}

/**
 * Whether the widget is enabled or disabled.
 *
 *     local ftp = ui.Checkbox(T"Use FTP")
 *     local ftp_server = ui.Input("ftp.midnight.org")
 *
 *     ftp.on_change = function(self)
 *       ftp_server.enabled = self.checked
 *     end
 *
 *     ui.Dialog():add(ftp, ftp_server):run()
 *
 * Tip: This property works for @{~#containers|containers} as well: You may
 * group widgets in a @{~#groupbox|groupbox} and enable/disable the
 * groupbox itself to affect all the widgets within.
 *
 * @attr widget.enabled
 * @property rw
 */
static int
l_widget_set_enabled (lua_State * L)
{
    Widget *w = luaUI_check_widget (L, 1);
    gboolean b = lua_toboolean (L, 2);

    WDialog *dlg;

    widget_disable (w, !b);

    dlg = w->owner;

    if (!b && dlg && dlg->current && dlg->current->data == w)
    {
        /* If we've disabled ourselves, focus the next widget. This in
         * order to circumvent a "bug" in MC where it's still possible
         * to hit ENTER on a disabled button thereby activating it. */
        dlg_one_down (dlg);
    }

    return 0;
}

static int
l_widget_get_enabled (lua_State * L)
{
    lua_pushboolean (L, (luaUI_check_widget (L, 1)->options & W_DISABLED) == 0);
    return 1;
}

/**
 * Destroys a widget.
 *
 * Destroys the C widget associated with this Lua object. The :is_alive()
 * method will then return false. Using any method that accesses the underlying
 * C widget will raise an exception (but it's safe: MC won't crash).
 *
 * End-users don't have a reason to call this method, so we don't document it.
 *
 * Note: The Dialog widget overrides this method (see l_dialog_destroy).
 */
static int
l_widget_destroy (lua_State * L)
{
    Widget *w = luaUI_check_widget_ex (L, 1, TRUE, NULL);

    /* If the user asks us to destroy an already destroyed widget, we
     * don't play drama queens but fail silently. That's the 'TRUE' in
     * the call above. */

    if (w)
    {
        if (w->owner != NULL)
        {
            /* This will make the dialog contain a pointer to invalid address.
             * The way to destroy a child widget is to destroy its dialog. */
            luaL_error (L, E_ ("You can't destroy a widget which is already mapped in a dialog."));
        }

        /* @FIXME: MC itself should have widget_destroy()! See another comment in this file mentioning it. */

        scripting_notify_on_widget_destruction (w);
        send_message (w, NULL, MSG_DESTROY, 0, NULL);
        g_free (w);
    }

    return 0;
}

/**
 * Executes a widget command.
 *
 * Certain widgets respond to certain commands. For example, an Input
 * widget responds to 'WordLeft', 'Paste', etc. An Editbox responds to
 * 'Undo', 'Redo', 'DeleteLine', etc. Instead of providing a Lua method
 * for every such command, this one method triggers any command by name.
 *
 * To see a list of available commands, check the C source code (e.g.,
 * @{git:keybind-defaults.c}, but that list isn't exhaustive).
 *
 * Note that some commands are to be sent to the dialog containing the widget,
 * not the widget itself (see example).
 *
 *    ui.Editbox.bind('C-x e', function(edt)
 *      edt:command "DeleteLine"
 *      edt.dialog:command "ShowMargin"
 *    end)
 *
 *    ui.Panel.bind('C-x d', function(pnl)
 *      pnl:command "MiddleOnScreen"
 *      pnl:redraw() -- Some commands, such as MiddleOnScreen,
 *                   -- don't automatically redraw the widget.
 *      pnl.dialog:command "Find"
 *    end)
 *
 * This method returns **true** if the command was handled.
 *
 * @method widget:command
 * @args (command_name)
 */
static int
l_widget_command (lua_State * L)
{
    Widget *w = luaUI_check_widget (L, 1);
    const char *cmd_name = luaL_checkstring (L, 2);

    int cmd;

    cmd = keybind_lookup_action (cmd_name);

    if (cmd == CK_IgnoreKey)
        luaL_error (L, E_ ("Invalid command name '%s'"), cmd_name);

    /*
     * MC bug:
     *
     * dialog:command("ScreenNext") and dialog:command("Down") (and
     * some others) won't work.
     *
     * That's because these specific commands are handled in
     * dlg_execute_cmd(), which is only called in response to keyboard
     * events. dlg_execute_cmd() isn't anywhere in the call chain when
     * we trigger these command explicitly by send_message().
     *
     * (This problem pertains to any dialog, not just to Lua dialogs.)
     */

    /*
     * MC snafu:
     *
     * Editbox has no proper constructor (see note in ui-editbox.c). We emit
     * its <<load>> event before w->callback gets set. Here we catch any tries
     * to :command() an editbox from its <<load>> handler.
     *
     * @FIXME
     */
    if (w->callback == NULL)
        luaL_error (L,
                    E_
                    ("My oh my! w->callback is NULL. I cannot :command() the widget!\nAre you trying to :command() an Editbox from its <<load>> event?"));

    lua_pushboolean (L, send_message (w, NULL, MSG_ACTION, cmd, NULL) != MSG_NOT_HANDLED);
    return 1;
}

/**
 * Low-level message passing.
 *
 * This method calls the C function @{git:widget-common.h|send_message()}.
 *
 * [note]
 *
 * This method is intended for advanced users only. One won't normally
 * use it (which is proven by the fact that this method isn't used
 * in our core or in our sample modules). Its use is discouraged, which
 * is why we don't document its parameters here.
 *
 * See usage examples at @{git:snippets/hotlist_right_as_enter.lua} and
 * @{git:snippets/quicksearch_asterisk_first.lua}.
 *
 * [/note]
 *
 * @method widget:_send_message
 * @args (...)
 */
static int
l_widget_send_message (lua_State * L)
{
    Widget *w = luaUI_check_widget (L, 1);
    widget_msg_t msg = luaL_checkint (L, 2);
    int parm = luaL_optint (L, 3, 0);

    lua_pushboolean (L, send_message (w, NULL, msg, parm, NULL) != MSG_NOT_HANDLED);
    return 1;
}

/**
 * Whether the widget is alive.
 *
 * Note-short: You'll seldom, if ever, use this method.
 *
 * This method tells us whether the C widget associated with this Lua object
 * has been destroyed.
 *
 * To understand this method, let's imagine the following code:
 *
 *     local the_editbox = nil
 *
 *     ui.Editbox.bind('C-a', function(edt)
 *       the_editbox = edt
 *     end)
 *
 *     keymap.bind('C-b', function()
 *       if the_editbox then
 *         alert('The editbox edits the file ' .. the_editbox.filename)
 *       end
 *     end)
 *
 * We press `C-a` inside the editor. Then we close the editor. This destroys
 * the editbox. Now we press `C-b`. What will happen? An exception will be
 * raised, when we try to access the `filename` property. The error message
 * says "A living widget was expected, but an already destroyed
 * widget was provided". That's because the Lua object is now just a shell
 * over a dead body. To fix our code we can change it to:
 *
 *     keymap.bind('C-b', function()
 *       if the_editbox and the_editbox:is_alive() then
 *         alert('The editbox edits the file ' .. the_editbox.filename)
 *       end
 *     end)
 *
 * @method widget:is_alive
 */
/*
 * See also l_widget_destroy().
 */
static int
l_widget_is_alive (lua_State * L)
{
    lua_pushboolean (L, ! !luaUI_check_widget_ex (L, 1, TRUE, NULL));
    return 1;
}

/**
 * Redraws a widget.
 *
 * Draws ("paints", if you will) the widget.
 *
 * You won't normally need to call this method yourself, because all
 * properties that affect the visual appearance of a widget call :redraw()
 * automatically for you upon setting. For example, if you change the text of
 * an @{ui.Input|input} box or the value of a @{ui.Gauge|gauge}, you don't
 * need to call :redraw() afterwards.
 *
 * A notable case where you *do* have to call :redraw() yourself is after you
 * change the state of a @{ui.Custom} widget. Only you know what affects the
 * display of your custom widget, so only you can decide when to redraw it.
 *
 * For further information on the mechanism of updating the screen, see
 * @{~mod:tty#Drawing}.
 *
 * @method widget:redraw
 */
static int
l_widget_redraw (lua_State * L)
{
    widget_redraw (luaUI_check_widget (L, 1));
    return 0;
}

/**
 * Focuses a widget.
 *
 * That is, moves the keyboard focus (the cursor) to it.
 *
 * See example at @{on_validate}.
 *
 * Note that you can only focus a widget that has been @{mapped_children|"mapped"}
 * into a dialog. Mapping happens when you call @{run}, not before. Therefore,
 * a way to select the initial widget to get the focus is to use @{on_init},
 * as follows:
 *
 *    local function test()
 *      local dlg = ui.Dialog()
 *
 *      local name = ui.Input()
 *      local age = ui.Input()
 *
 *      dlg.on_init = function() age:focus() end
 *
 *      dlg:add(name, age)
 *      dlg:run()
 *    end
 *
 * @method widget:focus
 */
static int
l_widget_focus (lua_State * L)
{
    Widget *w = luaUI_check_widget (L, 1);

    if (!w->owner)
        luaL_error (L, E_ ("You can only focus a widget that has been mapped in a dialog."));

    dlg_select_widget (w);
    return 0;
}

/**
 * Returns a @{ui.Canvas|canvas object} encompassing the widget's area.
 *
 * This lets you draw inside the widget. You'd normally use this
 * method with a @{ui.Custom} widget only.
 *
 * @method widget:get_canvas
 */
static int
l_widget_get_canvas (lua_State * L)
{
    Widget *w;

    w = luaUI_check_widget (L, 1);

    /* We cache the canvas in _canvas. */

    luaMC_rawgetfield (L, 1, "_canvas");

    if (lua_isnil (L, -1))
    {
        luaUI_new_canvas (L);

        /* store it: */
        lua_pushvalue (L, -1);
        luaMC_rawsetfield (L, 1, "_canvas");
    }

    luaUI_set_canvas_dimensions (L, -1, w->x, w->y, w->cols, w->lines);
    return 1;
}

/**
 * Sets the widget's `pos_flags`.
 *
 * This is the traditional way to layout widgets in C. You may use it together
 * with, or instead of, our Lua layout model.
 *
 * (This is for "advanced users", so this documentation entry isn't currently
 * exposed in ldoc.)
 */
static int
l_widget_set_pos_flags (lua_State * L)
{
    luaUI_check_widget (L, 1)->pos_flags = luaL_checki (L, 2);
    return 0;
}

/* The following property is defined in ui-impl.c */
/**
 * The name of the widget's class.
 *
 * This property can aid in debugging. It's also a way for you to find
 * the type of a widget. E.g., `if w.widget_type == "Button"` (although
 * you can also do `if getmetatable(w) == ui.Button.meta`).
 *
 * @attr widget.widget_type
 * @property r
 */

/* *INDENT-OFF* */
static const struct luaL_Reg ui_widget_methods_lib[] = {
    { "init", l_widget_init },
    { "get_x", l_widget_get_x },
    { "set_x", l_widget_set_x },
    { "get_y", l_widget_get_y },
    { "set_y", l_widget_set_y },
    { "get_cols", l_widget_get_cols },
    { "set_cols", l_widget_set_cols },
    { "get_rows", l_widget_get_rows },
    { "set_rows", l_widget_set_rows },
    { "get_dialog", l_widget_get_dialog },
    { "set_enabled", l_widget_set_enabled },
    { "get_enabled", l_widget_get_enabled },
    { "command", l_widget_command },
    { "_send_message", l_widget_send_message },
    { "is_alive", l_widget_is_alive },
    { "redraw", l_widget_redraw },
    { "focus", l_widget_focus },
    { "get_canvas", l_widget_get_canvas },
    { "set_pos_flags", l_widget_set_pos_flags },
    { "_destroy", l_widget_destroy },
    { NULL, NULL }
};
/* *INDENT-ON* */

/* ------------------------------- Button --------------------------------- */

/*
 * For every widget type we define a LUA_TO_XYZ() macro.
 *
 * We could do 'luaUI_check_widget_ex(L, i, FALSE, "Xyz")' here instead to
 * make it type-safe, but then it'd be less efficient. We're using this
 * macro to read 'self' and it can be the wrong type only if the user
 * consciously tries to be a wise guy. It's his own responsibility then.
 *
 * EDIT: Well, there's no real performance penalty when using
 * luaUI_check_widget_ex(). We probably ought to make
 * widget->scripting_class_name an integer anyway.
 */
#define LUA_TO_BUTTON(L, i) (BUTTON (luaUI_check_widget (L, i)))

/**
 * Button widget.
 *
 * There are two ways to make a button do something: either by using the
 * @{button.result|result} property, or by using the @{button:on_click|on_click}
 * handler.
 *
 * @section button
 */

/**
 * Click handler.
 *
 * Called when a button is "clicked"; that is, activated.
 *
 *    btn.on_click = function()
 *      alert(T"hi there!")
 *    end
 *
 * Info: The name of this handler isn't very accurate. It's actually seldom
 * that users _click_ the mouse in a console application. The name was borrowed
 * from the JavaScript world to make most programmers feel "at home," and
 * to make code snippets more self-documented. It was felt that the
 * benefits outweigh the negatives.
 *
 * You may, of course, @{dialog:close|close} the dialog from the handler:
 *
 *    btn.on_click = function(self)
 *      alert(T"hi there!")
 *      self.dialog:close()
 *    end
 *
 * Often, however, using the @{button.result|result} property is shorter:
 *
 *    local btn = ui.Button{T"Show greeting", result="greet"}
 *    dlg:add(btn)
 *
 *    if dlg:run() == "greet" then
 *      alert(T"hi there!")
 *    end
 *
 * @method button:on_click
 * @args (self)
 * @callback
 */
static int
btn_callback (struct WButton *button, int action)
{
    (void) action;

    /* We send the button a generic "_action" ping and let the Lua side decide
     * on the "pretty" name to invoke (e.g., "on_click" or some alias). Our
     * philosophy is to delegate as many decisions as possible to the Lua side. */
    call_widget_method (WIDGET (button), "_action", 0, NULL);

    return 0;                   /* Don't close the dialog. If the programmer wants to, she can call dlg:close(). */
}

static Widget *
button_constructor (void)
{
    return WIDGET (button_new (5, 5, B_USER /* isn't used */ , NORMAL_BUTTON,
                               NULL, btn_callback));
}

static int
l_button_new (lua_State * L)
{
    luaUI_push_widget (L, button_constructor (), FALSE);
    return 1;
}

/**
 * The label shown on the button.
 * @attr button.text
 * @property rw
 */
static int
l_button_set_text (lua_State * L)
{
    button_set_text (LUA_TO_BUTTON (L, 1), luaL_checkstring (L, 2));
    return 0;
}

static int
l_button_get_text (lua_State * L)
{
    /* @FIXME: no reason for button_get_text() to return const! */
    luaMC_pushstring_and_free (L, const_cast (char *, button_get_text (LUA_TO_BUTTON (L, 1))));
    return 1;
}

/**
 * The type of the button.
 *
 * Possible types: "normal", "default", "narrow", "hidden".
 *
 * @attr button.type
 * @property w
 */
static int
l_button_set_type (lua_State * L)
{
    static const char *const type_names[] = {
        "hidden", "narrow", "normal", "default", NULL
    };
    static const int type_values[] = {
        HIDDEN_BUTTON, NARROW_BUTTON, NORMAL_BUTTON, DEFPUSH_BUTTON
    };

    WButton *btn;

    btn = LUA_TO_BUTTON (L, 1);

    btn->flags = luaMC_checkoption (L, 2, NULL, type_names, type_values);

    /* We re-set the label so the button's size gets calculated anew. */
    lua_settop (L, 1);
    l_button_get_text (L);
    l_button_set_text (L);

    return 0;
}

/* *INDENT-OFF* */
static const struct luaL_Reg ui_button_static_lib[] = {
    { "_new", l_button_new },
    { NULL, NULL }
};

static const struct luaL_Reg ui_button_methods_lib[] = {
    { "set_text", l_button_set_text },
    { "get_text", l_button_get_text },
    { "set_type", l_button_set_type },
    { NULL, NULL }
};
/* *INDENT-ON* */

/* ------------------------------ Checkbox -------------------------------- */

#define LUA_TO_CHECKBOX(L, i) (CHECK (luaUI_check_widget (L, i)))

/**
 * Checkbox widget.
 * @section checkbox
 */

static Widget *
checkbox_constructor (void)
{
    return WIDGET (check_new (5, 5, 0, NULL));
}

static int
l_checkbox_new (lua_State * L)
{
    luaUI_push_widget (L, checkbox_constructor (), FALSE);
    return 1;
}

/**
 * The state of the checkbox.
 *
 * A checkbox is either checked or not.
 *
 * See example in @{widget.enabled}.
 *
 * @attr checkbox.checked
 * @property rw
 */
static int
l_checkbox_get_checked (lua_State * L)
{
    lua_pushboolean (L, LUA_TO_CHECKBOX (L, 1)->state & C_BOOL);
    return 1;
}

static int
l_checkbox_set_checked (lua_State * L)
{
    WCheck *chk = LUA_TO_CHECKBOX (L, 1);
    gboolean b = lua_toboolean (L, 2);

    chk->state = b ? C_BOOL : 0;

    /* @todo: use C_CHANGE? It's not used anywhere in MC, but maybe in the
       future. @FIXME: MC should have a setter for this so we won't have to
       deal with stuff like this ourselves. */

    widget_redraw (WIDGET (chk));

    return 0;
}

/**
 * The label for the checkbox.
 * @attr checkbox.text
 * @property rw
 */
static int
l_checkbox_set_text (lua_State * L)
{
    WCheck *chk = LUA_TO_CHECKBOX (L, 1);
    const char *text = luaL_checkstring (L, 2);

    /* @FIXME: MC should have a function to set (and get) a checkbox text.
     * We use an ugly hack in the meantime. */

    if (WIDGET (chk)->owner)
    {
        /* Easier to give error than to bother with this. */
        luaL_error (L, "%s", E_ ("You must set the text *before* adding the checkbox to a dialog"));
    }

    {
        WCheck *dummy_chk;

        dummy_chk = check_new (0, 0, chk->state, text);
        dummy_chk->state = chk->state;
        send_message (chk, NULL, MSG_DESTROY, 0, NULL);
        *chk = *dummy_chk;
    }

    return 0;
}

/**
 * Convert a hotkey back to a string.
 *
 * @FIXME: this should be moved to lib/widget/widget-common.c.
 */
static char *
unparse_hotkey (const hotkey_t hotkey)
{
    return g_strdup_printf ("%s%s%s%s",
                            hotkey.start,
                            hotkey.hotkey ? "&" : "",
                            hotkey.hotkey ? hotkey.hotkey : "", hotkey.end ? hotkey.end : "");
}

static int
l_checkbox_get_text (lua_State * L)
{
    WCheck *chk = LUA_TO_CHECKBOX (L, 1);

    luaMC_pushstring_and_free (L, unparse_hotkey (chk->text));
    return 1;
}

/**
 * Change handler.
 *
 * Called when the user changes the state of a checkbox.
 *
 * @method checkbox:on_change
 * @args (self)
 * @callback
 */

/* *INDENT-OFF* */
static const struct luaL_Reg ui_checkbox_static_lib[] = {
    { "_new", l_checkbox_new },
    { NULL, NULL }
};

static const struct luaL_Reg ui_checkbox_methods_lib[] = {
    { "get_checked", l_checkbox_get_checked },
    { "set_checked", l_checkbox_set_checked },
    { "set_text", l_checkbox_set_text },
    { "get_text", l_checkbox_get_text },
    { NULL, NULL }
};
/* *INDENT-ON* */

/* ------------------------------- Label ---------------------------------- */

#define LUA_TO_LABEL(L, i) (LABEL (luaUI_check_widget (L, i)))

/**
 * Label widget.
 * @section label
 */

static Widget *
label_constructor (void)
{
    return WIDGET (label_new (0, 0, NULL));
}

static int
l_label_new (lua_State * L)
{
    luaUI_push_widget (L, label_constructor (), FALSE);
    return 1;
}

/**
 * The text displayed in the label.
 *
 * Note-short: If you wish to change this property after creation, see
 * discussion at @{label.auto_size}.
 *
 * @attr label.text
 * @property rw
 */
static int
l_label_set_text (lua_State * L)
{
    label_set_text (LUA_TO_LABEL (L, 1), luaL_checkstring (L, 2));
    return 0;
}

static int
l_label_get_text (lua_State * L)
{
    lua_pushstring (L, LUA_TO_LABEL (L, 1)->text);
    return 1;
}

/**
 * Whether the text decides the size of the widget.
 *
 * Normally, setting the @{label.text} property sets the size of the label widget.
 * When creating a label that shows a fixed string, this is what you what.
 * If your label changes its text after creation, however, you want to
 * turn off this feature so that the label doesn't paint over neighboring
 * widgets.
 *
 * `auto_size` is initially **true**. Set it to **false** to disable it; you'll
 * also want to set @{cols} explicitly to make the label wide enough to display
 * the bulk of its text, and/or to set @{expandx} to **true**.
 *
 *    local function test()
 *      local lst = ui.Listbox {items={"one", "two",
 *                               "a very loooooong string"}}
 *      local lbl = ui.Label {cols=20, auto_size=false}
 *
 *      lst.on_change = function()
 *        lbl.text = lst.value
 *      end
 *
 *      ui.Dialog():add(ui.Groupbox():add(lst), lbl):run()
 *    end
 *
 * See another example in @{git:ui_filechooser.mcs}.
 *
 * @attr label.auto_size
 * @property w
 */
static int
l_set_auto_size (lua_State * L)
{
    /* Note: 'auto_adjust_cols' is a misnomer: rows are changed as well. */
    LUA_TO_LABEL (L, 1)->auto_adjust_cols = lua_toboolean (L, 2);
    return 0;
}

/* *INDENT-OFF* */
static const struct luaL_Reg ui_label_static_lib[] = {
    { "_new", l_label_new },
    { NULL, NULL }
};

static const struct luaL_Reg ui_label_methods_lib[] = {
    { "set_text", l_label_set_text },
    { "get_text", l_label_get_text },
    { "set_auto_size", l_set_auto_size },
    { NULL, NULL }
};
/* *INDENT-ON* */

/* ------------------------------- Input ---------------------------------- */

#define LUA_TO_INPUT(L, i) (INPUT (luaUI_check_widget (L, i)))

/**
 * Input widget.
 * @section input
 */

static Widget *
input_constructor (void)
{
    return WIDGET (input_new (0, 0, input_colors, 10, NULL, NULL, INPUT_COMPLETE_NONE));
}

static int
l_input_new (lua_State * L)
{
    luaUI_push_widget (L, input_constructor (), FALSE);
    return 1;
}

/**
 * The text being edited.
 * @attr input.text
 * @property rw
 */
static int
l_input_get_text (lua_State * L)
{
    WInput *ipt = LUA_TO_INPUT (L, 1);

    if ((ipt->completion_flags & INPUT_COMPLETE_CD) != 0)
    {
        /* Idea stolen from lib/widget/quick.c. But since completion isn't
         * currently enabled (we do INPUT_COMPLETE_NONE), this is dead
         * code. Remove? */
        luaMC_pushstring_and_free (L, tilde_expand (ipt->buffer));
    }
    else
    {
        lua_pushstring (L, ipt->buffer);
    }

    return 1;
}

static int
l_input_set_text (lua_State * L)
{
    WInput *ipt = LUA_TO_INPUT (L, 1);
    const char *text = luaL_checkstring (L, 2);

    gboolean first;

    first = ipt->first;

    /* @FIXME: input_assign_text() doesn't reset the left-most column shown.
     * So we do it ourselves. It may not be necessary, but it won't hurt. */
    ipt->term_first_shown = 0;

    input_assign_text (ipt, text);

    /* @FIXME: input_assign_text() clears in->first. We restore its value: */
    ipt->first = first;

    return 0;
}

static int
l_input_set_cols (lua_State * L)
{
    Widget *w = WIDGET (LUA_TO_INPUT (L, 1));
    int cols = luaL_checkint (L, 2);

    /* Trigger update of internal variables of input line (done by its
     * MSG_RESIZE). We follow lib/widget/quick.c's example here. */
    widget_set_size (w, w->y, w->x, w->lines, cols);

    return 0;
}

/**
 * Inserts text at the cursor location.
 *
 *    -- Insert the current date and time into any input line.
 *    ui.Input.bind("C-y", function(ipt)
 *      ipt:insert(os.date("%Y-%m-%d %H:%M:%S"))
 *    end)
 *
 * @method input:insert
 * @args (s)
 */
static int
l_input_insert (lua_State * L)
{
    WInput *ipt = LUA_TO_INPUT (L, 1);
    const char *text = luaL_checkstring (L, 2);

    input_insert (ipt, text, FALSE);
    return 0;
}

/**
 * Whether to mask the input.
 *
 * If you're inputting a password, set this property to **true** to show
 * asterisks instead of the actual text.
 *
 *    -- Toggle masking for the current input field.
 *    ui.Input.bind('C-r', function(ipt)
 *      ipt.password = not ipt.password
 *    end)
 *
 * @attr input.password
 * @property rw
 */
static int
l_input_set_password (lua_State * L)
{
    WInput *ipt = LUA_TO_INPUT (L, 1);
    gboolean b = lua_toboolean (L, 2);

    ipt->is_password = b;

    widget_redraw (WIDGET (ipt));
    return 0;
}

static int
l_input_get_password (lua_State * L)
{
    lua_pushboolean (L, LUA_TO_INPUT (L, 1)->is_password);
    return 1;
}

/**
 * The cursor position.
 *
 * @attr input.cursor_offs
 * @property rw
 */
static int
l_input_set_cursor_offs (lua_State * L)
{
    WInput *ipt = LUA_TO_INPUT (L, 1);
    int pos = luaL_checkint (L, 2);

    input_set_point (ipt, pos - 1);
    return 0;
}

static int
l_input_get_cursor_offs (lua_State * L)
{
    lua_pushinteger (L, LUA_TO_INPUT (L, 1)->point + 1);
    return 1;
}

/**
 * The "mark" position.
 *
 * The "mark" is the point where the selection starts. If there's no
 * selction active, it equals **nil**.
 *
 * @attr input.mark
 * @property rw
 */
static int
l_input_set_mark (lua_State * L)
{
    WInput *ipt = LUA_TO_INPUT (L, 1);
    int pos = luaL_optint (L, 2, -1);

    if (pos != -1)
        ipt->mark = pos - 1;
    else
        ipt->mark = -1;

    widget_redraw (WIDGET (ipt));
    return 0;
}

static int
l_input_get_mark (lua_State * L)
{
    WInput *ipt = LUA_TO_INPUT (L, 1);

    if (ipt->mark >= 0)
        lua_pushinteger (L, ipt->mark + 1);
    else
        lua_pushnil (L);

    return 1;
}

/**
 * The history bin.
 *
 * It is a string naming the bin. (As this string isn't for human consumption,
 * you don't need to wrap it in @{locale.T|T}.)
 *
 *    local expr = ui.Input{history="calculator-expression"}
 *
 * @attr input.history
 * @property w
 */
static int
l_input_set_history (lua_State * L)
{
    WInput *ipt = LUA_TO_INPUT (L, 1);
    const char *histname = luaL_checkstring (L, 2);

    if (WIDGET (ipt)->owner)
    {
        /* The history is loaded in dlg_init() */
        luaL_error (L, "%s",
                    E_ ("You must set the history *before* adding the widget to a dialog"));
    }

    if ((histname != NULL) && (*histname != '\0'))
        ipt->history.name = g_strdup (histname);

    return 0;
}

/* *INDENT-OFF* */
static const struct luaL_Reg ui_input_static_lib[] = {
    { "_new", l_input_new },
    { NULL, NULL }
};

static const struct luaL_Reg ui_input_methods_lib[] = {
    { "insert", l_input_insert },
    { "set_cols", l_input_set_cols },
    { "set_text", l_input_set_text },
    { "get_text", l_input_get_text },
    { "set_cursor_offs", l_input_set_cursor_offs },
    { "get_cursor_offs", l_input_get_cursor_offs },
    { "set_mark", l_input_set_mark },
    { "get_mark", l_input_get_mark },
    { "set_password", l_input_set_password },
    { "get_password", l_input_get_password },
    { "set_history", l_input_set_history },
    { NULL, NULL }
};
/* *INDENT-ON* */

/* ------------------------------ Groupbox -------------------------------- */

#define LUA_TO_GROUPBOX(L, i) (GROUPBOX (luaUI_check_widget (L, i)))

/**
 * Groupbox widget.
 *
 * A Groupbox is a @{~#containers|container} that draws a frame around its
 * child widgets. You add widgets to it using its @{add|:add()} method. You
 * can even add child groupboxes to it.
 *
 * See example in @{git:ui_groupboxes.mcs}.
 *
 * @section groupbox
 */

static Widget *
groupbox_constructor (void)
{
    return WIDGET (groupbox_new (0, 0, 5, 40, NULL));
}

static int
l_groupbox_new (lua_State * L)
{
    luaUI_push_widget (L, groupbox_constructor (), FALSE);
    return 1;
}

/**
 * Caption.
 *
 * Caption to print on the groupbox's frame.
 *
 * @attr groupbox.text
 * @property rw
 */

static int
l_groupbox_set_text (lua_State * L)
{
    groupbox_set_title (LUA_TO_GROUPBOX (L, 1), luaL_checkstring (L, 2));
    return 0;
}

static int
l_groupbox_get_text (lua_State * L)
{
    lua_pushstring (L, LUA_TO_GROUPBOX (L, 1)->title);
    return 1;
}

/* *INDENT-OFF* */
static const struct luaL_Reg ui_groupbox_static_lib[] = {
    { "_new", l_groupbox_new },
    { NULL, NULL }
};

static const struct luaL_Reg ui_groupbox_methods_lib[] = {
    { "set_text", l_groupbox_set_text },
    { "get_text", l_groupbox_get_text },
    { NULL, NULL }
};
/* *INDENT-ON* */

/* ------------------------------ Listbox --------------------------------- */

#define LUA_TO_LISTBOX(L, i) (LISTBOX (luaUI_check_widget (L, i)))

/**
 * Listbox widget.
 *
 * A listbox dimensions by default are 12 characters wide (@{cols}) and 6
 * lines high (@{rows}). By default `expandx=true` so the width will
 * stretch. You may change all this by modifying these properties (and
 * `expandy`). There's also @{widest_item|:widest_item()} to your help.
 *
 * [tip]
 *
 * For _aesthetic_ reasons it's recommended that you wrap your listboxes in a
 * @{~#groupbox|groupbox}. I.e., instead of `dlg:add(lstbx)` do
 * `dlg:add(ui.Groupbox(T"Pick a word"):add(lstbx))`.
 *
 * [/tip]
 *
 * @section listbox
 */

/**
 * While working on the Listbox code you may notice several of the widget's
 * idiosyncrasies. Here are some oddities/trivia-facts of Listboxes to be
 * aware of:
 *
 * - When you select entries with the keyboard, an MSG_ACTION is fired.
 *   When you select with the mouse, *nothing* is fired.
 *
 * - Pressing a hotkey: a callback is called. By default: the dialog is
 *   stopped (B_ENTER).
 *
 * - Double-clicking with the mouse: Same as pressing a hotkey.
 *
 * - When you hit ENTER and the dialog closes it's not because the Listbox
 *   asked to; it's because the dialog itself handles this key (B_ENTER).
*/

static Widget *
listbox_constructor (void)
{
    return WIDGET (listbox_new (0, 0, 6, 12, FALSE, NULL));
}

static int
l_listbox_new (lua_State * L)
{
    luaUI_push_widget (L, listbox_constructor (), FALSE);
    return 1;
}

/**
 * The index of the selected item.
 *
 * Tip-short: You may find using the `listbox.value` property easier.
 *
 * @attr listbox.selected_index
 * @property rw
 */
static int
l_listbox_set_selected_index (lua_State * L)
{
    WListbox *lst = LUA_TO_LISTBOX (L, 1);
    int index = luaL_checkint (L, 2);

    listbox_select_entry (lst, index - 1);
    widget_redraw (WIDGET (lst));
    return 0;
}

static int
l_listbox_get_selected_index (lua_State * L)
{
    WListbox *lst = LUA_TO_LISTBOX (L, 1);

    lua_pushinteger (L, lst->pos + 1);
    return 1;
}


typedef void (*item_processor) (void *data, const char *label, long keycode);

/**
 * Traverses a Lua list of Listbox items and (usually) feed them into the C widget.
 */
static void
process_list (lua_State * L, item_processor f, void *data)
{
    const int LST_IDX = 2;      /* The position of the list in the stack. */
    int len, i;

    LUAMC_GUARD (L);

    len = lua_rawlen (L, LST_IDX);

    for (i = 1; i <= len; i++)
    {
        lua_rawgeti (L, LST_IDX, i);

        if (lua_isstring (L, -1))
        {
            /* The item is of the simplest form. */
            if (f)
                f (data, lua_tostring (L, -1), 0);
            lua_pop (L, 1);
        }
        else if (lua_istable (L, -1))
        {
            /* The item is of the the form {"Label", value="value", hotkey="C-p"} */
            const char *label;
            long keycode;

            lua_rawgeti (L, -1, 1);
            if (!lua_isstring (L, -1))
                luaL_error (L,
                            E_
                            ("Invalid element of list at index %d: string expected as first element of table."),
                            i);
            label = lua_tostring (L, -1);

            lua_getfield (L, -2, "hotkey");
            if (!lua_isnil (L, -1))
                keycode = luaTTY_check_keycode (L, -1, FALSE);
            else
                keycode = 0;

            if (f)
                f (data, label, keycode);

            lua_pop (L, 3);     /* Pop the label, the hotkey, and the element's table itself. */
        }
        else
        {
            luaL_error (L,
                        E_
                        ("Invalid element type of list at index %d: either string or table expected."),
                        i);
        }
    }

    LUAMC_UNGUARD (L);
}

static void
add_to_listbox (void *data, const char *label, long keycode)
{
    WListbox *lst = LISTBOX (data);

    listbox_add_item (lst, LISTBOX_APPEND_AT_END, keycode, label, NULL);
}

/**
 * The listbox items.
 *
 * In its simplest form, each item is a string:
 *
 *    lstbx.items = {
 *      'apple',
 *      'banana',
 *      'water melon',
 *    }
 *
 * Alternatively, any item may be a list whose first element is the string,
 * plus two optional keyed elements: **value** and **hotkey**. The string
 * is meant for humans whereas the **value** is what your program actually
 * sees. This **value** can be any complex object; not just strings or
 * numbers. The **hotkey**, if exists, lets you select the associated item
 * and close the dialog by pressing a key.
 *
 *    local lstbx = ui.Listbox()
 *
 *    lstbx.items = {
 *      { T'Read only', value='r' },
 *      { T'Write only', value='w' },
 *      { T'Read/write', value='r+', hotkey='C-b' },
 *    }
 *
 *    if ui.Dialog():add(lstbx):run() then
 *      local f = assert( fs.open('/etc/passwd', lstbx.value) )
 *      -- ...
 *    end
 *
 * Tip-short: An alternative to using **hotkey** elements is using @{dialog:on_key}.
 *
 * @attr listbox.items
 * @property rw
 */
static int
l_listbox_set_items (lua_State * L)
{
    WListbox *lst = LUA_TO_LISTBOX (L, 1);

    luaL_checktype (L, 2, LUA_TTABLE);
    listbox_remove_list (lst);
    process_list (L, add_to_listbox, lst);

    /* The 'value' keys in the Lua table can't be represented in the
     * C widget, so we store the Lua table too. */
    luaMC_rawsetfield (L, 1, "_items");

    widget_redraw (WIDGET (lst));
    return 0;
}

static int
l_listbox_get_items (lua_State * L)
{
    WListbox *lst = LUA_TO_LISTBOX (L, 1);

    luaMC_rawgetfield (L, 1, "_items");

    /* Listboxes created in C don't have the _items shadow property,
     * and for them we need to work harder.
     *
     * We can be lazy and return an empty list for them, but then we
     * won't be able to implement Lua utilities like find-as-you-type,
     * which should work no matter how a listbox was created.
     */
    if (lua_isnil (L, -1))
    {
        GList *le;
        int i;

        lua_newtable (L);

        for (i = 1, le = listbox_get_first_link (lst); le != NULL; i++, le = g_list_next (le))
        {
            WLEntry *e = LENTRY (le->data);
            lua_pushstring (L, e->text);
            lua_rawseti (L, -2, i);
        }
    }

    return 1;
}

/**
 * Change handler.
 *
 * Called when the user changes the selection in the listbox.
 *
 * See example in @{git:ui_filechooser.mcs}.
 *
 * @method listbox:on_change
 * @args (self)
 * @callback
 */

/* *INDENT-OFF* */
static const struct luaL_Reg ui_listbox_static_lib[] = {
    { "_new", l_listbox_new },
    { NULL, NULL }
};

static const struct luaL_Reg ui_listbox_methods_lib[] = {
    { "set_items", l_listbox_set_items },
    { "get_items", l_listbox_get_items },
    { "set_selected_index", l_listbox_set_selected_index },
    { "get_selected_index", l_listbox_get_selected_index },
    { NULL, NULL }
};
/* *INDENT-ON* */

/* ------------------------------- Radio ---------------------------------- */

#define LUA_TO_RADIOS(L, i) (RADIO (luaUI_check_widget (L, i)))

/**
 * Radios widget.
 *
 * The radios widget, for the sake of convenience, shares the same API with
 * the @{~#listbox|listbox widget}.
 *
 * @section radios
 */

static Widget *
radios_constructor (void)
{
    return WIDGET (radio_new (0, 0, 0, NULL));
}

static int
l_radios_new (lua_State * L)
{
    luaUI_push_widget (L, radios_constructor (), FALSE);
    return 1;
}

/**
 * The radio items.
 *
 * Everything discussed at @{listbox.items} applies here as well except that
 * a **hokey** element for an item has no effect on radios.
 *
 * @attr radios.items
 * @property rw
 */

/**
 * @FIXME: A radios widget, unlike a listbox widget, doesn't have a function
 * for setting its items. Until this is fixed we resort to a dirty hack.
 */
static void
set_radios_items (WRadio * rad, const char **items, int items_count)
{
    WRadio *rad_dummy;

    rad_dummy = radio_new (0, 0, items_count, items);

    /* The dimensions of the dummy are now the ones we want. */
    WIDGET (rad)->cols = WIDGET (rad_dummy)->cols;
    WIDGET (rad)->lines = WIDGET (rad_dummy)->lines;

    *WIDGET (rad_dummy) = *WIDGET (rad);

    /* Free the old items. */
    send_message (rad, NULL, MSG_DESTROY, 0, NULL);

    *rad = *rad_dummy;

    g_free (rad_dummy);
}

static void
radios__add_to_array (void *data, const char *label, long keycode)
{
    GPtrArray *items = data;
    (void) keycode;

    g_ptr_array_add (items, g_strdup (label));
}

static int
l_radios_set_items (lua_State * L)
{
    WRadio *rad = LUA_TO_RADIOS (L, 1);
    GPtrArray *items;

    luaL_checktype (L, 2, LUA_TTABLE);
    luaMC_checkargcount (L, 2, TRUE);

    /* Validate the list: let exceptions abort us before we allocate memory. */
    process_list (L, NULL, NULL);

    /* Store the items in a (dynamic) C array. */
    items = g_ptr_array_new ();
    g_ptr_array_set_free_func (items, g_free);
    process_list (L, radios__add_to_array, items);

    /* Finally, set the items on the radios. */
    set_radios_items (rad, (const char **) items->pdata, items->len);

    g_ptr_array_free (items, TRUE);

    /* The 'value' keys in the Lua table can't be represented in the
     * C widget, so we store the Lua table too. */
    luaMC_rawsetfield (L, 1, "_items");

    widget_redraw (WIDGET (rad));
    return 0;
}

static int
l_radios_get_items (lua_State * L)
{
    (void) LUA_TO_RADIOS (L, 1);
    luaMC_rawgetfield (L, 1, "_items");

    /* Unlike in l_listbox_get_items(), here we don't fetch items of radios
     * created in C, as we don't currently see why it'd be useful. Feel free
     * to change this. */
    return 1;
}

/**
 * The index of the selected item.
 *
 * Tip-short: You may find using the `radios.value` property easier.
 *
 * @attr radios.selected_index
 * @property rw
 */
static int
l_radios_set_selected_index (lua_State * L)
{
    WRadio *rad = LUA_TO_RADIOS (L, 1);
    int sel = luaL_checkint (L, 2);

    rad->pos = rad->sel = sel - 1;
    widget_redraw (WIDGET (rad));

    return 0;
}

static int
l_radios_get_selected_index (lua_State * L)
{
    WRadio *rad = LUA_TO_RADIOS (L, 1);

    lua_pushinteger (L, rad->sel + 1);

    return 1;
}

/**
 * Change handler.
 *
 * Called when the user changes the selection in radio boxes.
 *
 * @method radios:on_change
 * @args (self)
 * @callback
 */

/* *INDENT-OFF* */
static const struct luaL_Reg ui_radios_static_lib[] = {
    { "_new", l_radios_new },
    { NULL, NULL }
};

static const struct luaL_Reg ui_radios_methods_lib[] = {
    { "set_items", l_radios_set_items },
    { "get_items", l_radios_get_items },
    { "set_selected_index", l_radios_set_selected_index },
    { "get_selected_index", l_radios_get_selected_index },
    { NULL, NULL }
};
/* *INDENT-ON* */

/* ------------------------------ Gauge ----------------------------------- */

#define LUA_TO_GAUGE(L, i) (GAUGE (luaUI_check_widget (L, i)))

/**
 * Gauge widget.
 *
 * A gauge, also known as a progress-bar, shows a percentage in a graphic
 * manner. The percentage is @{gauge.value|value} / @{gauge.max|max}. Typically
 * you continuously change @{gauge.value|value} to reflect the status of a task
 * carried out.
 *
 * The @{cols} property (the gauge's size) is 25 characters by default. You
 * may change this and/or use `expandx=true`.
 *
 * @section gauge
 */

static Widget *
gauge_constructor (void)
{
    return WIDGET (gauge_new (0, 0, 25, TRUE, 100, 0));
}

static int
l_gauge_new (lua_State * L)
{
    luaUI_push_widget (L, gauge_constructor (), FALSE);
    return 1;
}

/**
 * The current value.
 *
 * As your task progresses, you'd update this property to anything between
 * 0 and @{gauge.max|max}. It is allowed for it to exceed @{gauge.max|max}
 * (in which case it'd be treated as if it were equal to @{gauge.max|max}).
 *
 * Note: You'll usually have to call @{dialog:refresh} to see the gauge
 * updated on the screen, because screen refresh is only done automatically
 * @{~mod:tty#drawing|when} a keyboard or mouse event is handled, something
 * which probably doesn't happen in your loop.
 *
 * See example at @{dialog:on_idle}.
 *
 * @attr gauge.value
 * @property rw
 */
static int
l_gauge_set_value (lua_State * L)
{
    WGauge *g = LUA_TO_GAUGE (L, 1);
    /* Note: We use checknumber, not checkinteger! It's very likely we'll
     * be fed a floating-point number and we don't want Lua 5.3 to raise
     * an exception. */
    int value = luaL_checknumber (L, 2);

    gauge_set_value (g, g->max, value);
    return 0;
}

static int
l_gauge_get_value (lua_State * L)
{
    lua_pushinteger (L, LUA_TO_GAUGE (L, 1)->current);
    return 1;
}

/**
 * The maximal value.
 *
 * This number is the 100% value. By default this is 100. You may
 * change it if you think it'd make your calculations easier.
 *
 * Note: This number, as well as @{gauge.value|value}, is stored internally
 * as C-language's `int`. Therefore setting @{gauge.max|max} to 1.0 and
 * moving @{gauge.value|value} from 0.0 to 0.1 to 0.2 ... to 1.0 won't
 * quite work.
 *
 * @attr gauge.max
 * @property rw
 */
static int
l_gauge_set_max (lua_State * L)
{
    WGauge *g = LUA_TO_GAUGE (L, 1);
    /* See explanation at l_gauge_set_value() for why we don't use checkinteger(). */
    int max = luaL_checknumber (L, 2);

    gauge_set_value (g, max, g->current);
    return 0;
}

static int
l_gauge_get_max (lua_State * L)
{
    lua_pushinteger (L, LUA_TO_GAUGE (L, 1)->max);
    return 1;
}

/**
 * The visibility of the gauge.
 *
 * Whether the gauge is shown or not. A gauge that is not shown still consumes
 * space on the screen. You'd use this property when, for example, you wish to
 * show the gauge only when some process is running.
 *
 * A gauge is shown by default.
 *
 * @attr gauge.shown
 * @property rw
 */
static int
l_gauge_set_shown (lua_State * L)
{
    gauge_show (LUA_TO_GAUGE (L, 1), lua_toboolean (L, 2));
    return 0;
}

static int
l_gauge_get_shown (lua_State * L)
{
    lua_pushboolean (L, LUA_TO_GAUGE (L, 1)->shown);
    return 1;
}

/* *INDENT-OFF* */
static const struct luaL_Reg ui_gauge_static_lib[] = {
    { "_new", l_gauge_new },
    { NULL, NULL }
};

static const struct luaL_Reg ui_gauge_methods_lib[] = {
    { "set_value", l_gauge_set_value },
    { "get_value", l_gauge_get_value },
    { "set_max", l_gauge_set_max },
    { "get_max", l_gauge_get_max },
    { "set_shown", l_gauge_set_shown },
    { "get_shown", l_gauge_get_shown },
    { NULL, NULL }
};
/* *INDENT-ON* */

/* ------------------------------ HLine ----------------------------------- */

#define LUA_TO_HLINE(L, i) (HLINE (luaUI_check_widget (L, i)))

/**
 * HLine widget.
 *
 * An HLine widget is simply a horizontal line, possibly with text on it.
 * It's similar to HTML's `<hr>` element. You can use it to separate
 * sections in a dialog.
 *
 * See also @{ZLine}, which looks nicer.
 *
 * @section hline
 */

static Widget *
hline_constructor (void)
{
    return WIDGET (hline_new (0, 0, 5));
}

static int
l_hline_new (lua_State * L)
{
    luaUI_push_widget (L, hline_constructor (), FALSE);
    return 1;
}

static int
l_hline_set_through (lua_State * L)
{
    LUA_TO_HLINE (L, 1)->auto_adjust_cols = lua_toboolean (L, 2);
    return 0;
}

/**
 * Optional caption.
 *
 * Text to print centered on the line.
  *
 * @attr hline.text
 * @property rw
 */
static int
l_hline_set_text (lua_State * L)
{
    hline_set_text (LUA_TO_HLINE (L, 1), luaL_checkstring (L, 2));
    return 0;
}

static int
l_hline_get_text (lua_State * L)
{
    lua_pushstring (L, LUA_TO_HLINE (L, 1)->text);
    return 1;
}

/* *INDENT-OFF* */
static const struct luaL_Reg ui_hline_static_lib[] = {
    { "_new", l_hline_new },
    { NULL, NULL }
};

static const struct luaL_Reg ui_hline_methods_lib[] = {
    { "set_through", l_hline_set_through },
    { "set_text", l_hline_set_text },
    { "get_text", l_hline_get_text },
    { NULL, NULL }
};
/* *INDENT-ON* */

/* ----------------------------- Dialog ----------------------------------- */

#define LUA_TO_DIALOG(L, i) (DIALOG (luaUI_check_widget (L, i)))

/**
 * Dialog widget.
 * @section dialog
 */

static void
init_child (void *data, void *user_data)
{
    Widget *w = data;
    (void) user_data;

    call_widget_method (w, "on_init", 0, NULL);
}

/**
 * Keypress handler.
 *
 * Lets you respond to a key before any of the child widgets sees it. Return
 * `true` from this handler to signal that you've consumed the key.
 *
 * See examples at @{ui.Custom:on_key}, which is used similarly.
 *
 * @param self The dialog
 * @param keycode A number
 *
 * @method dialog:on_key
 * @callback
 */

/**
 * Keypress handler.
 *
 * Lets you respond to a key **after** the child widgets had a chance to
 * respond to it. Return `true` from this handler to signal that you've
 * consumed the key.
 *
 * See examples at @{ui.Custom:on_key}, which is used similarly.
 *
 * Note: It happens that the system doesn't really care what you return from
 * this specific handler. But for "forward-compatibility" it won't hurt that
 * you do return `true` for keys you handled.
 *
 * @param self The dialog
 * @param keycode A number
 *
 * @method dialog:on_post_key
 * @callback
 */

/**
 * Closing validation handler.
 *
 * Lets you decide whether it's alright to close the dialog. This handler is
 * called whenever an attempt is made to close the dialog. Return `true` from
 * this handler to signal that it's alright to close the dialog; else, the
 * dialog will stay open.
 *
 *    -- Asks the user for his name and age. If the user
 *    -- omits either name or age, we nag him.
 *
 *    local function test()
 *      local dlg = ui.Dialog(T"Tell me about yourself")
 *
 *      local name = ui.Input()
 *      local age = ui.Input()
 *
 *      name.data = {
 *        required = true,
 *        errmsg = T"Missing name!",
 *      }
 *
 *      age.data = {
 *        required = true,
 *        errmsg = T"Missing age!",
 *      }
 *
 *      dlg.on_validate = function()
 *        if dlg.result then  -- We validate the input only if the
 *                            -- user pressed some positive button.
 *                            -- This excludes ESC and "Cancel".
 *          for widget in dlg:gmatch() do
 *            if widget.data and widget.data.required
 *                and widget.text == ""
 *            then
 *              alert(widget.data.errmsg)
 *              widget:focus()  -- Move user to the rogue widget.
 *              return false    -- Don't let user close the dialog.
 *            end
 *          end
 *        end
 *        return true -- Allow closing.
 *      end
 *
 *      dlg:add(
 *        ui.HBox():add(ui.Label(T"Name:"), name),
 *        ui.HBox():add(ui.Label(T"Age:"), age),
 *        ui.DefaultButtons()
 *      )
 *
 *      dlg:run()
 *    end
 *
 * Info: If the user is exiting MC, and the dialog is modaless, the dialog will
 * get closed anyway.
 *
 * Info: A special case: on_validate has no effect when you close the dialog from
 * @{on_idle} (see @{git:dialog.c|dialog.c:frontend_dlg_run}).
 *
 * @method dialog:on_validate
 * @args (self)
 * @callback
 */

/**
 * Initialization handler.
 *
 * Called just before a dialog becomes @{state|active}.
 *
 * See usage example at @{widget:focus}.
 *
 * Note: when this handler is called the dialog isn't yet considered
 * @{state|active}. This means that some operations on the dialog, like
 * drawing it on screen or closing it, can't be done yet. If
 * you do need such operations, put your code in @{on_idle} instead (and
 * in it also set the handler to `nil` so it'd run only once).
 *
 * @method dialog:on_init
 * @args (self)
 * @callback
 */

/**
 * Resize handler.
 *
 * Called when the screen changes its size.
 *
 * Normally you don't need to implement this handler: The default handler
 * does an adequate job: it will re-center the dialog on the screen (unless
 * it has figured out, by noticing that you've called @{set_dimensions}
 * earlier, that it's not what you want).
 *
 * You may implement this handler if you need to do some custom positioning.
 * For example, here's how to keep a dialog a fixed distance from the screen
 * edges, similar to how the "Directory hotlist" behaves:
 *
 *     local dlg = ui.Dialog()
 *
 *     dlg.on_resize = function(self)
 *       self:set_dimensions(nil, nil, tty.get_cols() - 10, tty.get_rows() - 2)
 *     end
 *
 *     dlg:on_resize() -- We have to call this explicitly in the beginning,
 *                     -- as it only gets called when the screen changes size.
 *     dlg:run()
 *
 * @method dialog:on_resize
 * @args (self)
 * @callback
 */

/**
 * Frame drawing handler.
 *
 * Called to draw the background and frame of the dialog.
 *
 * You should return **true** from this handler to signal that you've done the
 * job or else the default frame will then be drawn, overwriting yours.
 *
 * Note: You wouldn't normally be interested in this handler. It is only useful
 * for special applications (e.g., for drawing a @{git:mcscript.lua|wallpaper};
 * although this is alternatively possible by adding a @{ui.Custom} to the
 * dialog).
 *
 * @method dialog:on_draw
 * @args (self)
 * @callback
 */
static cb_ret_t
ui_dialog_callback (Widget * w, Widget * sender, widget_msg_t msg, int parm, void *data)
{
    switch (msg)
    {
    case MSG_INIT:
        {
            call_widget_method (w, "on_init", 0, NULL);
            /* Undocumented feature: we also send on_init event to child widgets: */
            g_list_foreach (DIALOG (w)->widgets, init_child, NULL);
            return MSG_HANDLED;
        }

    case MSG_RESIZE:
        {
            call_widget_method (w, "on_resize", 0, NULL);
            return MSG_HANDLED;
        }

    case MSG_IDLE:
        {
            gboolean action_found;

            call_widget_method (w, "on_idle__real", 0, &action_found);
            return action_found ? MSG_HANDLED : MSG_NOT_HANDLED;
        }

    case MSG_POST_KEY:
        {
            Widget *current = mc_lua_current_widget (DIALOG (w));

            if (current)
            {
                /* Undocumented feature: normal widgets get on_post_key()
                 * event too. Currently the only place we use it is to
                 * simulate an on_change event for Input widget. */
                call_widget_method (current, "on_post_key", 0, NULL);
            }

            lua_pushinteger (Lg, parm);
            return call_widget_method (w, "on_post_key", 1, NULL);
        }

    case MSG_KEY:
        {
            lua_pushinteger (Lg, parm);
            return call_widget_method (w, "on_key", 1, NULL);
        }

    case MSG_ACTION:
        if (sender != NULL)
        {
            gboolean action_found;

            /**
             * The value of a checkbox or listbox has been modified.
             *
             * We send the widget a generic "_action" ping and let the Lua
             * side decide on the "pretty" name to invoke (e.g., on_change,
             * on_click, etc.)
             *
             * (Note: Button widgets aren't handled here: they have their own
             * callback.)
             */
            call_widget_method (sender, "_action", 0, &action_found);
            if (action_found)
                return MSG_HANDLED;
        }
        else
        {
            if (parm == CK_Cancel)
            {
                /* We notify the dialog when the user "cancels" it. We ignore the
                 * returned value: if the programmer wants to abort the closing,
                 * she can do that using on_validate. Currently, the Lua side of
                 * the UI module uses this event internally, so we don't document
                 * it to the end user. */
                call_widget_method (w, "on_cancel", 0, NULL);
            }
        }
        return MSG_NOT_HANDLED;

    case MSG_VALIDATE:
        {
            WDialog *dlg = DIALOG (w);
            gboolean action_found, ok_to_close;
            dlg_state_t old_state;

            /* At this point the dialog is DLG_CLOSED. This may cause an
             * aesthetic problem: if the on_validate handler shows an alert(),
             * dismissing this alert() won't repaint our dialog. So we
             * temporarily activate the dialog. */
            old_state = dlg->state;
            dlg->state = DLG_ACTIVE;

            ok_to_close = (call_widget_method (w, "on_validate", 0, &action_found) == MSG_HANDLED);

            if (action_found)
                dlg->state = ok_to_close ? DLG_CLOSED : DLG_ACTIVE;
            else
                dlg->state = old_state;

            if (mc_global.midnight_shutdown)
            {
                /* See editcmd.c:edit_ok_to_exit():
                 *
                 * We can't cancel a shutdown: the only question a dialog can
                 * ask is "Save changes? Y/N", not "Save changes? Y/N/C".
                 */
                /* message (D_NORMAL, "Debug", "MC is exiting. I'm closing this modaless dialog anyway."); */
                DIALOG (w)->state = DLG_CLOSED;
            }

            return MSG_HANDLED;
        }

    case MSG_DRAW:
        {
            if (call_widget_method (w, "on_draw", 0, NULL) == MSG_HANDLED)
                return MSG_HANDLED;
            /* Else we fall through to 'default:' ! */
        }

    default:
        return dlg_default_callback (w, sender, msg, parm, data);
    }
}

/**
 * Title handler.
 *
 * Called to generate a modaless dialog's title. It's not used
 * for modal dialogs. The default handler returns the dialog's title.
 *
 *    local dlg = ui.Dialog("bobo")
 *
 *    dlg.on_title = function()
 *      return "Clock: " .. os.date()
 *    end
 *
 *    dlg.modal = false
 *
 *    dlg:add(ui.DefaultButtons())
 *    dlg:run()
 *
 * @method dialog:on_title
 * @args (self)
 * @callback
 */
static char *
dlg_title_handler (const WDialog * dlg, size_t len)
{
    char *title;
    (void) len;

    call_widget_method_ex (WIDGET (dlg), "on_title", 0, NULL, NULL, FALSE);
    title = g_strdup (lua_tostring (Lg, -1) ? lua_tostring (Lg, -1) : "");
    lua_pop (Lg, 1);

    return title;
}

static Widget *
dialog_constructor (void)
{
    /* The '-1' is a sentry value we check for on the Lua side. */
    WDialog *dlg = dlg_create (TRUE, -1, -1, 4, 4,
                               dialog_colors, ui_dialog_callback,
                               NULL, NULL, NULL, 0);
    dlg->get_title = dlg_title_handler; /* for modaless dialogs. */
    return WIDGET (dlg);
}

static int
l_dialog_new (lua_State * L)
{
    luaUI_push_widget (L, dialog_constructor (), FALSE);
    return 1;
}

/**
 * Idle handler.
 *
 * Called while there's no keyboard input.
 *
 * You may use this handler, for example, to perform one slice of a
 * lengthy task, repeatedly. This gives the impression of performing in
 * the background: the user is able to interact with the dialog between the
 * invocations of this handler.
 *
 *     ui.Panel.bind('C-q', function()
 *       local dlg = ui.Dialog()
 *       local gg = ui.Gauge()
 *       gg.max = 5000000
 *       dlg.on_idle = function()
 *         -- ... imagine we perform a slice of a lengthy calculation here ...
 *         gg.value = gg.value + 1
 *         if gg.value > gg.max then
 *           gg.value = 0
 *         end
 *         dlg:refresh()  -- We have to refresh the terminal ourselves.
 *       end
 *       dlg:add(gg)
 *       dlg:add(ui.DefaultButtons())
 *       dlg:run()
 *     end)
 *
 * Comments:
 *
 * - If it happens that you no longer need this handler, set it to `nil` so it
 *   won't get invoked and waste CPU cycles.
 *
 * - A alternative to @{on_idle} is to use the @{timer}. But you can't quite
 *   close a dialog (if you need to) from a timed function (because right
 *   after MC executes the timers it waits for a key (see @{git:tty/key.c|tty/key.c:tty_get_event}),
 *   even if the dialog is closed), which is something you *can* do from
 *   @{on_idle}.
 *
 * - If you wish to close a dialog from @{on_idle} (let's say when you finish
 *   your lengthy "background" task), you first need to set the handler to
 *   `nil` (or else MC will keep calling it, since there's still no keyboard
 *   input):
 *
 *        dlg.on_idle = function()
 *          do_a_slice_of_some_task()
 *          if task_was_completed() then
 *            dlg.on_idle = nil
 *            dlg:close()
 *          end
 *        end
 *
 * @method dialog:on_idle
 * @args (self)
 * @callback
 */

static int
l_dialog_set_on_idle (lua_State * L)
{
    widget_set_options (WIDGET (LUA_TO_DIALOG (L, 1)), W_WANT_IDLE, lua_toboolean (L, 2));
    luaMC_rawsetfield (L, 1, "on_idle__real");
    return 0;
}

static int
l_dialog_get_on_idle (lua_State * L)
{
    luaMC_rawgetfield (L, 1, "on_idle__real");
    return 1;
}

/**
 * The colors of the dialog.
 *
 * The set of colors to be used to paint the dialog and the widgets within.
 * Possible values:
 *
 *   - `"normal"`
 *   - `"alarm"` (typically red dominated, for error boxes.)
 *   - `"pmenu"` (colors of popup menus, like the "User menu".)
 *
 *
 * You'd usually set this property in the constructor call:
 *
 *    dlg = ui.Dialog{T"A frightening dialog", colorset="alarm"}
 *
 * But you can set it anytime afterwards:
 *
 *    local answer = ui.Input()
 *
 *    answer.on_change = function(self)
 *      if self.text == "" then
 *        -- Missing data.
 *        self.dialog.colorset = "alarm"
 *      else
 *        self.dialog.colorset = "normal"
 *      end
 *    end
 *
 * Note: The @{~#groupbox|groupbox} widget, and disabled widgets, don't respect
 * the dialog's colorset, unless it's `"normal"`. These are MC @{3468|bugs}
 * that should be fixed.
 *
 * @attr dialog.colorset
 * @property w
 */
static int
l_dialog_set_colorset (lua_State * L)
{
    static const char *const colorset_names[] = {
        "normal", "alarm", "pmenu", NULL
    };
    static const int *colorset_values[] = {
        dialog_colors, alarm_colors, listbox_colors
    };

    WDialog *dlg;

    dlg = LUA_TO_DIALOG (L, 1);

    dlg->color = luaMC_checkoption (L, 2, NULL, colorset_names, colorset_values);

    dlg_redraw (dlg);           /* In case the user changes the colorset of an active dialog. */

    return 0;
}

static void
add_child (Widget * w, lua_State * L)
{
    /* Note the use of the _ex() version: We also push widgets that don't
       have Lua counterparts. */
    luaUI_push_widget_ex (L, w, TRUE, TRUE);
    luaMC_raw_append (L, -2);
}

/**
 * The child widgets.
 *
 * Returns a list of all the widgets "mapped" into the dialog. Pseudo
 * widgets (those used for layout: HBox, VBox, Space) aren't included in the
 * list.
 *
 * Tip-short: @{find} and @{gmatch} are easy-to-use wrappers around this property.
 *
 * [info]
 *
 * A short explanation for the frightening word "mapped":
 *
 * When you use @{add|add()} to add a widget to a dialog, it doesn't get added
 * yet to the dialog itself but to a *layout manager*. Only when you call
 * @{run} does the layout manager physically add the widgets to the dialog.
 * The widgets are then called "mapped" (a term borrowed from Tk, which is
 * not the only toolkit to use it).
 *
 * [/info]
 *
 * @attr dialog.mapped_children
 * @property r
 */
static int
l_dialog_get_mapped_children (lua_State * L)
{
    WDialog *dlg = LUA_TO_DIALOG (L, 1);

    lua_newtable (L);
    g_list_foreach (dlg->widgets, (GFunc) add_child, L);

    return 1;
}

/**
 * A low-level function to run the dialog.
 *
 * We export it to Lua as _run(). We wrap it in a Lua version that does
 * some bookkeeping.
 */
static int
l_dialog_run (lua_State * L)
{
    WDialog *dlg;

    int result;

    dlg = LUA_TO_DIALOG (L, 1);

    /*
     * It's not allowed to not have a focus-able widget (MC will hang after
     * calling dlg_run()).
     *
     * So we search for the first focus-able. If we find none, we add a
     * dummy hidden button (a technique we learn from query_dialog().)
     *
     * The method we use to locate the focusable widget isn't optimal. The
     * proper way is to call MSG_FOCUS, but the dialog hasn't been
     * initialized yet. This work should be done by dialog.c, not by us!
     */
    dlg->current = dlg->widgets;

    while (dlg->current)
    {
        Widget *w;

        w = WIDGET (dlg->current->data);

        if (((w->options & W_DISABLED) == 0)
            && ((w->options & (W_WANT_CURSOR | W_WANT_HOTKEY)) != 0 && !is_custom (w)))
            break;

        dlg->current = g_list_next (dlg->current);
    }

    if (!dlg->current)
        add_widget (dlg, button_new (0, 0, 0, HIDDEN_BUTTON, "-", NULL));

    result = dlg_run (dlg);

    /* We aren't interested in dlg_run()'s exact result (because we manage
     * the result ourselves, form the Lua side; this gives us the advantage of
     * not being limited to 'int' results), but there's one case we have
     * to be aware of: if no widget in the dialog handles the ENTER key, the
     * dialog itself handle it to mean "successful exit" (see dlg_handle_key()).
     * See also the Lua source for Dialog:run(). */
    lua_pushboolean (L, result != B_CANCEL);

    return 1;
}

/**
 * The method that actually adds a widget to a dialog. End user won't use this
 * so we don't ldoc it.
 */
static int
l_dialog_map_widget (lua_State * L)
{
    WDialog *dlg = LUA_TO_DIALOG (L, 1);
    Widget *w = luaUI_check_widget (L, 2);

    if (w->owner)
        return luaL_error (L,
                           E_
                           ("Attempt is made to add to a dialog a widget which was already added."));

    add_widget_autopos (dlg, w, w->pos_flags, NULL);

    return 0;
}

/**
 * A method that removes a widget from a dialog. We don't use it in core. May be used
 * by advanced users.
 *
 * UNFORTUNATELY, MC's 'widget/dialog.c' doesn't have any function that merely *removes*
 * a widget form its dialog. The del_widget() we use here also *destroys* the widget.
 *
 * @FIXME:
 * Once this is fixed in MC we would export this function as dlg:unmap_widget(). In the
 * meantime we export it as dlg:_del_widget().
 */
static int
l_dialog_del_widget (lua_State * L)
{
    WDialog *dlg = LUA_TO_DIALOG (L, 1);
    Widget *w = luaUI_check_widget (L, 2);

    (void) dlg;

    if (w->owner)
    {
        /* FIXME: Once MC has widget_destroy() we would put scripting_notify_...() there
           and won't have to call it anywhere else! */
        scripting_notify_on_widget_destruction (w);
        del_widget (w);
    }

    return 0;
}

/**
 * The dialog window's title.
 *
 * @attr dialog.text
 * @property rw
 */
static int
l_dialog_set_text (lua_State * L)
{
    WDialog *dlg = LUA_TO_DIALOG (L, 1);
    const char *text = luaL_checkstring (L, 2);

    /* @FIXME: MC should have a setter for this. */
    g_free (dlg->title);
    if (*text != '\0')
        /* MC should be fixed to draw the padding spaces itself! */
        dlg->title = g_strdup_printf (" %s ", text);
    else
        dlg->title = NULL;

    return 0;
}

static int
l_dialog_get_text (lua_State * L)
{
    const char *text = LUA_TO_DIALOG (L, 1)->title;

    if (text)
        /* @FIXME: see note above about the silliness of MC's space padding. */
        lua_pushlstring (L, text + 1, strlen (text) - 2);
    else
        lua_pushliteral (L, "");

    return 1;
}

/**
 * Whether the dialog is modal or modaless.
 *
 * By default dialogs are modal: the user has to finish interacting with
 * them in order to continue. In other words, @{dialog:run} doesn't return
 * while the dialog is still open. But a dialog can also be **modaless**:
 * the user can switch to some other dialog while working with them.
 *
 * [info]
 *
 * In MC, by default, switching between modaless dialogs (sometimes called
 * "screens", or "windows") is done with the following key bindings:
 *
 * - `M-{` (command name: "ScreenPrev")
 * - `M-}` (command name: "ScreenNext")
 * - `M-[AMP]#96;` (command name: "ScreenList")
 *
 * [/info]
 *
 * To make a dialog modaless, simply set this property to **true** before
 * calling @{dialog:run}.
 *
 * [tip]
 *
 * For best *aesthetic* results, make your modaless dialogs
 * @{dialog:set_dimensions|maximized}.
 *
 * That's because MC won't paint the dialog at the background (that is,
 * the filemanager) when the need arises (see
 * @{git:lib/widget/dialog.c|lib/widget/dialog.c:dlg_redraw()}, called
 * by do_refresh(): it only paints active dialogs). This is certainly an MC bug
 * that should be fixed.
 *
 * [/tip]
 *
 * @attr dialog.modal
 * @property rw
 */
static int
l_dialog_set_modal (lua_State * L)
{
    LUA_TO_DIALOG (L, 1)->modal = lua_toboolean (L, 2);
    return 0;
}

static int
l_dialog_get_modal (lua_State * L)
{
    lua_pushboolean (L, LUA_TO_DIALOG (L, 1)->modal);
    return 1;
}

/**
 * Destroys a dialog (and all its child widgets).
 *
 * Overrides l_widget_destroy.
 *
 * End-users don't need to bother with this function, as it's called
 * automatically on GC, so we don't document it. Some savvy users, however,
 * may want to call it explicitly to have better control on memory
 * management.
 */
static int
l_dialog_destroy (lua_State * L)
{
    WDialog *dlg;

    dlg = LUA_TO_DIALOG (L, 1);

    if (dlg->state != DLG_CLOSED && dlg->state != DLG_CONSTRUCT)
    {
        /* In case a programmer tries to close a dialog by calling destroy() */
        return luaL_error (L,
                           E_
                           ("Attempt is made to destroy a dialog which isn't closed (call dialog:close() first)."));
    }
    else
    {
        dlg_destroy (dlg);
    }

    return 0;
}

/**
 * Redraws a dialog.
 *
 * You won't normally need to call this method.
 *
 * This method is similar in principle to @{widget:redraw} but works on the
 * whole dialog: the dialog draws itself (frame and background), then its
 * children. It also asks the widget in focus to reposition the cursor.
 *
 * @method dialog:redraw
 */
static int
l_dialog_redraw (lua_State * L)
{
    dlg_redraw (LUA_TO_DIALOG (L, 1));
    return 0;
}

/**
 * Positions the cursor at the focused element.
 *
 * You won't normally need to call this method.
 *
 * This method asks the widget in focus to reposition the cursor.
 *
 * As to why this method has "redraw" in its name, see the section
 * @{~mod:tty#Drawing}.
 *
 * @method dialog:redraw_cursor
 */
static int
l_dialog_redraw_cursor (lua_State * L)
{
    update_cursor (LUA_TO_DIALOG (L, 1));
    return 0;
}

/**
 * Closes a dialog. Normally you'd use this method from click handlers of
 * buttons.
 *
 *    dlg = ui.Dialog()
 *    dlg:add(ui.Button {T"say something nice", on_click = function()
 *      alert(T"something nice!")
 *      dlg:close()
 *    end})
 *    dlg:run()
 *
 * @method dialog:close
 */
static int
l_dialog_close (lua_State * L)
{
    dlg_stop (LUA_TO_DIALOG (L, 1));
    return 0;
}

/**
 * This is exported to Lua as _set_dimensions() and is wrapped by a
 * higher-level Lua function that does some fancy layouting.
 */
static int
l_dialog_set_dimensions (lua_State * L)
{
    WDialog *dlg;
    Widget *w;
    int x, y, cols, rows;
    gboolean send_msg_resize;

    dlg = LUA_TO_DIALOG (L, 1);

    x = luaL_checkint (L, 2);
    y = luaL_checkint (L, 3);
    cols = luaL_checkint (L, 4);
    rows = luaL_checkint (L, 5);
    send_msg_resize = lua_toboolean (L, 6);

    dlg_set_position (dlg, y, x, y + rows, x + cols);

    if (send_msg_resize)
        send_message (dlg, NULL, MSG_RESIZE, 0, NULL);

    /*
     * The 'fullscreen' flag tells MC the dialog from which to
     * start painting the whole screen (see dialog.c:do_refresh()).
     *
     * The only place where this is important to us is when using
     * 'mcscript': we create a dialog to serve as the background
     * wallpaper, and we need it marked as 'fullscreen'.
     *
     * @FIXME: MC sets this flag in dlg_create(), but Lua dialogs
     * have their size set (or modified) after creation. Which is why
     * we need to duplicate this code here. Solution: MC should
     * set it in dialog.c:dlg_set_position().
     */
    w = WIDGET (dlg);
    dlg->fullscreen = (w->x == 0 && w->y == 0 && w->cols == COLS && w->lines == LINES);

    return 0;
}

/**
 * The state of the dialog.
 *
 * Use this property to inquire about the state of the dialog. Possible
 * states:
 *
 * - "construct": The dialog hasn't been @{run} yet.
 * - "active": The dialog is running.
 * - "suspended": A modaless dialog has been switched out of.
 * - "closed": The dialog has been closed.
 *
 * This is a read-only property. To actually change the state of the dialog
 * you use other methods; e.g., @{run|:run}, @{close|:close}.
 *
 * @attr dialog.state
 * @property r
 */
static int
l_dialog_get_state (lua_State * L)
{
    WDialog *dlg = LUA_TO_DIALOG (L, 1);

    const char *state;

    /* *INDENT-OFF* */
    switch (dlg->state) {
    case DLG_CONSTRUCT: state = "construct"; break;
    case DLG_ACTIVE:    state = "active";    break;
    case DLG_SUSPENDED: state = "suspended"; break;
    case DLG_CLOSED:    state = "closed";    break;
    default:            state = "_invalid_"; break;
    }
    /* *INDENT-ON* */

    lua_pushstring (L, state);

    return 1;
}

/**
 * Whether extra space is shown around the dialog's frame. A boolean flag.
 *
 * The difference between this and @{dialog.padding|padding} is that padding
 * governs the space inside the frame whereas `compact` governs the space
 * outside the frame.
 *
 * @attr dialog.compact
 * @property rw
 */
static int
l_dialog_get_compact (lua_State * L)
{
    lua_pushboolean (L, LUA_TO_DIALOG (L, 1)->flags & DLG_COMPACT);
    return 1;
}

static int
l_dialog_set_compact (lua_State * L)
{
    WDialog *dlg = LUA_TO_DIALOG (L, 1);

    if (lua_toboolean (L, 2))
        dlg->flags |= DLG_COMPACT;
    else
        dlg->flags &= ~DLG_COMPACT;

    return 0;
}

/**
 * Switches to the dialog.
 *
 * Only works for modaless dialogs.
 *
 * Note: You won't normally use this method. It can be used to implement
 * special features like a windows switcher or tabs.
 *
 * This method doesn't return immediately (unless you switch to the
 * filemanager): it starts an event loop. This is not a limitation in our
 * Lua API but the way MC works.
 *
 * @method dialog:focus
 */
static int
l_dialog_focus (lua_State * L)
{
    dialog_switch_focus (LUA_TO_DIALOG (L, 1));
    return 0;
}

/**
 * Triggered after a dialog has been painted.
 *
 * You may use this event to add decoration to the dialog, like a
 * @{git:drop-shadow.lua|drop shadow}.
 *
 *    ui.Dialog.bind('<<draw>>', function(dlg)
 *      local c = dlg:get_canvas()
 *      c:set_style(tty.style('yellow, red'))
 *      c:goto_xy(0, 0)
 *      c:draw_string(T"hello!")
 *    end)
 *
 * [info]
 *
 * The differences between this event and @{on_draw} are:
 *
 * - This event is global: it's triggered for *every* dialog box in the
 *   application, whereas @{on_draw} is attached to a single dialog you
 *   yourself created.
 * - This event is triggered after the child widgets had painted themselves,
 *   whereas @{on_draw} is triggered before that.
 *
 * [/info]
 *
 * @moniker draw__event
 * @event
 */

/**
 * Triggered when a dialog has been opened.
 *
 * You may use this event to notify the user with sound on alert boxes,
 * text-to-speech the title, etc.
 *
 *    -- Read aloud dialogs' titles.
 *
 *    ui.Dialog.bind('<<open>>', function(dlg)
 *       -- Note: we run espeak in the background (&) or else we'll be
 *       -- blocked till it finishes voicing the text.
 *       os.execute(('espeak %q &'):format(dlg.text))
 *    end)
 *
 * You may also use it to set initial values for widgets of builtin dialogs:
 *
 *    -- Make 'xsel' the default command of 'Paste output of...'.
 *    --
 *    -- (This technique isn't very robust becaue dialog titles may
 *    -- change between MC releases.)
 *
 *    ui.Dialog.bind('<<open>>', function(dlg)
 *      if dlg.text == T'Paste output of external command' then
 *        dlg:find('Input').text = 'xsel'
 *      end
 *    end)
 *
 * @moniker open__event
 * @event
 */

/**
 * Triggered after a dialog layouts itself.
 *
 * Triggered after the placement of child widgets has been set.
 * You may use this event to inject your own widgets into the dialog.
 *
 * [note]
 *
 * This event is currently triggered only for MC's filemanager and MC's
 * editor. It is used by the @{git:docker.lua|docker} module to inject
 * widgets there.
 *
 * (In the future we may replace this event with `<<resize>>`.)
 *
 * [/note]
 *
 * @moniker layout__event
 * @event
 */

/**
 * Static dialog properties.
 * @section
 */

/**
 * The topmost dialog.
 *
 * This is the "current" dialog.
 *
 *    -- Closes the current dialog.
 *    keymap.bind('C-y', function()
 *      ui.Dialog.top:close()
 *    end)
 *
 * @attr Dialog.top
 * @property r
 */
static int
l_dialog_get_top (lua_State * L)
{
    luaUI_push_widget (L, WIDGET (top_dlg != NULL ? top_dlg->data : NULL), TRUE);
    return 1;
}

static void
add_screen (WDialog * dlg, lua_State * L)
{
    if (dlg != NULL)            /* dialog_switch_list() checks for NULLs, so we too. It may not be necessary. */
    {
        luaUI_push_widget (L, WIDGET (dlg), TRUE);
        luaMC_raw_append (L, -2);
    }
}

/**
 * A list of all the modaless dialogs.
 *
 *    -- Show all the edited files.
 *
 *    local append = table.insert
 *
 *    keymap.bind('C-y', function()
 *      local edited_files = {}
 *      for _, dlg in ipairs(ui.Dialog.screens) do
 *        -- A single editor dialog may contain several editboxes (aka "windows").
 *        for edt in dlg:gmatch('Editbox') do
 *          append(edited_files, edt.filename)
 *        end
 *      end
 *      devel.view(edited_files)
 *    end)
 *
 * @attr Dialog.screens
 * @property r
 */
static int
l_dialog_get_screens (lua_State * L)
{
    lua_newtable (L);
    dialog_switch_foreach ((GFunc) add_screen, L);
    return 1;
}

/*
 * Used for modaless dialogs. See comment at dialog:run() (Lua).
 */
static int
l_dialog_switch_process_pending (lua_State * L)
{
    (void) L;

    dialog_switch_process_pending ();
    return 0;
}

/**
 * @section end
 */


/* *INDENT-OFF* */
static const struct luaL_Reg ui_dialog_static_lib[] = {
    { "_new", l_dialog_new },
    { "get_top", l_dialog_get_top },
    { "get_screens", l_dialog_get_screens },
    { "_switch_process_pending", l_dialog_switch_process_pending },
    { NULL, NULL }
};

static const struct luaL_Reg ui_dialog_methods_lib[] = {
    { "_run", l_dialog_run },
    { "_destroy", l_dialog_destroy },
    { "redraw", l_dialog_redraw },
    { "redraw_cursor", l_dialog_redraw_cursor },
    { "close", l_dialog_close },
    { "get_mapped_children", l_dialog_get_mapped_children },
    { "map_widget", l_dialog_map_widget },
    { "_del_widget", l_dialog_del_widget },
    { "set_text", l_dialog_set_text },
    { "get_text", l_dialog_get_text },
    { "set_modal", l_dialog_set_modal },
    { "get_modal", l_dialog_get_modal },
    { "set_colorset", l_dialog_set_colorset },
    { "get_state", l_dialog_get_state },
    { "_set_dimensions", l_dialog_set_dimensions },
    { "set_compact", l_dialog_set_compact },
    { "get_compact", l_dialog_get_compact },
    { "set_on_idle", l_dialog_set_on_idle },
    { "get_on_idle", l_dialog_get_on_idle },
    { "focus", l_dialog_focus },
    { NULL, NULL }
};
/* *INDENT-ON* */

/**
 * @section end
 */

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg uilib[] = {
    /* No functions are currently defined under the 'ui' namespace.
     * (Note: ui.current_widget() is an alias to mc._current_widget().) */
    { NULL, NULL }
};
/* *INDENT-ON* */

#define REGC(name) { #name, name }

static const luaMC_constReg uilib_constants[] = {

    /*
     * Positioning flags.
     *
     * Currently we only use them to center text in a Label (WPOS_CENTER_HORZ |
     * WPOS_KEEP_TOP). Since we have our own positioning mechanism (hbox/vbox),
     * we don't use them for anything else, but we provide them nevertheless for
     * advanced users.
     */
    REGC (WPOS_CENTER_HORZ),
    REGC (WPOS_CENTER_VERT),
    REGC (WPOS_KEEP_LEFT),
    REGC (WPOS_KEEP_RIGHT),
    REGC (WPOS_KEEP_TOP),
    REGC (WPOS_KEEP_BOTTOM),
    REGC (WPOS_KEEP_HORZ),
    REGC (WPOS_KEEP_VERT),
    REGC (WPOS_KEEP_ALL),
    REGC (WPOS_KEEP_DEFAULT),

    /*
     * Constants for widget:_send_message().
     *
     * Not all of these are needed (e.g., one'd better do w:redraw() instead
     * of w:_send_message(MSG_DRAW)), and some of these won't make sense, but
     * instead of cherry-picking we provide all of them.
     */
    REGC (MSG_INIT),
    REGC (MSG_FOCUS),
    REGC (MSG_UNFOCUS),
    REGC (MSG_DRAW),
    REGC (MSG_KEY),
    REGC (MSG_HOTKEY),
    REGC (MSG_HOTKEY_HANDLED),
    REGC (MSG_UNHANDLED_KEY),
    REGC (MSG_POST_KEY),
    REGC (MSG_ACTION),
    REGC (MSG_CURSOR),
    REGC (MSG_IDLE),
    REGC (MSG_RESIZE),
    REGC (MSG_VALIDATE),
    REGC (MSG_END),
    REGC (MSG_DESTROY),

    {NULL, 0}
};

int
luaopen_ui (lua_State * L)
{
    luaL_newlib (L, uilib);
    luaMC_register_constants (L, uilib_constants);

    /* Stores the module for easy access in REG["ui.module"].
     * Alternatively we could install a "ui" variable in the global scope,
     * but we prefer not to pollute it. */
    lua_pushvalue (L, -1);
    lua_setfield (L, LUA_REGISTRYINDEX, "ui.module");

    create_widget_metatable (L, "Widget", ui_widget_methods_lib, NULL, NULL);
    create_widget_metatable (L, "Button", ui_button_methods_lib, ui_button_static_lib, "Widget");
    create_widget_metatable (L, "Label", ui_label_methods_lib, ui_label_static_lib, "Widget");
    create_widget_metatable (L, "Input", ui_input_methods_lib, ui_input_static_lib, "Widget");
    create_widget_metatable (L, "Checkbox", ui_checkbox_methods_lib, ui_checkbox_static_lib, "Widget");
    create_widget_metatable (L, "Groupbox", ui_groupbox_methods_lib, ui_groupbox_static_lib, "Widget");
    create_widget_metatable (L, "Listbox", ui_listbox_methods_lib, ui_listbox_static_lib, "Widget");
    create_widget_metatable (L, "Radios", ui_radios_methods_lib, ui_radios_static_lib, "Widget");
    create_widget_metatable (L, "Gauge", ui_gauge_methods_lib, ui_gauge_static_lib, "Widget");
    create_widget_metatable (L, "HLine", ui_hline_methods_lib, ui_hline_static_lib, "Widget");
    create_widget_metatable (L, "Dialog", ui_dialog_methods_lib, ui_dialog_static_lib, "Widget");

    luaMC_new_weak_table (L, "v,k");
    lua_setfield (L, LUA_REGISTRYINDEX, "ui.weak");

    return 1;
}
