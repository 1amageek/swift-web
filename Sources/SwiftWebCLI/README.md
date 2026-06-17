# SwiftWebCLI

SwiftWebCLI provides the `swift-web` executable.

It owns command parsing and project scaffolding. Generated package materialization and development server orchestration live in `SwiftWebDevelopment`.

## Responsibility

| Area | Responsibility |
|---|---|
| Command parsing | Parses `swift-web` command names and command-line options. |
| Project creation | Generates minimal named app skeletons through the `new` command. |
| Generated package | Delegates `.swiftweb/generated` materialization to `SwiftWebDevelopment`. |
| Dev command | Parses CLI options and delegates to `SwiftWebDevelopment.SwiftWebDevRuntime`. |
| Build command | Builds the generated server product or generated WASM runtime product. |
| Storyboard command | Generates an isolated SwiftWebUI component style board and runs it through the same dev runtime. |

## New Command

`swift-web new <AppName>` creates the smallest runnable SwiftWeb package. It gives the package, library product, target, source directory, and `SwiftWeb.App` type the provided app name.

```mermaid
flowchart LR
  A["swift-web new MyApp"] --> B["Package.swift"]
  A --> C["Sources/MyApp/App.swift"]
  A --> D["Sources/MyApp/Routes/HomePage.swift"]
  A --> E[".swiftweb/generated"]
```

| Generated file | Responsibility |
|---|---|
| `Package.swift` | Declares the app library and depends on `SwiftWeb` plus `SwiftHTML`. |
| `Sources/<AppName>/App.swift` | Mounts the app routes through `SwiftWeb.App`. |
| `Sources/<AppName>/Routes/HomePage.swift` | Defines a single `@Page("/")` route that renders `Hello World`. |
| `.swiftweb/generated` | Generated launcher package for dev/server builds. |

## Package Boundary

```mermaid
flowchart TD
  A["User Package.swift"] --> B["App library target"]
  C["swift-web CLI"] --> D[".swiftweb/generated/server"]
  C --> E[".swiftweb/generated/dev"]
  C --> F[".swiftweb/generated/wasm"]
  D --> G["AppServerLauncher"]
  E --> H["SwiftWebDevLauncher"]
  E --> I["AppDevelopmentServerLauncher"]
  F --> J["WASM runtime target"]
  G --> B
  I --> B
  J --> K["Generated client-only source copy"]
```

User packages should stay small: one app library target plus SwiftWeb dependencies. Production server launchers, dev launchers, dev child server launchers, WASM linker flags, client source copies, and client-runtime source copies belong to `.swiftweb/generated`.

Client WASM bundle generation follows the contract in [`docs/ClientBundleLoadingDesign.md`](../../docs/ClientBundleLoadingDesign.md). The CLI and generated packages materialize the resolved main bundle plus explicitly declared split bundles; they should not expose automatic bundle planning as a user-facing feature.

## Dev Command Flow

```mermaid
flowchart LR
  A["swift-web dev"] --> B["DevCommand parse"]
  B --> C["SwiftWebDevRuntime"]
  C --> D["materialize .swiftweb/generated"]
  D --> E["swift build --package-path generated/dev --product app-server-dev"]
  E --> F["launch executable directly"]
  C --> G["watch package files with FSEvents"]
  G --> H["save event detected"]
  H --> I["classify change"]
  I --> J["style / client / server update"]
  J --> T["typed dev event"]
  T --> L["EventSource target transport"]
  T --> M["reload-token fallback"]
  F --> P["child receives parent PID"]
  P --> N["child exits if parent disappears"]
```

`SwiftWebDevRuntime` checks the configured host and port before starting the child server. If the port is already occupied, the CLI exits with a clear error before Vapor can fail during bind.

The runtime watches the app package plus local `.package(path:)` dependencies so edits in a checked-out SwiftWeb framework also trigger rebuilds. The dev child server receives `SWIFT_WEB_DEV_PARENT_PID`, imports `SwiftWebDevelopment`, and installs development hooks before `App.run()`.

Startup, ready, reload, child-exit, and shutdown events are emitted through `swift-log` with `codes.swiftweb.dev` as the logger label.

