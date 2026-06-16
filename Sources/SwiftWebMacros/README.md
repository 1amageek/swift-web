# SwiftWebMacros

SwiftWebMacros contains compile-time code generation for SwiftWeb.

It owns syntax analysis and generated Swift declarations for page types and action references. It does not perform runtime routing, request decoding, rendering, actor resolution, or server execution.

## Responsibility

| Area | Responsibility |
|---|---|
| Macro implementation | Implements the `@Page` macro using SwiftSyntax. |
| Page conformance | Generates `PageRoute` and `Page` conformance for annotated page types. |
| Route registration | Generates calls that lower page paths to Vapor route registration. |
| Parameter checks | Cross-checks path parameters with `Params` declarations where possible. |
| Metadata lowering | Generates calls to async page metadata before response encoding. |
| Server action references | Validates `@ServerAction distributed func` declarations and generates typed, resolvable action references plus runtime descriptors. |
| Diagnostics | Emits compile-time errors for unsupported or inconsistent page declarations. |

## Boundary With SwiftWeb

```mermaid
flowchart LR
  A["source: @Page"] --> B["SwiftWebMacros"]
  B --> C["generated extension"]
  C --> D["SwiftWeb.PageRoute + Page"]
  D --> E["Vapor route at runtime"]
```

## Server Action Lowering

`@ServerAction` belongs on a `distributed func`. The macro validates that the function is a supported server-side command boundary and generates a typed `ActionReference` that can be exported to the client hydration manifest as a `Resolvable` value.

```mermaid
flowchart LR
  A["@ServerAction distributed func"] --> B["signature validation"]
  B --> C["ServerActionDescriptor"]
  B --> D["instance ActionReference<Input, Output>"]
  C --> E["@Page page-owned service registration"]
  D --> F["SwiftWebUI Button/Form"]
  E --> G["SwiftWeb ActionGateway"]
  G --> H["typed distributed func invoker"]
```

The macro should reject unsupported signatures instead of letting invalid actions fail at runtime.

| Requirement | Reason |
|---|---|
| Function is `distributed` | Server Action is a Distributed Actor method invocation. |
| Input is `Codable & Sendable` | Client and gateway need a stable transport contract. |
| Output is `Codable & Sendable` or `ActionResult` | Runtime needs typed result encoding. |
| Context is `ActionInvocationContext` | Actor methods receive normalized request context, not raw Vapor request state. |
| Actor identity is representable | Client handles must resolve to a concrete singleton or session actor. |

## Not Responsible For

| Not owned by SwiftWebMacros | Owner |
|---|---|
| Runtime route matching | Vapor / `SwiftWeb` |
| Request context storage | `SwiftWeb` |
| HTML rendering | `SwiftHTML` |
| UI components | `SwiftWebUI` |
| CLI templates and dev server | `SwiftWebCLI` |
| Runtime validation that requires a live request | `SwiftWeb` |
| Actor registration and typed invocation | `SwiftWeb` and the configured `DistributedActorSystem` |

## Design Notes

- Macro output should be small and predictable.
- The macro should generate code that calls public SwiftWeb APIs instead of duplicating runtime logic.
- Compile-time diagnostics should catch path/parameter mismatches early.
- The macro must not maintain route manifests, route trees, or matching state.
- `@ServerAction` marks the exported method explicitly; no actor-level grouping macro is required.
- Page-owned distributed actor services are registered through generated `@Page` instance registration when their actor system is `WebActorSystem`.
- Generated descriptors should carry a typed invoker instead of requiring SwiftWeb to synthesize compiler-internal distributed target names.
- Generated action references should describe actor name, method name, input type, output type, actor identity policy, and capability metadata.
