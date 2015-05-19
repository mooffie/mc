#ifndef MC__LUA_PLUMBING_H
#define MC__LUA_PLUMBING_H

/*
 * If a function needs a lua_State argument then it means it doesn't belong here.
 */

/* -------------------------- Meta information ---------------------------- */

const char *mc_lua_engine_name (void);
const char *mc_lua_system_dir (void);
const char *mc_lua_user_dir (void);

/* ----------------------------- Start/stop ------------------------------- */

void mc_lua_init (void);
void mc_lua_load (void);
void mc_lua_before_vfs_shutdown (void);
void mc_lua_shutdown (void);

void mc_lua_request_restart (void);
gboolean mc_lua_is_restarting (void);

#define MCEVENT_GROUP_LUA  "Lua"        /* used for mc_event_add(), mc_event_raise(). */

/* ------------------------------- Runtime -------------------------------- */

/* forward declarations */
struct Widget;
typedef struct Widget Widget;

gboolean mc_lua_eat_key (int keycode);
void mc_lua_trigger_event (const char *event_name);
void mc_lua_trigger_event__with_widget (const char *event_name, Widget * w);
void mc_lua_notify_on_widget_destruction (Widget * w);  /* implemented in ui-impl.c */
gboolean mc_lua_ui_is_ready (void);

/* --------------------------- mcscript-related --------------------------- */

#define MC_LUA_SCRIPT_RESULT_CONTINUE     0
#define MC_LUA_SCRIPT_RESULT_FINISH       1
#define MC_LUA_SCRIPT_RESULT_ERROR        2
int mc_lua_run_script (const char *filename);
void mc_lua_create_argv (const char *script_path, int argc, char **argv, int offs);

#endif /* MC__LUA_PLUMBING_H */
