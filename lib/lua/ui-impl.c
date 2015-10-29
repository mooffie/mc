/**
 * Implementation details of the ui module.
 *
 * This is the only place where our C code uses "rocket science".
 */

#include <config.h>

#include <stdlib.h>

#include "lib/global.h"
#include "lib/widget.h"

#include "capi.h"
#include "capi-safecall.h"
#include "utilx.h"

#include "plumbing.h"           /* declaration of mc_lua_notify_on_widget_destruction() */
#include "ui-impl.h"

/* ------------------------------------------------------------------ */
/**

Lua widgets are tables that contain a pointer (__cwidget__) to the C
widget. (We often, in this documentation, use the term "object" instead
of "table".)

We need a mapping between C pointers and Lua widgets. This is achieved
by the 'ui.weak' table. This mapping lets us:

 - When a C widget is destroyed, its Lua counterpart is located and the
   pointer is set to nil. next time Lua code calls method on this widget
   we know to raise exception instead of crash.

 - In C callbacks: finding the Lua object (and the associated 'onclick',
   'action', 'onchange' handlers).

*/
/* ------------------------------------------------------------------ */

/**
 * Record a widget in the ui.weak table.
 */
static void
register_widget (lua_State * L, int index, Widget * w)
{
    /* ui.weak[w] = LuaWidget */
    lua_pushvalue (L, index);
    lua_pushlightuserdata (L, w);
    lua_insert (L, -2);         /* index may not be absolute, so we do it backwards. */
    luaMC_registry_settable (L, "ui.weak");

    /*
     * Because of the way weak tables work in 5.2+ (see comment bellow),
     * we also store it the other way around:
     */

    /* ui.weak[LuaWidget] = w */
    lua_pushvalue (L, index);
    lua_pushlightuserdata (L, w);
    luaMC_registry_settable (L, "ui.weak");
}


static gboolean luaUI_push_registered_widget (lua_State * L, Widget * w, gboolean search_hard);

/**
 * Remove a widget from the ui.weak table.
 */
static void
unregister_widget (lua_State * L, Widget * w)
{
    /* ui.weak[LuaWidget] = nil */
    if (luaUI_push_registered_widget (L, w, TRUE))
    {
        lua_pushnil (L);
        luaMC_registry_settable (L, "ui.weak");
    }

    /* ui.weak[w] = nil */
    lua_pushlightuserdata (L, w);
    lua_pushnil (L);
    luaMC_registry_settable (L, "ui.weak");
}

/**
 * Given a C widget, pushes onto the stack the corresponding Lua widget.
 *
 * If no corresponding Lua widget was found, pushes nothing.
 *
 * Return TRUE on success.
 */
static gboolean
luaUI_push_registered_widget (lua_State * L, Widget * w, gboolean search_hard)
{
    /* stack.push( ui.weak[w] ) */
    lua_pushlightuserdata (L, w);
    luaMC_registry_gettable (L, "ui.weak");

    if (lua_isnil (L, -1) && search_hard)
    {
        lua_pop (L, 1);
/**

The ui.weak table is where Lua widgets are registered (as explained
above).

In Lua 5.2+, Lua widgets that are in the process of being GC won't seem
to appear in this table. This means that this table won't serve its
purpose (and Bad Things will happen).

The truth is that Lua widgets being *values* in that table will indeed
disappear, but, fortunately, when they're *keys*, they'll still be
there.

So, in this situation, of being in a GC stage, what we need to do is to
search the ui.weak table a bit harder: instead of using the 'Widget *w'
as the lookup key, we traverse the table element by element till we find 
the Lua widget whose value is this 'Widget *w'. That's why in
register_widget() we stored the relationship both ways.

This only needs to be used from mc_lua_notify_on_widget_destruction.

A section form Lua 5.2 manual explains this:

    "Resurrected objects (that is, objects being finalized and objects
    accessible only through objects being finalized) have a special
    behavior in weak tables. They are removed from weak values before
    running their finalizers, but are removed from weak keys only in the
    next collection after running their finalizers, when such objects
    are actually freed. This behavior allows the finalizer to access
    properties associated with the object through weak tables.

----

Here's an example of what can happen *without* our "searching hard":

  do
    local lbl = ui.Label("whatever")
    local dlg = ui.Dialog()

    dlg:add(lbl)
    dlg:run()
  end

  collectgarbage()
  collectgarbage()

The label and the dialog both get GCed. They both "vanish" (in Lua 5.2+)
from ui.weak. The dialog happens to get its __gc called first. Its __gc
calls dlg:destroy(), which calls a C function which destroys all the C
widgets. When the label gets destroyed, from the C side,
mc_lua_notify_on_widget_destruction() tries to find this label's Lua
counterpart to zero its __cwidget__ field, but it *can't find* this Lua
counterpart. Next, the __gc of 'lbl' is called and down the chain it
calls some function that access __cwidgte__, which points to *invalid*
memory address.

*/

        LUAMC_GUARD (L);
        lua_getfield (L, LUA_REGISTRYINDEX, "ui.weak");
        lua_pushlightuserdata (L, w);
        luaMC_search_table (L, -2);
        lua_remove (L, -2);     /* ui.weak */
        LUAMC_UNGUARD_BY (L, 1);
    }

    if (!lua_isnil (L, -1))
        return TRUE;
    else
    {
        lua_pop (L, 1);
        return FALSE;
    }
}

