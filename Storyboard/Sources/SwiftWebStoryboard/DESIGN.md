# SwiftWebStoryboard Application

## Purpose and Scope

Application module of the [Storyboard package](../../DESIGN.md). Children:
[Catalog](Catalog/DESIGN.md) and [Routes](Routes/DESIGN.md).

## Responsibilities and Boundaries

`SwiftWebStoryboard` composes the root redirect and catalog routes. It owns no
framework runtime, server process, or shared-state synchronization.

## Related Designs

| Design | Relationship | Contract used | Summary | Cautions |
|---|---|---|---|---|
| [Package](../../DESIGN.md) | parent | Build and execution | Owns dependency graph | Keep one application target |
| [Catalog](Catalog/DESIGN.md) | child | Catalog and client components | Renders interactive examples | Preserve discovery in this target |
| [Routes](Routes/DESIGN.md) | child | Page scenes | Serves catalog routes | Keep route identity stable |

## Architecture

```text
SwiftWebStoryboard -> Routes -> Catalog -> SwiftWebUI
```

## Contracts and Invariants

`SwiftWebStoryboard` exposes the existing three scenes. The generic CLI discovers
it through `sweb.json`; legacy preview scaffolding supplies a separate app
entry point and excludes this module's App.swift.

## Verification and Change Impact

[Package tests](../../Tests/SwiftWebStoryboardTests) own catalog rendering and
client dispatch. The repository browser E2E owns the composed route and
hydration behavior. App or route changes require that composed gate.
