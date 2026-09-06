#!/bin/bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <timeout-seconds> [--] <command> [arguments...]" >&2
  exit 64
fi

timeout_seconds="$1"
shift

if [ "${1:-}" = "--" ]; then
  shift
fi

if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [ "$timeout_seconds" -lt 1 ] || [ "$timeout_seconds" -gt 1800 ]; then
  echo "Timeout must be an integer between 1 and 1800 seconds." >&2
  exit 64
fi

if [ "$#" -eq 0 ]; then
  echo "A command is required." >&2
  exit 64
fi

exec python3 - "$timeout_seconds" "$@" <<'PY'
import os
import signal
import subprocess
import sys
import time

timeout_seconds = int(sys.argv[1])
command = sys.argv[2:]
interruption = None

def record_interruption(signum, _frame):
    global interruption
    if interruption is None:
        interruption = signum

for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
    signal.signal(signum, record_interruption)

def signal_group(process, signum):
    try:
        os.killpg(process.pid, signum)
        return True
    except ProcessLookupError:
        return False

def stop_group(process):
    # The leader may exit before its descendants. Reap the leader, but wait
    # for the entire owned session's process group before reporting cleanup.
    for signum in (signal.SIGTERM, signal.SIGKILL):
        if not signal_group(process, signum):
            process.wait()
            return True
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            process.poll()
            if not signal_group(process, 0):
                process.wait()
                return True
            time.sleep(0.02)
    return False

process = None
return_code = 1
try:
    # The signal handler records, rather than raises, so interruption during
    # Popen cannot lose ownership of a child that has already been spawned.
    process = subprocess.Popen(command, start_new_session=True)
    deadline = time.monotonic() + timeout_seconds
    while True:
        if interruption is not None:
            return_code = 128 + interruption
            break
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return_code = 124
            print(f"Timed out after {timeout_seconds} seconds: {' '.join(command)}", file=sys.stderr)
            break
        try:
            return_code = process.wait(timeout=min(remaining, 0.1))
            if return_code < 0:
                return_code = 128 - return_code
            break
        except subprocess.TimeoutExpired:
            continue
finally:
    if process is not None:
        if not stop_group(process):
            print(f"Process group {process.pid} did not terminate after TERM/KILL", file=sys.stderr)
            return_code = 1
        elif interruption is not None:
            return_code = 128 + interruption

sys.exit(return_code)
PY
