# Dev Server Reconciler Design

Status: approved design, not yet implemented.
Baseline: swift-web `8e893b7`. All `file:line` references below are against this
commit and may drift; treat them as anchors, not exact coordinates.

This document is self-contained: an implementer should not need the original
review conversation. Section 12 is the task breakdown for implementation
agents; Section 2 defines the vocabulary the rest of the document uses.

---

## 1. Problem statement

`sweb dev` hot reload is **edge-triggered**: a pipeline carries change events
(`FSEvents → classify → build → swap`) and nothing in the system records the
two facts that matter — *what state the source tree is in* and *what state the
running worker was built from*. Every observed failure is a lost-edge symptom
of that single design decision:

| Symptom (all observed in real use) | Mechanism | Anchor |
|---|---|---|
| Edits made while the initial build runs are silently discarded; the server keeps serving pre-edit output forever | `watcher.discardPendingChanges()` wipes the pending diff after first readiness | `SwiftWebDevRuntime.swift:136` |
| A compile error during hot reload kills the whole `sweb dev` process; every later edit does nothing | build error rethrown out of the run loop | `SwiftWebDevRuntime.swift:363-384`, caught and rethrown at `:178-183` |
| A missed FSEvents delivery silences change detection permanently | snapshot reconcile happens only on FSEvents callback; no periodic fallback, no stream-death detection | `SwiftWebDevFileChangeWatcher.swift:47-63` |
| A crashed worker is not restarted until the next file edit | crash path only marks unavailable and "waits for changes" | `SwiftWebDevRuntime.swift:165-176` |
| "ready reloaded" does not mean the latest edit is live | rebuild is a 1–3 min synchronous window; edits landing inside it are picked up one loop later, but the log/status cannot express "serving X, sources at Y" | `SwiftWebDevRuntime.swift:138-177` |
| No way to verify freshness | neither the worker nor the host reports which source state a response was built from | — |

Secondary costs (kept as later phases, not the core rewrite):

| Cost | Anchor |
|---|---|
| Every changed-file set re-materializes the generated packages and re-parses **all** app sources with SwiftSyntax, even for `.css`-only changes | `SwiftWebDevRuntime.swift:141`, `SwiftWebGeneratedPackageMaterializer.swift:286-341, 458-509` |
| Every server rebuild spawns `swift build` twice (build + `--show-bin-path`) | `SwiftWebDevServerProcess.swift:81-109` |
| SSE polling re-reads and re-decodes the whole `hmr-events.jsonl` every 300 ms (O(n²) over a session) | `SwiftWebDevEventLog.swift:58-82`, `SwiftWebDevHostHTTPHandler.swift:160-177` |
| CSS embedded in Swift string literals cannot use the style HMR fast path; every CSS tweak is a full server rebuild | `SwiftWebDevChangeClassifier.swift:70-77` (only `.css` files are style-patched) |

## 2. Core idea: two loops — fast feedback (edge) + slow truth (level)

Replace the event pipeline with a **reconciliation loop** whose only job is to
converge `actual` (the running worker) toward `desired` (the source tree):

```
                 ┌────────────────────── wake hints ──────────────────────┐
                 │  FSEvents callback   periodic timer (2 s)              │
                 │  build finished      worker process exited             │
                 └────────────────────────┬───────────────────────────────┘
                                          ▼
   desired  = SourceFingerprint(watched tree)          ← recomputed on wake (stat-scan)
   actual   = fingerprint the active worker was built from
   converge:  desired == actual && worker alive  →  nothing to do
              otherwise                          →  build / relaunch / report
```

Edge signals (FSEvents, SSE style patches, WASM HMR) remain — but only as
**latency optimizations**. Correctness comes exclusively from the level loop.
A dropped event now costs at most one timer period (2 s), not permanent
staleness. `discardPendingChanges`, the initial-build special case, and the
"wait for changes after crash" path all disappear *structurally*: there is no
edge to lose.

