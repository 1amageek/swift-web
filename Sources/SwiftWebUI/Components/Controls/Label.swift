import SwiftHTML

public struct Label<Title: HTML, Icon: HTML>: WebUIAttributeComponent {
    private let title: Title
    private let icon: Icon
    private let attributes: [HTMLAttribute]
    @Environment(\.labelStyle) private var labelStyle

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
            span(.class("swui-label-icon")) {
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
