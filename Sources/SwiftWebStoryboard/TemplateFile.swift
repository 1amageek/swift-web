import Foundation

/// A single file emitted by a storyboard template.
struct TemplateFile {
    let path: String
    let contents: String

    init(path: String, contents: String) {
        self.path = path
        self.contents = contents
    }
}
