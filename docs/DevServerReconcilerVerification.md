# Dev Server Reconciler Verification

Status: implemented and automated by `Tests/BrowserE2E/counter-wasm-runtime-e2e.mjs`.

This runbook verifies the real `sweb dev` process, generated WASM package,
application worker, status endpoint, response headers, and browser runtime.
Unit-test success alone does not satisfy T8.

## Fixed build contract

| Input | Required value |
|---|---|
| Swift toolchain | `swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a` |
| Standard WASM SDK | `swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a_wasm` |
| `swift-html` | released package `0.15.0` |
| Browser | Playwright Chromium; WebKit is an optional additional smoke |

The E2E rewrites only the `swift-web` dependency to the local checkout. It
keeps `swift-html` as a remote versioned dependency so unpublished sibling
repository changes cannot make the verification pass.

## Automated gate

Run from the repository root:

```bash
export SWIFT_WEB_TOOLCHAIN_BIN="$HOME/Library/Developer/Toolchains/swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a.xctoolchain/usr/bin"
export SWIFTWEB_E2E_HOST_SWIFT_EXECUTABLE="$SWIFT_WEB_TOOLCHAIN_BIN/swift"
export SWIFT_WEB_WASM_SWIFT="$SWIFT_WEB_TOOLCHAIN_BIN/swift"
export SWIFT_WEB_WASM_TOOLCHAIN_BIN="$SWIFT_WEB_TOOLCHAIN_BIN"
export SWIFTWEB_E2E_TIMEOUT_MS=900000
export SWIFTWEB_E2E_HMR_TIMEOUT_MS=600000

cd Tests/BrowserE2E
npm run counter-wasm
```

The command must exit with status zero and report every phase below.

| Scenario | Automated phase/evidence | Acceptance condition |
|---|---|---|
| Edit during initial build | `reconciler.initial-build.edited` | Served HTML contains the edit and status converges to the latest fingerprint. |
| Syntax failure and recovery | `client.hmr.failure-rollback`, then `client.hmr.recover` | Status is `error` and stale while the old UI remains usable; restoring the serving fingerprint clears the failure without a rebuild and reaches `ready`. |
| Worker `SIGKILL` | `reconciler.worker-crash.recovered` | A new worker PID serves the same build fingerprint without a new build. |
| Timestamp-only touch | `reconciler.touch.no-rebuild` | Source/build fingerprints and worker PID remain unchanged. |
| Quiescent freshness | response and status assertions throughout | `X-SwiftWeb-Dev-Build`, `X-SwiftWeb-Dev-Source`, `sourceFingerprint`, and `servingFingerprint` match; stale is false. |
| Browser runtime | `wasm.ready` through `passed` | WASM hydration, same-type component identity, state, loading policies, ServerAction invalidation, generation-batched HMR rollback/recovery, injected DOM-command rollback, and page patching complete without a full reload on the normal path. An intercepted expired-generation `410` deliberately performs one full reload and converges to the latest runtime. |
| Long-lived HMR stream | Browser diagnostics after more than 30 seconds | The SSE response remains connected without incomplete-chunk or reconnect errors. |
| Shutdown | `postStopProcessCheck` in the JSON report | No generated worker or build process remains. |

The native transaction suite additionally executes a termination-resistant
process tree and verifies `timeout -> SIGTERM -> SIGKILL`,
`task cancellation -> SIGTERM -> SIGKILL`, normal leader-exit descendant
drain, and cancellation arriving during that drain across the process group, restores a
mixed set of existing/new build files, atomically switches an immutable WASM
generation through the `current` symlink, proves delayed events resolve their
own generation rather than the latest bytes, proves an open artifact descriptor
survives collection while a later request receives typed `410 Gone`, preserves live worker leases,
collects released history beyond eight generations, verifies shared-lock event
reads, and reads a multi-event append in order. Client runtime tests verify ABI
status/copy ownership, same-type sibling identity, per-component state
preservation, nested handler ownership, and zero partial DOM application when
a later runtime fails.

If a browser reconnects after its generation has already been collected, the
generation route returns `410 Gone`. The host script treats that status as an
explicit full-reload requirement instead of applying bytes from another
generation.

Generated application templates have a separate behavioral gate:

```bash
SWIFT_WEB_HOST_SWIFT="$SWIFT_WEB_TOOLCHAIN_BIN/swift" \
  ./scripts/verify-new-command-templates.sh
```

The gate runs real minimal and AI `sweb new` commands, resolves both generated
packages, and builds both with Xcode using the pinned toolchain.

## Manual status and header inspection

While `sweb dev` is quiescent, inspect the same build through both contracts:

```bash
curl -sS http://127.0.0.1:<port>/__dev/status
curl -sSI http://127.0.0.1:<port>/counter
```

The status must be `ready`, `stale` must be `false`, and these values must be
equal:

```text
status.sourceFingerprint
status.servingFingerprint
X-SwiftWeb-Dev-Source
X-SwiftWeb-Dev-Build
```

During an intentional syntax error, status must remain available with
`phase = error`, `stale = true`, and a non-empty `lastErrorSummary`. Repeating
the status request without editing source must not start another build. After
fixing the source, the fields must converge again without restarting `sweb`.

## Failure triage

| Observation | First evidence to collect |
|---|---|
| Initial edit is not served | Status fingerprints and `changesQueuedDuringTransition` log entry. |
| Repeated builds for one syntax error | Source fingerprint over time and repeated fast-path/build log count. |
| Worker does not relaunch | Worker exit status, crash count, and active worker PID list. |
| Headers disagree after ready | Full status JSON plus response headers from the same request window. |
| Browser trap | Browser stack, raw WASM artifact, and resolved `swift-html` revision. |

Do not mark T8 complete from declarations, generated package structure, or a
WASM link alone. The complete browser-visible process path must pass.
