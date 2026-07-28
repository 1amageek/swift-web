#!/bin/bash
set -euo pipefail

repeats=3
timeout_seconds=30
build_timeout_seconds=120

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repeats)
      repeats="$2"
      shift 2
      ;;
    --timeout)
      timeout_seconds="$2"
      shift 2
      ;;
    --build-timeout)
      build_timeout_seconds="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 64
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 [--repeats N] [--timeout N] [--build-timeout N] -- <test-command>" >&2
  exit 64
fi

if ! [[ "$repeats" =~ ^[0-9]+$ ]] || [ "$repeats" -lt 1 ]; then
  echo "Repeats must be a positive integer." >&2
  exit 64
fi

script_directory="$(cd "$(dirname "$0")" && pwd)"
artifact_root="${SWIFT_TEST_HANG_GUARD_ARTIFACT_ROOT:-$PWD/.test-artifacts/hang-guard}"
lock_directory="$artifact_root/.lock"
run_directory="$artifact_root/$(date -u +%Y%m%dT%H%M%SZ)-$$"

mkdir -p "$artifact_root"
if ! mkdir "$lock_directory" 2>/dev/null; then
  echo "Another hang-guard run is active: $lock_directory" >&2
  exit 3
fi
trap 'rmdir "$lock_directory" 2>/dev/null || true' EXIT
mkdir -p "$run_directory"

helper_pids() {
  pgrep -f 'swiftpm-testing-helper' 2>/dev/null | sort -n || true
}

baseline_helpers="$(helper_pids)"

for run in $(seq 1 "$repeats"); do
  run_timeout="$timeout_seconds"
  if [ "$run" -eq 1 ]; then
    run_timeout="$build_timeout_seconds"
  fi

  log_file="$run_directory/run-$run.log"
  diagnostic_file="$run_directory/run-$run.diag.txt"
  set +e
  "$script_directory/swift-test-timeout.sh" "$run_timeout" -- "$@" >"$log_file" 2>&1
  status=$?
  set -e

  current_helpers="$(helper_pids)"
  {
    echo "status=$status"
    echo "baseline_helpers=$baseline_helpers"
    echo "current_helpers=$current_helpers"
    ps -axo pid,ppid,etime,command | grep -E 'swiftpm-testing-helper|xcodebuild|xctest|swift-build' | grep -v grep || true
    find .build -maxdepth 2 -name .lock -print 2>/dev/null || true
  } >"$diagnostic_file"

  if [ "$status" -ne 0 ]; then
    cat "$log_file"
    echo "Hang-guard run $run failed; diagnostics: $diagnostic_file" >&2
    exit "$status"
  fi

  new_helpers="$(comm -13 <(printf '%s\n' "$baseline_helpers") <(printf '%s\n' "$current_helpers"))"
  if [ -n "$new_helpers" ]; then
    cat "$log_file"
    echo "Hang-guard run $run left swiftpm-testing-helper processes: $new_helpers" >&2
    exit 1
  fi
done

echo "OK: $repeats guarded run(s) completed without timeout or stale helper"
