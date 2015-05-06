#ifndef MC__LUA_UI_IMPL_H
#define MC__LUA_UI_IMPL_H

void luaUI_push_widget_ex (lua_State * L, Widget * w, gboolean created_in_c,
                           gboolean allow_abstract);
void luaUI_push_widget (lua_State * L, Widget * w, gboolean created_in_c);

Widget *luaUI_check_widget_ex (lua_State * L, int idx, gboolean allow_destroyed,
                               const char *lua_class_name);
Widget *luaUI_check_widget (lua_State * L, int idx);

cb_ret_t call_widget_method (Widget * w, const char *method_name, int nargs,
                             gboolean * method_found);
cb_ret_t call_widget_method_ex (Widget * w, const char *method_name, int nargs,
                                gboolean * lua_widget_found, gboolean * method_found, gboolean pop);
gboolean widget_method_exists (Widget * w, const char *method_name);

void create_widget_metatable (lua_State * L, const char *className, const luaL_Reg * lib,
                              const luaL_Reg * static_lib, const char *parent);
const char *mc_lua_ui_meta_name (const char *widget_type);

#endif /* MC__LUA_UI_IMPL_H */
