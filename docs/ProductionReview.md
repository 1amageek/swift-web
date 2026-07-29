# Production Review

This record captures the P0/P1 release gate for the SwiftHTML 0.14 migration,
Client WASM runtime, and development reconciler. Declarations and compilation
are supporting evidence only; the release gate also requires native behavior
tests, a production Standard WASM build, and the Chromium end-to-end path.

## 0.8.0 release delta

| Area | Release change |
|---|---|
| Generic component storage | Storyboard containers, `Toggle`, and `DisclosureGroup` preserve their typed public builder APIs while storing executable content through SwiftHTML `ComponentContent`. |
| Released dependency | SwiftHTML `0.14.0` supplies the matching fixed runtime storage for modifiers and `ForEach`; the root lock resolves its published tag commit. |
| Concurrency | Application, service, and scene protocol metatypes satisfy the sendable-metatype contract used by Swift 6.4. |
| Release tooling | README, examples, CLI templates, Storyboard scaffolding, and browser E2E fixtures consistently target SwiftWeb `0.8.0` and SwiftHTML `0.14.0`. |

## Shared-state review matrix

| Logical state | Native storage / isolation | Standard WASM storage / isolation | Embedded WASM contract | Read / mutation entry points | Shutdown / owner release |
|---|---|---|---|---|---|
| Single-component client bridge | `Mutex<RuntimeState>` plus `ClientRuntimeAccessGate` | Same source and same two primitives | Same source contract; public browser materialization rejects Embedded before construction | `bootstrap`, `dispatch`, `snapshotState`, `restoreState`; DOM callbacks execute outside every mutex | Entrypoint owns bridge and response storage; no stream owner |
| Bundle client bridge | `Mutex<RuntimeState>`, one isolated `StateStore` per registered component, operation gate | Same source and isolation | Same source contract; browser profile rejects Embedded | Bootstrap stages fresh runtimes, merged state, atomic styles, and one DOM batch; the previous runtime set stays active on failure | Entrypoint owns all registered runtimes |
| WASM ABI response | `Mutex<Data>` | Same source; JS copies while the Swift lock is held | Same storage contract when compiled; browser profile remains unsupported | Operation stores response; `responseLength`, `copyResponse`, `freeResponse` | `freeResponse` clears owned data |
| Node and handler translation | Value-owned open-addressed arrays / sorted arrays | Identical storage, avoiding the Standard WASM `Dictionary` path | Identical value-owned storage | Bridge bootstrap/reconcile builds maps; dispatch performs lookup | Released with bridge runtime state |
| Dev desired package | `SwiftWebDevDesiredStateCoordinator` actor | Host-only | Not constructed | One preparation per source fingerprint; package and all Client WASM artifacts become ready together | Runtime cancellation leaves the last committed package active |
| Client WASM artifacts | Immutable generation directory plus atomically replaced `current` symlink; build outputs and stamps retain file snapshots until publication succeeds | Host builds Standard WASM | Embedded SDK rejected with typed error | Build and stage every runtime, atomically switch `current`, then append one `clientRuntimeBatchUpdate` whose asset URLs name that exact generation; the host validates metadata and opens the selected representation before streaming; build/event failure restores the previous symlink and build files | Workers lease their pinned generation; an already-open descriptor remains readable during collection, while a new request for an unleased collected generation receives typed `410 Gone` and performs an explicit full reload |
| Browser HMR generation | One shared promise queue plus captured manifest/runtime/hydration/hash and document root/head/body state | Same browser host script | Browser profile rejects Embedded | Every runtime in one event is staged before strict CSS and DOM commands run; any command failure restores HTML attributes, head, body, and the captured runtime generation | Superseded instances become unreachable after a successful batch commit |
| Build child process | `Mutex<State>` cancellation owner storing the process and verified process-group ID | Host-only | Not constructed | Timeout, cancellation, and normal leader exit drain the entire process group with `SIGTERM`, then `SIGKILL` after the configured grace period, even if the leader exits first; cancellation is rechecked after that drain | Bounded process-group exit wait and descendant termination precede controller release |
| Active worker target | `Mutex<State>` registry | Host-only | Not constructed | Crash transition clears active target before restart; proxy returns 503 until replacement | Runtime shutdown terminates the current worker |
| HMR event log | POSIX exclusive writer lock and shared reader lock | Host/worker file contract | Not constructed | Single or batched JSONL append; offset reader consumes complete records | File descriptor closes after every operation |
| Actor activation and UI gesture state | `Mutex<State>` in common source | Same source and primitive | Same source and primitive | Explicit locked helpers only; callbacks and I/O occur after lock release | Owner shutdown paths release or finish their streams |

