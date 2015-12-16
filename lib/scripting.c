/**
 * A langauge-neutral API for scripting.
 *
 * Use this API whenever you can. It insulates you from the scripting engine
 * used (whether it be Lua, Pythion, S-Lang, ...). It also makes your code
 * visually cleaner because you don't need to use #ifdef.
 *
 * For example, instead of:
 *
 *     #ifdef ENABLE_LUA
 *     #include "lib/lua/plumbing.h"
 *     #endif
 *     ...
 *     #ifdef ENABLE_LUA
 *     mc_lua_trigger_event ("some_event_name");
 *     #endif
 *
 * do:
 *
 *     #include "lib/scripting.h"
 *     ...
 *     scripting_trigger_event ("some_event_name");
 */
#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"         /* Widget type */
#ifdef ENABLE_LUA
#include "lib/lua/plumbing.h"
#endif

#include "scripting.h"

void
scripting_trigger_event (const char *event_name)
{
#ifdef ENABLE_LUA
    mc_lua_trigger_event (event_name);
#else
    (void) event_name;
#endif
}

void
scripting_trigger_widget_event (const char *event_name, Widget * w)
{
#ifdef ENABLE_LUA
    mc_lua_trigger_event__with_widget (event_name, w);
#else
    (void) event_name;
    (void) w;
#endif
}

/**
 * Inform script engines of dead widgets.
 */
void
scripting_notify_on_widget_destruction (Widget * w)
{
#ifdef ENABLE_LUA
    mc_lua_notify_on_widget_destruction (w);
#else
    (void) w;
#endif
}
