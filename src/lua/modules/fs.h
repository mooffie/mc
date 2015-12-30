#ifndef MC__LUA_FS_H
#define MC__LUA_FS_H

/* -------------------- Implemented in fs-vpath.c: ------------------------ */

void luaFS_push_vpath (lua_State * L, const vfs_path_t * vpath);
vfs_path_t *luaFS_check_vpath (lua_State * L, int index);
vfs_path_t *luaFS_check_vpath_ex (lua_State * L, int index, gboolean relative);

typedef struct
{
    vfs_path_t *vpath;
    gboolean allocated_by_us;
} vpath_argument;

vpath_argument *get_vpath_argument (lua_State * L, int index);
void destroy_vpath_argument (vpath_argument * arg);

#endif /* MC__LUA_FS_H */
