import SwiftWebUITheme
import SwiftHTML

public struct Label<Title: HTML, Icon: HTML>: AttributeComponent {
    private let title: Title
    private let icon: Icon
    private let attributes: [HTMLAttribute]
    @Environment({ $0.labelStyle }) private var labelStyle: LabelStyleKind

    public init(
        @HTMLBuilder title: () -> Title,
        @HTMLBuilder icon: () -> Icon
    ) {
        self.title = title()
        self.icon = icon()
        self.attributes = []
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "span",
            attributes: mergedAttributes(
                class: controlClassName("swui-label", labelStyle.className),
                extra: attributes
            )
        ) {
            // The icon is decorative: the title is the label's accessible name.
            // For the icon-only style the title is visually hidden (not removed)
            // so it still names the control — see `.swui-label-style-iconOnly`.
            span(.class("swui-label-icon"), .aria("hidden", "true")) {
                icon
            }
            span(.class("swui-label-title")) {
                title
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title: title, icon: icon, attributes: self.attributes + attributes)
    }

    private init(title: Title, icon: Icon, attributes: [HTMLAttribute]) {
        self.title = title
        self.icon = icon
        self.attributes = attributes
    }
}

public extension Label where Title == text, Icon == Image {
    init(_ title: String, systemImage: String) {
        self.init(title: text(title), icon: Image(systemName: systemImage), attributes: [])
    }
}
