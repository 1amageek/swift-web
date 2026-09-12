# SwiftWeb Examples

| Example | Purpose |
|---|---|
| `HelloWorld` | Minimal `@Page` and SwiftWebUI rendering example. |
| `CounterApp` | Canonical `.actor(Type.self, identity:)` sample with local Actor hosting, server and browser `@RemoteActor` calls, WASM hydration, and Server Actions. |

Select the pinned Swift 6.4 snapshot and install its matching WASM SDK as described
in [Toolchain](../docs/Toolchain.md). Standard installations are detected automatically.

Their package manifests resolve SwiftWeb from the repository root. This keeps
the examples on the same runtime, adapter schema, and generated-package
contract as the checkout being developed.

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
