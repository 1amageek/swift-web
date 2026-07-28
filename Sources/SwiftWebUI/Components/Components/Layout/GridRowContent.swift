import SwiftHTML

public struct GridRowContent<Content: Component>: Sendable {
    let content: Content
    let cellCount: Int

    init(content: Content, cellCount: Int) {
        self.content = content
        self.cellCount = cellCount
    }
}
