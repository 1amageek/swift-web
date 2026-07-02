import SwiftWebUITheme
import SwiftHTML

public struct NavigationStack<Content: HTML>: WebUIAttributeComponent {
    private let path: Binding<NavigationPath>?
    private let content: Content
    private let attributes: [HTMLAttribute]

    public init(
        path: Binding<NavigationPath>? = nil,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder root: () -> Content
    ) {
        self.path = path
        self.attributes = attributes
        self.content = root()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "nav",
            attributes: mergedAttributes(
                class: "swui-navigation-stack",
                extra: navigationAttributes + attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(path: path, attributes: self.attributes + attributes, content: content)
    }

    private init(path: Binding<NavigationPath>?, attributes: [HTMLAttribute], content: Content) {
        self.path = path
        self.attributes = attributes
        self.content = content
    }

    private var navigationAttributes: [HTMLAttribute] {
        guard let path else {
            return [HTMLAttribute("data-navigation-stack", "true")]
        }
        return [
            HTMLAttribute("data-navigation-stack", "true"),
            HTMLAttribute("data-navigation-path", path.wrappedValue.components.joined(separator: "/")),
        ]
    }
}
