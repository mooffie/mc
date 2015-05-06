/*
 * The functions here serve the mechanism that lets us schedule Lua
 * functions to run in the future.
 *
 * That mechanism is written in Lua: it's our Lua 'timer' module, which
 * exposes, notably, the functions set_timeout() and set_interval().
 *
 * The C side, this file, contains a few devices:
 *
 * First, it defines a timestamp data type (pit_t) whose resolution is
 * 1/1000 of a second. (Which makes it more useful than Unix' classic
 * 1-second resolution returned by time().) "pit" stands for "Point In
 * Time".
 *
 * Second, it defines a few primitive functions:
 *
 * - mc_lua_set_next_timeout() and mc_lua_timer_now(), which are used by
 *   the Lua side.
 *
 * - mc_lua_execute_ready_timeouts() and mc_lua_has_pending_timeouts(),
 *   which are used by the C side.
 */

#include <config.h>

#include <sys/time.h>           /* gettimeofday() */

#include "lib/global.h"

#include "capi.h"
#include "capi-safecall.h"

#include "timer.h"


/**
 * Holds the timestamp of the next Lua function we're to run. Zero if
 * there's none.
 *
 * Note that this is *all* the data we, the C side, need. We do *not*
 * store here the complete datastructure containing information about
 * *all* the scheduled functions. *That* is what the Lua side does. We
 * only need to know when to invoke the Lua side.
 */
static pit_t next_timeout;

/**
 * This flag is documented at Lua's timer.unlock().
 */
static gboolean lock;

/**
 * The Lua side uses this function (exposed to Lua in the modules/timr.c)
 * to tell us when it's time to invoke it.
 */
void
mc_lua_set_next_timeout (pit_t tm)
{
    next_timeout = tm;
}

void
mc_lua_timer_unlock ()
{
    lock = FALSE;
}

/**
 * Returns the current timestamp.
 *
 * You can think of it as the equivalent of C's time(), with the following
 * differences:
 *
 * - The resolution is 1/1000 of a second.
 *
 * - The first call to mc_lua_timer_now() is the 'epoch'. That is, the first
 *   call returns zero.
 *
 * - mc_lua_timer_now() is monotonous: if the admin sets the clock to earlier
 *   time, mc_lua_timer_now() will detect this and at most return a reading
 *   equal to the previous reading.
 */
pit_t
mc_lua_timer_now ()
{
    static struct timeval last_reading;
    static pit_t current_pit;

    struct timeval now;

    /* We're using gettimeofday(), not clock_gettime() because: (1) the
       former is what's already used throughout MC. (2) According
       clock_gettime's manual page(s), while Linux and BSD do support
       CLOCK_MONOTONIC, which could free us from the need to handle the
       monotony issue ourselves, this is not guaranteed to be supported
       on other systems, so we'd have to handle this ourselves anyway. */
    gettimeofday (&now, NULL);

    if (last_reading.tv_sec == 0)
    {
        /* First call. */
        last_reading = now;
    }
    else if (now.tv_sec < last_reading.tv_sec
             || (now.tv_sec == last_reading.tv_sec && now.tv_usec < last_reading.tv_usec))
    {
        /* The clock was set backwards in time. Ensure monotony. */
        last_reading = now;
    }

    current_pit +=
        /* If the following seems like an error to you, consider that
           (B-A)*m + (b-a)/n    equals    (B*m+b/n) - (A*m+a/n)  */
        (now.tv_sec - last_reading.tv_sec) * 1000 + ((now.tv_usec - last_reading.tv_usec) / 1000);

    last_reading = now;

    return current_pit;
}

/**
 * Tells us whether there are functions scheduled to run, and calculates
 * the time till the first scheduled function.
 *
 * MC's event loop uses this function to know the maximum time it's
 * got to wait for user input.
 */
gboolean
mc_lua_has_pending_timeouts (struct timeval * time_out)
{
    if (next_timeout != 0)
    {
        if (time_out)
        {
            /* Calculate time till next timeout. */
            pit_t now = mc_lua_timer_now ();
            if (next_timeout <= now)
            {
                time_out->tv_sec = 0;
                time_out->tv_usec = 0;
            }
            else
            {
                pit_t diff = next_timeout - now;
                time_out->tv_sec = diff / 1000;
                time_out->tv_usec = (diff % 1000) * 1000;
            }
        }
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}

/**
 * Runs the scheduled functions that are now ready to run.
 *
 * MC's event loop calls this function.
 */
void
mc_lua_execute_ready_timeouts ()
{
    if (lock)
        return;

    if (next_timeout != 0 && next_timeout <= mc_lua_timer_now ())       /* There's a timeout ready */
    {
        lock = TRUE;

        if (luaMC_get_system_callback (Lg, "timer::execute_ready_timeouts"))
            luaMC_safe_call (Lg, 0, 0);

        /* We might want to call mc_refresh() here so the user doesn't
         * have to call 'tty.refresh()' himself (see explanation in
         * modules/tty.c). But perhaps such call is time consuming. */

        lock = FALSE;
    }
}
