import SwiftWebUITheme
import SwiftHTML

public struct AccessibilityTraits: OptionSet, Sendable, Equatable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let isButton = AccessibilityTraits(rawValue: 1 << 0)
    public static let isHeader = AccessibilityTraits(rawValue: 1 << 1)
    public static let isSelected = AccessibilityTraits(rawValue: 1 << 2)
    public static let isLink = AccessibilityTraits(rawValue: 1 << 3)
    public static let isSearchField = AccessibilityTraits(rawValue: 1 << 4)
    public static let isImage = AccessibilityTraits(rawValue: 1 << 5)
    public static let isKeyboardKey = AccessibilityTraits(rawValue: 1 << 6)
    public static let isStaticText = AccessibilityTraits(rawValue: 1 << 7)
    public static let isSummaryElement = AccessibilityTraits(rawValue: 1 << 8)
    public static let isModal = AccessibilityTraits(rawValue: 1 << 9)
    public static let isToggle = AccessibilityTraits(rawValue: 1 << 10)
}

public struct AccessibilityChildBehavior: Sendable, Hashable {
    private let rawValue: String

    private init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let ignore = AccessibilityChildBehavior("ignore")
    public static let contain = AccessibilityChildBehavior("contain")
    public static let combine = AccessibilityChildBehavior("combine")

    var cssValue: String {
        rawValue
    }
}

public struct AccessibilityActionKind: Sendable, Equatable {
    private let rawValue: String

    public init(named name: String) {
        self.rawValue = name
    }

    private init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let `default` = AccessibilityActionKind("default")
    public static let escape = AccessibilityActionKind("escape")
    public static let magicTap = AccessibilityActionKind("magicTap")
    public static let delete = AccessibilityActionKind("delete")
    public static let showMenu = AccessibilityActionKind("showMenu")

    var cssValue: String {
        rawValue
    }
}

public enum AccessibilityAdjustmentDirection: Sendable, Equatable {
    case increment
    case decrement

    var cssValue: String {
        switch self {
        case .increment:
            "increment"
        case .decrement:
            "decrement"
        }
    }
}

public enum AccessibilityHeadingLevel: Sendable, Equatable {
    case unspecified
    case h1
    case h2
    case h3
    case h4
    case h5
    case h6

    var ariaLevel: String? {
        switch self {
        case .unspecified:
            nil
        case .h1:
            "1"
        case .h2:
            "2"
        case .h3:
            "3"
        case .h4:
            "4"
        case .h5:
            "5"
        case .h6:
            "6"
        }
    }
}

