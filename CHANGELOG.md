# Changelog

## 0.9.0 - 2026-08-06

| Area | Change |
|---|---|
| Host rendering | Adds the single `AppRenderer.render(_:in:) -> RenderedApp` boundary and makes native serving begin with `HTTPServerHost.render(_:)`. |
| App ownership | Keeps `App` declarative and removes host router, logger, storage, and lifecycle ownership from the app definition. |
| Breaking cleanup | Removes `ApplicationProtocol`, the `Application` alias, app service containers, route-installer callbacks, `HTTPServerAppRunner`, and the obsolete HTTP application wrapper without compatibility shims. |
| Requests | Replaces the application reference on `Request` with the rendered app's framework-owned `RequestRuntimeContext`. |
| Actions | Registers form and page-owned actions through scenes and rendering context rather than an application container. |
| Dependencies | Resolves the released SwiftHTML `0.15.0` dependency and its SwiftSyntax `603.0.2` macro toolchain. |
| Validation | Verifies the Native package suite and Standard and Embedded WASM host builds with the pinned Swift 6.4 snapshot. |
| Documentation | Defines host rendering, request translation, ownership, failure, and lifecycle contracts for native and external platform adapters. |

## 0.8.0 - 2026-07-30

| Area | Included |
|---|---|
| SwiftHTML | Updates the released dependency to SwiftHTML `0.14.0`, including fixed `ComponentContent` runtime storage for Standard WASM generic builder paths. |
| Storyboard | Lowers preview frames, canvases, and the style root into fixed `ComponentContent` storage so generated Storyboard WASM reaches the browser-ready state. |
| SwiftWebUI | Preserves the public generic `Toggle` and `DisclosureGroup` APIs while storing their label and child builder results as `ComponentContent`. |
| Concurrency | Requires sendable metatypes for `App` and `Scene`, and includes the Embedded collection projection paths introduced after `0.7.0`. |
| Templates | Updates package examples, `sweb new`, Storyboard scaffolding, and generated package references to SwiftWeb `0.8.0` and SwiftHTML `0.14.0`. |
| Verification | Passes the full Native package suite, repeated focused tests, Standard and Embedded WASM builds, Storyboard browser bootstrap, and the complete Chromium development/HMR release gate. |
| Documentation | Rewrites installation examples for the current tagged releases and refreshes the P0/P1 production review. |

## 0.7.0 - 2026-07-28

Completed the SwiftHTML package migration, Standard WASM client runtime,
generation-based HMR transaction model, production artifact processing, and
the initial P0/P1 release gate.
