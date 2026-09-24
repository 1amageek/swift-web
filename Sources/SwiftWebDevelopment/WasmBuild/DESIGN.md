# SwiftWebWasmBuild

## Purpose and Scope

This module owns compiler and Swift SDK compatibility checks for SwiftWeb host
and WebAssembly builds. It is a child module of the
[SwiftWeb package](../../../DESIGN.md) and has no child designs.

## Responsibilities and Boundaries

`SwiftWebPinnedToolchain` validates the compiler version reported by the
selected `swift` executable. `SwiftWebWasmToolchain` resolves the selected
profile's compiler, linker, and SDK identity. This module does not install
toolchains or SDKs and does not choose the process-wide Swiftly default.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [SwiftWeb package](../../../DESIGN.md) | parent | Supported Swift compiler/SDK tuples | Owns package-wide toolchain constraints. | A host build alone does not prove WASM execution. |
| [Toolchain contract](../../../docs/Toolchain.md) | canonical constraint | Default snapshot and explicit release tuple | Documents selection and matching rules. | Never combine a compiler and SDK from different tuples. |
| [Package generation](../PackageGeneration/DESIGN.md) | used by | Matching standard or Embedded SDK identity | Generates profile-specific package manifests. | Profile and SDK must agree. |
| [Development server](../DevServer/DESIGN.md) | used by | Explicit compiler/SDK selection and failure | Builds and launches the browser runtime. | Invalid overrides fail before serving. |

## Architecture

```text
runtime profile + optional SDK name
              |
              v
     profile/SDK compatibility
              |
              v
 compiler + linker resolution
              |
              v
 supported compiler validation
              |
              v
 generated SwiftPM build
```

## Contracts and Invariants

| Selection | Compiler | SDK |
|---|---|---|
| Default | Swift 6.4 development snapshot `2026-08-14-a` | Matching standard or Embedded SDK |
| Explicit release | Official Swift 6.4.0 release | Matching `swift-6.4.0-RELEASE` standard or Embedded SDK |

- The default snapshot remains unchanged; an explicit override selects the
  official release without modifying Swiftly's configured default.
- Standard and Embedded profiles accept only their own SDK name for either
  supported compiler tuple.
- WASM compiler validation requires the compiler and `wasm-ld` from the same
  resolved SDK directory. Host compiler selection uses the same supported
  compiler check.
- An unsupported compiler, SDK/profile pairing, missing executable, or linker
  is a typed failure; resolution never silently falls back to another tuple.

## Runtime Flows

1. The caller selects a runtime profile and may provide an explicit SDK name.
2. The module rejects an SDK that does not match that profile.
3. It resolves `swift` and `wasm-ld` from the selected SDK bundle and validates
   the compiler's version output.
4. The package generator passes the validated SDK identity to SwiftPM.

## Failure, Concurrency, and Constraints

Toolchain probing and filesystem discovery can fail. The caller receives the
typed probe, unsupported-SDK, or not-found error; no SDK is downloaded and no
compiler is installed by this module.

## Verification and Change Impact

`SwiftWebWasmToolchainTests` verifies accepted and rejected compiler versions,
SDK/profile pairing, and adjacent linker resolution. The SwiftWeb CLI build
and an actual `sweb dev` browser build verify the selected tuple end to end.
Changes to these constraints require updating the package master and
[Toolchain.md](../../../docs/Toolchain.md); changes to profile selection also
require rechecking package generation and the development server.
