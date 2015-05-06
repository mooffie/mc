/**
 * @module timer
 */

#include <config.h>

#include "lib/global.h"

#include "../capi.h"
#include "../capi-safecall.h"
#include "../modules.h"
#include "../timer.h"


/**
 * The timer module is written mostly in Lua. Only a couple of functions
 * are written in C.
 */

/**
 * We don't document the functions in ldoc as it's not intended
 * for end-users; only for the implementation of the timer module.
 */
static int
l_set_next_timeout (lua_State * L)
{
    /* We're passed 'nil' if there are no pending timeouts. */
    mc_lua_set_next_timeout (luaL_opti (L, 1, 0));
    return 0;
}

/**
 * Returns the current "timestamp".
 *
 * This function is similar to Unix's @{time(2)} function, except that our
 * timestamp is of higher resolution (milliseconds instead of seconds) and the
 * Epoch is the time the program started (the time this function was first
 * called, to be exact).
 *
 * This function is mainly useful for building peripheral utilities, like
 * benchmarking code.
 *
 * Note: **You don't need this function in order to use timers (or
 * intervals).** You'll seldom find a need for this function.
 *
 * @function now
 */
static int
l_now (lua_State * L)
{
    lua_pushi (L, mc_lua_timer_now ());
    return 1;
}

/**
 * Enables "reentrancy".
 *
 * Note-short: This function is very seldom needed. Feel free to ignore it.
 *
 * By default, timers don't fire while a scheduled function is already
 * running. This is a feature intended to prevent the following code from
 * "blowing up" your application with alert boxes:
 *
 *    timer.set_interval(function() alert('bomb!') end, 100)
 *
 * Info: This issue only exists when the scheduled function calls the event
 * loop (i.e., when it opens a dialog). It's the event loop that fires the
 * timers (remember: MC isn't multithreaded). So if your function doesn't
 * open a dialog, no timer will ever get the chance to fire anyway.
 *
 * If you want to disable this protective feature, call `timer.unlock()` at
 * the start of your scheduled function: this will fool the system to think
 * that no scheduled code is currently running.
 *
 * Note: there's no corresponding `lock()` function: the lock flag is
 * automatically set when a scheduled function is called.
 *
 * @function unlock
 */
static int
l_unlock (lua_State * L)
{
    (void) L;
    mc_lua_timer_unlock ();
    return 0;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg timerlib[] = {
    { "now", l_now },
    { "_set_next_timeout", l_set_next_timeout },
    { "unlock", l_unlock },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_timer (lua_State * L)
{
    luaL_newlib (L, timerlib);
    return 1;
}
