import Foundation

enum Format {
    /// "3h 20m", "45m", "0m" — the app's one way of saying a duration.
    static func duration(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    static func duration(minutes: Double) -> String {
        duration(minutes: Int(minutes.rounded()))
    }

    /// "12.4" — hours with one decimal, for the big stat numbers.
    static func hours(minutes: Int) -> String {
        hours(minutes: Double(minutes))
    }

    static func hours(minutes: Double) -> String {
        let h = minutes / 60
        return h < 10
            ? String(format: "%.1f", h)
            : String(format: "%.0f", h.rounded())
    }

    static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    static func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 { return date.formatted(.dateTime.weekday(.wide)) }
        if days < 365 { return date.formatted(.dateTime.month(.abbreviated).day()) }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    static func mediumDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    static func count(_ n: Int, _ singular: String, _ plural: String? = nil) -> String {
        "\(n) \(n == 1 ? singular : plural ?? singular + "s")"
    }
}
