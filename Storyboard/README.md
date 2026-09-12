# SwiftWebUI Storyboard

An independent application package in this repository. It consumes the parent
SwiftWeb package and owns the component catalog and its tests.

From the repository root, with the [pinned toolchain](../docs/Toolchain.md):

```bash
swift run --package-path . sweb storyboard
swift run --package-path . sweb storyboard build
swift test --package-path Storyboard
```

Open `/storyboard` on the development server. Generated output stays under
`Storyboard/.swiftweb`; the application sources are authored, not generated.
The repository browser gate is `npm run storyboard-navigation` in
`Tests/BrowserE2E` and launches this app through `sweb storyboard`.

The repository root selects this application using the [CLI contract](../Sources/SwiftWebCLI/DESIGN.md).

See [DESIGN.md](DESIGN.md) for ownership and verification boundaries.