/**
 * Add our own prefix to metatables stored in the registry so they don't
 * accidentally override metatables of other applications. (This prefix
 * isn't looked up anywhere else so it can be absolutely anything.)
 */
const char *
mc_lua_ui_meta_name (const char *widget_type)
{
    static char buf[BUF_MEDIUM];
    strcpy (buf, "ui.");
    strcat (buf, widget_type);
    return buf;
}

/**
 * Converts a C widget to a Lua object.
 *
 * (It has the semantic of lua_pushXXX.)
 *
 * @param created_in_c
 *   If a Lua object is to be created, flag it as one created in C code.
 * @param allow_abstract
 *   If the widget doesn't have a Lua counterpart, push it anyway (instead of
 *   raising error). On the Lua side it will be a "Widget" type, which supports
 *   only the basic operations (e.g., reading and setting screen coordinates).
 */
void
luaUI_push_widget_ex (lua_State * L, Widget * w, gboolean created_in_c, gboolean allow_abstract)
{
    if (w == NULL)
    {
        lua_pushnil (L);
        return;
    }

    if (luaUI_push_registered_widget (L, w, FALSE))
    {
        /* The Lua object already exists; and has just been fetched. */
        return;
    }

    if (!allow_abstract)
    {
        if (w->scripting_class_name == NULL)
        {
            /*
             * This should never happen, so it's just a sanity check what
             * we're doing here.
             *
             * And maybe we should have 'allow_abstract' always turned on.
             */
            fprintf (stderr,
                     E_ ("Internal error: w->scripting_class_name == NULL. Please report this bug.\n"));
            exit (EXIT_FAILURE);
            /* (We can't use g_assert() as it may be "compiled out".) */
        }
    }

    /*
     * Create the Lua object.
     */

    /* Create a new table ... */
    lua_newtable (L);
    luaL_setmetatable (L, mc_lua_ui_meta_name (w->scripting_class_name ? w->scripting_class_name : "Widget"));
    luaMC_enable_table_gc (L, -1);

    /* Populate it ... */
    lua_pushlightuserdata (L, w);
    luaMC_rawsetfield (L, -2, "__cwidget__");
    if (created_in_c)
    {
        lua_pushboolean (L, TRUE);
        luaMC_rawsetfield (L, -2, "__created_in_c__");
    }
#if 0
    {
        /*
         * This is a small teaching aid that shows you whether, for example, repeated
         * calls to ui.current_widget() return the same Lua widget (unless a GC
         * happens inbetween; BTW, in _bootstrap.lua there's a timer that performs
         * GC, and you may disable it and examine the effect).
         */
        static int serial_number = 0;
        lua_pushinteger (L, ++serial_number);
        luaMC_rawsetfield (L, -2, "__serial_number");
    }
#endif

    /* And register it. */
    register_widget (L, -1, w);

    /* Finally, call a custom initialization method, for widgets that want to make use of it. */
    luaMC_pingmeta (L, -1, "init");
}

/**
 * Converts a C widget to a Lua object.
 *
 * This is an "easy" version of luaUI_push_widget_ex().
 */
void
luaUI_push_widget (lua_State * L, Widget * w, gboolean created_in_c)
{
    luaUI_push_widget_ex (L, w, created_in_c, FALSE);
}

/**
 * Calls a widget's method.
 *
 * This is an "easy" version of call_widget_method_ex().
 */
