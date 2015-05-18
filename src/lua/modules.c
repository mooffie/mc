/**
 * All C modules have to be registered here.
 */

#include <config.h>

#include "lib/global.h"
#include "lib/lua/capi.h"

#include "modules-open.h"
#include "modules.h"

/* As to why we expose some modules as "c.NAME", see "Writing hybrid
 * modules" in doc/HACKING. */
static const struct luaL_Reg mods [] = {
/* *INDENT-OFF* */
  { "conf",         luaopen_conf },
  { "c.fields",     luaopen_fields },
  { "c.fs",         luaopen_fs },
  { "fs.dir",       luaopen_fs_dir },
  { "fs.filedes",   luaopen_fs_filedes },
  { NULL,           luaopen_fs_statbuf },
  { NULL,           luaopen_fs_vpath },
  { "internal",     luaopen_internal },
  { "locale",       luaopen_locale },
  { "c.mc",         luaopen_mc },
  { NULL,           luaopen_mc_os },
  { "c.prompts",    luaopen_prompts },
  { "c.regex",      luaopen_regex },
  { "c.timer",      luaopen_timer },
  { "c.tty",        luaopen_tty },
  { "c.ui",         luaopen_ui },
  { NULL,           luaopen_ui_canvas },
  { NULL,           luaopen_ui_custom },
  { NULL,           luaopen_ui_panel },
  { NULL,           luaopen_ui_viewer },
  { "utils.bit32",  luaopen_utils_bit32 },
  { "c.utils.text", luaopen_utils_text },
  { "c.utils.text.transport", luaopen_utils_text_transport },
#ifdef USE_INTERNAL_EDIT
  { NULL,           luaopen_ui_editbox },
#endif
#ifdef ENABLE_VFS_LUAFS
  { "luafs.gc",     luaopen_luafs_gc },
#endif
  { NULL, NULL }
/* *INDENT-ON* */
};

/**
 * "Loads" all our C modules.
 *
 * Typically called from main().
 */
void
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
}
