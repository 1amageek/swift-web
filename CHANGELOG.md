# Changelog

## 0.8.0 - 2026-07-30

| Area | Included |
|---|---|
| SwiftHTML | Updates the released dependency to SwiftHTML `0.14.0`, including fixed `ComponentContent` runtime storage for Standard WASM generic builder paths. |
| Storyboard | Lowers preview frames, canvases, and the style root into fixed `ComponentContent` storage so generated Storyboard WASM reaches the browser-ready state. |
| SwiftWebUI | Preserves the public generic `Toggle` and `DisclosureGroup` APIs while storing their label and child builder results as `ComponentContent`. |
| Concurrency | Requires sendable metatypes for `App`, `AppServices`, and `Scene`, and includes the Embedded collection projection paths introduced after `0.7.0`. |
| Templates | Updates package examples, `sweb new`, Storyboard scaffolding, and generated package references to SwiftWeb `0.8.0` and SwiftHTML `0.14.0`. |
| Verification | Passes the full Native package suite, repeated focused tests, Standard and Embedded WASM builds, Storyboard browser bootstrap, and the complete Chromium development/HMR release gate. |
| Documentation | Rewrites installation examples for the current tagged releases and refreshes the P0/P1 production review. |

## 0.7.0 - 2026-07-28

Completed the SwiftHTML package migration, Standard WASM client runtime,
generation-based HMR transaction model, production artifact processing, and
the initial P0/P1 release gate.
