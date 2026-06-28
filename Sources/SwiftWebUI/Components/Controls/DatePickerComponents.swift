import SwiftWebUITheme
import SwiftHTML

/// The components shown by a `DatePicker`, mirroring SwiftUI
/// `DatePickerComponents`.
///
/// The selected set maps to the native input type:
/// `.date` → `date`, `.hourAndMinute` → `time`, both → `datetime-local`.
public struct DatePickerComponents: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let hourAndMinute = DatePickerComponents(rawValue: 1 << 0)
    public static let date = DatePickerComponents(rawValue: 1 << 1)

    /// The native `<input>` type that represents this component set.
    var inputType: InputType {
        let hasDate = contains(.date)
        let hasTime = contains(.hourAndMinute)
        if hasDate && hasTime {
            return .datetimeLocal
        }
        if hasTime {
            return .time
        }
        return .date
    }
}
