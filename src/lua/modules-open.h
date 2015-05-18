#ifndef MC__LUA_MODULES_OPEN_H
#define MC__LUA_MODULES_OPEN_H

void mc_lua_open_c_modules (void);  /* implemented in modules.c */

/*
 * The reason we have this silly file, instead of putting that declaration
 * in modules.h, is because this function is called by main(), and if we
 * #include modules.h in main.c, it will complain about unknown type
 * lua_State. We can of course put forward declaration to lua_State in
 * module.h, but this doesn't seem elegant.
 */

#endif /* MC__LUA_MODULES_OPEN_H */
