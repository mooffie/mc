#ifndef MC__LUA_MODULES_H
#define MC__LUA_MODULES_H

int luaopen_conf (lua_State * L);
int luaopen_internal (lua_State * L);
int luaopen_locale (lua_State * L);
int luaopen_prompts (lua_State * L);
int luaopen_tty (lua_State * L);
int luaopen_utils_bit32 (lua_State * L);

#endif /* MC__LUA_MODULES_H */
