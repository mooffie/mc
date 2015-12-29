#ifndef MC__LUA_FS_H
#define MC__LUA_FS_H

int luaFS_push_error (lua_State * L, const char *filename);
int luaFS_push_error__by_idx (lua_State * L, int filename_index);
int luaFS_push_result (lua_State * L, int result, const char *filename);

/* ------------------- Implemented in fs-statbuf.c: ----------------------- */

struct stat *luaFS_push_statbuf (lua_State * L, struct stat *sb_init);
struct stat *luaFS_check_statbuf (lua_State * L, int idx);
struct stat *luaFS_to_statbuf (lua_State * L, int idx);
int luaFS_statbuf_extract_fields (lua_State * L, struct stat *sb, int start_index);

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
