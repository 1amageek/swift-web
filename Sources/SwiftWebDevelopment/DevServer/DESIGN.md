# SwiftWebDevServer

## Purpose and Scope

This module is the development-server child of the
[SwiftWeb package design](../../../DESIGN.md). It owns desired-state
convergence, generated-input admission, Native worker transitions, browser HMR
coordination, and terminal worker cleanup. It has no child design units.

The module does not own generated package replacement internals, WASM runtime
semantics, application Actor state, or browser-engine behavior.

## Responsibilities and Boundaries

`SwiftWebDevReconciler` derives desired state from source fingerprints and owns
the single active worker transition. `SwiftWebDevDesiredStateCoordinator`
prepares generated inputs, while the builder and launcher own compilation and
worker startup. The reconciler decides when preparation is safe; the package
materializer decides how a generated root is replaced transactionally.

The injected `SwiftWebDevHotReload` client owns one private HMR state per
browser document. That state owns its active fetch controller or `EventSource`
and any reconnect timer. Script replacement and the document's terminal
lifecycle signal are the only callers that close this owner; closing is
idempotent and terminal, so no callback may reconnect after it.

File-watcher and timer wakes are coalesced latency hints. Correctness comes
from re-reading the source fingerprint inside the reconciler actor.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [SwiftWeb package](../../../DESIGN.md) | parent | Toolchain, browser gate, and generated-root lifetime | Defines system-wide development and browser evidence. | A browser failure may expose a host lifecycle defect before browser startup. |
| [Package generation](../PackageGeneration/DESIGN.md) | depends on | Transactional generated-root replacement | Supplies prepared server and WASM package roots. | Replacement requires a quiescent consumer boundary. |
| [Development verification](../../../docs/DevServerReconcilerVerification.md) | used by | Actual `sweb dev` behavioral gate | Exercises convergence, HMR, browser runtime, and cleanup. | Unit tests do not replace the live process path. |

## Architecture

```text
watcher / timer / worker exit
           |
           v
  SwiftWebDevReconciler actor
    | desired fingerprint
    | one transitionTask
    | worker + failure latch
    |
    +-- quiescent --> fast-path preparation --> package materializer
    |
    `-- transition --> builder --> launcher --> ready worker swap
                              `--> terminal wake --> latest desired state

  browser document
    `-- injected HMR state --> native EventSource
          |                   `--> fetch-SSE / reload-poll capability fallbacks
          `-- terminal close <- replacement / non-persisted pagehide