The two-loop split also resolves an existing dev/prod divergence: today a
pure-`ClientComponent` edit triggers WASM HMR but never rebuilds the server,
so SSR output for that component stays stale indefinitely. Under this design
the WASM HMR still fires instantly (fast loop), and the reconciler
independently notices server-fingerprint drift and rebuilds in the background
(slow loop); blue/green swap makes the rebuild invisible.

### Non-goals

- No dylib / interpreter hot-swap of server code. Considered and rejected:
  Swift ABI, global state, and actor-runtime initialization make in-process
  code replacement fragile. The compiled binary + blue/green port swap stays.
- No change to the WASM HMR build path (`SwiftWebDevBuildProcess`,
  `SwiftWebDevWasmArtifactCache`) beyond how it is invoked.
- No change to the SSE wire protocol or the injected client script in Phase 1.

## 3. SourceFingerprint

New file: `Sources/SwiftWebDevelopment/DevServer/SwiftWebDevSourceFingerprint.swift`

```swift
package struct SwiftWebDevSourceFingerprint: Sendable, Equatable, Hashable,
    CustomStringConvertible {
  /// Full SHA-256 hex over the manifest (see below). Equality uses this.
  package let digest: String
  package let fileCount: Int
  /// First 12 hex chars, used in logs, headers, and status payloads.
  package var short: String { String(digest.prefix(12)) }
  package var description: String { short }
}
```

Computation (`SwiftWebDevSourceFingerprintScanner`, same file family — keep
one type per file per repo convention, so the scanner is its own file):

1. Walk the same roots the watcher walks (app package + local dependency
   roots), with the same exclusions (`.build`, `.git`, `.swiftweb`,
   `.swiftpm`, `DerivedData`) and the same inclusion filter
   (`Package.swift`, `*.swift`, `css/json/html/leaf`) — reuse or extract the
   logic currently in `SwiftWebDevFileChangeWatcher.swift:348-411` so watcher
   and fingerprint can never disagree.
2. **Exclude `Package.resolved`** everywhere, as an explicit invariant. It is
   an *output* of dependency resolution (rewritten by `swift build` /
   `swift package resolve`), not a build input. Implementation note
   (verified during T1): its `resolved` extension was never in the watched
   set, so this exclusion is defensive — it keeps the invariant true even if
   the watched-extension list grows. It also means `discardPendingChanges()`
   has **no known legitimate trigger**: builds write only into excluded
   directories (`.build`, `.swiftweb`), so the discard only ever swallows
   real user edits.
3. Per file compute `contentHash = SHA-256(bytes)`, cached in
   `Mutex<[String: CachedFileHash]>` keyed by absolute path where
   `CachedFileHash = (mtimeNanoseconds, size, hash)`. A scan whose
   (mtime, size) stamps all match is stat-only and takes milliseconds; only
   changed files are re-read. (Known limitation: a content change that
   preserves both nanosecond mtime and size returns the stale hash. On APFS
   this is not reachable in practice; document, do not defend against.)
4. `digest = SHA-256` over `sorted lines of "\(relativeRootedPath)\u{0}\(contentHash)\n"`.

Use `Crypto` (swift-crypto is already in the dependency graph — see
`swift-crypto_Crypto` in build logs). `Mutex` (Synchronization) is correct
here per repo concurrency rules: memory-only, high-frequency, no suspension.

Consequences worth tests:
- `touch` (content unchanged) produces the **same** fingerprint → no rebuild.
  This is a behavior *improvement* over mtime-based systems.
- Fingerprint is order- and timing-independent → deterministic across runs.

## 4. Reconciler

New file: `Sources/SwiftWebDevelopment/DevServer/SwiftWebDevReconciler.swift`

An `actor` (repo rule: I/O + ordering ⇒ actor). It owns all mutable dev-loop
state; `SwiftWebDevRuntime.run()` shrinks to bootstrap + `await reconciler.run()`.

