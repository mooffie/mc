
/** \file widget-common.h
 *  \brief Header: shared stuff of widgets
 */

#ifndef MC__WIDGET_INTERNAL_H
#define MC__WIDGET_INTERNAL_H

#include "lib/tty/mouse.h"
#include "lib/widget/mouse.h"   /* mouse_msg_t, mouse_event_t */

/*** typedefs(not structures) and defined constants **********************************************/

#define WIDGET(x) ((Widget *)(x))
#define CONST_WIDGET(x) ((const Widget *)(x))

#define widget_move(w, _y, _x) tty_gotoyx (CONST_WIDGET(w)->y + (_y), CONST_WIDGET(w)->x + (_x))
/* Sets/clear the specified flag in the options field */
#define widget_want_cursor(w,i) widget_set_options(w, W_WANT_CURSOR, i)
#define widget_want_hotkey(w,i) widget_set_options(w, W_WANT_HOTKEY, i)
#define widget_want_idle(w,i) widget_set_options(w, W_WANT_IDLE, i)
#define widget_disable(w,i) widget_set_options(w, W_DISABLED, i)

/*** enums ***************************************************************************************/

/* Widget messages */
typedef enum
{
    MSG_INIT = 0,               /* Initialize widget */
    MSG_FOCUS,                  /* Draw widget in focused state or widget has got focus */
    MSG_UNFOCUS,                /* Draw widget in unfocused state or widget has been unfocused */
    MSG_DRAW,                   /* Draw widget on screen */
    MSG_KEY,                    /* Sent to widgets on key press */
    MSG_HOTKEY,                 /* Sent to widget to catch preprocess key */
    MSG_HOTKEY_HANDLED,         /* A widget has got the hotkey */
    MSG_UNHANDLED_KEY,          /* Key that no widget handled */
    MSG_POST_KEY,               /* The key has been handled */
    MSG_ACTION,                 /* Send to widget to handle command */
    MSG_NOTIFY,                 /* Typically sent to dialog to inform it of state-change
                                 * of listboxes, check- and radiobuttons. */
    MSG_CURSOR,                 /* Sent to widget to position the cursor */
    MSG_IDLE,                   /* The idle state is active */
    MSG_RESIZE,                 /* Screen size has changed */
    MSG_VALIDATE,               /* Dialog is to be closed */
    MSG_END,                    /* Shut down dialog */
    MSG_DESTROY,                /* Sent to widget at destruction time */
    MSG_BEFORE_DESTROY          /* Sent before MSG_DESTROY */
} widget_msg_t;

/* Widgets are expected to answer to the following messages:
   MSG_FOCUS:   MSG_HANDLED if the accept the focus, MSG_NOT_HANDLED if they do not.
   MSG_UNFOCUS: MSG_HANDLED if they accept to release the focus, MSG_NOT_HANDLED if they don't.
   MSG_KEY:     MSG_HANDLED if they actually used the key, MSG_NOT_HANDLED if not.
   MSG_HOTKEY:  MSG_HANDLED if they actually used the key, MSG_NOT_HANDLED if not.
 */

typedef enum
{
    MSG_NOT_HANDLED = 0,
    MSG_HANDLED = 1
} cb_ret_t;

/* Widget options */
typedef enum
{
    W_DEFAULT = (0 << 0),
    W_WANT_HOTKEY = (1 << 1),
    W_WANT_CURSOR = (1 << 2),
    W_WANT_IDLE = (1 << 3),
    W_IS_INPUT = (1 << 4),
    W_DISABLED = (1 << 5)       /* Widget cannot be selected */
} widget_options_t;

/* Flags for widget repositioning on dialog resize */
typedef enum
{
    WPOS_CENTER_HORZ = (1 << 0),        /* center widget in horizontal */
    WPOS_CENTER_VERT = (1 << 1),        /* center widget in vertical */
    WPOS_KEEP_LEFT = (1 << 2),  /* keep widget distance to left border of dialog */
    WPOS_KEEP_RIGHT = (1 << 3), /* keep widget distance to right border of dialog */
    WPOS_KEEP_TOP = (1 << 4),   /* keep widget distance to top border of dialog */
    WPOS_KEEP_BOTTOM = (1 << 5),        /* keep widget distance to bottom border of dialog */
    WPOS_KEEP_HORZ = WPOS_KEEP_LEFT | WPOS_KEEP_RIGHT,
    WPOS_KEEP_VERT = WPOS_KEEP_TOP | WPOS_KEEP_BOTTOM,
    WPOS_KEEP_ALL = WPOS_KEEP_HORZ | WPOS_KEEP_VERT,
    WPOS_KEEP_DEFAULT = WPOS_KEEP_LEFT | WPOS_KEEP_TOP
} widget_pos_flags_t;
/* NOTE: if WPOS_CENTER_HORZ flag is used, other horizontal flags (WPOS_KEEP_LEFT, WPOS_KEEP_RIGHT,
 * and WPOS_KEEP_HORZ are ignored).
 * If WPOS_CENTER_VERT flag is used, other horizontal flags (WPOS_KEEP_TOP, WPOS_KEEP_BOTTOM,
 * and WPOS_KEEP_VERT are ignored).
 */

