#ifndef MC__LUA_FIELDS_H
#define MC__LUA_FIELDS_H

/*
 * Since we're referring to WPanel here, you'll have to #include this file after src/filemanager/panel.h.
 */

void mc_lua_set_current_field (WPanel * panel, const char *field_id);

#endif /* MC__LUA_FIELDS_H */
