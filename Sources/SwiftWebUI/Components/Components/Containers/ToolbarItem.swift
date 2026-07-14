import SwiftWebUITheme
import SwiftHTML

struct ToolbarRegionEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue: ToolbarItemPlacement.Region? = nil
}

extension EnvironmentValues {
    var toolbarRegion: ToolbarItemPlacement.Region? {
        get { self[ToolbarRegionEnvironmentKey.self] }
        set { self[ToolbarRegionEnvironmentKey.self] = newValue }
    }
}

/// A toolbar item with a placement, mirroring SwiftUI's `ToolbarItem`.
///
/// The enclosing `.toolbar { ... }` renders its content once per bar region and
/// each item emits only in the region its placement selects, so declaration
/// order inside the builder does not constrain the visual layout.
public struct ToolbarItem<Content: HTML>: Component {
    @Environment({ $0.toolbarRegion }) private var region: ToolbarItemPlacement.Region?

    private let placement: ToolbarItemPlacement
    private let content: Content

    public init(
        placement: ToolbarItemPlacement = .automatic,
        @HTMLBuilder content: () -> Content
    ) {
        self.placement = placement
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        if region == nil || region == placement.region {
            Element(
                "div",
                attributes: mergedAttributes(class: "swui-toolbar-item", extra: [])
            ) {
                content
            }
        }
    }
}

/// A group of toolbar content sharing one placement, mirroring SwiftUI's
/// `ToolbarItemGroup`.
public struct ToolbarItemGroup<Content: HTML>: Component {
    @Environment({ $0.toolbarRegion }) private var region: ToolbarItemPlacement.Region?

    private let placement: ToolbarItemPlacement
    private let content: Content

    public init(
        placement: ToolbarItemPlacement = .automatic,
        @HTMLBuilder content: () -> Content
    ) {
        self.placement = placement
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        if region == nil || region == placement.region {
            Element(
                "div",
                attributes: mergedAttributes(class: "swui-toolbar-item swui-toolbar-item-group", extra: [])
            ) {
                content
            }
        }
    }
}
