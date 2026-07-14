/// A pure proleptic-Gregorian calendar date with the arithmetic
/// ``CalendarView`` needs. No Foundation involved: the math is deterministic
/// and identical on every profile, which byte-stable server rendering
/// depends on. Algorithms follow Howard Hinnant's civil-date derivations.
public struct GregorianDay: Sendable, Hashable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12:
            31
        case 4, 6, 9, 11:
            30
        case 2:
            isLeapYear(year) ? 29 : 28
        default:
            30
        }
    }

    /// Days since 1970-01-01 (negative before it).
    public var daysSinceEpoch: Int {
        let adjustedYear = month <= 2 ? year - 1 : year
        let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
        let yearOfEra = adjustedYear - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    public init(daysSinceEpoch: Int) {
        let shifted = daysSinceEpoch + 719_468
        let era = (shifted >= 0 ? shifted : shifted - 146_096) / 146_097
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let year = yearOfEra + era * 400
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp + (mp < 10 ? 3 : -9)
        self.init(year: month <= 2 ? year + 1 : year, month: month, day: day)
    }

    /// The weekday `1...7` with `1` = Sunday, matching Foundation's
    /// Gregorian `Calendar.component(.weekday, from:)`.
    public var weekday: Int {
        let days = daysSinceEpoch
        // 1970-01-01 was a Thursday (weekday 5).
        let shifted = (days + 4) % 7
        return (shifted >= 0 ? shifted : shifted + 7) + 1
    }

    public func adding(days: Int) -> GregorianDay {
        GregorianDay(daysSinceEpoch: daysSinceEpoch + days)
    }

    /// `YYYY-MM-DD`.
    public var isoDate: String {
        "\(Self.pad(year, 4))-\(Self.pad(month, 2))-\(Self.pad(day, 2))"
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        guard digits.count < width else {
            return digits
        }
        return String(repeating: "0", count: width - digits.count) + digits
    }
}
