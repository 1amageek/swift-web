# SwiftWeb Browser E2E

These tests exercise the real browser WASM runtime. They are opt-in because they start a SwiftWeb dev server, build the ClientComponent WASM bundle, and launch a browser.

```bash
cd Tests/BrowserE2E
npm install
npm run counter-wasm
```

The test copies `Examples/CounterApp` into a temporary directory, rewrites its dependencies to the local `swift-web` and `swift-html` packages, starts `swift-web dev`, and validates:

- browser WASM runtime readiness
- WASM asset fetch and instantiation metrics
- ClientComponent `@State` updates through WASM event dispatch
- `.visible`, `.idle`, `.interaction`, and `.manual` ClientComponent loading policies
- named/shared split bundle contracts
- ServerAction page invalidation without full navigation
- ClientComponent HMR patching while preserving state
- ClientComponent HMR build failure rollback without replacing the old UI
- dev process shutdown cleanup
- optional WebKit smoke when Playwright WebKit is installed

Environment variables:

| Name | Purpose |
|---|---|
| `SWIFTWEB_BROWSER_E2E` | Must be `1` to run. Otherwise the script exits successfully without work. |
| `SWIFTWEB_E2E_HEADFUL` | Set to `1` to show the browser. |
| `SWIFTWEB_E2E_PORT` | Fixed port. If omitted, an available port is selected. |
| `SWIFTWEB_E2E_TIMEOUT_MS` | Overall wait timeout for server, runtime, and HMR phases. |
| `SWIFTWEB_E2E_SWIFT_HTML_ROOT` | Override the local `swift-html` path. Defaults to `../swift-html` next to the repo. |
| `SWIFTWEB_E2E_BROWSER_EXECUTABLE_PATH` | Use a specific Chromium-compatible browser executable. |
| `SWIFTWEB_E2E_REQUIRE_WEBKIT` | Set to `1` to fail when the optional WebKit smoke cannot run. |
