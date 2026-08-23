# SwiftWeb Documentation

This directory contains current SwiftWeb contracts and executable verification
runbooks. Historical roadmaps, completed migration plans, and unsupported
Embedded WASM experiments are intentionally not kept here; Git history remains
the archive for those records.

## Start Here

| Document | Audience | Purpose |
|---|---|---|
| [Project README](../README.md) | Application developers | Installation, first app, authoring, CLI, and production builds |
| [Changelog](../CHANGELOG.md) | All users | Tagged release changes and compatibility notes |
| [Toolchain](Toolchain.md) | All contributors | Exact Swift 6.4 host and WASM build contract |
| [HTML Authoring Model](HTMLAuthoringModel.md) | Application and framework developers | `Component`, `HTMLDocument`, and `Page` boundaries |
| [Host Rendering Contract](HostRenderingContract.md) | Host adapter and framework developers | `AppRenderer`, `RenderedApp`, request translation, and lifecycle ownership |
| [Development Reconciler Verification](DevServerReconcilerVerification.md) | Maintainers | Real `sweb dev` and Chromium release gate |
| [Host, Deployment, and Service Adapter Contract](AdapterContract.md) | Application and adapter developers | SwiftPM discovery, environments, independent services, artifacts, templates, and lifecycle tasks |

## Public Runtime Contracts

| Document | Status |
|---|---|
| [Client Bundle Loading](ClientBundleLoadingDesign.md) | Implemented browser bundle and loading contract |
| [Client Navigation](ClientNavigationDesign.md) | Implemented progressive navigation contract |
| [Actor Injection](ActorInjectionDesign.md) | Current local and deployment-bound concrete actor binding, `.actor(Type.self, identity:)`, and `@RemoteActor` contract |
| [Remote Connections](RemoteConnectionArchitecture.md) | Actor-versus-Server boundary, implemented cross-application request/reply slice, platform samples, and remaining adapter requirements |
| [SwiftWebUI Core](SwiftWebUICoreDesign.md) | Current component, property, modifier, and environment model |
| [SwiftWebUI Style](SwiftWebUIStyleDesign.md) | Current styling responsibility and resolution rules |
| [Atomic Styling](AtomicStyling.md) | Current class generation, collection, and emission contract |

## Architecture Decisions

| Document | Decision |
|---|---|
| [Swift Actor System](SwiftActorSystemDesign.md) | A concrete `distributed actor` declaration is the single source of truth; Native uses Swift Distributed Actors and Embedded uses generated semantic twins over one transport-neutral core |
| [Remote Connections](RemoteConnectionArchitecture.md) | Actor connections preserve Swift Distributed Actor semantics; non-Actor destinations remain Server connections |
| [Browser Runtime JavaScriptKit](BrowserRuntimeJavaScriptKitDecision.md) | JavaScriptKit is the internal browser adapter; SwiftWebUI remains the public UI API |
| [Host, Deployment, and Service Adapter Contract](AdapterContract.md) | Hosts, deployments, and independent service applications are separate adapter components discovered through SwiftPM |
| [Host Rendering Contract](HostRenderingContract.md) | Hosts own platform lifecycle and consume one common SwiftWeb rendering result |

## Release Evidence

| Document | Scope |
|---|---|
| [Production Review](ProductionReview.md) | SwiftWeb 0.8.0 P0/P1 sign-off and measured release gates |

## Documentation Rules

- Describe shipped behavior in the present tense.
- Mark a document as proposed only when it defines a concrete future decision;
  do not mix proposals into user-facing setup instructions.
- Keep commands aligned with the pinned values in [Toolchain](Toolchain.md).
- Keep implementation evidence in a runbook or release record, not in the
  project README.
- Remove completed TODO documents after their durable contract has moved into
  code, tests, or a current design document.
