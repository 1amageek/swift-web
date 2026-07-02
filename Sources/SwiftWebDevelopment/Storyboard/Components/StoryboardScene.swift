import Foundation

/// The curated preview backdrops. Liquid Glass and materials are invisible
/// against a void, so every stage renders on one of these gradient scenes;
/// categories map to scenes so sibling pages feel related.
enum StoryboardScene: String, Sendable {
    case aurora
    case dawn
    case mist
    case meadow

    var className: String {
        "swui-storyboard-scene swui-storyboard-scene-\(rawValue)"
    }

    static func scene(forItem id: String) -> StoryboardScene {
        switch catalogCategory(for: id)?.id {
        case "foundations", "layout":
            return .mist
        case "content":
            return .dawn
        case "menus", "navigation", "animation":
            return .aurora
        case "input", "status":
            return .meadow
        case "presentation":
            return .dawn
        default:
            return .mist
        }
    }
}