### 4.1 State

```swift
package actor SwiftWebDevReconciler {
  private var desired: SwiftWebDevSourceFingerprint
  private var worker: WorkerState                    // .none / .running(process, fingerprint)
  private var building: SwiftWebDevSourceFingerprint?
  private var lastFailure: BuildFailure?             // (fingerprint, summary, fullLogPath)
  private var crashHistory: [Date]                   // sliding window for crash-loop latch
}
```

### 4.2 Wake sources

A single `AsyncStream<Void>` with `bufferingPolicy: .bufferingNewest(1)`
(wakes coalesce; the loop re-derives everything from state, so one wake is as
good as ten). Producers:

- FSEvents callback (existing `SwiftWebDevFileEventStream`, unchanged).
- A timer `Task` yielding every 2 s — **the correctness backstop**. FSEvents
  becomes purely a latency optimization.
- Build-task completion (success or failure).
- Worker process termination (`Process.terminationHandler`).

Repo rule: the type exposing the stream implements `shutdown()` which calls
`continuation.finish()`; the reconciler loop exits when the stream finishes.

### 4.3 Convergence algorithm

```
for await _ in wakes { await converge() }

converge():
  desired = scanner.fingerprint()                  // stat-scan; hashes only changed files
  emitFastPathEvents()                             // §4.6 — stylePatch / wasm HMR, best effort
  if building != nil            → return           // single-flight; completion wakes us
  if lastFailure?.fingerprint == desired
                                → status(.failed)  // wait: only a source change can help
                                  return
  switch worker:
    .running(let p, let fp) where p.isRunning && fp == desired
                                → status(.serving); return
    .running(let p, let fp) where !p.isRunning
                                → handleCrash(fp)  // §4.5
                                  return
    .running(_, let fp)         → startBuild(for: desired, replacing: fp)
    .none                       → startBuild(for: desired, replacing: nil)
```

`startBuild` snapshots the fingerprint it is building **before** launching the
build and runs the build in a child `Task` (the actor stays responsive):

```
startBuild(for: fp):
  building = fp
  status(.building, from: servingFingerprint, to: fp)
  Task {
    do {
      let executable = try await builder.build()           // §5
      let next = try await launcher.launch(executable, fingerprint: fp)  // new port
      try await launcher.waitReady(next)
      registry.activate(next)                              // blue/green swap
      old?.stop()
      worker = .running(next, fp); lastFailure = nil; crashHistory = []
      eventLog.append(.serverRestarted)
      log("serve \(fp.short) (was \(previous?.short ?? "none"))")
    } catch {
      lastFailure = BuildFailure(fingerprint: fp, error: error)
      registry.markError(...); eventLog.append(.error(...))
      log("error build failed for \(fp.short): \(firstLine)")
    }
    building = nil
    wake()                                                 // desired may have moved on
  }
```

Properties that fall out (each maps to a Section 1 symptom, each gets a test):

1. **Edit during any build** (including the very first): after completion the
   final `wake()` observes `desired != actual` and immediately builds again.
   llbuild incremental compilation makes the second pass cheap. On swap, if
   `desired != builtFingerprint`, log
   `note N changes arrived during build — rebuilding for <fp>` so nobody
   misreads "serve" as "latest".
2. **Build failure** is a *state* (`lastFailure`), not an exception escaping
   the loop. `sweb dev` never exits because app code does not compile. The
   failure latch (`lastFailure.fingerprint == desired`) prevents hot-looping
   on the same broken tree; any source change clears it by construction.
3. **No cancellation of in-flight builds.** Finishing an incremental build and
   immediately running the next is faster and simpler than cancel/restart.
4. **The initial build is not a special case.** Bootstrap starts the
   reconciler with `worker = .none`; the first converge builds. All
   initialization-window bugs (F1) are unrepresentable.

