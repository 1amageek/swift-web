import SwiftHTML

enum StoryboardSchemePreference: String, Sendable {
    static let cookieName = "swui-storyboard-scheme"

    case light
    case dark
    case auto

    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            return nil
        }
    }
}
