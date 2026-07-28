import SwiftHTML

public struct GridContent<Content: Component>: Sendable {
    let content: Content
    let maximumColumnCount: Int

    init(content: Content, maximumColumnCount: Int) {
        self.content = content
        self.maximumColumnCount = maximumColumnCount
    }
}