### 4.4 Bootstrap and configuration errors

`SwiftWebDevRuntime.run()` keeps throwing for *environment* errors that no
file edit can fix (missing `Package.swift`, port already bound, dev host
failed to start, initial WASM runtime build failure — preserve current
behavior at `SwiftWebDevRuntime.swift:26-35, 89-135`). Everything downstream
of "the dev host is listening" is reconciler state, never a process exit.

### 4.5 Worker crash policy

`handleCrash(fp)`: the executable for `fp` already exists — **relaunch without
rebuilding**. Append to `crashHistory`; if ≥ 3 crashes within 60 s, set
`lastFailure = (fp, "worker crashed repeatedly", …)` and stop relaunching
until sources change (crash-loop breaker). This replaces the current
"mark unavailable and wait for an edit" behavior.

### 4.6 Fast-path events (edge loop)

The scanner exposes the per-wake changed-path diff (it computes it anyway to
know which files to re-hash). From that diff:

- `.css` changes → emit `stylePatch` SSE events exactly as today
  (`SwiftWebDevRuntime.swift:264-295` logic moves here unchanged).
- Client-component `.swift` changes → schedule the WASM HMR build exactly as
  today (`:297-336`), still serialized behind the reconciler (WASM builds and
  server builds share the loop; keep it simple — one build at a time total).
- Classification still uses `SwiftWebDevChangeClassifier` /
  `SwiftWebDevSwiftFileClassifier`, both unchanged.

These paths are **best effort**: if any of them error, log + SSE error event
and continue. The server fingerprint still covers the same files, so the slow
loop guarantees the served binary eventually reflects them regardless.

Materialization moves out of the wake path: `materialize()` runs inside
`builder.build()` (it is build preparation), not on every change. A css-only
save no longer re-materializes anything. (Full discovery caching is Phase 3;
this reordering alone removes the per-save constant cost for style edits.)

## 5. Worker build/launch split

`SwiftWebDevServerProcess` currently couples "build the executable" and "run
it" in `start()` (`SwiftWebDevServerProcess.swift:28-60, 81-109`). Split it —
this enables crash-relaunch-without-rebuild (§4.5), bin-path caching, and
testable seams:

```swift
package protocol SwiftWebDevWorkerBuilding: Sendable {
  /// Materializes the generated packages and builds the dev server product.
  /// Returns the executable URL. Throws SwiftWebDevRuntimeError on failure
  /// with the captured compiler output attached.
  func build() async throws -> URL
}

package protocol SwiftWebDevWorkerLaunching: Sendable {
  func launch(executable: URL, fingerprint: SwiftWebDevSourceFingerprint)
      async throws -> SwiftWebDevWorkerHandle
  func waitReady(_ handle: SwiftWebDevWorkerHandle) async throws
}
```