```

## Contracts and Invariants

- At most one build, relaunch, or worker-replacement transition is active.
- An active transition owns every generated compiler/build input it consumes
  until `runTransition` reaches its terminal state.
- Fast-path preparation that may materialize the generated root runs only when
  no transition is active and shutdown does not own the process lifetime.
- A source change during a transition updates `desired` but does not advance
  `lastFastPathFingerprint`. The transition's terminal wake later prepares the
  latest desired fingerprint exactly once before starting its transition.
- Worker-crash handling retains precedence over the single-flight guard and
  current-source failure latch. A failed build remains latched until the source
  fingerprint changes.
- A ready replacement is published before the previous worker is stopped.
  Shutdown cancels and joins the active transition before stopping the worker.
- Each browser document owns exactly one current HMR connection state. A
  replacement script closes the previous state before publishing its successor.
- A non-persisted `pagehide` closes the current document state. Terminal close
  aborts the active fetch or closes the `EventSource`, cancels reconnect timers,
  settles any pending reconnect delay exactly once, and prevents every EOF, error, or delayed callback from opening another
  connection. It does not suppress genuine failures while the document is live.
- Chromium and WebKit use native `EventSource` when it is available. The user
  agent alone owns its `CONNECTING` reconnection and standard `Last-Event-ID`
  cursor; client code does not recreate an `EventSource` or add a retry timer.
- An unexpected native `CLOSED` state is terminal for that document owner. It
  permits at most one abortable request to the same events endpoint to observe
  the HTTP status, aborts the response body immediately after its headers are
  read, reloads only for the existing 401/403 session-change contract, and
  otherwise exposes the status failure without retrying. Closing the owner also
  aborts this probe.
- The streaming development host and the finite compatibility route accept an
  explicit `lastEventID` query cursor first and otherwise the standard
  `Last-Event-ID` header. Authentication is checked before cursor admission;
  neither failure nor reconnection exposes the development token.

## Runtime Flows

1. A wake causes the actor to re-read the desired source fingerprint and clear
   a stale failure latch when the fingerprint changed.
2. A stopped worker is handled before build-failure admission. If a transition
   or shutdown is active, convergence returns without preparing generated
   inputs.
3. At a quiescent boundary, the fast path prepares current generated inputs.
   The reconciler then either retains the current worker, respects the current
   failure latch, or starts one transition toward the desired fingerprint.
4. `runTransition` builds or reuses an executable, launches it, waits for
   readiness, and publishes the replacement. Its terminal path clears the
   transition and wakes convergence so changes observed while it ran are not
   lost.
5. The injected browser client selects native `EventSource` first. Its
   `CONNECTING` state keeps browser-owned reconnection, while unexpected
   `CLOSED` performs one status-only probe and then either reloads for 401/403
   or remains visibly terminal. Fetch-SSE is selected only when `EventSource`
   is unavailable, and reload-poll remains the final capability fallback.
6. Replacement or non-persisted `pagehide` closes the per-document owner. That
   close terminates the native source, a status probe, or a fallback fetch and
   settles any fallback reconnect delay without opening another request.

## State, Ownership, and Lifecycle

All reconciler mutable state is isolated by `SwiftWebDevReconciler`, a Swift
actor. The transition task owns its builder and launcher work until completion,
cancellation, or failure. The materializer owns staged/backup root mechanics,
but may publish a replacement only after reconciler admission. The active
worker owns its executable process until replacement or shutdown stops it.

Browser HMR connection state is document-local JavaScript state. The document
retains it until script replacement or terminal navigation; the state retains
only its connection handles, reconnect timer, event queue, and diagnostics.
Closing this owner neither shuts down the dev server nor changes Actor or WASM
runtime ownership.

## Failure, Concurrency, and Constraints

Preparation and build failures remain observable and do not become successful
transitions. Application compile failure latches for its exact fingerprint to
avoid a hot loop. Wakes may race or coalesce, but actor isolation and the
single-flight transition guard preserve ordering. Deferring preparation must
not introduce a second queue, lock, or global state; `desired`,
`lastFastPathFingerprint`, and the terminal wake remain the convergence owners.

A terminal browser abort is expected cleanup, not an HMR failure. It must not
be hidden by filtering diagnostics: correctness is the absence of any request
or reconnect attempt from the old document after terminal close. Live-document
HTTP, parsing, and event-application failures retain their existing diagnostics.

Transport failure never selects a lower capability fallback. Native
`EventSource` failure remains native-source failure; fetch-SSE and reload-poll
are selected only when the preceding browser API is absent. The one CLOSED
status probe distinguishes the existing authentication recovery from other
terminal failures without timing delays, error-string classification, or a
second source owner.

## Verification and Change Impact

`SwiftWebDevReconcilerTests` holds a build transition open, changes the source
fingerprint, and rejects any fast-path preparation for the new fingerprint
until that transition finishes. It then requires preparation and a follow-up
transition for the latest fingerprint. Existing crash, failure-latch, queued
edit, and shutdown tests preserve the surrounding state-machine contract.

The required `counter-wasm` Chromium and WebKit run is the live owner-level
gate: it must complete initial-build edits, HMR and crash recovery, both browser
paths, and process cleanup without moving generated inputs out from under an
active compiler. Changes to preparation order require rechecking package
generation and the parent package design.

Changes to browser HMR connection lifetime first require a focused generated-
script regression that rejects a reconnect after terminal close and checks
native-source selection, browser-owned `CONNECTING`, one terminal CLOSED status
probe, 401/403 reload, and capability-only fetch/reload-poll fallbacks. Host
tests must prove query/header cursor equivalence on both events routes. The
cached required Chromium and WebKit Counter gate then must complete Actor
mutation and reload persistence with no browser access-control, request,
console, or server diagnostics and no residual process or listener. A string-
presence assertion alone is not runtime proof of document-lifetime cleanup.
