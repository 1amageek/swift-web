# SwiftWebUI Storyboard

An independent application package in this repository. It consumes the parent
SwiftWeb package and owns the component catalog and its tests.

From the repository root, with the [pinned toolchain](../docs/Toolchain.md):

```bash
swift run --package-path . sweb dev --package-path Storyboard
swift run --package-path . sweb build --package-path Storyboard
swift test --package-path Storyboard
```

Open `/storyboard` on the development server. Generated output stays under
`Storyboard/.swiftweb`; the application sources are authored, not generated.
The repository browser gate is `npm run storyboard-navigation` in
`Tests/BrowserE2E` and launches this app through generic `sweb dev`.

The legacy `sweb storyboard` command remains available for managed preview
copies and its existing production flags. It links this package's catalog and
routes into `.swiftweb/storyboard`, excluding this app's entry point.

See [DESIGN.md](DESIGN.md) for ownership and verification boundaries.
