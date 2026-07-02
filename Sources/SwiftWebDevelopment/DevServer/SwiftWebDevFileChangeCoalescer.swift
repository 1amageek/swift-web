import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
enum SwiftWebDevFileChangeCoalescer {
    static func coalesce(_ changes: [SwiftWebDevFileChange]) -> [SwiftWebDevFileChange] {
        var orderedPaths: [String] = []
        var byPath: [String: SwiftWebDevFileChange] = [:]

        for change in changes {
            guard let oldChange = byPath[change.path] else {
                orderedPaths.append(change.path)
                byPath[change.path] = change
                continue
            }

            byPath[change.path] = merged(oldChange, with: change)
        }

        return orderedPaths.compactMap { byPath[$0] }
    }

    private static func merged(
        _ old: SwiftWebDevFileChange,
        with new: SwiftWebDevFileChange
    ) -> SwiftWebDevFileChange {
        let kind: SwiftWebDevFileChange.Kind
        switch (old.kind, new.kind) {
        case (.added, .modified):
            kind = .added
        case (.added, .removed):
            kind = .removed
        case (.removed, .added):
            kind = .modified
        default:
            kind = new.kind
        }
        return SwiftWebDevFileChange(path: new.path, url: new.url, kind: kind)
    }
}
