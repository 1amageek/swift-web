import SwiftWebDevServer
import SwiftWebPackageGeneration
import Foundation

public struct SwiftWebStoryboardRuntimeObserver: Sendable {
    public let didGenerate: @Sendable (URL) -> Void
    public let didSkipServer: @Sendable (URL) -> Void
    public let willStartServer: @Sendable (String, Int) -> Void

    public init(
        didGenerate: @escaping @Sendable (URL) -> Void = { _ in },
        didSkipServer: @escaping @Sendable (URL) -> Void = { _ in },
        willStartServer: @escaping @Sendable (String, Int) -> Void = { _, _ in }
    ) {
        self.didGenerate = didGenerate
        self.didSkipServer = didSkipServer
        self.willStartServer = willStartServer
    }
}
