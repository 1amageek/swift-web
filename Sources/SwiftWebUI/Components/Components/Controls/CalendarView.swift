#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SwiftHTML

/// A month-grid calendar view, in the spirit of UIKit's `UICalendarView`.
///
/// It renders a `<table role="grid">` with weekday column headers and one cell
/// per day — including the adjacent-month days that pad the first and last
/// weeks. Each element carries a `data-slot` attribute (`grid`, `grid-header`,
/// `grid-body-row`, `cell`, …) so styling and tooling can address the anatomy
/// without depending on tag structure, and each day cell carries its state as
/// `data-today` / `data-outside-month` / `data-weekend`.
///
/// The default cell renders the day number through ``CalendarCellContent`` and
/// ``CalendarCellHeader``:
///
/// ```swift
/// CalendarView(month: monthDate)
/// ```
///
/// Pass a cell closure to compose custom content per day — the closure receives
/// a ``CalendarDay`` and typically stacks a header and a ``CalendarCellBody``:
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
///
/// The grid math uses the view's `Calendar` (default `.current`); no
/// `DateFormatter` is used, so the component is safe in the WebAssembly
/// runtime. Weekday header labels default to English abbreviations; pass
/// `weekdaySymbols` (indexed by weekday `1...7`) for other languages.
public struct CalendarView<Cell: HTML>: Component {
    private let referenceDate: Date
    private let calendar: Calendar
    private let weekdaySymbols: [String]?
    private let accessibilityLabel: String?
    private let cell: @Sendable (CalendarDay) -> Cell

    /// - Parameters:
    ///   - month: Any date within the month to display.
    ///   - calendar: The calendar for the grid (weeks, first weekday, today).
    ///   - weekdaySymbols: Seven header labels indexed by weekday `1...7`
    ///     (`1` = the calendar's Sunday). Defaults to English abbreviations.
    ///   - accessibilityLabel: The grid's `aria-label` (e.g. a localized month).
    ///   - cell: Builds the content of one day cell from its ``CalendarDay``.
    public init(
        month: Date,
        calendar: Calendar = .current,
        weekdaySymbols: [String]? = nil,
        accessibilityLabel: String? = nil,
        @HTMLBuilder cell: @escaping @Sendable (CalendarDay) -> Cell
    ) {
        self.referenceDate = month
        self.calendar = calendar
        self.weekdaySymbols = weekdaySymbols
        self.accessibilityLabel = accessibilityLabel
        self.cell = cell
    }

