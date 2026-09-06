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

## State, Ownership, and Lifecycle

All reconciler mutable state is isolated by `SwiftWebDevReconciler`, a Swift
actor. The transition task owns its builder and launcher work until completion,
cancellation, or failure. The materializer owns staged/backup root mechanics,
but may publish a replacement only after reconciler admission. The active
worker owns its executable process until replacement or shutdown stops it.

## Failure, Concurrency, and Constraints

Preparation and build failures remain observable and do not become successful
transitions. Application compile failure latches for its exact fingerprint to
avoid a hot loop. Wakes may race or coalesce, but actor isolation and the
single-flight transition guard preserve ordering. Deferring preparation must
not introduce a second queue, lock, or global state; `desired`,
`lastFastPathFingerprint`, and the terminal wake remain the convergence owners.

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