cb_ret_t
call_widget_method (Widget * w, const char *method_name, int nargs, gboolean * method_found)
{
    return call_widget_method_ex (w, method_name, nargs, NULL, method_found, TRUE);
}

/**
 * Checks whether a widget has a certain method.
 */
gboolean
widget_method_exists (Widget * w, const char *method_name)
{
    if (luaUI_push_registered_widget (Lg, w, FALSE))
    {
        gboolean exists;

        lua_getfield (Lg, -1, method_name);
        exists = lua_isfunction (Lg, -1);
        lua_pop (Lg, 2);
        return exists;
    }

    return FALSE;
}

/**
 * Calls a widget's method.
 *
 * You may, if you need to, push arguments onto the stack to pass to the
 * method. 'nargs' tells the function how many arguments you pushed (it may
 * be zero).
 *
 * If 'pop' is FALSE, this function leaves on the stack one value, which is
 * either what the method returned, or nil if there was some error (no
 * Lua widget, or method not found).
 *
 * Return value:
 *
 * If the method exists and returned a true-ish value, MSG_HANDLED is
 * returned. Else MSG_NOT_HANDLED. (To distinguish between a method that
 * doesn't exist and a method that returns false, use the 'method_found'
 * pointer.
 */
cb_ret_t
call_widget_method_ex (Widget * w, const char *method_name, int nargs, gboolean * lua_widget_found,
                       gboolean * method_found, gboolean pop)
{
#define SET_FLAG(name, value)   do { if (name) *name = value; } while (0)
    cb_ret_t result;

    SET_FLAG (lua_widget_found, FALSE);
    SET_FLAG (method_found, FALSE);

    if (luaUI_push_registered_widget (Lg, w, FALSE))
    {
        SET_FLAG (lua_widget_found, TRUE);

        lua_getfield (Lg, -1, method_name);

        if (lua_isfunction (Lg, -1))
        {
            SET_FLAG (method_found, TRUE);

            lua_insert (Lg, -2);

            /*
             * Now at the top of the stack are the method, and the widget.
             * We move these two down so the nargs are above.
             *
             *  before:           after:
             *
             *  -1: widget        -1: arg3
             *  -2: method        -2: arg2
             *  -3: arg3          -3: arg1
             *  -4: arg2          -4: widget
             *  -5: arg1          -5: method
             */
            lua_insert (Lg, -(nargs + 2));
            lua_insert (Lg, -(nargs + 2));

            if (!luaMC_safe_call (Lg, 1 + nargs, 1))
            {
                SET_FLAG (method_found, FALSE);
                lua_pushnil (Lg);
            }
        }
        else
        {
            /* Method was not found. Return with only one value, nil, on the stack. */
            lua_pop (Lg, 2);    /* The widget and the non-existent method. */
            lua_pop (Lg, nargs);
            lua_pushnil (Lg);
        }
    }
    else
    {
        /* No Lua widget. */
        lua_pop (Lg, nargs);
        lua_pushnil (Lg);
    }

    result = lua_toboolean (Lg, -1) ? MSG_HANDLED : MSG_NOT_HANDLED;

    if (pop)
        lua_pop (Lg, 1);

    return result;
#undef SET_FLAG
}

/**
 * Converts a Lua object to a C widget.
 *
 * (It has the semantic of luaL_checkXXX.)
 */
Widget *
luaUI_check_widget (lua_State * L, int idx)
{
    return luaUI_check_widget_ex (L, idx, FALSE, NULL);
}

Widget *
luaUI_check_widget_ex (lua_State * L, int idx, gboolean allow_destroyed, const char *scripting_class_name)
{
    Widget *w;

    if (!lua_istable (L, idx))
        luaL_typerror (L, idx, "widget");

    luaMC_rawgetfield (L, idx, "__cwidget__");

    /* A boolean (false) is used to signify a destroyed widget. See mc_lua_notify_on_widget_destruction() */
    if (lua_isboolean (L, -1))
    {
        lua_pop (L, 1);
        if (!allow_destroyed)
            luaL_argerror (L, idx,
                           E_
                           ("A living widget was expected, but an already destroyed widget was provided"));
        return NULL;
    }

    /*
     * In Lua 5.2+ the stack top may be nil, in the __gc stage. We're called by
     * :is_alive() then (and allow_destroyed happens to be TRUE).
     *
     * In any other case, a nil means a programming error, so we raise an exception.
     * Such programming error is, for example, doing 'ParentWidgetMeta:on_draw()'
     * instead of 'ParentWidgetMeta.on_draw(self)' (see test/ui_subclass.lua).
     */
    if (!allow_destroyed && lua_isnil (L, -1))
    {
        luaL_typerror (L, idx, "widget*");
    }

    w = lua_touserdata (L, -1);
    lua_pop (L, 1);

    if (w && scripting_class_name && !STREQ (w->scripting_class_name, scripting_class_name))
    {
        /* It's a pity luaL_argerror() doesn't let us use %s */
        luaL_error (L, E_ ("A widget of type '%s' was expected, but '%s' was given."),
                    scripting_class_name, w->scripting_class_name);
    }

    return w;
}

