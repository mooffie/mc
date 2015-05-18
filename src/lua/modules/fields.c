/**
 * Fields are the columns shown in the filemanager's panels.
 *
 * The documentation for this subsystem is in core/fields.lua and in the
 * user guide (there's a chapter dedicated to fields).
 */

#include <config.h>

#include "lib/global.h"
#include "lib/lua/capi.h"
#include "lib/lua/capi-safecall.h"
#include "lib/widget.h"         /* Widget type */
#include "lib/lua/ui-impl.h"    /* luaUI_push_widget() */

#include "src/filemanager/panel.h"

#include "../modules.h"
#include "tty.h"                /* luaTTY_check_align() */
#include "fs.h"                 /* luaFS_push_statbuf() */

#include "fields.h"


static void invalidate_info_table (lua_State * L);

/**

To be able to render and sort fields, we register two callback functions
with MC (see render_multiplex and sort_multiplex).

However, when MC calls our functions it passes them the file entries
only. It doesn't pass them the field ID, which we need in order to
channel the call to the correct Lua callback.

To fix this problem we keep a track of which is the "current
field". We also want to know which is the "current panel" because the Lua
programmer might want to pull information out of this object (e.g., the
file's directory).

This tracking task is carried out by mc_lua_set_current_field(). We have to
call this function whenever the current field changes.

*/

/* *INDENT-OFF* */
static const char *current_field_id;
static WPanel     *current_field_panel;
/* *INDENT-ON* */

void
mc_lua_set_current_field (WPanel * panel, const char *field_id)
{
    current_field_panel = panel;
    current_field_id = field_id;        /* @todo: is it possible for it to be g_free()'ed while we're holding it? and in the future? */
    invalidate_info_table (Lg);
}

/**

This is a "map" showing where mc_lua_set_current_field() is called.

We call it before any dir_list_{load|reload|sort} because of the sorting.
We call it in format_file because of the rendering.


  Legend:
  F - Calls mc_lua_set_current_field():
  T - Triggers panel::load

  --

  panel.c:format_file    F

  --

  panel.c:_do_panel_cd          FT
  panel.c:panel_new_with_dir    FT

    dir.c:dir_list_load
      dir.c:dir_list_sort

  --

  panel.c:panel_reload     FT

    dir.c:dir_list_reload
      dir.c:dir_list_sort

  --

  panel.c:panel_re_sort    F
    dir.c:dir_list_sort

*/


/**
 * The "info" table is basket of goodies we pass to the Lua "render" and
 * "sort" handlers. The Lua programmer might find it useful.
 *
 * For efficiency reasons we don't create this table anew for each "render"
 * call. We cache it in Lua's registry.
 */
static void
push_info_table (lua_State * L)
{
    if (!luaL_getsubtable (L, LUA_REGISTRYINDEX, "fields.info"))
    {
        if (current_field_panel)
        {
            lua_pushstring (L, current_field_panel->cwd_vpath->str);
            lua_setfield (L, -2, "dir");
            luaUI_push_widget (L, WIDGET (current_field_panel), TRUE);
            lua_setfield (L, -2, "panel");
        }
    }
}

static void
invalidate_info_table (lua_State * L)
{
    lua_pushnil (L);
    lua_setfield (L, LUA_REGISTRYINDEX, "fields.info");
}

/**

Efficiency "bug" in MC:

When you hit the down arrow, for example, the whole panel will be
painted. While panel.c:move_down() gives the impression that only the
previous/current files will be painted, the select_item() that it calls
does 'panel->dirty = 1', and later midnight_callback(msg=MSG_POST_KEY)
kicks in and calls update_dirty_panels(), which paints everything :-(

You can see this bug using:

  ui.Panel.register_field {
    id = "rnd",
    title = N"Rnd",
    render = function()
      return os.date("%S")
    end,
  }

You'll notice that the whole column, for all files shown, will be
painted (you see the number changing), even when you just move up/down.

So, the lesson learned:

You should keep you render functions efficient.

*/