public extension HTML {
    func accessibilityIdentifier(_ identifier: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([.data("accessibility-identifier", identifier)], role: .semantic))
    }

    func accessibilityLabel(_ label: String, isEnabled: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard isEnabled else {
            return modifier(HTMLAttributeModifier([], role: .semantic))
        }
        return modifier(HTMLAttributeModifier([.aria("label", label)], role: .semantic))
    }

    func accessibilityHint(_ hint: String, isEnabled: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard isEnabled else {
            return modifier(HTMLAttributeModifier([], role: .semantic))
        }
        return modifier(HTMLAttributeModifier([.aria("description", hint)], role: .semantic))
    }

    func accessibilityValue(_ value: String, isEnabled: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard isEnabled else {
            return modifier(HTMLAttributeModifier([], role: .semantic))
        }
        return modifier(HTMLAttributeModifier([.aria("valuetext", value)], role: .semantic))
    }

    func accessibilityHidden(_ hidden: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([.aria("hidden", hidden ? "true" : "false")], role: .semantic))
    }

    func accessibilityRole(_ role: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([.role(role)], role: .semantic))
    }

    func accessibilityAddTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier(accessibilityTraitAttributes(traits, mode: "add"), role: .semantic))
    }

    func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("accessibility-remove-traits", traits.cssValue)
        ], role: .semantic))
    }

    func accessibility(addTraits traits: AccessibilityTraits) -> ModifiedContent<Self, HTMLAttributeModifier> {
        accessibilityAddTraits(traits)
    }

    func accessibility(removeTraits traits: AccessibilityTraits) -> ModifiedContent<Self, HTMLAttributeModifier> {
        accessibilityRemoveTraits(traits)
    }

    func accessibilityElement(
        children: AccessibilityChildBehavior = .ignore
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("accessibility-child-behavior", children.cssValue)
        ], role: .semantic))
    }

    func accessibilitySortPriority(_ sortPriority: Double) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("accessibility-sort-priority", trimmedNumber(sortPriority))
        ], role: .semantic))
    }

    func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> ModifiedContent<Self, HTMLAttributeModifier> {
        var attributes: [HTMLAttribute] = [
            .role("heading")
        ]
        if let ariaLevel = level.ariaLevel {
            attributes.append(.aria("level", ariaLevel))
        }
        return modifier(HTMLAttributeModifier(attributes, role: .semantic))
    }

    func accessibilityInputLabels(_ labels: [String]) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .aria("label", labels.joined(separator: ", ")),
            .data("accessibility-input-labels", labels.joined(separator: "|")),
        ], role: .semantic))
    }

    func accessibilityAction(
        _ actionKind: AccessibilityActionKind = .default,
        _ handler: @escaping @Sendable () -> Void
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("accessibility-action", actionKind.cssValue),
            .event("accessibilityaction") { _ in handler() },
        ], role: .semantic))
    }

    func accessibilityAction(
        named name: String,
        _ handler: @escaping @Sendable () -> Void
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("accessibility-action", name),
            .event("accessibilityaction") { _ in handler() },
        ], role: .semantic))
    }

    func accessibilityAdjustableAction(
        _ handler: @escaping @Sendable (AccessibilityAdjustmentDirection) -> Void
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("accessibility-adjustable", "true"),
            .event("accessibilityadjust") { event in
                switch event["direction"] {
                case AccessibilityAdjustmentDirection.increment.cssValue:
                    handler(.increment)
                case AccessibilityAdjustmentDirection.decrement.cssValue:
                    handler(.decrement)
                default:
                    break
                }
            },
            .onKeyDown { event in
                switch event.key {
                case "ArrowUp", "ArrowRight":
                    handler(.increment)
                case "ArrowDown", "ArrowLeft":
                    handler(.decrement)
                default:
                    break
                }
            },
        ], role: .semantic))
    }

    func accessibilityActivationPoint(_ activationPoint: UnitPoint) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("accessibility-activation-point", activationPoint.cssValue)
        ], role: .semantic))
    }

    func accessibilityActivationPoint(_ activationPoint: CGPoint) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("accessibility-activation-point", "\(activationPoint.x.cssValue) \(activationPoint.y.cssValue)")
        ], role: .semantic))
    }

    func accessibilityDragPoint(
        _ point: UnitPoint,
        description: String,
        isEnabled: Bool = true
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard isEnabled else {
            return modifier(HTMLAttributeModifier([], role: .semantic))
        }
        return modifier(HTMLAttributeModifier([
            .data("accessibility-drag-point", point.cssValue),
            .data("accessibility-drag-description", description),
        ], role: .semantic))
    }

    func accessibilityDropPoint(
        _ point: UnitPoint,
        description: String,
        isEnabled: Bool = true
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard isEnabled else {
            return modifier(HTMLAttributeModifier([], role: .semantic))
        }
        return modifier(HTMLAttributeModifier([
            .data("accessibility-drop-point", point.cssValue),
            .data("accessibility-drop-description", description),
        ], role: .semantic))
    }

    func accessibilityRespondsToUserInteraction(
        _ respondsToUserInteraction: Bool = true
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("accessibility-responds-to-user-interaction", respondsToUserInteraction ? "true" : "false")
        ], role: .semantic))
    }
}

public extension WebUIAttributeMutableHTML {
    func accessibilityIdentifier(_ identifier: String) -> Self {
        addingAttributes([.data("accessibility-identifier", identifier)])
    }

    func accessibilityLabel(_ label: String, isEnabled: Bool = true) -> Self {
        guard isEnabled else {
            return self
        }
        return addingAttributes([.aria("label", label)])
    }

    func accessibilityHint(_ hint: String, isEnabled: Bool = true) -> Self {
        guard isEnabled else {
            return self
        }
        return addingAttributes([.aria("description", hint)])
    }

    func accessibilityValue(_ value: String, isEnabled: Bool = true) -> Self {
        guard isEnabled else {
            return self
        }
        return addingAttributes([.aria("valuetext", value)])
    }

    func accessibilityHidden(_ hidden: Bool = true) -> Self {
        addingAttributes([.aria("hidden", hidden ? "true" : "false")])
    }

    func accessibilityRole(_ role: String) -> Self {
        addingAttributes([.role(role)])
    }

    func accessibilityAddTraits(_ traits: AccessibilityTraits) -> Self {
        addingAttributes(accessibilityTraitAttributes(traits, mode: "add"))
    }

    func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> Self {
        addingAttributes([.data("accessibility-remove-traits", traits.cssValue)])
    }

    func accessibility(addTraits traits: AccessibilityTraits) -> Self {
        accessibilityAddTraits(traits)
    }

    func accessibility(removeTraits traits: AccessibilityTraits) -> Self {
        accessibilityRemoveTraits(traits)
    }

    func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> Self {
        addingAttributes([.data("accessibility-child-behavior", children.cssValue)])
    }

    func accessibilitySortPriority(_ sortPriority: Double) -> Self {
        addingAttributes([.data("accessibility-sort-priority", trimmedNumber(sortPriority))])
    }

    func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> Self {
        var attributes: [HTMLAttribute] = [.role("heading")]
        if let ariaLevel = level.ariaLevel {
            attributes.append(.aria("level", ariaLevel))
        }
        return addingAttributes(attributes)
    }

