#ifndef MC__LUA_UI_CANVAS_H
#define MC__LUA_UI_CANVAS_H

void luaUI_new_canvas (lua_State * L);
void luaUI_set_canvas_dimensions (lua_State * L, int index, int x, int y, int cols, int rows);

#endif /* MC__LUA_UI_CANVAS_H */
