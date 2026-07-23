import SwiftHTML

public struct GridRowContent<Content: HTML>: Sendable {
    let content: Content
    let cellCount: Int

    init(content: Content, cellCount: Int) {
        self.content = content
        self.cellCount = cellCount
    }
}
