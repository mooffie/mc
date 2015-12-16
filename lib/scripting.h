#ifndef MC__SCRIPTING_H
#define MC__SCRIPTING_H

/* forward declarations */
struct Widget;
typedef struct Widget Widget;

void scripting_trigger_event (const char *event_name);
void scripting_trigger_widget_event (const char *event_name, Widget * w);
void scripting_notify_on_widget_destruction (Widget * w);

#endif /* MC__SCRIPTING_H */
