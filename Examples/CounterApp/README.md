# CounterApp

CounterApp is the primary SwiftWeb sample for validating the intended application shape:

- `Package.swift` declares only the user app library.
- `CounterApp` owns route mounting through `SwiftWeb.App`.
- `CounterPage` keeps server data loading and page UI in one `@Page`.
- `ClientCounter` owns client-side `@State` and is copied into the generated WASM client target.
- `CounterService` exposes distributed server actions through function-level `@ServerAction`.
- `.swiftweb/generated` owns launchers, server executable packaging, client-runtime source copies, and WASM runtime packaging.

## Structure

```mermaid
flowchart TD
  UserPackage["CounterApp Package.swift"]
  AppTarget["CounterApp library target"]
  GeneratedPackage[".swiftweb/generated Package.swift"]
  DevProduct["CounterApp dev product"]
  ServerProduct["app-server product"]
  WasmProduct["counter-wasm-runtime product"]
  Page["CounterPage @Page"]
  Client["ClientCounter ClientComponent"]
  Service["CounterService distributed actor"]

  UserPackage --> AppTarget
  AppTarget --> Page
  Page --> Client
  Page --> Service
  GeneratedPackage --> DevProduct
  GeneratedPackage --> ServerProduct
  GeneratedPackage --> WasmProduct
  ServerProduct --> AppTarget
  WasmProduct --> Client
```

| Area | Responsibility |
|---|---|
| `Examples/CounterApp/Package.swift` | User-owned app module only. No launchers, no server executable, no WASM linker flags. |
| `Sources/CounterApp` | Pages, client components, app declaration, and page-local services. |
| `.swiftweb/generated/Package.swift` | Generated build package for dev launcher, server launcher, and WASM runtime targets. |
| `.swiftweb/generated/Sources/AppServerLauncher` | Thin generated server entrypoint that calls `CounterApp.run()`. |
| `.swiftweb/generated/Sources/SwiftWebDevLauncher` | Generated Xcode/CLI-friendly dev entrypoint that delegates to `SwiftWebDevRuntime`. |
| `.swiftweb/generated/Sources/CounterApp` | Generated client-only source copy for WASM builds. |
| `.swiftweb/generated/Sources/SwiftWebUI` | Generated copy of the client UI component library used by the WASM build. |
| `swift-html` package dependency | Client HTML runtime used by server rendering and WASM builds. |
| `.swiftweb/generated/Sources/CounterWasmRuntime` | Generated WASM exports for client-side state and event dispatch. |

The hand-written app surface is intentionally small:

```text
CounterApp
├─ App.swift                SwiftWeb.App declaration
├─ ClientCounter.swift      ClientComponent used by server render and WASM runtime
├─ Routes/CounterPage.swift @Page body
└─ Actions/CounterService.swift
```

`CounterApp` mounts routes only:

```swift
public var body: some AppContent {
    Redirect("/", to: "/counter")
    CounterPage()
}
```

`CounterPage` owns its server counter service for the route lifetime:

```swift
private let counterService = CounterService(actorSystem: .shared)

func load() async throws -> Int {
    try await counterService.currentValue()
}

Button("Increment", action: counterService.incrementAction)
```

The server counter value lives inside `CounterService`. It is not stored in the URL query and it is not a client-side hidden field.

The server action mutates actor state and returns `ActionResult.invalidate(.page)`. The client WASM runtime then refreshes the server counter DOM while preserving `ClientCounter`'s local `@State`.

```mermaid
flowchart LR
  A["ClientCounter @State"] --> B["Preserved"]
  C["CounterService value"] --> D["Mutated on server"]
  D --> E["invalidate(.page)"]
  E --> F["Server Counter DOM updated"]
```

## Run

Run the development server with hot reload:

```bash
swift-web dev --package-path Examples/CounterApp
```

Open:

```text
http://127.0.0.1:3000/counter
```

`swift-web dev` materializes `.swiftweb/generated/Package.swift`, builds `app-server` from that generated package, starts the Vapor child process, watches the app package plus local package dependencies, and reloads the browser through the dev reload endpoint.

```mermaid
flowchart LR
  A["swift-web dev"] --> B["materialize .swiftweb/generated"]
  B --> C["swift build --package-path .swiftweb/generated --product app-server"]
  C --> D["launch server executable"]
  D --> E["FSEvents watch"]
  E --> F["rebuild and restart"]
  F --> G["browser reload wait completes"]
```

Build the server without running it:

```bash
swift-web build --package-path Examples/CounterApp
```

Run from Xcode:

```text
Open Examples/CounterApp/.swiftweb/generated in Xcode and select the CounterApp scheme.
```

The generated `CounterApp` scheme builds `SwiftWebDevLauncher`. Running it starts the same `SwiftWebDevRuntime` used by `swift-web dev`, including FSEvents rebuild, child restart, parent PID cleanup, and browser reload signaling.

Build the user app library only:

```bash
swift build --package-path Examples/CounterApp
```

## Build WASM Runtime

```bash
swift-web build \
  --package-path Examples/CounterApp \
  --wasm \
  --swift-sdk swift-6.3.1-RELEASE_wasm \
  -c release
```

The generated WASM branch compiles a generated client-only `CounterApp` target from `.swiftweb/generated/Sources/CounterApp`, links `SwiftHTML` from the `swift-html` package dependency, uses the generated `SwiftWebUI` source copy, then links `CounterWasmRuntime`. Server-only sources stay in the user app library and are not part of the WASM target.

The output is written to the shared SwiftPM scratch path:

```text
.build/wasm32-unknown-wasip1/release/counter-wasm-runtime.wasm
```
