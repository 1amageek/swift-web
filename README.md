# SwiftWeb

SwiftWeb is a Swift framework for server-rendered web applications with an
optional Swift WASM browser runtime. Applications describe routes and complete
HTML documents in Swift, use SwiftWebUI for higher-level components, and opt
individual client components into hydration, local state, and browser events.

> SwiftWeb 0.8 is a developer preview. It requires the pinned Swift 6.4
> development snapshot because its HTTP host uses the current lifetime-aware
> Swift server APIs.

## What You Build

```mermaid
flowchart LR
  App["SwiftWeb.App"] --> Scene["Scene and routes"]
  Scene --> Page["@Page"]
  Page --> Document["HTMLDocument"]
  Document --> HTML["server-rendered HTML"]
  Document --> Island["ClientComponent"]
  Island --> WASM["Swift WASM runtime"]
  WASM --> Browser["hydration, state, and events"]
```

| Layer | Responsibility |
|---|---|
| `SwiftHTML` | HTML elements, reusable `Component` values, documents, and rendering |
| `SwiftWeb` | Application scenes, pages, routing, request context, actions, and actors |
| `SwiftWebUI` | Layout, controls, themes, modifiers, and client components |
| `sweb` | Project generation, generated packages, development server, Storyboard, and production builds |

## Requirements

SwiftWeb pins the host toolchain and WASM SDK to the same snapshot.

| Item | Required value |
|---|---|
| Swift tools version | `6.4` |
| Swiftly selector | `6.4-snapshot-2026-07-23` |
| Swift toolchain | `swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-23-a` |
| Browser SDK | `swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-23-a_wasm` |
| Package platform | macOS 26.2 or newer |

For WASM commands, point SwiftWeb at the real toolchain directory. A `swiftly`
shim does not contain the matching `wasm-ld` executable.

```bash
export SWIFT_WEB_TOOLCHAIN_BIN="$HOME/Library/Developer/Toolchains/swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-23-a.xctoolchain/usr/bin"
export SWIFT_WEB_HOST_SWIFT="$SWIFT_WEB_TOOLCHAIN_BIN/swift"
export SWIFT_WEB_WASM_SWIFT="$SWIFT_WEB_TOOLCHAIN_BIN/swift"
export SWIFT_WEB_WASM_TOOLCHAIN_BIN="$SWIFT_WEB_TOOLCHAIN_BIN"

"$SWIFT_WEB_HOST_SWIFT" --version
test -x "$SWIFT_WEB_WASM_TOOLCHAIN_BIN/wasm-ld"
```

See [Toolchain](docs/Toolchain.md) for the complete host and WASM setup.

## Quick Start

