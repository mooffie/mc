#ifndef MC__LUA_TTY_H
#define MC__LUA_TTY_H

long luaTTY_check_keycode (lua_State * L, int name_index, gboolean push_name_short);
void luaTTY_assert_ui_is_ready (lua_State * L);

#endif /* MC__LUA_TTY_H */
