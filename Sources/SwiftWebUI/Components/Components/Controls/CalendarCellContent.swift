import SwiftHTML

/// The vertical layout wrapper for one ``CalendarView`` day cell. It stacks a
/// ``CalendarCellHeader`` (the day number) above an optional
/// ``CalendarCellBody`` (custom content such as event markers):
///
/// ```swift
/// CalendarView(month: monthDate) { day in
///     CalendarCellContent {
///         CalendarCellHeader(day)
///         CalendarCellBody {
///             EventDots(on: day.date)
///         }
///     }
/// }
/// ```
public struct CalendarCellContent<Content: Component>: Component {
    private let childContent: Content

    public init(@HTMLBuilder content: () -> Content) {
        self.childContent = content()
    }

    public var content: some Component {
        div(.class("swui-calendar-cell-content"), .data("slot", "cell-content")) {
            childContent
        }
    }
}
