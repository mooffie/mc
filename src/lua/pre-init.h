#ifndef MC__LUA_PRE_INIT_H
#define MC__LUA_PRE_INIT_H

void mc_lua_pre_init (void);    /* implemented in modules.c */

/*
 * The reason we have this header file, instead of just putting the above
 * declaration in modules.h, is because this function is called by main(),
 * and if we #include modules.h in main.c, it will complain about the
 * unknown type lua_State used in that header. We can of course put forward
 * declaration to lua_State in module.h, but this doesn't seem elegant.
 */

#endif /* MC__LUA_PRE_INIT_H */
