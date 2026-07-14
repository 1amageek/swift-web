#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// One day cell in a ``CalendarView`` month grid, passed to the cell content
/// closure. It carries the day's date plus the display state a cell renders
/// from, so a caller can render anything (day number, event markers,
/// availability) and branch on `isToday` / `isOutsideMonth` / `isWeekend`.
///
/// `CalendarView` also stamps the same state on the `<td>` as `data-today`,
/// `data-outside-month`, and `data-weekend`, and ``CalendarCellHeader`` repeats
/// it on the day-number element, so styling can react without the closure
/// having to add classes.
public struct CalendarDay: Sendable, Identifiable {
    public let year: Int
    public let month: Int
    public let day: Int
    /// The calendar weekday, `1` (first weekday of the week) through `7`.
    public let weekday: Int
    /// Whether the date is today in the view's calendar.
    public let isToday: Bool
    /// `true` for the adjacent-month days that pad the first and last weeks.
    public let isOutsideMonth: Bool
    /// Saturday or Sunday. (Locale-specific weekend rules are not applied.)
    public let isWeekend: Bool

    public init(
        year: Int,
        month: Int,
        day: Int,
        weekday: Int,
        isToday: Bool,
        isOutsideMonth: Bool,
        isWeekend: Bool
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.weekday = weekday
        self.isToday = isToday
        self.isOutsideMonth = isOutsideMonth
        self.isWeekend = isWeekend
    }

    /// A stable identity for `ForEach`, distinguishing an in-month day from the
    /// same day number appearing as an adjacent-month pad cell.
    public var id: String {
        "\(year)-\(month)-\(day)-\(isOutsideMonth ? "out" : "in")"
    }

    /// `YYYY-MM-DD` for the day, for `data-date` and links.
    public var isoDate: String {
        "\(Self.pad(year, 4))-\(Self.pad(month, 2))-\(Self.pad(day, 2))"
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        guard digits.count < width else { return digits }
        return String(repeating: "0", count: width - digits.count) + digits
    }

    #if !hasFeature(Embedded)
    /// The day's date at UTC midnight, derived from `year`/`month`/`day`.
    /// (Previously this was the start of day in the view's calendar; the
    /// pure value triple is the source of truth now.)
    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(GregorianDay(year: year, month: month, day: day).daysSinceEpoch) * 86_400)
    }
    #endif
}
