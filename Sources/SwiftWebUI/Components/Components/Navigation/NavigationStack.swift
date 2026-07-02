import SwiftWebUITheme
import SwiftHTML

struct NavigationPathSegmentsEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue: [String]? = nil
}

extension EnvironmentValues {
    var navigationPathSegments: [String]? {
        get { self[NavigationPathSegmentsEnvironmentKey.self] }
        set { self[NavigationPathSegmentsEnvironmentKey.self] = newValue }
    }
}

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
                .environment(\.navigationPathSegments, path?.wrappedValue.components)
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
        var attributes = [
            HTMLAttribute("data-navigation-stack", "true"),
            HTMLAttribute("data-navigation-path", path.wrappedValue.components.joined(separator: "/")),
        ]
        if !path.wrappedValue.isEmpty {
            attributes.append(HTMLAttribute("data-navigation-pushed", "true"))
        }
        return attributes
    }
}
