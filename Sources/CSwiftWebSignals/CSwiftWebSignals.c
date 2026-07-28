#include "CSwiftWebSignals.h"

#include <errno.h>
#include <signal.h>
#include <string.h>

static volatile sig_atomic_t swift_web_termination_requested = 0;

static void swift_web_handle_termination_signal(int signal_number) {
    (void)signal_number;
    swift_web_termination_requested = 1;
}

int swift_web_install_termination_signal_handlers(void) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = swift_web_handle_termination_signal;
    sigemptyset(&action.sa_mask);

    swift_web_termination_requested = 0;
    if (sigaction(SIGINT, &action, NULL) != 0) {
        return errno;
    }
    if (sigaction(SIGTERM, &action, NULL) != 0) {
        return errno;
    }
    return 0;
}

void swift_web_reset_termination_signal_request(void) {
    swift_web_termination_requested = 0;
}

bool swift_web_is_termination_requested(void) {
    return swift_web_termination_requested != 0;
}
