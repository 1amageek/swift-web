# CounterApp

CounterApp is the end-to-end SwiftWeb sample. It combines a loaded page,
SwiftWebUI, browser-owned state, server actions, and typed distributed actor
calls.

## Architecture

```mermaid
flowchart LR
  App["CounterApp"] --> ActorScene["ActorScene"]
  ActorScene --> Page["CounterPage"]
  Page --> Load["CounterService.currentValue"]
  Page --> Client["ClientCounter"]
  Client --> State["browser @State"]
  Client --> Remote["@RemoteActor"]
  Remote --> Service["CounterService"]
  Page --> Action["server action"]
  Action --> Service
```

| Source | Responsibility |
|---|---|
| `App.swift` | Redirects `/` and mounts the counter service and page in `ActorScene` |
| `Routes/CounterPage.swift` | Loads server state and renders the complete document |
| `ClientCounter.swift` | Owns browser `@State` and typed actor calls |
| `Actions/CounterService.swift` | Declares the concrete distributed actor contract and implements server state, calls, and page-invalidating actions |

The user package remains a library. `sweb` owns concrete launch products under
`.swiftweb/generated`:

```text
.swiftweb/generated/
├─ dev/       Xcode and development launchers
├─ server/    production HTTP server launcher
└─ wasm/      client-only source copies and runtime products
```

## State Ownership

The two counters intentionally have different owners:

| Value | Owner | Update path |
|---|---|---|
| Client counter | `ClientCounter` in browser WASM | Local event handler mutates `@State` |
| Server counter | `CounterService` distributed actor | Server action or typed RPC mutates actor state |

A server action returns page invalidation. SwiftWeb fetches the current page,
patches server-owned DOM, and preserves the client component's local state.

## Run

Configure the pinned toolchain from [Toolchain](../../docs/Toolchain.md), then:

```bash
sweb dev
```

Open [http://127.0.0.1:3000/counter](http://127.0.0.1:3000/counter). If the
port is occupied, use the URL printed by `sweb dev`.

The persistent DevHost serves application traffic and EventSource updates while
replaceable `SwiftWebHTTPServerHost` workers build and restart behind it.

## Xcode

```bash
sweb xcode
```

Open the generated `CounterApp-dev` scheme. It runs the same development
reconciler used by `sweb dev`.

## Production Builds

Build the native server:

```bash
sweb build
```

Build optimized browser runtimes and compression sidecars:

```bash
sweb build \
  --wasm \
  --runtime standard \
  --swift-sdk swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a_wasm \
  -c release
```

CounterApp is the fixture used by the real Chromium development-server gate in
[Development Reconciler Verification](../../docs/DevServerReconcilerVerification.md).
