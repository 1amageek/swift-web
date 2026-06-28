# SwiftWebMacros

SwiftWebMacros contains compile-time code generation for SwiftWeb.

It owns syntax analysis and generated Swift declarations for page types, action references, and actor export metadata. It does not perform runtime routing, request decoding, rendering, actor resolution, or server execution.

## Responsibility

| Area | Responsibility |
|---|---|
| Macro implementation | Implements the `@Page` macro using SwiftSyntax. |
| Page conformance | Generates `PageRoute` and `Page` conformance for annotated page types. |
| Route registration | Generates calls that lower page paths to Vapor route registration. |
| Parameter checks | Cross-checks path parameters with `Params` declarations where possible. |
| Metadata lowering | Generates calls to async page metadata before response encoding. |
| Server action references | Validates `@ServerAction` HTTP handler methods and generates typed action references, runtime descriptors, and internal invocation bridges. |
| Actor export metadata | Implements `@ResolvableActor`, which connects a server actor implementation to one Apple `@Resolvable` contract for `.actor(...)` scene export. |
| Diagnostics | Emits compile-time errors for unsupported or inconsistent page declarations. |

## Boundary With SwiftWeb

```mermaid
flowchart LR
  A["source: @Page"] --> B["SwiftWebMacros"]
  B --> C["generated extension"]
  C --> D["SwiftWeb.PageRoute + Page"]
  D --> E["Vapor route at runtime"]
```

## Server Interaction Macro Boundaries

SwiftWeb has two server interaction methods, and only one of them is owned by SwiftWebMacros.

| Method | Macro owner | Purpose |
|---|---|---|
| Server Action | `SwiftWebMacros.@ServerAction` | Generate a typed HTTP endpoint descriptor and an `ActionReference` for page-local HTTP work. |
| Resolvable RPC | Apple `@Resolvable`, SwiftWeb `@ResolvableActor`, and runtime `@Actor` | Apple generates the `$Protocol.resolve(id:using:)` entrypoint; SwiftWeb records the scene binding and generated WASM resolver registry. |

`@ServerAction` does not generate `$Protocol` resolvers. Apple's `@Resolvable` does not generate SwiftWeb action references. SwiftWeb `@Actor` must not create another resolver model; it should only make the resolved `@Resolvable` protocol object available as the property wrapped value.

The target actor injection contract is documented in
[`../../docs/ActorInjectionDesign.md`](../../docs/ActorInjectionDesign.md).

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
  E --> G["Vapor HTTP route"]
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
| Context is `ActionInvocationContext` | Action methods receive normalized request context, not raw Vapor request state. |

## Not Responsible For

| Not owned by SwiftWebMacros | Owner |
|---|---|
| Runtime route matching | Vapor / `SwiftWeb` |
| Request context storage | `SwiftWeb` |
| HTML rendering | `SwiftHTML` |
| UI components | `SwiftWebUI` |
| Runtime actor id lookup and `WebActorSystem` transport setup | `SwiftWeb` / `SwiftWebUIRuntime` / `SwiftWebActors` |
| Client `@Actor` resolver registry generation | `SwiftWebPackageGeneration` |
| CLI templates and dev server | `SwiftWebCLI` |
| Runtime validation that requires a live request | `SwiftWeb` |
| Handler registration and typed invocation | `SwiftWeb` |

## Design Notes

- Macro output should be small and predictable.
- The macro should generate code that calls public SwiftWeb APIs instead of duplicating runtime logic.
- Compile-time diagnostics should catch path/parameter mismatches early.
- The macro must not maintain route manifests, route trees, or matching state.
- `@ServerAction` marks the exported HTTP handler method explicitly; no actor-level grouping macro is required.
- Page-owned handlers are registered as Vapor routes through generated `@Page` instance registration.
- Generated descriptors should carry a typed invoker instead of requiring SwiftWeb to synthesize compiler-internal distributed target names.
- Generated action references should describe HTTP method and path. They should not expose handler names, action names, target identifiers, actor IDs, or RPC metadata.
- Apple's `@Resolvable` belongs on client-visible distributed actor protocols, not on SwiftWeb `ActionReference`.
- `@Actor` should expose the resolved service object to component code. It should not expose `WebActorSystem`, actor ids, or `$Protocol.resolve(id:using:)` in the standard component surface.
- `@ResolvableActor` belongs on server actor implementations that are exported through `.actor(...)`.