The CLI does not implement HMR itself. It delegates to `SwiftWebDevRuntime`, which emits typed development events such as `stylePatch`, `clientComponentUpdate`, `serverBuildStarted`, `serverRestarted`, `pagePatch`, `fullReload`, and `error`. The browser runtime prefers `/__swiftweb/dev/events` through EventSource and falls back to `/__swiftweb/dev/reload` token waiting when streaming responses are unavailable.

In the current Vapor 5 alpha HTTP server path, streaming response bodies are not yet written by the server handler. That means the typed EventSource contract is present, but the reload-token fallback remains the reliable browser transport until Vapor response streaming is wired.

## Storyboard Command Flow

```mermaid
flowchart LR
  A["swift-web storyboard"] --> B["generate .swiftweb/storyboard"]
  B --> C["generate .swiftweb/storyboard/.swiftweb/generated"]
  C --> D["SwiftWebDevRuntime"]
  D --> E["http://127.0.0.1:3001/storyboard"]
  E --> F["Theme x StyleSystem matrix"]
  E --> G["component states and controls"]
```

`swift-web storyboard` is a framework inspection tool. It does not edit the user's app source. It generates a managed package under `.swiftweb/storyboard`, mounts `StoryboardPage`, and runs on port `3001` by default so it can stay open beside an app running through `swift-web dev` on port `3000`.

The storyboard includes the default SwiftWebUI style, Material-style overrides, Liquid Glass-style overrides, light/dark theme coverage, control states, semantic `Text(as:)`, local `@State` controls, lists, navigation links, lazy stacks, and layout fill behavior.

## Build Command Flow

```mermaid
flowchart LR
  A["swift-web build"] --> B["materialize .swiftweb/generated"]
  B --> C["server build"]
  A2["swift-web build --wasm"] --> B
  B --> D["WASM build"]
  C --> E["app-server"]
  D --> F["<AppName>WasmRuntime"]
```

| Mode | Product | Notes |
|---|---|---|
| Server | `app-server` by default | Uses the app library product from the user package. |
| WASM | Main generated `*WasmRuntime` plus coalesced policy runtimes when non-eager islands exist | Defaults to release, sets `SWIFTWEB_WASM_BUILD=1`, uses the shell-selected `swift`, and builds the generated client-only package without reading the user app's server dependencies. `SWIFTWEB_WASM_SPLIT_BUILD_STRATEGY=resolved-bundles` forces one physical WASM product per resolved split for diagnostics. |

After a WASM build, the CLI runs the production artifact processor:

```mermaid
flowchart LR
  A[".wasm"] --> B["strip debug custom sections"]
  B --> C["wasm-opt -Oz when available"]
  C --> D[".wasm.size.json"]
  C --> E[".wasm.gz"]
  C --> F[".wasm.br"]
```

`SWIFTWEB_WASM_OPTIMIZE=0` skips `wasm-opt`. `SWIFTWEB_WASM_BROTLI_QUALITY` can lower Brotli quality when release build time matters more than maximum transfer compression.

## Generated Files

