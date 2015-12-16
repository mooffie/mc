#ifndef MC__LUA_MODULES_H
#define MC__LUA_MODULES_H

int luaopen_conf (lua_State * L);
int luaopen_fs (lua_State * L);
int luaopen_fs_dir (lua_State * L);
int luaopen_fs_filedes (lua_State * L);
int luaopen_fs_statbuf (lua_State * L);
int luaopen_fs_vpath (lua_State * L);
int luaopen_internal (lua_State * L);
int luaopen_locale (lua_State * L);
int luaopen_mc (lua_State * L);
int luaopen_mc_os (lua_State * L);
int luaopen_prompts (lua_State * L);
int luaopen_regex (lua_State * L);
int luaopen_timer (lua_State * L);
int luaopen_tty (lua_State * L);
int luaopen_ui (lua_State * L);
int luaopen_ui_canvas (lua_State * L);
int luaopen_ui_custom (lua_State * L);
int luaopen_ui_panel (lua_State * L);
int luaopen_utils_bit32 (lua_State * L);
int luaopen_utils_text (lua_State * L);
int luaopen_utils_text_transport (lua_State * L);
#ifdef ENABLE_VFS_LUAFS
int luaopen_luafs_gc (lua_State * L);
#endif

#endif /* MC__LUA_MODULES_H */