    public var body: some HTML {
        let model = CalendarMonthModel(
            month: referenceDate,
            calendar: calendar,
            weekdaySymbols: weekdaySymbols
        )
        let cell = self.cell
        table(
            .class("swui-calendar"),
            .role("grid"),
            .data("slot", "grid"),
            .aria("label", accessibilityLabel ?? model.isoMonth)
        ) {
            thead(.class("swui-calendar-grid-header"), .data("slot", "grid-header")) {
                tr(
                    .class("swui-calendar-grid-header-row"),
                    .role("row"),
                    .data("slot", "grid-header-row")
                ) {
                    ForEach(model.weekdays, id: { $0.weekday }) { weekday in
                        Element("th", attributes: Self.weekdayAttributes(weekday)) {
                            span {
                                text(weekday.symbol)
                            }
                        }
                    }
                }
            }
            tbody(.class("swui-calendar-grid-body"), .data("slot", "grid-body")) {
                ForEach(model.weeks, id: { $0.id }) { week in
                    tr(
                        .class("swui-calendar-grid-body-row"),
                        .role("row"),
                        .data("slot", "grid-body-row")
                    ) {
                        ForEach(week.days, id: { $0.id }) { day in
                            Element("td", attributes: Self.dayAttributes(day)) {
                                // A plain wrapper between the table cell and
                                // the caller's cell content, giving the cell
                                // interior a stable element anchor.
                                div(.class("swui-calendar-cell-button")) {
                                    cell(day)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private static func weekdayAttributes(_ weekday: CalendarWeekday) -> [HTMLAttribute] {
        var attributes: [HTMLAttribute] = [
            .class("swui-calendar-grid-header-cell"),
            .role("columnheader"),
            .data("slot", "grid-header-cell"),
            .attribute("scope", "col"),
        ]
        if weekday.isWeekend {
            attributes.append(.data("weekend", "true"))
        }
        return attributes
    }

    private static func dayAttributes(_ day: CalendarDay) -> [HTMLAttribute] {
        var attributes: [HTMLAttribute] = [
            .class("swui-calendar-cell"),
            .role("gridcell"),
            .data("slot", "cell"),
            .data("date", day.isoDate),
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
        return attributes
    }
}

public extension CalendarView where Cell == CalendarCellContent<CalendarCellHeader<text>> {
    /// A month grid with the default cell content: the day number rendered
    /// through ``CalendarCellContent`` and ``CalendarCellHeader``.
    init(
        month: Date,
        calendar: Calendar = .current,
        weekdaySymbols: [String]? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.init(
            month: month,
            calendar: calendar,
            weekdaySymbols: weekdaySymbols,
            accessibilityLabel: accessibilityLabel
        ) { day in
            CalendarCellContent {
                CalendarCellHeader(day)
            }
        }
    }
}

/// A weekday header label in calendar order.
private struct CalendarWeekday {
    let weekday: Int
    let symbol: String
    let isWeekend: Bool
}

/// One row of the month grid.
private struct CalendarWeek {
    let index: Int
    let days: [CalendarDay]
    var id: Int { index }
}

/// Computes the weeks and weekday headers for a month using only `Calendar`
/// arithmetic, so it works in the WebAssembly runtime.
private struct CalendarMonthModel {
    let isoMonth: String
    let weekdays: [CalendarWeekday]
    let weeks: [CalendarWeek]

    init(month referenceDate: Date, calendar: Calendar, weekdaySymbols: [String]?) {
        let monthComponents = calendar.dateComponents([.year, .month], from: referenceDate)
        let year = monthComponents.year ?? 1
        let month = monthComponents.month ?? 1
        let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? referenceDate
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let firstWeekday = calendar.firstWeekday
        let firstWeekdayOfMonth = calendar.component(.weekday, from: firstOfMonth)
        let leading = (firstWeekdayOfMonth - firstWeekday + 7) % 7
        let totalCells = Int((Double(leading + daysInMonth) / 7.0).rounded(.up)) * 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: firstOfMonth) ?? firstOfMonth
        let today = calendar.dateComponents([.year, .month, .day], from: Date())

        var days: [CalendarDay] = []
        days.reserveCapacity(totalCells)
        for offset in 0..<totalCells {
            let date = calendar.date(byAdding: .day, value: offset, to: gridStart) ?? gridStart
            let c = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
            let dayYear = c.year ?? year
            let dayMonth = c.month ?? month
            let dayNumber = c.day ?? 1
            let weekday = c.weekday ?? 1
            let isOutsideMonth = !(dayMonth == month && dayYear == year)
            let isToday = (dayYear == today.year && dayMonth == today.month && dayNumber == today.day)
            let isWeekend = (weekday == 1 || weekday == 7)
            days.append(
                CalendarDay(
                    date: date,
                    year: dayYear,
                    month: dayMonth,
                    day: dayNumber,
                    weekday: weekday,
                    isToday: isToday,
                    isOutsideMonth: isOutsideMonth,
                    isWeekend: isWeekend
                )
            )
        }

        var weeks: [CalendarWeek] = []
        var weekIndex = 0
        while weekIndex * 7 < days.count {
            let start = weekIndex * 7
            let end = min(start + 7, days.count)
            weeks.append(CalendarWeek(index: weekIndex, days: Array(days[start..<end])))
            weekIndex += 1
        }
        self.weeks = weeks

        let symbols = weekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var headers: [CalendarWeekday] = []
        for column in 0..<7 {
            let weekday = ((firstWeekday - 1 + column) % 7) + 1
            let symbol = symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : ""
            headers.append(CalendarWeekday(weekday: weekday, symbol: symbol, isWeekend: weekday == 1 || weekday == 7))
        }
        self.weekdays = headers
        self.isoMonth = "\(year)-\(month < 10 ? "0" : "")\(month)"
    }
}
