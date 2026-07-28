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

python3 - "$timeout_seconds" "$@" <<'PY'
import os
import signal
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
command = sys.argv[2:]
process = subprocess.Popen(command, start_new_session=True)

try:
    return_code = process.wait(timeout=timeout_seconds)
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    print(
        f"Timed out after {timeout_seconds} seconds: {' '.join(command)}",
        file=sys.stderr,
    )
    sys.exit(124)

sys.exit(return_code)
PY
