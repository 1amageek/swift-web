#ifndef C_SWIFT_WEB_SIGNALS_H
#define C_SWIFT_WEB_SIGNALS_H

#include <stdbool.h>

int swift_web_install_termination_signal_handlers(void);
void swift_web_reset_termination_signal_request(void);
bool swift_web_is_termination_requested(void);

#endif
