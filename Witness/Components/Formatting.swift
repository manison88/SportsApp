import Foundation

enum Fmt {
    /// "SUN · JAN 5 · 2025" in the venue's local time zone.
    static func eyebrowDate(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "EEE · MMM d · yyyy"
        return f.string(from: date).uppercased()
    }

    /// "OCT 30, 2016"
    static func shortDate(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date).uppercased()
    }

    /// "Sunday, January 5, 2025"
    static func longDate(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: date)
    }

    /// "10:43 PM"
    static func time(_ date: Date, tz: TimeZone, seconds: Bool = false) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = seconds ? "h:mm:ss a" : "h:mm a"
        return f.string(from: date)
    }

    /// "40 seconds", "3 minutes", "1 hr 12 min"
    static func span(_ interval: TimeInterval) -> String {
        let s = Int(abs(interval).rounded())
        if s < 60 { return s == 1 ? "1 second" : "\(s) seconds" }
        let m = s / 60
        if m < 60 { return m == 1 ? "1 minute" : "\(m) minutes" }
        return "\(m / 60) hr \(m % 60) min"
    }

    /// "40s", "3m"
    static func shortSpan(_ interval: TimeInterval) -> String {
        let s = Int(abs(interval).rounded())
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h \(s % 3600 / 60)m"
    }

    static func number(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic))
    }

    static func year(_ date: Date) -> String {
        String(Calendar.current.component(.year, from: date))
    }
}
