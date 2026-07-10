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
public struct CalendarCellContent<Content: HTML>: Component {
    private let content: Content

    public init(@HTMLBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some HTML {
        div(.class("swui-calendar-cell-content"), .data("slot", "cell-content")) {
            content
        }
    }
}