/**
 * Sets up a widget class's metatable.
 *
 * This function is called for every widget class (e.g., Button, Listbox,
 * Input, ...) you want to expose to Lua. It creates the expected
 * scaffoldings.
 */
void
create_widget_metatable (lua_State * L, const char *class_name, const luaL_Reg * lib,
                         const luaL_Reg * static_lib, const char *parent_class_name)
{
    /*
     * Create the metatable. The code is equal to the following pseudo code
     * ("Button" is an example class name):
     *
     *     REGISTRY["ui.Button"] = lib + {
     *       __index = self,
     *       widget_type = "Button"
     *     }
     *
     *     if parent then
     *       setmetatable(REGISTRY["ui.Button"], parent)
     */

    LUAMC_GUARD (L);

    luaMC_register_metatable (L, mc_lua_ui_meta_name (class_name), lib, TRUE);

    /*
     * The following property lets users figure out the widget's type. See its
     * documentation in ui.c (or in the ldoc) to learn of another way.
     *
     * (Note: This somewhat duplicates the meta["__name"] property which is
     * created by Lua 5.3+ (luaL_newmetatable) and which we don't use.)
     */
    lua_pushstring (L, class_name);
    lua_setfield (L, -2, "widget_type");

    if (parent_class_name != NULL)
        luaL_setmetatable (L, mc_lua_ui_meta_name (parent_class_name)); /* inheritance chain */

    lua_pop (L, 1);             /* the metatable */

    LUAMC_UNGUARD (L);

    /*
     * Create the static-functions table. The code is equal to the following
     * pseudo code:
     *
     *     ui.Button = static_lib + {
     *       meta = REGISTRY["ui.Button"]
     *     }
     */

    LUAMC_GUARD (L);

    lua_getfield (L, LUA_REGISTRYINDEX, "ui.module");
    luaL_getsubtable (L, -1, class_name);
    if (static_lib)
        luaL_setfuncs (L, static_lib, 0);
    luaL_getmetatable (L, mc_lua_ui_meta_name (class_name));
    lua_setfield (L, -2, "meta");

    lua_pop (L, 2);

    LUAMC_UNGUARD (L);
}

/**
 * This function is called whenever a C widget gets destroyed.
 *
 * We locate the corresponding Lua widget and mark it as invalid. Otherwise
 * calling most of the Lua widget's methods would crash the application.
 */
void
mc_lua_notify_on_widget_destruction (Widget * w)
{
    LUAMC_GUARD (Lg);

    /* Note the TRUE below, which means "search hard in ui.weak". */
    if (luaUI_push_registered_widget (Lg, w, TRUE))
    {
        lua_pushboolean (Lg, FALSE);
        luaMC_rawsetfield (Lg, -2, "__cwidget__");

        /* Note: we don't use luaMC_pingmeta() as it doesn't support inheritance. */
        call_widget_method (w, "on_destroy", 0, NULL);

        lua_pop (Lg, 1);        /* the lua object */

        /*
         * We also remove the widget from the weak table.
         *
         * Why? We don't have to. It will be removed automatically at some point.
         * But MC may create a widget that would happen to have the same address,
         * and luaUI_push_widget() would then return the destroyed Lua widget
         * instead of a new one.
         *
         * It might also ease in debugging: when we do
         * `devel.view(debug.getregistry()['ui.weak'])` no destroyed widgets will
         * clutter the view.
         */
        unregister_widget (Lg, w);
    }
    else
    {
        /* No corresponding Lua object. */
    }

    LUAMC_UNGUARD (Lg);
}
