# SwiftWebMacros

SwiftWebMacros contains compile-time code generation for SwiftWeb.

It owns syntax analysis and generated Swift declarations for page types, action references, and actor export metadata. It does not perform runtime routing, request decoding, rendering, actor resolution, or server execution.

## Responsibility

| Area | Responsibility |
|---|---|
| Macro implementation | Implements the `@Page` macro using SwiftSyntax. |
| Page conformance | Generates `PageRoute` and `Page` conformance for annotated page types. |
| Route registration | Generates calls that lower page paths through host-neutral route registration. |
| Parameter checks | Cross-checks path parameters with `Params` declarations where possible. |
| Metadata lowering | Generates calls to async page metadata before response encoding. |
| Server action references | Validates `@ServerAction` HTTP handler methods and generates typed action references, runtime descriptors, and internal invocation bridges. |
| Concrete actor injection | Implements the `@RemoteActor` accessor for concrete generated `ActorSystemReference` actor types. |
| Legacy actor export metadata | Retains deprecated `@ResolvableActor` support for the explicit compatibility path. |
| Diagnostics | Emits compile-time errors for unsupported or inconsistent page declarations. |

## Boundary With SwiftWeb

```mermaid
flowchart LR
  A["source: @Page"] --> B["SwiftWebMacros"]
  B --> C["generated extension"]
  C --> D["SwiftWeb.PageRoute + Page"]
  D --> E["host route at runtime"]
```

## Server Interaction Boundaries

SwiftWeb keeps distributed actor calls and Server Actions as distinct
programming models.

| Method | Owner | Purpose |
|---|---|---|
| Server Action | `SwiftWebMacros.@ServerAction` | Generate a typed HTTP endpoint descriptor and an `ActionReference` for page-local HTTP work. |
| Distributed actor call | Swift compiler, `ActorSystemGeneration`, and runtime `@RemoteActor` | Preserve the concrete actor method surface while generated metadata and profile projections supply identity and dispatch. |
| Legacy resolvable call | Apple `@Resolvable` plus deprecated SwiftWeb `@ResolvableActor` | Keep the previous protocol-based JSON path available only during migration. |

`@RemoteActor` is an injection convenience, not a contract declaration or
transport selector. For a concrete actor property it resolves the generated
`ActorSystemReference` metadata from the current scene binding scope. It does
not create another proxy protocol or expose HTTP/WebSocket selection.

The current actor contract is documented beside the runtime in
[`../SwiftWebRuntime/Actors/README.md`](../SwiftWebRuntime/Actors/README.md).
Legacy protocol-based declarations remain isolated behind the explicit
`LegacyActors` trait and are not a second authoring model.

## Server Action Lowering

`@ServerAction` belongs on an instance method inside a page or page-owned server handler. The macro validates that the function is a supported HTTP boundary and generates a typed `ActionReference` that can be exported to SwiftWebUI button/form rendering. Stored page services opt into route registration by conforming to `PageOwnedServerActions`; ordinary stored properties are not treated as server handlers.

```mermaid
flowchart LR
  A["@ServerAction(.post, 'save') func"] --> B["signature validation"]
  B --> C["ServerActionDescriptor"]
  B --> D["ActionReference<Input, Output>"]
  B --> I["generated action bridge"]
  C --> E["@Page route registration"]
  D --> F["SwiftWebUI Button/Form"]
  E --> G["HTTP route"]
  G --> I
  I --> H["handler method"]
```

The generated descriptor carries an HTTP method and path. Relative paths are resolved under the owning page route during `@Page` registration. The action method is not distributed because Server Action is ordinary HTTP, not direct RPC. The macro owns the generated bridge that lets the runtime invoke the local handler method safely.

The macro should reject unsupported signatures instead of letting invalid actions fail at runtime.

| Requirement | Reason |
|---|---|
| Function is declared inside a page, actor, or class | The runtime needs a concrete instance for route registration and typed invocation. |
| Function is not `distributed` | Server Action is an HTTP endpoint, not an Apple distributed actor RPC endpoint. |
| Attribute declares `ServerActionMethod` and path | The public contract is HTTP method + path. |
| Input is `Codable & Sendable` | Client and gateway need a stable HTTP transport contract. |
| Output is `Codable & Sendable` or `ActionResult` | Runtime needs typed result encoding. |
| Context is `ActionInvocationContext` | Action methods receive normalized request context, not concrete host request state. |

## Not Responsible For

| Not owned by SwiftWebMacros | Owner |
|---|---|
| Runtime route matching | `SwiftWebCore` and the selected host |
| Request context storage | `SwiftWeb` |
| HTML rendering | `SwiftHTML` |
| UI components | `SwiftWebUI` |
| Runtime actor id lookup and `WebActorSystem` transport setup | `SwiftWeb` / `SwiftWebUIRuntime` / `SwiftWebActors` |
| Actor schema, bootstrap, and profile projection generation | `ActorSystemGeneration` and `SwiftWebPackageGeneration` |
| CLI templates and dev server | `SwiftWebCLI` |
| Runtime validation that requires a live request | `SwiftWeb` |
| Handler registration and typed invocation | `SwiftWeb` |

## Design Notes

- Macro output should be small and predictable.
- The macro should generate code that calls public SwiftWeb APIs instead of duplicating runtime logic.
- Compile-time diagnostics should catch path/parameter mismatches early.
- The macro must not maintain route manifests, route trees, or matching state.
- `@ServerAction` marks the exported HTTP handler method explicitly; no actor-level grouping macro is required.
- Page-owned handlers are registered as host-neutral routes through generated `@Page` instance registration.
- Generated descriptors should carry a typed invoker instead of requiring SwiftWeb to synthesize compiler-internal distributed target names.
- Generated action references should describe HTTP method and path. They should not expose handler names, action names, target identifiers, actor IDs, or RPC metadata.
- Concrete `distributed actor` declarations are the only new actor contracts.
- `@RemoteActor` exposes a concrete actor reference to component code without exposing `WebActorSystem`, actor IDs, or transport handles in the component surface.
- `@Resolvable` and `@ResolvableActor` remain compatibility-only declarations and must not be selected as the primary path for new actors.
