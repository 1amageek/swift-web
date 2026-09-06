# SwiftWeb

## Purpose and Scope

SwiftWeb is the system package for server-rendered Swift applications and
optional Swift WASM browser runtimes. This document is the package-level master
for the 0.12.0 release.

The package root has three directly maintained design children:

- [Package generation](Sources/SwiftWebDevelopment/PackageGeneration/DESIGN.md)
  owns generated package materialization and runtime source mirroring.
- [Actor integration](Sources/SwiftWebRuntime/Actors/DESIGN.md) owns the
  SwiftWeb-facing Distributed Actor boundary.
- [Client runtime](Sources/SwiftWebBrowser/ClientRuntime/DESIGN.md) owns
  browser callback scheduling, state reconciliation, and terminal detachment.

The package root does not replace the module README files or the external
dependency contracts they reference.

## Responsibilities and Boundaries

The package manifest owns the SwiftPM dependency graph, package products,
platform minimum, and target composition. The package's modules own rendering,
browser state, host adapters, development orchestration, package generation,
and actor integration within their existing module boundaries.

The package does not own the internals of SwiftHTML, swift-actor-system,
swift-tls, or swift-tls-nio; each remains an independently released package.
Deployment adapters and cloud lifecycle are outside this package's runtime
proof boundary.

## Related Designs

| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [Package generation](Sources/SwiftWebDevelopment/PackageGeneration/DESIGN.md) | child | Materializes server, development, and WASM packages | Re-check source-owner lookup when dependency layout changes. |
| [Actor integration](Sources/SwiftWebRuntime/Actors/DESIGN.md) | child | Binds concrete Distributed Actors to SwiftWeb hosts and generated clients | Actor runtime ownership remains in the standalone package. |
| [Client runtime](Sources/SwiftWebBrowser/ClientRuntime/DESIGN.md) | child | Owns browser callback scheduling and callback lifetime | Re-check callback detachment and profile parity when runtime lifecycle changes. |
| [SwiftWebDevelopment facade](Sources/SwiftWebDevelopment/Facade/README.md) | used by child | CLI-facing development lifecycle | The facade does not own generated source contents. |
| [SwiftWebCore](Sources/SwiftWebRuntime/Core/README.md) | sibling module | Rendering and request/runtime boundary | Keep host and browser ownership separate. |
| [Adapter contract](docs/AdapterContract.md) | used by package and CLI | Schema-version-3 adapter discovery and service bindings | A Service build unit is not automatically an Actor API. |
| [Toolchain contract](docs/Toolchain.md) | package constraint | Pinned Swift 6.4 host and WASM SDKs | Toolchain, SDK, and target are one build contract. |
| [HTML authoring model](docs/HTMLAuthoringModel.md) | depends on | SwiftHTML document and component surface | Rendering semantics belong to SwiftHTML. |

## Architecture

```mermaid
flowchart TD
  App["Application Package.swift"] --> Graph["Resolved SwiftPM graph"]
  Graph --> HTML["SwiftHTML 0.16.x"]
  Graph --> Actor["swift-actor-system 0.1.x"]
  Graph --> TLS["swift-tls 2.1.x + swift-tls-nio 0.1.x"]
  Graph --> Modules["SwiftWeb modules"]
  Modules --> Host["Native host products"]
  Modules --> Generator["SwiftWebPackageGeneration"]
  Generator --> Generated["Generated server/dev/WASM packages"]
  Actor --> Resolved["Resolved checkout source owner"]
  Resolved --> Generated
```

Native targets link the released package products. Generated standard and
Embedded WASM packages copy only the runtime source targets required by their
profile from the resolved checkouts; they do not link the host-only graph.

## Contracts and Invariants

| Boundary | Assumption | Guarantee |
|---|---|---|
| SwiftPM graph | Dependencies resolve from their public repositories | The root manifest has no local-path or revision dependency for release packages. |
| Platform | The host is macOS 26.2 or newer | The package and generated host consumers use the same minimum platform. |
| Toolchain | The pinned Swift 6.4 snapshot and matching SDKs are selected | Host, standard WASM, and Embedded WASM evidence is attributed only to that tuple. |
| Actor source ownership | SwiftPM resolves `swift-actor-system` | SwiftWeb has no vendored Actor source tree; generation mirrors the resolved checkout. |
| WASM projection | The selected profile supplies its required actor targets | Standard uses `ActorSystemCore` plus `ActorSystemDistributed`; Embedded uses `ActorSystemCore` plus `ActorSystemEmbedded`. |
| Public surface | The release changes package ownership and dependency versions only | Existing Distributed Actor, scene binding, `ActorGroup`, `@RemoteActor`, HTTP, WSS, and generated-package APIs remain unchanged. |

An absent runtime source or an invalid resolved graph is a materialization
failure. It is never replaced with an empty or pseudo-runtime source set.

## Runtime Flows

1. SwiftPM resolves the application graph and records `Package.resolved`.
2. The development materializer discovers the resolved SwiftWeb and SwiftHTML
   roots, then locates the Actor targets from the same dependency context.
3. The materializer writes isolated server, development, and profile-specific
   WASM packages.
4. Native hosts serve rendered documents; standard WASM performs browser
   hydration and state reconciliation; Embedded WASM uses the generated actor
   projection where its target supports it.

## State, Ownership, and Lifecycle

The application owns authoring sources and `Package.swift`. SwiftPM owns
resolved dependency checkouts. SwiftWeb owns generated package directories as
replaceable build state. The standalone Actor package owns Actor runtime source
identity and lifecycle semantics.

The materializer's transaction owns staging and rollback of generated output;
it does not mutate dependency checkouts. Development workers and host
adapters own their process lifetimes under the existing development contracts.

## Failure, Concurrency, and Constraints

Materialization is serialized per application package and commits generated
roots atomically. Source lookup is ordered and validated by required target
directories. The generated profile must not import an inactive Actor target or
host-only dependency. Browser E2E is opt-in and bounded; cloud deployment is
not part of the 0.12.0 proof.

## Verification and Change Impact

| Evidence | Scope |
|---|---|
| `SwiftWebGeneratedPackageMaterializerTests` | Source projection, target selection, and generated package contracts. |
| `SwiftWebActorGroupTests`, `SwiftWebActorHostTests` | Native actor ownership, authorization, lifecycle, and failure behavior. |
| `ClientRuntimeConcurrencyTests`, `SwiftWebHTTPServerHostTests` | Browser runtime scheduling and HTTP/TLS/WSS host behavior. |
| Generated standard/Embedded package compile and link | Profile-specific source and dependency graph validity only. |
| `counter-wasm` Chromium E2E | Real standard-WASM browser state and remote Actor call path. |
| `SwiftWebServiceActorBrowserTests` | Native Main-to-Service HTTP Actor boundary, not generated WASM or cloud E2E. |

Changes to a child contract require rechecking this master and the directly
dependent module designs. Full release integration additionally proves the
public version graph and remote release targets.
