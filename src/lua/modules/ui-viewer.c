/**
 * A viewer widget.
 *
 * This widget doesn't currently expose many exciting properties and methods.
 * You can use @{ui.bind|ui.Panel.bind} and @{~mod:ui*widget:command|:command},
 * though.
 *
 * @classmod ui.Viewer
 */

#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"
#include "lib/lua/capi.h"
#include "lib/lua/ui-impl.h"    /* luaUI_*() */

#include "src/viewer/internal.h"

#include "../modules.h"

#define LUA_TO_VIEWER(L, i) ((mcview_t *) (luaUI_check_widget (L, i)))

/* ------------------------------------------------------------------------ */

/**
 * Properties
 * @section
 */

/**
 * The filename associated with the buffer.
 *
 * Returns **nil** if no filename is associated with the buffer (e.g., if the
 * data comes from a pipe).
 *
 * @function filename
 * @property r
 */
static int
l_view_get_filename (lua_State * L)
{
    mcview_t *view;

    view = LUA_TO_VIEWER (L, 1);

    /* Should we return a real VPath? C.f. ui.Editbox.filename. */
    lua_pushstring (L, vfs_path_as_str (view->filename_vpath)); /* pushes nil if NULL */

    return 1;
}

/**
 * Number of the first line displayed.
 *
 * Example:
 *
 *
 *    -- Launches the editor with F4.
 *
 *    ui.Viewer.bind("f4", function(vwr)
 *      mc.edit(
 *        abortive(vwr.filename, T"Cannot edit a pipe"),
 *        vwr.top_line
 *      )
 *    end)
 *
 *    -- See a more complete implementation at snippets/viewer_edit.lua.
 *
 * @function top_line
 * @property r
 */
static int
l_view_get_top_line (lua_State * L)
{
    mcview_t *view;

    off_t line, column;

    view = LUA_TO_VIEWER (L, 1);

    mcview_offset_to_coord (view, &line, &column, view->dpy_start);

    lua_pushi (L, line + 1);    /* Our API is 1-based. */

    return 1;
}

/**
 * @section end
 */

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg ui_viewer_static_lib[] = {
    { NULL, NULL }
};

static const struct luaL_Reg ui_viewer_lib[] = {
    { "get_filename", l_view_get_filename },
    { "get_top_line", l_view_get_top_line },
    { NULL, NULL }
};

/* *INDENT-ON* */

int
luaopen_ui_viewer (lua_State * L)
{
    create_widget_metatable (L, "Viewer", ui_viewer_lib, ui_viewer_static_lib, "Widget");
    return 0;                   /* Nothing to return! */
}
