/**
 * Operating-system facilities.
 *
 * The os module is the built-in [os](http://www.lua.org/manual/5.1/manual.html#5.8)
 * Lua module extended with the functions listed here.
 *
 * @module os
 */

#include <config.h>

#include <sys/types.h>
#include <signal.h>             /* kill() */
#include <unistd.h>             /* getpid() */

#include "lib/global.h"
#include "lib/lua/capi.h"

#include "../modules.h"


/**
 * Returns the current host name.
 *
 * Returns an empty string if the host name cannot be determined.
 *
 * @function hostname
 */
/**
 * Note: we export it as 'hostname', not 'gethostname', to make Node.js users
 * feel at home.
 */
static int
l_hostname (lua_State * L)
{
    char host[BUF_SMALL];

    if (gethostname (host, sizeof (host)) == -1)
        /* On error we return an empty string, instead of the customary nil.
         * This way an innocuous `print("You're on " .. os.hostname())` won't
         * ever raise exception. */
        host[0] = '\0';
    else
        host[sizeof (host) - 1] = '\0';

    lua_pushstring (L, host);

    return 1;
}

/**
 * Returns the process ID.
 *
 * @function getpid
 */
static int
l_getpid (lua_State * L)
{
    lua_pushi (L, getpid ());
    return 1;
}

/**
 * Sends a signal to a process.
 *
 * An interface to @{kill(2)}.
 *
 * __signal__ is either an integer or a signal name (such as "SIGKILL",
 * "SIGSTOP", etc.). Zero means to check for `pid` existance. If missing,
 * defaults to SIGTERM.
 *
 * __Returns:__
 *
 * __true__ on sucess.
 *
 * @function kill
 * @args (pid[, signal])
 */
static int
l_kill (lua_State * L)
{
    static const char *const signames[] = {
        "SIGHUP", "SIGINT", "SIGKILL", "SIGUSR1", "SIGUSR2",
        "SIGTERM", "SIGCONT", "SIGSTOP", "SIGWINCH", NULL
    };
    static int sigvals[] = {
        SIGHUP, SIGINT, SIGKILL, SIGUSR1, SIGUSR2,
        SIGTERM, SIGCONT, SIGSTOP, SIGWINCH
    };

    pid_t pid;
    int sig;

    pid = luaL_checki (L, 1);
    sig =
        lua_isnumber (L, 2) ? luaL_checki (L,
                                           2) : sigvals[luaL_checkoption (L, 2, "SIGTERM",
                                                                          signames)];

    lua_pushboolean (L, kill (pid, sig) == 0);

    return 1;
}

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg mc_os_lib[] = {
    { "hostname", l_hostname },
    { "getpid", l_getpid },
    { "kill", l_kill },
    { NULL, NULL }
};
/* *INDENT-ON* */

/**
 * Note: We can't name this function 'luaopen_os'. Lua itself already
 * has a function such named, and if we call ours thus, the linker will
 * replace Lua's with ours, resulting in a snafu.
 */
int
luaopen_mc_os (lua_State * L)
{
    lua_getglobal (L, "os");
    g_assert (!lua_isnil (L, -1));
    luaL_setfuncs (L, mc_os_lib, 0);
    return 0;                   /* Return nothing. We augment the standard Lua module. */
}