| File | Responsibility |
|---|---|
| `.swiftweb/generated/server/Package.swift` | Production server package. |
| `.swiftweb/generated/server/Sources/AppServerLauncher/ServerLauncher.swift` | Thin production entrypoint that calls `<AppName>.run()` without importing `SwiftWebDevelopment`. |
| `.swiftweb/generated/dev/Package.swift` | Development package for Xcode/CLI launchers. |
| `.swiftweb/generated/dev/Sources/SwiftWebDevLauncher/DevLauncher.swift` | Dev entrypoint that delegates to `SwiftWebDevRuntime`. |
| `.swiftweb/generated/dev/Sources/AppDevelopmentServerLauncher/ServerLauncher.swift` | Dev child server entrypoint that installs `SwiftWebDevelopment` hooks before running the app. |
| `.swiftweb/generated/wasm/Sources/<AppName>` | Client-only source copy used by WASM runtime targets. |
| `.swiftweb/generated/wasm/Sources/SwiftHTML` | Runtime-only SwiftHTML source copy. Preview macros and `swift-syntax` are not included in the WASM package graph. |
| `.swiftweb/generated/wasm/Sources/SwiftWebActors` | Generated copy of the shared distributed actor runtime used by WASM runtime targets. |
| `.swiftweb/generated/wasm/Sources/SwiftWebUI` | Client UI component source copy used by WASM runtime targets. |
| `.swiftweb/generated/wasm/Sources/SwiftWebUIRuntime` | JavaScriptKit-backed client runtime source copy used by WASM runtime targets. |
| `.swiftweb/generated/wasm/Sources/JavaScriptKit` | Runtime-only JavaScriptKit source copy. BridgeJS macro definitions and `swift-syntax` are not included in the WASM package graph. |
| `.swiftweb/generated/wasm/Sources/_CJavaScriptKit` | C shim target required by the runtime-only JavaScriptKit target. |
| `.swiftweb/generated/wasm/Sources/*WasmRuntime` | App-specific WASM export entrypoint. |
| `.swiftweb/storyboard` | Managed app package generated by `swift-web storyboard` for visual component inspection. |
| `swift-html` package dependency | Client HTML runtime used by the app and server packages; WASM uses a runtime-only source copy to keep macro dependencies out. |

Open `.swiftweb/generated/dev` in Xcode to run the generated `<AppName>-dev` scheme. That scheme builds `SwiftWebDevLauncher`, which starts the same `SwiftWebDevRuntime` used by `swift-web dev`.

## Clean Command

`swift-web clean` removes generated build products that are safe to recreate. It is intended to keep repeated dev, Storyboard, and WASM builds from accumulating unnecessary storage.

```mermaid
flowchart LR
  A["swift-web clean"] --> B[".swiftweb/generated/.build"]
  A --> C[".swiftweb/storyboard/.swiftweb/generated/.build"]
  A --> D[".swiftweb/wasm-tools"]
  A -. --swiftpm .-> E["package .build"]
  A -. --storyboard .-> F[".swiftweb/storyboard"]
  A -. --all .-> G["all optional clean targets"]
```

| Option | Behavior |
|---|---|
| Default | Removes generated SwiftWeb build caches and WASM helper caches. |
| `--swiftpm` | Also removes the package-level `.build` directory. |
| `--storyboard` | Removes the managed Storyboard package source as well as its generated caches. |
| `--all` | Enables both `--swiftpm` and `--storyboard`. |

## Not Responsible For

| Not owned by SwiftWebCLI | Owner |
|---|---|
| HTTP response rendering | `SwiftWeb` and `SwiftHTML` |
| Development browser runtime injection | `SwiftWebDevelopment` |
| Development watch/restart runtime | `SwiftWebDevelopment` |
| Component layout and theme behavior | `SwiftWebUI` |
| Macro expansion | `SwiftWebMacros` |
| Vapor route registration | `SwiftWeb` |
| Client WASM graph, diff, and hydration internals | `SwiftHTML` |

## Design Notes

- The CLI should parse commands and delegate development runtime behavior to `SwiftWebDevelopment`.
- The dev command delegates browser update behavior to `SwiftWebDevRuntime`. That runtime prefers typed EventSource HMR events and keeps reload-token waiting as a compatibility fallback.
- Component-level HMR is a SwiftWeb runtime responsibility. The CLI only starts the runtime and materializes the generated package used by server and WASM builds.
- Client WASM builds should use stable generated package layouts, write-if-changed materialization, dirty bundle rebuilds, and content-addressed caches keyed by sources, dependencies, toolchain, SDK, and build flags.
- Child server cleanup is part of the dev runtime contract, not something each app should implement manually.
- Templates should demonstrate supported features without becoming the source of runtime behavior.
- The storyboard is generated output for framework authors. It must stay isolated from application source and should cover style regressions broadly enough to make visual changes reviewable.
- Storyboard materialization replaces only managed generated sources by default. Build caches are cleaned by `swift-web clean` so normal regeneration does not throw away useful incremental build state.
- Generated projects should depend on library APIs rather than private implementation details.
