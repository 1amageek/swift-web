# SwiftWeb Documentation

This directory contains current SwiftWeb contracts and executable verification
runbooks. Historical roadmaps, completed migration plans, and unsupported
Embedded WASM experiments are intentionally not kept here; Git history remains
the archive for those records.

## Start Here

| Document | Audience | Purpose |
|---|---|---|
| [Project README](../README.md) | Application developers | Installation, first app, authoring, CLI, and production builds |
| [Package design](../DESIGN.md) | Framework and adapter developers | Design master and direct module-design index |
| [Changelog](../CHANGELOG.md) | All users | Unreleased changes, tagged releases, and compatibility notes |
| [Toolchain](Toolchain.md) | All contributors | Exact Swift 6.4 host and WASM build contract |
| [HTML Authoring Model](HTMLAuthoringModel.md) | Application and framework developers | `Component`, `HTMLDocument`, and `Page` boundaries |
| [Host Rendering Contract](HostRenderingContract.md) | Host adapter and framework developers | `AppRenderer`, `RenderedApp`, request translation, and lifecycle ownership |
| [Development Reconciler Verification](DevServerReconcilerVerification.md) | Maintainers | Real `sweb dev` and Chromium release gate |
| [Service Actor HTTP Boundary](../Tests/BrowserE2E/README.md#service-actor-http-boundary) | Maintainers and adapter developers | Browser-to-Main-to-Service forwarding, authorization, and exact identity checks; separate from WASM hydration |
| [Host, Deployment, and Service Adapter Contract](AdapterContract.md) | Application and adapter developers | SwiftPM discovery, environments, independent services, artifacts, templates, and lifecycle tasks |

## Public Runtime Contracts

| Document | Status |
|---|---|
| [Client Bundle Loading](ClientBundleLoadingDesign.md) | Implemented browser bundle and loading contract |
| [Client Navigation](ClientNavigationDesign.md) | Implemented progressive navigation contract |
| [Actor Integration Design](../Sources/SwiftWebRuntime/Actors/DESIGN.md) | Canonical connection policy, destination examples, host/binding contracts, and verification boundaries |
| [Actor Authoring Guide](../Sources/SwiftWebRuntime/Actors/README.md) | Existing concrete actor declarations, scene binding, and call-site examples |
| [SwiftWebUI Core](SwiftWebUICoreDesign.md) | Current component, property, modifier, and environment model |
| [SwiftWebUI Style](SwiftWebUIStyleDesign.md) | Current styling responsibility and resolution rules |
| [Atomic Styling](AtomicStyling.md) | Current class generation, collection, and emission contract |

## Architecture Decisions

| Document | Decision |
|---|---|
| [Browser Runtime JavaScriptKit](BrowserRuntimeJavaScriptKitDecision.md) | JavaScriptKit is the internal browser adapter; SwiftWebUI remains the public UI API |
| [Host, Deployment, and Service Adapter Contract](AdapterContract.md) | Hosts, deployments, and independent service applications are separate adapter components discovered through SwiftPM |
| [Host Rendering Contract](HostRenderingContract.md) | Hosts own platform lifecycle and consume one common SwiftWeb rendering result |

## Documentation Rules

- Describe implemented behavior in the present tense and identify unreleased
  changes separately from tagged releases.
- Mark a document as proposed only when it defines a concrete future decision;
  do not mix proposals into user-facing setup instructions.
- Keep each design decision in its owning `DESIGN.md`, reachable from the
  package master; guides link to that authority. Label future destination
  scenarios separately from implemented and verified paths.
- Keep commands aligned with the pinned values in [Toolchain](Toolchain.md).
- Keep implementation evidence in a runbook or release record, not in the
  project README.
- Remove completed TODO documents after their durable contract has moved into
  code, tests, or a current design document.