    func accessibilityInputLabels(_ labels: [String]) -> Self {
        addingAttributes([
            .aria("label", labels.joined(separator: ", ")),
            .data("accessibility-input-labels", labels.joined(separator: "|")),
        ])
    }

    func accessibilityAction(
        _ actionKind: AccessibilityActionKind = .default,
        _ handler: @escaping @Sendable () -> Void
    ) -> Self {
        addingAttributes([
            .data("accessibility-action", actionKind.cssValue),
            .event("accessibilityaction") { _ in handler() },
        ])
    }

    func accessibilityAction(
        named name: String,
        _ handler: @escaping @Sendable () -> Void
    ) -> Self {
        addingAttributes([
            .data("accessibility-action", name),
            .event("accessibilityaction") { _ in handler() },
        ])
    }

    func accessibilityAdjustableAction(
        _ handler: @escaping @Sendable (AccessibilityAdjustmentDirection) -> Void
    ) -> Self {
        addingAttributes([
            .data("accessibility-adjustable", "true"),
            .event("accessibilityadjust") { event in
                switch event["direction"] {
                case AccessibilityAdjustmentDirection.increment.cssValue:
                    handler(.increment)
                case AccessibilityAdjustmentDirection.decrement.cssValue:
                    handler(.decrement)
                default:
                    break
                }
            },
            .onKeyDown { event in
                switch event.key {
                case "ArrowUp", "ArrowRight":
                    handler(.increment)
                case "ArrowDown", "ArrowLeft":
                    handler(.decrement)
                default:
                    break
                }
            },
        ])
    }

    func accessibilityActivationPoint(_ activationPoint: UnitPoint) -> Self {
        addingAttributes([.data("accessibility-activation-point", activationPoint.cssValue)])
    }

    func accessibilityActivationPoint(_ activationPoint: CGPoint) -> Self {
        addingAttributes([
            .data("accessibility-activation-point", "\(activationPoint.x.cssValue) \(activationPoint.y.cssValue)")
        ])
    }

    func accessibilityDragPoint(
        _ point: UnitPoint,
        description: String,
        isEnabled: Bool = true
    ) -> Self {
        guard isEnabled else {
            return self
        }
        return addingAttributes([
            .data("accessibility-drag-point", point.cssValue),
            .data("accessibility-drag-description", description),
        ])
    }

    func accessibilityDropPoint(
        _ point: UnitPoint,
        description: String,
        isEnabled: Bool = true
    ) -> Self {
        guard isEnabled else {
            return self
        }
        return addingAttributes([
            .data("accessibility-drop-point", point.cssValue),
            .data("accessibility-drop-description", description),
        ])
    }

    func accessibilityRespondsToUserInteraction(_ respondsToUserInteraction: Bool = true) -> Self {
        addingAttributes([
            .data("accessibility-responds-to-user-interaction", respondsToUserInteraction ? "true" : "false")
        ])
    }
}

func accessibilityTraitAttributes(_ traits: AccessibilityTraits, mode: String) -> [HTMLAttribute] {
    var attributes: [HTMLAttribute] = [
        .data("accessibility-\(mode)-traits", traits.cssValue)
    ]
    if traits.contains(.isButton) {
        attributes.append(.role("button"))
    }
    if traits.contains(.isHeader) {
        attributes.append(.role("heading"))
    }
    if traits.contains(.isSelected) {
        attributes.append(.aria("selected", "true"))
    }
    if traits.contains(.isLink) {
        attributes.append(.role("link"))
    }
    if traits.contains(.isSearchField) {
        attributes.append(.role("searchbox"))
    }
    if traits.contains(.isImage) {
        attributes.append(.role("img"))
    }
    if traits.contains(.isKeyboardKey) {
        attributes.append(.role("button"))
        attributes.append(.data("accessibility-keyboard-key", "true"))
    }
    if traits.contains(.isStaticText) {
        attributes.append(.data("accessibility-static-text", "true"))
    }
    if traits.contains(.isSummaryElement) {
        attributes.append(.data("accessibility-summary-element", "true"))
    }
    if traits.contains(.isModal) {
        attributes.append(.aria("modal", "true"))
    }
    if traits.contains(.isToggle) {
        attributes.append(.role("switch"))
    }
    return attributes
}

extension AccessibilityTraits {
    var cssValue: String {
        var values: [String] = []
        if contains(.isButton) { values.append("isButton") }
        if contains(.isHeader) { values.append("isHeader") }
        if contains(.isSelected) { values.append("isSelected") }
        if contains(.isLink) { values.append("isLink") }
        if contains(.isSearchField) { values.append("isSearchField") }
        if contains(.isImage) { values.append("isImage") }
        if contains(.isKeyboardKey) { values.append("isKeyboardKey") }
        if contains(.isStaticText) { values.append("isStaticText") }
        if contains(.isSummaryElement) { values.append("isSummaryElement") }
        if contains(.isModal) { values.append("isModal") }
        if contains(.isToggle) { values.append("isToggle") }
        return values.joined(separator: " ")
    }
}
