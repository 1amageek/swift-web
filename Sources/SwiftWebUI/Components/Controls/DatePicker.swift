import Foundation
import SwiftHTML

/// A control for selecting a date and/or time, mirroring SwiftUI `DatePicker`.
///
/// Lowers to a native `<input>` of type `date`, `time`, or `datetime-local`
/// depending on `displayedComponents`. The field composes the shared thin
/// material, matching `TextField`.
///
/// The bound `Date` is an absolute instant; the rendered value and parsed input
/// use `Calendar.current` (the runtime's calendar and time zone). This is an
/// explicit, documented choice — the same one SwiftUI makes through its
/// environment calendar — not a silent default.
public struct DatePicker: WebUIAttributeComponent {
    private let title: String
    private let selection: Binding<Date>
    private let displayedComponents: DatePickerComponents
    private let attributes: [HTMLAttribute]
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ title: String,
        selection: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date],
        _ attributes: HTMLAttribute...
    ) {
        self.title = title
        self.selection = selection
        self.displayedComponents = displayedComponents
        self.attributes = attributes
    }

    private init(
        title: String,
        selection: Binding<Date>,
        displayedComponents: DatePickerComponents,
        attributes: [HTMLAttribute]
    ) {
        self.title = title
        self.selection = selection
        self.displayedComponents = displayedComponents
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        let selection = self.selection
        let type = displayedComponents.inputType
        Element("label", attributes: [.class("swui-field swui-date-picker-field")]) {
            span(.class("swui-field-label")) {
                title
            }
            Element(
                "input",
                attributes: mergedAttributes(
                    class: "swui-date-picker \(controlSize.className) \(MaterialClass.material) \(MaterialClass.thin)",
                    styles: .custom("--swui-material-tint", "var(--swui-field-background)"),
                    extra: [
                        .type(type),
                        .value(Self.formattedValue(selection.wrappedValue, type: type)),
                        .onInput { event in
                            guard let raw = event.value,
                                  let parsed = Self.parse(raw, type: type, base: selection.wrappedValue)
                            else {
                                // A cleared or unparseable value is intentionally
                                // ignored: `Binding<Date>` cannot represent an
                                // empty selection, so the prior date is kept.
                                return
                            }
                            selection.wrappedValue = parsed
                        },
                    ] + disabledAttributes + attributes
                ),
                isVoid: true
            )
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            title: title,
            selection: selection,
            displayedComponents: displayedComponents,
            attributes: self.attributes + attributes
        )
    }

    private var disabledAttributes: [HTMLAttribute] {
        isEnabled ? [] : [.disabled, .aria("disabled", "true")]
    }

    // MARK: Date <-> native value-string conversion

    private static func formattedValue(_ date: Date, type: InputType) -> String {
        let calendar = Calendar.current
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let y = pad(c.year ?? 0, width: 4)
        let mo = pad(c.month ?? 1, width: 2)
        let d = pad(c.day ?? 1, width: 2)
        let h = pad(c.hour ?? 0, width: 2)
        let mi = pad(c.minute ?? 0, width: 2)
        switch type {
        case .time:
            return "\(h):\(mi)"
        case .datetimeLocal:
            return "\(y)-\(mo)-\(d)T\(h):\(mi)"
        default:
            return "\(y)-\(mo)-\(d)"
        }
    }

    private static func parse(_ raw: String, type: InputType, base: Date) -> Date? {
        let calendar = Calendar.current
        var comps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: base
        )
        switch type {
        case .time:
            let parts = raw.split(separator: ":")
            guard parts.count >= 2, let h = Int(parts[0]), let mi = Int(parts[1]) else {
                return nil
            }
            comps.hour = h
            comps.minute = mi
            comps.second = 0
        case .datetimeLocal:
            let halves = raw.split(separator: "T")
            guard halves.count == 2 else { return nil }
            let dateParts = halves[0].split(separator: "-")
            let timeParts = halves[1].split(separator: ":")
            guard dateParts.count == 3, timeParts.count >= 2,
                  let y = Int(dateParts[0]), let mo = Int(dateParts[1]), let d = Int(dateParts[2]),
                  let h = Int(timeParts[0]), let mi = Int(timeParts[1])
            else {
                return nil
            }
            comps.year = y
            comps.month = mo
            comps.day = d
            comps.hour = h
            comps.minute = mi
            comps.second = 0
        default:
            let parts = raw.split(separator: "-")
            guard parts.count == 3, let y = Int(parts[0]), let mo = Int(parts[1]), let d = Int(parts[2]) else {
                return nil
            }
            comps.year = y
            comps.month = mo
            comps.day = d
        }
        return calendar.date(from: comps)
    }

    private static func pad(_ value: Int, width: Int) -> String {
        let digits = String(value)
        guard digits.count < width else { return digits }
        return String(repeating: "0", count: width - digits.count) + digits
    }
}
