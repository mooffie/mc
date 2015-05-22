#ifndef MC__LUA_PLUMBING_H
#define MC__LUA_PLUMBING_H

/*
 * If a function needs a lua_State argument then it means it doesn't belong here.
 */

/* -------------------------- Meta information ---------------------------- */

/* Names of environment variables with which user can override directory paths. */
#define MC_LUA_SYSTEM_DIR__ENVAR "MC_LUA_SYSTEM_DIR"
#define MC_LUA_USER_DIR__ENVAR "MC_LUA_USER_DIR"

const char *mc_lua_engine_name (void);
const char *mc_lua_system_dir (void);
const char *mc_lua_user_dir (void);

/* ----------------------------- Start/stop ------------------------------- */

#define MCEVENT_GROUP_LUA "Lua" /* used for mc_event_add(), mc_event_raise(). */

void mc_lua_init (void);
void mc_lua_load (void);
void mc_lua_before_vfs_shutdown (void);
void mc_lua_shutdown (void);

void mc_lua_request_restart (void);
gboolean mc_lua_is_restarting (void);

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

typedef enum
{
    MC_LUA_SCRIPT_RESULT_CONTINUE,
    MC_LUA_SCRIPT_RESULT_FINISH,
    MC_LUA_SCRIPT_RESULT_ERROR
} mc_lua_script_result_t;

mc_lua_script_result_t mc_lua_run_script (const char *filename);
void mc_lua_create_argv (const char *script_path, int argc, char **argv, int offs);

#endif /* MC__LUA_PLUMBING_H */
