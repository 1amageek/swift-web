# Dev Server Reconciler Verification

Status: implemented and automated by `Tests/BrowserE2E/counter-wasm-runtime-e2e.mjs`.

This runbook verifies the real `sweb dev` process, generated WASM package,
application worker, status endpoint, response headers, and browser runtime.
Unit-test success alone does not satisfy T8.

## Fixed build contract

| Input | Required value |
|---|---|
| Swift toolchain | `swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a` |
| Standard WASM SDK | `swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a_wasm` |
| `swift-html` | Released `0.16.1`, commit `573aba6454604780c07ad8a7aabd0e153423fe4b` |
| Browser | Playwright Chromium and WebKit; both are required |

The E2E rewrites only the `swift-web` dependency to the local checkout. The
example and SwiftWeb both declare `swift-html` with `from: "0.16.1"` in their
[manifests](../Package.swift); the release graph is recorded in
[resolved pins](../Package.resolved). Preserve the temporary CounterApp's
`Package.resolved` for the actual run; no local SwiftHTML sibling override is used.

The standard browser gate below is independent from Embedded verification.
See the [root design](../DESIGN.md#verification-and-change-impact) for profile
boundaries and [completed work](../PROGRESS.md) (`FIX-HTML` and
`FIX-EMBEDDED-HOST`) for the corrected Debug Embedded path and actual local-workerd
page/Actor evidence. That evidence does not claim Embedded browser execution,
live deployment, or a release-profile gate.

## Automated gate

With the pinned compiler selected and matching SDK installed, run from the
repository root. See [automatic discovery](Toolchain.md#automatic-discovery).

```bash
export SWIFTWEB_E2E_TIMEOUT_MS=900000
export SWIFTWEB_E2E_HMR_TIMEOUT_MS=600000

cd Tests/BrowserE2E
npm run install-webkit
npm run counter-wasm
```

Both `counter-wasm` and `counter-wasm:webkit` run the same required two-engine
gate. WebKit must launch and close before temporary app preparation or Swift
builds; missing or unlaunchable WebKit fails immediately. An explicit
`SWIFTWEB_E2E_REQUIRE_WEBKIT=1` without `SWIFTWEB_BROWSER_E2E=1` is a configuration
failure, not a skip. The command must exit with status zero and report every
phase below.

| Scenario | Automated phase/evidence | Acceptance condition |
|---|---|---|
| Edit during initial build | `reconciler.initial-build.edited` | Served HTML contains the edit and status converges to the latest fingerprint. |
| Syntax failure and recovery | `client.hmr.failure-rollback`, then `client.hmr.recover` | Status is `error` and stale while the old UI remains usable; restoring the serving fingerprint clears the failure without a rebuild and reaches `ready`. |
| Worker `SIGKILL` | `reconciler.worker-crash.recovered` | A new worker PID serves the same build fingerprint without a new build. |
| Timestamp-only touch | `reconciler.touch.no-rebuild` | Source/build fingerprints and worker PID remain unchanged. |
| Quiescent freshness | response and status assertions throughout | `X-SwiftWeb-Dev-Build`, `X-SwiftWeb-Dev-Source`, `sourceFingerprint`, and `servingFingerprint` match; stale is false. |
| Browser runtime | `wasm.ready` through `passed` | WASM hydration, same-type component identity, state, loading policies, ServerAction invalidation, generation-batched HMR rollback/recovery, injected DOM-command rollback, and page patching complete without a full reload on the normal path. An intercepted expired-generation `410` deliberately performs one full reload and converges to the latest runtime. |
| Required WebKit | `webkit.preflight.passed`, `webkit.ready`, `webkit.actor.incremented`, `webkit.actor.persisted`, `webkit.passed` | After the unchanged full Chromium suite, WebKit waits for eager hydration and the scheduled idle bundle, increments the current Native Actor baseline through the client without changing a window marker, reloads, and sees the incremented server-rendered value. Eager-plus-idle readiness is required again before reporting and closing; browser diagnostics and cleanup remain required. |
| Long-lived HMR stream | Browser diagnostics after more than 30 seconds | The SSE response remains connected without incomplete-chunk or reconnect errors. |
| Shutdown | `postStopProcessCheck` in the JSON report | No generated worker or build process remains. |

The native transaction suite additionally executes a termination-resistant
process tree and verifies `timeout -> SIGTERM -> SIGKILL`,
`task cancellation -> SIGTERM -> SIGKILL`, normal leader-exit descendant
drain, owner exit while a descendant is in an independent process group, and
cancellation arriving during that drain, restores a
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

Generated application templates have a separate behavioral gate. This script
requires an explicit compiler path to avoid its machine-specific default; adjust
the path below to your installation:

```bash
SWIFT_WEB_HOST_SWIFT="$HOME/Library/Developer/Toolchains/swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a.xctoolchain/usr/bin/swift" \
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