static const char *
render_multiplex (file_entry_t * fe, int len)
{
    if (luaMC_get_system_callback (Lg, "fields::render_field"))
    {
        lua_pushstring (Lg, current_field_id);
        lua_pushstring (Lg, fe->fname);
        luaFS_push_statbuf (Lg, &fe->st);
        lua_pushinteger (Lg, len);
        push_info_table (Lg);

        if (luaMC_safe_call (Lg, 5, 1))
        {
            static char buffer[MC_MAXPATHLEN * MB_LEN_MAX + 1]; /* Borrowed from panel.c:string_file_name() */
            const char *s;

            s = lua_tostring (Lg, -1);
            g_strlcpy (buffer, s ? s : "", sizeof (buffer));
            lua_pop (Lg, 1);    /* We must always clean up after a successful luaMC_safe_call() */
            return buffer;
        }
        else
            return Q_ ("fields|failure");
    }
    else
        return _("NO CALLBACK");
}

static int
sort_multiplex (file_entry_t * a, file_entry_t * b)
{
    /**
     * FIXME: We ignore "panels_options.mix_all_files, exec_first, reverse" for
     * the time being. We should make the MY_ISDIR() macro of dir.c public and
     * use it, but to do this we must un-"static" a few variables there.
     */

    if (luaMC_get_system_callback (Lg, "fields::sort_field"))
    {
        lua_pushstring (Lg, current_field_id);
        lua_pushstring (Lg, a->fname);
        luaFS_push_statbuf (Lg, &a->st);
        lua_pushstring (Lg, b->fname);
        luaFS_push_statbuf (Lg, &b->st);
        push_info_table (Lg);

        if (luaMC_safe_call (Lg, 6, 1))
        {
            /* The callback returns the comparison result. */
            int sign = luaMC_get_sign (Lg, -1);
            lua_pop (Lg, 1);
            return sign;
        }
    }

    return 0;                   /* failed. */
}

/**
 * This is exposed to lua as fields._register_field() and is wrapped by the
 * higher-level ui.Panel.register_field().
 */
static int
l_register_field (lua_State * L)
{
    gboolean has_render;
    gboolean has_sort;

    static const char *const sort_names[] = {
        "name", "version", "extension",
        "size", "mtime", "atime",
        "ctime", "inode", "unsorted", NULL
    };
    static GCompareFunc sort[] = {
        (GCompareFunc) sort_name, (GCompareFunc) sort_vers, (GCompareFunc) sort_ext,
        (GCompareFunc) sort_size, (GCompareFunc) sort_time, (GCompareFunc) sort_atime,
        (GCompareFunc) sort_ctime, (GCompareFunc) sort_inode, (GCompareFunc) unsorted
    };

    panel_field_t field = {
        "", 12, FALSE, J_LEFT,
        "",
        "", FALSE, FALSE,
        NULL,
        NULL
    };

    /* *INDENT-OFF* */
    field.id            = luaL_checkstring(L, 1);
    field.title_hotkey  = luaL_checkstring(L, 2);   /* title */
    field.hotkey        = luaL_checkstring(L, 3);   /* sort indicator. @FIXME: misnomer. */
    field.min_size      = luaL_checkint(L, 4);      /* @FIXME: "min_size" is a misnomer. It's the _default_ size. */
    field.expands       = lua_toboolean(L, 5);
    field.default_just  = luaTTY_check_align(L, 6);
    /* *INDENT-ON* */

    has_render = lua_toboolean (L, 7);
    has_sort = lua_toboolean (L, 8);

    if (has_render)
    {
        field.string_fn = render_multiplex;
        /* The following is used by the spiffy "Listing Format Editor"
         * (src/filemanager/listmode.c). */
        field.use_in_user_format = TRUE;
    }

    if (has_sort)
    {
        if (lua_type (L, 8) == LUA_TSTRING)
            /* It's a name of a built-in sort function. */
            field.sort_routine = sort[luaL_checkoption (L, 8, NULL, sort_names)];
        else
            field.sort_routine = (GCompareFunc) sort_multiplex;
        field.is_user_choice = TRUE;
    }

    /* We need these to survive after the Lua stack goes away. (We didn't do
     * this earlier as we might have had to raise exceptions.) */
    /* *INDENT-OFF* */
    field.id            = g_strdup(field.id);
    field.title_hotkey  = g_strdup(field.title_hotkey);
    field.hotkey        = g_strdup(field.hotkey);
    /* *INDENT-ON* */

    panel_fields_register (&field);

    return 0;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg fields_lib[] = {
    { "_register_field", l_register_field },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_fields (lua_State * L)
{
    panel_fields_init ();       /* When restarting Lua, clear previously registered fields. */

    luaL_newlib (L, fields_lib);
    return 1;
}
