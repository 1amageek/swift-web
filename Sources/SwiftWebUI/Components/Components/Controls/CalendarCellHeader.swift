import SwiftHTML

/// The day-number element of a ``CalendarView`` cell. It renders the day's
/// number in a fixed-size, pill-shaped span and stamps the day state on it as
/// `data-today`, `data-outside-month`, `data-weekend`, and `data-selected`, so
/// the theme (and caller CSS) can style states without extra classes.
///
/// Selection lives in caller state — pass it back through `isSelected` and the
/// theme fills the day with the accent:
///
/// ```swift
/// CalendarCellHeader(day, isSelected: day.isoDate == selected)
/// ```
///
/// Pass a custom label to replace the day number while keeping the state
/// attributes:
///
/// ```swift
/// CalendarCellHeader(day) {
///     Text(day.isToday ? "Today" : String(day.day))
/// }
/// ```
public struct CalendarCellHeader<Label: HTML>: Component {
    private let day: CalendarDay
    private let isSelected: Bool
    private let label: Label

    public init(
        _ day: CalendarDay,
        isSelected: Bool = false,
        @HTMLBuilder label: () -> Label
    ) {
        self.day = day
        self.isSelected = isSelected
        self.label = label()
    }

    public var body: some HTML {
        div(.class("swui-calendar-cell-header-wrapper")) {
            Element("span", attributes: Self.headerAttributes(day, isSelected: isSelected)) {
                label
            }
        }
    }

    private static func headerAttributes(_ day: CalendarDay, isSelected: Bool) -> [HTMLAttribute] {
        var attributes: [HTMLAttribute] = [
            .class("swui-calendar-cell-header"),
            .data("slot", "cell-header"),
        ]
        if day.isToday {
            attributes.append(.data("today", "true"))
        }
        if day.isOutsideMonth {
            attributes.append(.data("outside-month", "true"))
        }
        if day.isWeekend {
            attributes.append(.data("weekend", "true"))
        }
        if isSelected {
            attributes.append(.data("selected", "true"))
        }
        return attributes
    }
}

public extension CalendarCellHeader where Label == text {
    /// Renders the day number as the header label.
    init(_ day: CalendarDay, isSelected: Bool = false) {
        self.init(day, isSelected: isSelected) { text(String(day.day)) }
    }
}
