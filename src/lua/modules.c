/**
 * All C modules have to be registered here.
 */

#include <config.h>

#include "lib/global.h"

#include "capi.h"

#include "modules.h"

/* As to why we expose some modules as "c.NAME", see "Writing hybrid
 * modules" in doc/HACKING. */
static const struct luaL_Reg mods [] = {
  { "conf", luaopen_conf },
  { "c.tty", luaopen_tty },
  { "internal", luaopen_internal },
  { "c.fs", luaopen_fs },
  { "fs.filedes", luaopen_fs_filedes },
  { "fs.dir", luaopen_fs_dir },
  { NULL, luaopen_fs_vpath },
  { NULL, luaopen_fs_statbuf },
  { "c.timer", luaopen_timer },
  { "c.prompts", luaopen_prompts },
  { "c.utils.text", luaopen_utils_text },
  { "c.utils.text.transport", luaopen_utils_text_transport },
  { "utils.bit32", luaopen_utils_bit32 },
  { "c.regex", luaopen_regex },
  { "c.mc", luaopen_mc },
  { NULL, luaopen_mc_os },
  { "locale", luaopen_locale },
  { "c.fields", luaopen_fields },
#ifdef ENABLE_VFS_LUAFS
  { "luafs.gc", luaopen_luafs_gc },
#endif

  { "c.ui", luaopen_ui },
#ifdef USE_INTERNAL_EDIT
  { NULL, luaopen_ui_editbox },
#endif
  { NULL, luaopen_ui_custom },
  { NULL, luaopen_ui_canvas },
  { NULL, luaopen_ui_viewer },
  { NULL, luaopen_ui_panel },

  { NULL, NULL }
};

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
