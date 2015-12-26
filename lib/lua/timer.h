#ifndef MC__LUA_TIMER_H
#define MC__LUA_TIMER_H

/*
 * "Point in Time"
 *
 * Holds milliseconds since the epoch (being: moment of first call).
 */
typedef gint64 pit_t;           /* "long long" isn't ANSI C. */

pit_t mc_lua_timer_now (void);
void mc_lua_set_next_timeout (pit_t tm);
void mc_lua_execute_ready_timeouts (void);
gboolean mc_lua_has_pending_timeouts (struct timeval *time_out);
void mc_lua_timer_unlock (void);

#endif /* MC__LUA_TIMER_H */
