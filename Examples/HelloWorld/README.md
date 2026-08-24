# HelloWorld

HelloWorld is the minimal SwiftWeb example. It mounts a single page at `/` and renders a static SwiftWebUI view.

Its package manifest uses the SwiftWeb checkout at the repository root, so the
example exercises the current lifecycle and adapter schema.

## Structure

```text
HelloWorld
├─ Package.swift
└─ Sources/HelloWorld
   ├─ App.swift
   └─ Routes/HelloPage.swift
```

## Run

Use the pinned Swift 6.4 snapshot from the
[toolchain contract](../../docs/Toolchain.md):

```bash
export SWIFT_WEB_TOOLCHAIN_BIN="$HOME/Library/Developer/Toolchains/swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a.xctoolchain/usr/bin"
export SWIFT_WEB_HOST_SWIFT="$SWIFT_WEB_TOOLCHAIN_BIN/swift"
```

When `sweb` is installed:

```bash
sweb dev
```

Open:

```text
http://127.0.0.1:3000/
```

## Build

```bash
sweb build --environment local
```

The lifecycle builds the server and verifies the selected local deployment.
HelloWorld has no client island, so it skips the optional browser WASM runtime.
