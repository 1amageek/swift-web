import SwiftWebUITheme
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SwiftHTML

public struct NavigationLink<Label: HTML>: WebUIAttributeComponent {
    private let destination: URL
    private let attributes: [HTMLAttribute]
    private let label: Label

    public init(
        destination: URL,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder label: () -> Label
    ) {
        self.destination = destination
        self.attributes = attributes
        self.label = label()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "a",
            attributes: mergedAttributes(
                class: "swui-navigation-link",
                extra: [
                    .href(destination.relativeString),
                    HTMLAttribute("data-navigation-link", "true"),
                ] + attributes
            )
        ) {
            label
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(destination: destination, attributes: self.attributes + attributes, label: label)
    }

    private init(destination: URL, attributes: [HTMLAttribute], label: Label) {
        self.destination = destination
        self.attributes = attributes
        self.label = label
    }
}

public extension NavigationLink where Label == text {
    init(_ title: String, destination: URL, _ attributes: HTMLAttribute...) {
        self.init(destination: destination, attributes: attributes, label: text(title))
    }
}
