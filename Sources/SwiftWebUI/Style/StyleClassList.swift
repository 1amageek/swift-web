import SwiftHTML

public struct StyleClassList: Sendable, Equatable, Hashable, ExpressibleByArrayLiteral, ExpressibleByStringLiteral, CustomStringConvertible {
    public private(set) var classes: [StyleClass]

    public init(_ classes: [StyleClass]) {
        var seen: Set<StyleClass> = []
        self.classes = classes.filter { seen.insert($0).inserted }
    }

    public init(_ classes: [StyleClass?]) {
        self.init(classes.compactMap { $0.self })
    }

    public init(_ rawValue: String) {
        self.init(rawValue.split(whereSeparator: { $0.isWhitespace }).map { StyleClass(String($0)) })
    }

    public init(arrayLiteral elements: StyleClass...) {
        self.init(elements)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public var rawValue: String {
        classes.map { $0.rawValue }.joined(separator: " ")
    }

    public var description: String {
        rawValue
    }

    public var isEmpty: Bool {
        classes.isEmpty
    }

    public var attribute: HTMLAttribute {
        .class(rawValue)
    }
}

public func styleClasses(_ classes: StyleClass?...) -> StyleClassList {
    StyleClassList(classes)
}

public func styleClasses(_ classes: [StyleClass?]) -> StyleClassList {
    StyleClassList(classes)
}

public extension HTMLAttribute {
    static func `class`(_ classList: StyleClassList) -> HTMLAttribute {
        classList.attribute
    }
}
