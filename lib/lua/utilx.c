/**
 * Miscellaneous utilities.
 */

#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"

#include "utilx.h"

/**
 * Returns a dialog's current widget.
 *
 * Since it's intended for use by Lua, we only care about widgets that
 * can be represented in Lua (that is, have scripting_class_name).
 */
Widget *
mc_lua_current_widget (WDialog * dlg)
{
    if (dlg->current)
    {
        Widget *w = WIDGET (dlg->current->data);

        if (w->scripting_class_name)
            return w;
    }

    return NULL;
}
