#ifndef MC__LUA_CAPI_SAFECALL_H
#define MC__LUA_CAPI_SAFECALL_H

gboolean luaMC_safe_call (lua_State * L, int nargs, int nresults);
int luaMC_safe_dofile (lua_State * L, const char *dirname, const char *basename);

#endif /* MC__LUA_CAPI_SAFECALL_H */
