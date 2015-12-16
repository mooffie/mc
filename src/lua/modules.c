/**
 * All C modules have to be registered here.
 */

#include <config.h>

#include "lib/global.h"
#include "lib/event.h"          /* mc_event_add() */
#include "lib/lua/capi.h"
#include "lib/lua/plumbing.h"   /* MCEVENT_GROUP_LUA */

#include "modules.h"
#include "pre-init.h"

/* As to why we expose some modules as "c.NAME", see "Writing hybrid
 * modules" in doc/HACKING. */
static const struct luaL_Reg mods[] = {
/* *INDENT-OFF* */
    { "conf",         luaopen_conf },
    { "c.fs",         luaopen_fs },
    { "fs.dir",       luaopen_fs_dir },
    { "fs.filedes",   luaopen_fs_filedes },
    { NULL,           luaopen_fs_statbuf },
    { NULL,           luaopen_fs_vpath },
    { "internal",     luaopen_internal },
    { "locale",       luaopen_locale },
    { "mc",           luaopen_mc },
    { "c.prompts",    luaopen_prompts },
    { "c.regex",      luaopen_regex },
    { "c.timer",      luaopen_timer },
    { "c.tty",        luaopen_tty },
    { "c.ui",         luaopen_ui },
    { NULL,           luaopen_ui_canvas },
    { NULL,           luaopen_ui_custom },
    { "utils.bit32",  luaopen_utils_bit32 },
    { "c.utils.text", luaopen_utils_text },
    { "c.utils.text.transport", luaopen_utils_text_transport },
    { NULL, NULL }
/* *INDENT-ON* */
};

/**
 * "Loads" all our C modules.
 */
static gboolean
mc_lua_open_c_modules (void)
{
    const luaL_Reg *mod = mods;

    while (mod->func)
    {
        if (mod->name)
        {
            luaMC_requiref (Lg, mod->name, mod->func);
        }
        else
        {
            lua_pushcfunction (Lg, mod->func);
            lua_call (Lg, 0, 0);
        }
        ++mod;
    }

    return TRUE;
}

/**
 * Our Lua integration is split into the 'lib' and the 'src' trees. The
 * modules are here, in the 'src' tree.
 *
 * This poses a problem: since code in 'lib' is not supposed to call code in
 * 'src', there's no way for Lua's initialization routine (in 'lib') to load
 * our modules! The solution: main() calls the following function, which
 * registers itself to trigger when Lua initializes.
 *
 * It wouldn't have worked for main() to call mc_lua_open_c_modules() directly
 * because it (mc_lua_open_c_modules) has to be called also when Lua restarts,
 * a mechanism which main() knows nothing about.
 */
void
mc_lua_pre_init (void)
{
    mc_event_add (MCEVENT_GROUP_LUA, "init", (mc_event_callback_func_t) mc_lua_open_c_modules, NULL,
                  NULL);
    /* Note: It's OK that mc_lua_open_c_modules() doesn't declare in its
     * signature all the parameters mc_event_raise() sends it: we have this
     * scenario when we pass g_free (and others) to g_list_foreach(). */
}
