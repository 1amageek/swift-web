# SwiftWeb Examples

| Example | Purpose |
|---|---|
| `HelloWorld` | Minimal `@Page` and SwiftWebUI rendering example. |
| `CounterApp` | Canonical sample for `@Page`, SwiftWebUI layout, client `@State`, WASM hydration, server actions, and distributed service RPC. |

Both examples use the pinned Swift 6.4 snapshot documented in
[Toolchain](../docs/Toolchain.md). Configure
the real toolchain executable before running them:

```bash
export SWIFT_WEB_TOOLCHAIN_BIN="$HOME/Library/Developer/Toolchains/swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-23-a.xctoolchain/usr/bin"
export SWIFT_WEB_HOST_SWIFT="$SWIFT_WEB_TOOLCHAIN_BIN/swift"
export SWIFT_WEB_WASM_SWIFT="$SWIFT_WEB_TOOLCHAIN_BIN/swift"
export SWIFT_WEB_WASM_TOOLCHAIN_BIN="$SWIFT_WEB_TOOLCHAIN_BIN"
```

Run the hello world sample:

```bash
cd Examples/HelloWorld
sweb dev
```

Open `http://127.0.0.1:3000/`.

Run the counter sample:

```bash
cd Examples/CounterApp
sweb dev
```

Open `http://127.0.0.1:3000/counter`.