Concrete types wrap the existing `SwiftWebDevServerProcess` internals:
process spawning, env preparation (`:215-263`), port allocation, readiness
probe. The reconciler depends only on the protocols (repo rule: protocol-
oriented, dependency-injected — this is what makes §10's unit tests possible).

Changes inside the builder:
- Query `--show-bin-path` **once per process lifetime** per
  (packageDirectory, scratchDirectory) pair and cache it (`Mutex` cache).
  The path is configuration-derived and stable; nuking `.build` does not
  change it.
- `launch` must pass two new environment variables (§6).
- `Process.terminationHandler` wired to the reconciler's wake stream.

## 6. Observability contract

This section is a *contract*: agents and humans must be able to answer "is
what I'm looking at built from my current sources?" without grepping logs.

### 6.1 Response headers

- Worker: every response in dev mode carries
  `X-SwiftWeb-Dev-Build: <fingerprint.short>`.
  Implementation: the worker receives `SWIFT_WEB_DEV_BUILD_FINGERPRINT` in its
  environment (set by the launcher); the development hooks layer
  (`SwiftWebDevelopmentHooks`, where `SWIFT_WEB_DEV` is already read —
  `SwiftWebDevHotReload.swift:12-18`) adds the header alongside the existing
  dev token header.
- Dev host: after proxying (`SwiftWebDevHostHTTPHandler.swift:239-310`), add
  `X-SwiftWeb-Dev-Source: <desired.short>` and
  `X-SwiftWeb-Dev-Stale: true|false` (desired vs. the serving fingerprint the
  registry reports). One `curl -I` now settles every staleness question.

### 6.2 `/__dev/status`

Extend `SwiftWebDevHostStatus` (`SwiftWebDevHostStatus.swift`) with optional
fields so the existing readiness probe (`SwiftWebDevHostReadiness.swift:40-70`
decodes this type) stays compatible:

```jsonc
{
  "phase": "serving" | "building" | "failed" | "starting",
  "message": "…", "detail": "…",
  "activeWorkerURL": "http://127.0.0.1:PORT",
  // new, all optional:
  "sourceFingerprint": "d4e5f6a1b2c3",
  "servingFingerprint": "a1b2c3d4e5f6",
  "buildingFingerprint": null,
  "stale": true,
  "pendingPaths": ["Sources/App/Style.swift"],   // ≤ 20 entries
  "queuedChangeCount": 3,
  "lastErrorSummary": "…first compiler error line…",
  "lastErrorLogPath": "/tmp/swiftweb-dev-build-….log"
}
```

The registry (`SwiftWebDevWorkerRegistry`) grows fingerprint fields; it stays
a `Mutex`-guarded value store (correct per repo rules: no I/O, no ordering).

### 6.3 Console log

Log lines become state transitions, formatted by the existing console logging
(`SwiftWebDevConsoleLogging`):

```
change  3 files  sources=d4e5f6  (Sources/…/EventCalendarStyle.swift, …)
build   server d4e5f6 starting
build   server d4e5f6 completed in 74s
serve   d4e5f6 (was a1b2c3)
note    2 changes arrived during build — rebuilding for f0e1d2
error   build failed for d4e5f6: …first error line…  (log: /tmp/…)
crash   worker exited (status 4); relaunching a1b2c3
```

The browser status pill (`SwiftWebDevHotReload.swift` client script) already
renders phases; add a "stale — rebuilding" presentation driven by the status
payload. No SSE protocol change.

## 7. Watcher changes

`SwiftWebDevFileChangeWatcher` mostly survives:

- **Delete** `discardPendingChanges()` (`SwiftWebDevFileChangeWatcher.swift:85-91`)
  and its call site (`SwiftWebDevRuntime.swift:136`). Nothing replaces it:
  builds write only into excluded directories and `Package.resolved` is
  outside the watched set (see §3), so there is no init-window churn to
  swallow — the discard only ever dropped real user edits, and the
  reconciler converges on those instead.
- The FSEvents stream's callback now feeds the reconciler wake stream.
- The snapshot/diff machinery (`SwiftWebDevFileSnapshot`) merges with the
  fingerprint scanner (§3) so there is exactly one definition of "watched
  file". The watcher keeps producing `[SwiftWebDevFileChange]` diffs for
  fast-path classification (§4.6); the scanner produces the fingerprint.
  They share the walk.
- Fix the composite-key smell while merging: snapshot keys are
  `"\(root.path):\(path)"` string concatenations split on `:`
  (`SwiftWebDevFileChangeWatcher.swift:292, 330`); replace with a proper
  key struct.

## 8. Event log fix (small enough to include in Phase 1)

`events(after:)` re-reads and re-decodes the entire file per 300 ms poll
(`SwiftWebDevEventLog.swift:58-82`). Keep the JSONL file (workers read it via
env path), but make the host-side reader remember its byte offset per stream
and only decode appended data. This is a contained change with its own test.

## 9. Phase 2 — Stylesheet as a first-class resource

The framework currently makes "CSS in a Swift string" the path of least
resistance, which is why app CSS misses the style-HMR fast path entirely.
Give CSS a supported home:

```swift
// App code:
public struct Stylesheet: Sendable {
  public init(_ name: String, bundle: Bundle = .module)
}
// Rendering emits: <link rel="stylesheet" href="/__swiftweb/styles/<name>.css?v=<contentHash>">
```

- **Dev**: the runtime passes the app's resource roots to the worker
  (`SWIFT_WEB_DEV_STYLE_ROOTS`); a dev-only route serves the `.css` straight
  from the source tree. A `.css` edit hits the existing `stylePatch` SSE path
  (instant, zero rebuild) *and* the fingerprint (background rebuild keeps the
  embedded copy honest for prod parity).
- **Release**: the file is a SwiftPM resource; a static route serves it from
  the bundle with `immutable` caching; `?v=<contentHash>` busts caches.
- Migration guide: move app-embedded CSS strings (the JapanEventCalendar
  `EventCalendarStyle.swift` pattern) into `Resources/*.css`.

Design freedom is intentionally left on exact route naming and the
`Stylesheet` render integration — the implementing agent should follow
existing static-asset routing conventions in `SwiftWebHost`.

## 10. Phase 3 — build-cost reductions

1. **Discovery caching.** `materializeUnlocked` re-parses every app source
   with SwiftSyntax on each build (`SwiftWebGeneratedPackageMaterializer.swift:286-341,
   458-509`). Key per-file discovery results
   (client components, environment keys, server-runtime surface) by the
   file's content hash — the fingerprint cache (§3) already has the hashes.
   Re-parse only changed files.
2. **Single `swift build` invocation** per rebuild (bin-path cached, §5).
3. Optional: skip `materialize()` when the previous generated output's input
   set is fingerprint-identical (write the input fingerprint into
   `.swiftweb/generated/…/materialize-stamp.json`).

## 11. Phase 4 (optional) — DOM morphing instead of full reload

The injected client already handles a `pagePatch` SSE kind
(`SwiftWebDevHotReload.swift:481-492`) but nothing emits it. After a swap, the
dev host can fetch the browser's current page from the new worker and emit
`pagePatch`; the client morphs the DOM using swift-html's existing
HTMLDiff/HTMLGraph machinery, preserving scroll and form state. Requires the
host to know the page URL per SSE subscriber (send it as a query param on the
events request). Explicitly out of scope until Phases 1–3 land.

## 12. Implementation plan (agent task breakdown)

Interface contracts agents must share are all in this document (§3 types,
§5 protocols, §6 schema). Repo-wide rules apply: English-only code and
comments, one primary type per file, typed errors and no `try?`, no silent
fallbacks, actors for I/O+ordering / `Mutex` for hot value state,
`AsyncStream` owners implement `shutdown()`.

| ID | Task | Files (new / touched) | Depends on | Acceptance criteria |
|---|---|---|---|---|
| T1 | `SwiftWebDevSourceFingerprint` + scanner + hash cache | new: `SwiftWebDevSourceFingerprint.swift`, `SwiftWebDevSourceFingerprintScanner.swift`; touched: extract shared walk/filter from `SwiftWebDevFileChangeWatcher.swift` | — | Unit tests: determinism; order independence; `Package.resolved`/`.build` exclusion; touch-same-content ⇒ equal; content change ⇒ different; stat-only rescan is fast path (assert no re-read via injected file-reader spy) |
| T2 | Builder/launcher split + bin-path cache + build-log capture | new: `SwiftWebDevWorkerBuilder.swift`, `SwiftWebDevWorkerLauncher.swift`, `SwiftWebDevWorkerHandle.swift`; touched: `SwiftWebDevServerProcess.swift` (dismantled into the above) | — | `--show-bin-path` invoked once across N builds (spy test); launch env contains `SWIFT_WEB_DEV_BUILD_FINGERPRINT`; build failure surfaces first error line + log path in the thrown error |
| T3 | `SwiftWebDevReconciler` actor + wake stream + crash policy | new: `SwiftWebDevReconciler.swift`, `SwiftWebDevReconcilerWake.swift` | T1, T2 (protocols only) | Unit tests with fake builder/launcher covering: edit-during-initial-build converges to latest; build failure ⇒ `.failed` state, loop alive, next edit rebuilds; same-fingerprint failure does not hot-loop; crash ⇒ relaunch without rebuild; 3 crashes/60 s ⇒ latched failure; timer-only wake (no FSEvents) converges; no build when fingerprint unchanged |
| T4 | Runtime rewire: bootstrap → reconciler; delete discard; fast-path events move | touched: `SwiftWebDevRuntime.swift` (run loop replaced), `SwiftWebDevFileChangeWatcher.swift` (delete `discardPendingChanges`, key struct fix, wake hookup) | T3 | `sweb dev` behaves per §4.4 (config errors still exit; compile errors never exit); style/wasm fast paths still emit the same SSE kinds (existing `SwiftWebDevHMRTests` patterns extended) |
| T5 | Status schema + host stale headers | touched: `SwiftWebDevHostStatus.swift`, `SwiftWebDevWorkerRegistry.swift`, `SwiftWebDevHostHTTPHandler.swift` | T3 | `/__dev/status` returns new fields; old fields unchanged (readiness probe still decodes); proxied responses carry `X-SwiftWeb-Dev-Source` + `X-SwiftWeb-Dev-Stale`; 503 body while `.failed` includes error summary |
| T6 | Worker build header via development hooks | touched: `SwiftWebDevelopmentHooks` (where `SWIFT_WEB_DEV` env is read) | T2 | Every worker response in dev carries `X-SwiftWeb-Dev-Build`; absent in non-dev |
| T7 | Event log offset reader | touched: `SwiftWebDevEventLog.swift`, host handler SSE loop | — | Appending N events costs O(new bytes) per poll (test with reader spy); SSE resume via `lastEventID` still works |
| T8 | Scenario verification runbook | new: `docs/DevServerReconcilerVerification.md` | T4–T6 | Scripted manual scenarios: (a) edit during initial build → converges; (b) introduce syntax error → `failed` status, fix → recovers; (c) `kill -9` worker → auto relaunch; (d) `touch` → no rebuild; (e) `curl -I` shows matching build/source fingerprints after quiesce |
| T9 (P2) | `Stylesheet` resource + dev route + stylePatch wiring | per §9 | T4 | `.css` edit reflects in browser < 1 s without server rebuild; release build serves from bundle |
| T10 (P3) | Discovery cache + materialize stamp | per §10 | T1, T4 | Rebuild after single-file edit re-parses exactly one file (spy test) |

Suggested parallelization: T1, T2, T7 have no interdependencies; T3 needs only
the *interfaces* of T1/T2; T5/T6 can start once T3's state shape is fixed.

Testing note: existing dev-server tests live in `Tests/SwiftWebTests`
(`SwiftWebDevHMRTests.swift` etc.) — follow their patterns. Run test suites
fine-grained (per suite/case), always with a timeout.

## 13. Compatibility notes

- `SwiftWebDevRuntimeConfiguration`, CLI flags, generated package layout,
  SSE event kinds, and the injected client script are unchanged in Phase 1.
- `/__swiftweb/dev/reload` (60 s long-poll fallback,
  `SwiftWebDevHostHTTPHandler.swift:193-237`) is untouched in Phase 1;
  fold into Phase 3 cleanup (align host behavior with the worker-side route
  or remove the host copy once the fetch-stream path is deemed universal).
- Anything currently reading `SwiftWebDevHostStatus` keeps working (additive
  optional fields only).