Install the `sweb` executable from the 0.10.0 release with
[Mint](https://github.com/yonaskolb/Mint):

```bash
export PATH="$SWIFT_WEB_TOOLCHAIN_BIN:$PATH"
mint install 1amageek/swift-web@0.10.0 sweb
sweb --help
```

Create and run an application:

```bash
sweb new MyApp --output .
cd MyApp
sweb dev
```

Open [http://127.0.0.1:3000](http://127.0.0.1:3000). If port 3000 is
occupied, `sweb dev` selects the next available port and prints it.

The generated package depends on released versions of SwiftWeb and SwiftHTML:

```swift
// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS("26.2")],
    products: [
        .library(name: "MyApp", targets: ["MyApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/1amageek/swift-web.git", from: "0.10.0"),
        .package(url: "https://github.com/1amageek/swift-html.git", from: "0.15.0"),
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                .product(name: "SwiftHTML", package: "swift-html"),
                .product(name: "SwiftWeb", package: "swift-web"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

## Authoring Model

### Application and routes

An application declares its route topology through `App.body`:

```swift
import SwiftWeb

public struct MyApp: SwiftWeb.App {
    public init() {}

    public var body: some Scene {
        HomePage()
        AboutPage()
    }
}
```

`App` owns only the declarative application definition. The host owns its
server configuration and lifecycle, then renders the app through SwiftWeb's
common rendering boundary:

```swift
import SwiftWebHTTPServerHost

let host = HTTPServerHost(hostname: "127.0.0.1", port: 8080)
let installation = try await host.render(MyApp())
defer { installation.shutdown() }
try await installation.serve()
```

`App.run()` is the command-line convenience over this same path. Host adapter
authors should follow the [Host Rendering Contract](docs/HostRenderingContract.md).

A static page returns a complete `HTMLDocument`:

```swift
import SwiftHTML
import SwiftWeb

@Page("/")
struct HomePage {
    var document: some HTMLDocument {
        PageDocument(
            title: "Home",
            description: "A SwiftWeb application."
        ) {
            main {
                h1 { "Hello SwiftWeb" }
                p { "Rendered on the server with SwiftHTML." }
            }
        }
    }
}
```

Use `load()` and `document(_:)` when rendering needs asynchronous data:

```swift
import SwiftHTML
import SwiftWeb

@Page("/profile")
struct ProfilePage {
    struct Model: Sendable {
        let displayName: String
    }

    func load() async throws -> Model {
        Model(displayName: "Taylor")
    }

    func document(_ model: Model) -> some HTMLDocument {
        PageDocument(title: model.displayName) {
            main {
                h1 { model.displayName }
            }
        }
    }
}
```

`Component` is the reusable, nestable authoring unit. `HTMLDocument` owns a
complete page and cannot be nested inside a component. The full contract is in
[HTML Authoring Model](docs/HTMLAuthoringModel.md).

### SwiftWebUI

Add the `SwiftWebUI` product when you want higher-level layout and controls:

```swift
.product(name: "SwiftWebUI", package: "swift-web")
```

SwiftWebUI components lower into the same SwiftHTML graph, so raw HTML elements
and SwiftWebUI values can be composed at one page boundary.

```swift
import Foundation
import SwiftHTML
import SwiftWeb
import SwiftWebUI

@Page("/")
struct HomePage {
    var document: some HTMLDocument {
        PageDocument(title: "Home") {
            main {
                VStack(spacing: .large) {
                    Text("Hello SwiftWeb").as(.h1)
                    Link("About", destination: URL(string: "/about")!)
                }
                .frame(maxWidth: 720)
            }
        }
    }
}
```

### Browser components

`ClientComponent` runs in the generated standard Swift WASM runtime. Its
`@State` values and event handlers remain in the browser:

```swift
import SwiftHTML
import SwiftWebUI

public struct Counter: ClientComponent {
    @State private var count = 0

    public init() {}

    public var content: some Component {
        VStack(spacing: .small) {
            Text("Count: \(count)")
            Button("Increment") {
                count += 1
            }
        }
    }
}
```

The default contract places small client components in the eager main bundle.
Large or deferred islands can declare a loading and bundle policy:

```swift
public static let loadPolicy: LoadPolicy = .visible
public static let bundle: BundlePolicy = .named("analytics")
```

Available load policies are `.eager`, `.visible`, `.interaction`, `.idle`, and
`.manual`. See [Client Bundle Loading](docs/ClientBundleLoadingDesign.md) for
bundle resolution, ownership, and production behavior.

## Development Workflow

`sweb dev` maintains desired source state and the currently serving worker. It
materializes generated packages, rebuilds changed browser/server paths, swaps a
ready worker, and recovers from build failures without discarding the last good
application.

```mermaid
flowchart LR
  Edit["edit Sources"] --> Dev["sweb dev"]
  Dev --> Prepare["materialize .swiftweb/generated"]
  Prepare --> Build["build WASM and server worker"]
  Build --> Serve["serve latest successful generation"]
  Serve --> HMR["browser HMR or page patch"]
  HMR --> Edit
```

Generated content is build output. Keep application changes in `Package.swift`
and `Sources`; do not edit `.swiftweb/generated` directly.

| Command | Purpose |
|---|---|
| `sweb new <Name> [--output <directory>]` | Create a minimal application |
| `sweb new <Name> --ai` | Create a chat-oriented SwiftWebUI application |
| `sweb new <Name> --adapter <owner/repository>` | Add an adapter package and configured production environment |
| `sweb prepare [--environment <name>]` | Resolve adapters and materialize configured environments |
| `sweb xcode` | Refresh and open `.swiftweb/generated/dev` |
| `sweb dev [--environment <name>] [--host <host>] [--port <port>]` | Build and run the selected environment locally |
| `sweb storyboard` | Generate and run the SwiftWebUI component Storyboard |
| `sweb build [--environment <name>]` | Build and verify the selected environment |
| `sweb deploy [--environment <name>]` | Build, verify, and deploy the selected environment |
| `sweb clean [--storyboard] [--swiftpm] [--all]` | Remove selected generated output |

All package commands accept `--package-path <directory>`. Lifecycle commands
select their default environment from the source-controlled `sweb.json`.

Run `sweb xcode` to use the generated `<AppName>-dev` scheme in Xcode:

```bash
cd MyApp
sweb xcode
```

## Production Builds and Deployment

Build the complete selected environment. The Host adapter owns compilation and
the Deployment adapter owns platform validation:

```bash
cd MyApp
sweb build --environment production
```

Deploy only after the same environment has passed prepare and build:

```bash
sweb deploy --environment production
```

`sweb deploy` reruns prepare and build before the deployment operation. Remote
state changes remain isolated to the selected Deployment adapter's deploy
tasks.

The public browser profile is standard Swift WASM. Embedded Swift WASM is not
a supported SwiftWeb browser runtime.

## Project Layout

```text
MyApp/
├─ Package.swift
├─ sweb.json                  source-controlled environments
├─ Sources/MyApp/
│  ├─ App.swift
│  ├─ Routes/
│  └─ Components/
└─ .swiftweb/                 generated; do not edit
   └─ generated/
      ├─ environments/<name>/workspace/
      ├─ dev/
      ├─ server/
      └─ wasm/
```

SwiftWeb itself is split into runtime, browser, UI, development, and host
targets. The [documentation index](docs/README.md) maps each current contract
to its owning area.

## Host and Deployment Adapters

Deployment integrations live outside the core package. `sweb new` adds the
selected adapter as a SwiftPM dependency and writes its environment selection
to `sweb.json`:

```bash
sweb new Chat --ai --adapter owner/repository --output .
sweb new App --adapter owner/repository --output .
```

The adapter repository contract is documented in
[Host and Deployment Adapter Contract](docs/AdapterContract.md).

## Examples

| Example | Demonstrates |
|---|---|
| [HelloWorld](Examples/HelloWorld) | Minimal app, static `@Page`, SwiftHTML, and SwiftWebUI rendering |
| [CounterApp](Examples/CounterApp) | Loaded pages, client state, hydration, server actions, and distributed actor RPC |

```bash
cd Examples/HelloWorld
sweb dev
```

## Documentation

Read the [changelog](CHANGELOG.md) for release-level changes, then use the
[documentation index](docs/README.md) for current public contracts,
architecture decisions, and verification runbooks.

## Contributing

Use the pinned toolchain for every validation command. Native tests run through
Xcode with a timeout guard:

```bash
TOOLCHAINS=org.swift.64202607171a \
scripts/swift-test-hang-guard.sh \
  --repeats 1 \
  --timeout 1200 \
  --build-timeout 1200 \
  -- xcodebuild test \
    -scheme swift-web-Package \
    -destination platform=macOS \
    -jobs 2 \
    -parallel-testing-enabled NO
```

The complete browser-visible development path is verified separately:

```bash
cd Tests/BrowserE2E
npm run counter-wasm
```

See [Development Reconciler Verification](docs/DevServerReconcilerVerification.md)
for the required environment and acceptance conditions.

## License

SwiftWeb is available under the [MIT License](LICENSE).
