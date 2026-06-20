# HelloWorld

HelloWorld is the minimal SwiftWeb example. It mounts a single page at `/` and renders a static SwiftWebUI view.

## Structure

```text
HelloWorld
├─ Package.swift
└─ Sources/HelloWorld
   ├─ App.swift
   └─ Routes/HelloPage.swift
```

## Run

```bash
sweb dev --package-path Examples/HelloWorld
```

Open:

```text
http://127.0.0.1:3000/
```

## Build

```bash
xcrun swift build --package-path Examples/HelloWorld
```
