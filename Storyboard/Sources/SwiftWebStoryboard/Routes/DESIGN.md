# Routes

## Purpose and Scope

Component of the [application module](../DESIGN.md), with no children.

## Responsibilities and Boundaries

Owns catalog page paths, request-cookie scheme selection, selection parameters, and document composition. Catalog owns the displayed content.

## Related Designs

| Design | Relationship | Contract used | Summary | Cautions |
|---|---|---|---|---|
| [Application](../DESIGN.md) | parent | Scene composition | Owns app entry point | Preserve target membership |
| [Catalog](../Catalog/DESIGN.md) | coordinates with | Catalog selection and rendering | Composes the catalog page | Keep paths and selection identities consistent |

## Architecture

```text
request -> StoryboardPage / StoryboardSelectionPage -> Catalog
```

## Contracts and Invariants

Source relocation preserves existing rendering, selection fallback, client
component identities, and platform branches byte-for-byte. No state owner,
isolation, callback, or failure behavior changes in this extraction.

## Verification and Change Impact

[Catalog tests](../../../Tests/SwiftWebStoryboardTests) exercise rendering,
invalid selections, and hydration-index dispatch. The repository Storyboard
browser gate verifies composed navigation and scheme persistence. Changes to
this contract require rechecking the application and package designs.