/*** structures declarations (and typedefs of structures)*****************************************/

/* Widget callback */
typedef cb_ret_t (*widget_cb_fn) (Widget * widget, Widget * sender, widget_msg_t msg, int parm,
                                  void *data);
/* Widget mouse callback */
typedef void (*widget_mouse_cb_fn) (Widget * w, mouse_msg_t msg, mouse_event_t * event);

/* Every Widget must have this as its first element */
struct Widget
{
    int x, y;
    int cols, lines;
    widget_options_t options;
    widget_pos_flags_t pos_flags;       /* repositioning flags */
    unsigned int id;            /* Number of the widget, starting with 0 */
    widget_cb_fn callback;
    widget_mouse_cb_fn mouse_callback;
    void (*set_options) (Widget * w, widget_options_t options, gboolean enable);
    WDialog *owner;
    /* Mouse-related fields. */
    struct
    {
        /* Public members: */
        gboolean forced_capture;        /* Overrides the 'capture' member. Set explicitly by the programmer. */

        /* Implementation details: */
        gboolean capture;       /* Whether the widget "owns" the mouse. */
        mouse_msg_t last_msg;   /* The previous event type processed. */
        int last_buttons_down;
    } mouse;

    /*
     * To be able to convert a Widget to a scriptable object, we have to
     * know its type (aka "class"). This member serves this purpose.
     *
     * We currently use a string, for simplicity (for the benefit of
     * reviewers).
     *
     * In the future we'll probably change this to a numeric ID. How to do
     * this "properly" is explained in 'TODO.long'. We'll also change its
     * name to 'class_id' because it's useful also outside the realm of
     * scripting.
     *
     * (Using strings has a flaw: we have to settle on the names used in one
     * scripting engine (Lua). Somebody designing, say, a Python support may
     * want to name his classes differently.)
     */
    const char *scripting_class_name;
};

/* structure for label (caption) with hotkey, if original text does not contain
 * hotkey, only start is valid and is equal to original text
 * hotkey is defined as char*, but mc support only singlebyte hotkey
 */
typedef struct hotkey_t
{
    char *start;
    char *hotkey;
    char *end;
} hotkey_t;

/*** global variables defined in .c file *********************************************************/

/*** declarations of public functions ************************************************************/

/* create hotkey from text */
hotkey_t parse_hotkey (const char *text);
/* release hotkey, free all mebers of hotkey_t */
void release_hotkey (const hotkey_t hotkey);
/* return width on terminal of hotkey */
int hotkey_width (const hotkey_t hotkey);
/* draw hotkey of widget */
void hotkey_draw (Widget * w, const hotkey_t hotkey, gboolean focused);

/* widget initialization */
void widget_init (Widget * w, int y, int x, int lines, int cols,
                  widget_cb_fn callback, widget_mouse_cb_fn mouse_callback,
                  const char *lua_class_name);
/* Default callback for widgets */
cb_ret_t widget_default_callback (Widget * w, Widget * sender, widget_msg_t msg, int parm,
                                  void *data);
void widget_default_set_options_callback (Widget * w, widget_options_t options, gboolean enable);
void widget_set_options (Widget * w, widget_options_t options, gboolean enable);
void widget_set_size (Widget * widget, int y, int x, int lines, int cols);
/* select color for widget in dependance of state */
void widget_selectcolor (Widget * w, gboolean focused, gboolean hotkey);
void widget_redraw (Widget * w);
void widget_erase (Widget * w);
gboolean widget_is_active (const void *w);
gboolean widget_overlapped (const Widget * a, const Widget * b);
void widget_replace (Widget * old, Widget * new);
void widget_destroy (Widget * w);

/* get mouse pointer location within widget */
Gpm_Event mouse_get_local (const Gpm_Event * global, const Widget * w);
gboolean mouse_global_in_widget (const Gpm_Event * event, const Widget * w);

/* --------------------------------------------------------------------------------------------- */
/*** inline functions ****************************************************************************/
/* --------------------------------------------------------------------------------------------- */

static inline cb_ret_t
send_message (void *w, void *sender, widget_msg_t msg, int parm, void *data)
{
    cb_ret_t ret = MSG_NOT_HANDLED;

#if 1
    if (w != NULL)              /* This must be always true, but... */
#endif
        ret = WIDGET (w)->callback (WIDGET (w), WIDGET (sender), msg, parm, data);

    return ret;
}

/* --------------------------------------------------------------------------------------------- */

#endif /* MC__WIDGET_INTERNAL_H */
