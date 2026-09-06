#!/usr/bin/env python3
"""Exercise the timeout wrapper and verify that its owned children are gone."""
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time

wrapper = Path(__file__).with_name("swift-test-timeout.sh")
cases = {
    "success": (0, None),
    "failure": (7, None),
    "timeout": (124, None),
    "interrupt": (130, signal.SIGINT),
    "terminate": (143, signal.SIGTERM),
    "cleanup_interrupt": (130, signal.SIGINT),
}

def exists(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False

for name in sys.argv[1:] or cases:
    expected, interruption = cases[name]
    # The descendant ignores TERM, so checking the leader alone cannot pass.
    child_code = "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print('ready', flush=True); time.sleep(60)"
    command = (
        "import os,subprocess,sys,time; "
        f"child=subprocess.Popen([sys.executable,'-u','-c',{child_code!r}],stdout=subprocess.PIPE,text=True); "
        "assert child.stdout.readline().strip()=='ready'; "
        "print(os.getpid(),child.pid,flush=True); "
        + ("sys.exit(0)" if name == "cleanup_interrupt" else
           f"sys.exit({expected})" if name in ("success", "failure") else "time.sleep(60)")
    )
    process = subprocess.Popen(
        ["bash", str(wrapper), "1" if name == "timeout" else "30", sys.executable, "-u", "-c", command],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True,
    )
    child_group = descendant = None
    try:
        assert select.select([process.stdout], [], [], 5)[0], f"{name}: child did not start"
        child_group, descendant = map(int, process.stdout.readline().split())
        if name == "cleanup_interrupt":
            deadline = time.monotonic() + 2
            while exists(child_group) and time.monotonic() < deadline:
                time.sleep(0.02)
            assert not exists(child_group), "The command must exit before interrupting cleanup"
        if interruption:
            process.send_signal(interruption)
        status = process.wait(timeout=12)
        deadline = time.monotonic() + 2
        while exists(descendant) and time.monotonic() < deadline:
            time.sleep(0.02)
        assert not exists(descendant), f"{name}: descendant {descendant} survived"
        assert not exists(child_group), f"{name}: leader {child_group} survived"
        assert status == expected, f"{name}: exit {status}, expected {expected}"
        print(f"{name}=passed cleanup=terminal", flush=True)
    finally:
        # Even a red regression must not leave the deliberately stubborn child.
        for group in (child_group, process.pid):
            if group is not None:
                try:
                    os.killpg(group, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        process.wait(timeout=5)
