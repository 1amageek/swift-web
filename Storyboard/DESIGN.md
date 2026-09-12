# Storyboard

## Purpose and Scope

Repository-local application package for the SwiftWebUI catalog. Parent:
[SwiftWeb system](../DESIGN.md). Child: [application module](Sources/SwiftWebStoryboard/DESIGN.md).

## Responsibilities and Boundaries

Owns the app manifest, catalog sources, and catalog tests. Consumes public
SwiftWeb products through a local parent-package dependency; the parent SwiftPM
graph does not depend on this package. Framework rendering and generation remain
owned by SwiftWeb.

## Related Designs

| Design | Relationship | Contract used | Summary | Cautions |
|---|---|---|---|---|
| [SwiftWeb](../DESIGN.md) | parent, depends on | App, UI, styles, runtime | Supplies framework products | Preserve pinned toolchain and SDK tuple |
| [Application](Sources/SwiftWebStoryboard/DESIGN.md) | child | App scenes | Owns catalog composition | Sources must remain in the application target for client discovery |
| [Generation](../Sources/SwiftWebDevelopment/PackageGeneration/DESIGN.md) | depends on | Source discovery and materialization | Builds Native and WASM consumers | Recheck relocated client source discovery |

## Architecture

```text
Storyboard package -> SwiftWeb products
    sweb.json -> generic sweb dev/build -> generated server/WASM
sweb storyboard -> declared package path -> generic lifecycle
```

## Contracts and Invariants

- The root manifest neither publishes nor tests the catalog target.
- Package, product, target, and App type are named `SwiftWebStoryboard`, as required
  by the existing generated development/server launcher contract.
- Catalog Swift sources move unchanged; routes, styles, state, and failure semantics remain intact.
- The authored app owns `/` redirect, `/storyboard`, and `/storyboard/:selection`.
- The repository declares this package using the [CLI selector contract](../Sources/SwiftWebCLI/DESIGN.md); the command does not know its source layout.
- The standalone package uses the repository's pinned 2026-08-14 toolchain and matching SDKs.

## Verification and Change Impact

`swift test --package-path Storyboard` owns catalog rendering, invalid-selection,
and hydration-index dispatch evidence. The CLI tests own package selection and failure contracts. `Tests/BrowserE2E/storyboard-client-navigation-e2e.mjs`
launches this package via `sweb storyboard` and checks real WASM navigation,
history, color-scheme state, and diagnostics. Source moves must preserve existing
catalog bytes; framework changes require their own owner tests.
