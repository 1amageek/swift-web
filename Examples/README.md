# SwiftWeb Examples

| Example | Purpose |
|---|---|
| `HelloWorld` | Minimal `@Page` and SwiftWebUI rendering example. |
| `CounterApp` | Canonical sample for `@Page`, SwiftWebUI layout, client `@State`, WASM hydration, server actions, and distributed service RPC. |

Run the hello world sample:

```bash
sweb dev --package-path Examples/HelloWorld
```

Open `http://127.0.0.1:3000/`.

Run the counter sample:

```bash
sweb dev --package-path Examples/CounterApp
```

Open `http://127.0.0.1:3000/counter`.