No target branch replaces a `Mutex` or actor with raw mutable state. No
`nonisolated(unsafe)` or `@unchecked Sendable` escape is part of these paths.

## P0/P1 acceptance evidence

| Risk | Required behavioral evidence |
|---|---|
| Response lifetime and encode failure | Concurrent response writers/copies return one complete payload; ABI tests cover success (`0`), typed operation/encoding failure (`1`), rejected reentry (`2`), owned response copy/free, and Chromium execution. |
| Multi-component partial commit | A later component bootstrap failure produces zero DOM/style applications, does not commit the staged runtime set, and preserves every component's isolated state snapshot. |
| Same-type component identity | Two sibling instances of the same component type retain unique component paths and IDs during SSR, hydration, handler dispatch, state restore, and post-bootstrap updates. |
| Multi-artifact mixed generation | File rollback restores old files/removes newly created files; the production path publishes one generation event only after every runtime artifact succeeds. |
| Delayed generation replay and disk retention | A live HTTP host returns exact Brotli and identity bytes for generation-specific URLs, rejects a wrong hash with `409`, preserves an already-open descriptor across collection, and returns `410` for a new request after collection. Retention preserves a real worker-launch lease and collects it after process exit while bounding ordinary history to eight generations. |
| Cross-runtime browser consistency | One serialized event queue stages the complete runtime update batch, then commits styles, strict DOM commands, manifest, hydration index, hashes, and primary instance together; an injected command failure restores the exact document root/head/body state. |
| Nested client event ownership | A handler inside nested registered client components dispatches to the innermost runtime through a linear DOM ownership walk. |
| Worker crash gap | Registry test observes no active target while restarting; real `SIGKILL` E2E converges to a replacement PID. |
| Hung, cancelled, or normally completed builds | Timeout and task-cancellation tests prove that a child and descendant ignoring `SIGTERM` both reach `SIGKILL` before operation ownership is released. Normal leader exit also drains descendants, and cancellation arriving during that drain remains observable by the caller. |
| Large DOM mapping | 20,000-entry insert, lookup, inversion, and removal behavior test plus a 2,000-row real hydration rebase completes; child-position and boundary-marker remapping use single-pass/open-addressed indexes. |
| Generated template behavior | The reusable template gate runs real minimal and AI `sweb new` commands, resolves each generated package, and builds both with Xcode and the pinned Swift 6.4 toolchain. |
| Released dependency | Root lock, example manifests, generated scaffold fallback, and template output resolve SwiftHTML `0.14.0`; no implicit sibling fallback remains. Example lock files are intentionally omitted because they cannot pin the release commit before its tag exists. |

## Verification record

Verified on 2026-07-30 with
`swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a` and the matching
`swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a_wasm` SDK.

| Gate | Result |
|---|---|
| Native package tests | The complete `swift-web-Package` scheme passed with `xcodebuild test`, two build jobs, a bounded timeout, and no stale test helper. The directly changed SwiftWebUI, Storyboard scaffold, and CLI template suites also passed three guarded runs. |
| Standard WASM | Five release-configuration CounterApp runtimes built and linked from the released SwiftHTML `0.14.0` dependency. Chromium loaded the 58,194,616-byte eager runtime and every staged runtime. |
| Embedded capability | `SwiftWebCore` built with the matching Embedded WASM SDK, `SWIFTWEB_CORE_ONLY=1`, and default traits disabled so the unsupported external actor runtime remains outside the graph. |
| Storyboard Standard WASM | The generated Button Storyboard built, linked, and reached `data-wasm-ready="true"` with phase `ready` in the in-app browser; browser warnings and errors were empty. |
| Chromium end to end | Passed initial-build edit convergence, no-op touch, worker `SIGKILL` recovery, five runtime load policies, event dispatch, state-preserving HMR, injected transaction rollback, failed-build rollback/latching, exact-source recovery, server-page HMR, and an injected expired-generation `410` followed by an explicit full reload onto the latest runtime. |
| Browser diagnostics | Zero console errors, browser errors, HTTP failures, unexpected server log noise, and post-shutdown child processes. |
| Generated minimal and AI templates | `scripts/verify-new-command-templates.sh` passed real generation, dependency resolution, and Xcode builds for both templates. |
| Optional WebKit smoke | Skipped because the Playwright WebKit executable is not installed; this is not a required release gate. |
