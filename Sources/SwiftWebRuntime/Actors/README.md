# SwiftWebActors

SwiftWebActors is SwiftWeb's application-facing integration for the
transport-neutral [swift-actor-system](https://github.com/1amageek/swift-actor-system)
package.

The concrete `distributed actor` declaration is the actor contract on Native
and standard WASM. Embedded WASM consumes a generated semantic twin with the
same actor identity, method surface, schema, payload, and error model. Actor
code never selects HTTP, WebSocket, or another transport.

The [Actor integration design](DESIGN.md) owns the connection policy, runtime
contracts, destination examples, and implementation limits. This guide shows
the existing authoring surface. A deployed Service remains a build/deploy unit;
its actors are selected through their Swift types.

## Responsibility

| Area | Responsibility |
|---|---|
| Compiler-facing facade | `WebActorSystem` delegates Swift Distributed Actor requirements to `SwiftActorSystem`. |
| Common runtime | `ActorSystemCore` owns identity, frames, routing, correlation, timeout, cancellation, and lifecycle. |
| Host policy | `SwiftWebActorHost` owns authorization, virtual activation, persistence, passivation, reminders, and remote state. |
| Transport adapters | SwiftWeb HTTP and WebSocket adapters move bounded binary actor frames and authenticated metadata. |
| Scene binding | `ActorGroup`, `.actor(...)`, and `@RemoteActor` bind concrete actor references without exposing transport handles. |
| Service binding | Deployment-generated route templates are combined with the logical identity from `.actor(Type.self, identity:)`. |
| Embedded projection | Generated actor twins use `EmbeddedActorSystem` without importing `Distributed`, `Codable`, or ActorRuntime. |
| Compatibility | `LegacyWebActorSystem` and legacy JSON envelopes remain explicit deprecated migration paths. |

## Runtime Flow

See the [runtime flow and ownership](DESIGN.md#runtime-flows). Transport selection
does not change the concrete Distributed Actor call surface.

## Browser Service Routing

See [browser Service routing](DESIGN.md#browser-service-routing) for the
same-origin gateway and optional direct `clientRoute`, including admission,
authorization, and ownership requirements. See [Verification](#verification)
for the evidence owned by each boundary.

## Authoring Model

An application declares one concrete actor:

```swift
import Distributed
import SwiftWeb

public distributed actor Counter {
    public typealias ActorSystem = WebActorSystem

    private var value = 0

    public distributed func increment(by amount: Int) async throws -> Int {
        value += amount
        return value
    }
}
```

Direct resolution and invocation retain the Distributed Actor surface:

```swift
let counter = try Counter.resolve(id: address, using: actorSystem)
let value = try await counter.increment(by: 1)
```

SwiftWeb can inject that same concrete reference:

```swift
public struct CounterClient: ClientComponent {
    @RemoteActor
    private var counter: Counter

    public func increment() async throws -> Int {
        try await counter.increment(by: 1)
    }
}
```

An application binds an actor hosted by another Service application without a
wrapper scene or service proxy:

```swift
CounterPage()
    .actor(Counter.self, identity: "primary")
```

The modifier is available on both `PageRoute` and `Scene`. The project Service
declaration names `Counter` as a concrete contract, while the deployment
adapter supplies a structured route template. Neither manifest owns the
logical identity.

The application that hosts the actor registers its construction policy:

```swift
ActorGroup { actorSystem in
    Counter(actorSystem: actorSystem)
}
```

When moving that actor to a Service, move its hosting registration out of the
primary application and into the Service application. The caller keeps its
`.actor` modifier and `@RemoteActor` property. Configure authorization on the
host and gateway for the intended callers; registration does not grant access.

Resolve `@RemoteActor` within a bound handler, following the
[binding lifetime contract](DESIGN.md#state-ownership-and-lifecycle).
See [ClientCounter](../../../Examples/CounterApp/Sources/CounterApp/ClientCounter.swift)
for asynchronous event handling and error display.

The actor type receives generated `ActorSystemReference` metadata. Applications
do not author a service protocol, contract annotation, implementation
annotation, method ID, wire layout, or transport binding.

## SwiftWeb Host Boundary

The [host lifecycle contract](DESIGN.md#state-ownership-and-lifecycle) defines
the `AppRuntime`, `WebActorSystem`, Core, and host-policy ownership boundaries.

## Difference From Server Actions

| Method | Caller surface | Runtime boundary |
|---|---|---|
| Distributed actor call | `try await counter.increment(by: 1)` | Binary actor frame through `ActorSystemCore` and `ActorTransport` |
| Server Action | `Button` or form action | Page-local typed HTTP endpoint and `ActionReference` |

Server Actions are not actor stubs. Distributed actor calls do not fall back to
Server Actions or to the legacy JSON actor endpoint.

For an external API, an application-owned actor can provide a domain contract
while consuming that API as a resource. See the
[destination examples](DESIGN.md#destination-examples) before selecting a host.

## Legacy Compatibility

The [legacy compatibility contract](DESIGN.md#legacy-compatibility) documents
the explicit `LegacyActors` trait, separate endpoints, and migration boundary.

## Verification

| Evidence | What it checks | Boundary |
|---|---|---|
| [Core execution tests](https://github.com/1amageek/swift-actor-system/blob/0.2.0/Tests/ActorSystemCoreTests/ActorSystemCoreBehaviorTests.swift) | Local execution and forwarding share an exactly-once claim; missing forwarding capability fails | Core behavior, not browser integration |
| [Actor host tests](../../../Tests/SwiftWebTests/SwiftWebActorHostTests.swift) and [Scene binding tests](../../../Tests/SwiftWebTests/SwiftWebActorGroupTests.swift) | Exact-address admission, authorization, ownership conflicts, direct-route isolation, timeout, cancellation, failure, and shutdown | Native host and in-process transport fixtures |
| [Service Actor browser test](../../../Tests/SwiftWebTests/SwiftWebServiceActorBrowserTests.swift) | Chromium calls Main's real HTTP endpoint; only the authorized, bound call reaches an Actor on a separate Service host | Two native HTTP hosts; pre-encoded browser frames, not generated Swift-WASM calls |
| [CounterApp development gate](../../../Tests/BrowserE2E/counter-wasm-runtime-e2e.mjs) | Swift-WASM events, actor calls, state, Server Actions, and development updates | The Actor is hosted in the same application |

Follow the [browser test runbook](../../../Tests/BrowserE2E/README.md#service-actor-http-boundary)
for prerequisites and commands. These gates do not establish a complete
generated Swift-WASM-to-separate-Service deployment or Embedded runtime E2E.

## Not Responsible For

| Not owned by SwiftWebActors | Owner |
|---|---|
| Actor schema scanning and profile source generation | `ActorSystemGeneration` and SwiftWeb package generation |
| HTTP listener and RFC 6455 implementation | SwiftWeb host adapters |
| Page routing and rendering | `SwiftWebCore` and `SwiftHTML` |
| Component state and DOM patching | `SwiftWebUIRuntime` |
| Board-specific UART, BLE, TCP, ISR, or DMA adaptation | Deployment-provided `ActorTransport` |

The [design](DESIGN.md#verification-and-change-impact) defines verification
ownership and the acceptance criteria for additional destination adapters.
