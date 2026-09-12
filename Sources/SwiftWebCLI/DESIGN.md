# SwiftWebCLI

## Purpose and Scope

Command parsing and lifecycle composition. Parent: [system](../../DESIGN.md).
No child design units.

## Responsibilities and Boundaries

The CLI owns command selection and configuration resolution. Application packages
own App types, routes, catalog contents, and lifecycle environments. The CLI never
imports or locates concrete catalog source files.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [System](../../DESIGN.md) | parent | Package graph | Supplies development products | No dependency on a catalog implementation |
| [Generation](../SwiftWebDevelopment/PackageGeneration/DESIGN.md) | depends on | Generic materialization | Consumes the selected application | Preserve application identity |
| [Dev server](../SwiftWebDevelopment/DevServer/DESIGN.md) | depends on | Supervised lifecycle | Owns workers and shutdown | Delegate cancellation unchanged |

## Architecture

```text
sweb storyboard [prepare|build|dev]
  -> declaring sweb.json: storyboard.packagePath
  -> selected package's sweb.json
  -> LifecycleCommand -> existing project lifecycle -> application
```

## Contracts and Invariants

- `storyboard` defaults to `dev`; explicit operations are `prepare`, `build`, and `dev`.
- The declaring `sweb.json` requires `schemaVersion: 3` and
  `storyboard: { "packagePath": "<relative directory>" }`. It may contain the normal
  application fields or be a selector-only workspace document.
- The nonempty package path is relative to the declaring directory. Absolute paths
  are rejected; parent-relative paths are supported. The target must contain
  `Package.swift` and `sweb.json`. Selection is one hop, never recursive.
- The target's existing schema-3 application manifest owns product, module, type,
  environments, defaults, and adapter tasks. Generic lifecycle validation is authoritative.
- Missing declarations, malformed JSON, unsupported schemas, and invalid targets
  fail before generation. There is no directory-name fallback or source copying.
- Lifecycle options and failure/cancellation semantics are reused unchanged.
- Legacy scaffold flags and production preview flags are rejected. Use `prepare`
  instead of `--no-run`, and `build --environment <name>` for production artifacts;
  serving production artifacts belongs to the application's host/deployment contract.
- The removed `SwiftWebStoryboardTooling` product has no compatibility implementation.

## Verification and Change Impact

[Command tests](../../Tests/SwiftWebCLITests/StoryboardCommandTests.swift) verify
arbitrary target paths, option forwarding, invalid declarations, and generic
lifecycle failure propagation. The [browser gate](../../Tests/BrowserE2E/storyboard-client-navigation-e2e.mjs)
invokes the public command and checks actual application hydration/navigation and
shutdown. Selector changes affect this CLI contract; App changes belong to the
selected package and its tests.
