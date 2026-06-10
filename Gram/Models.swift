import Foundation

// Field names match the API JSON (snake_case) so no CodingKeys are needed.

struct AgendaItem: Decodable, Identifiable {
    let id: Int
    let title: String
    let body: String
    let source: String
    let url: String
    let urgency: String
    let status: String
    let snooze_until: String
    let decision: String
    let created_at: String
    let resolved_at: String
}

struct CalendarEvent: Decodable, Identifiable {
    let id: Int
    let uid: String
    let title: String
    let description: String
    let location: String
    let start: String          // YYYY-MM-DD or YYYY-MM-DDTHH:MM (floating local)
    let end: String
    let all_day: Int
    let source: String

    var dayKey: String { String(start.prefix(10)) }
    var timeLabel: String {
        (all_day == 1 || start.count == 10) ? "All day" : String(start.dropFirst(11).prefix(5))
    }
}

struct Obligation: Decodable, Identifiable {
    let id: Int
    let name: String
    let category: String
    let notes: String
    let due_date: String       // YYYY-MM-DD
    let recur: String          // none | days | monthly | quarterly | yearly
    let recur_interval: Int
    let archived: Int
    let source: String
    let days_left: Int

    var recurLabel: String {
        guard recur != "none" else { return "one-time" }
        return recur_interval == 1 ? recur : "every \(recur_interval) \(recur)"
    }
}

struct Doc: Decodable, Identifiable {
    let id: Int
    let filename: String
    let mime: String
    let size: Int
    let title: String
    let category: String
    let doc_date: String
    let notes: String
    let text_status: String
    let source: String
    let added_at: String
    let snippet: String?       // only present on FTS search results

    var displayTitle: String { title.isEmpty ? filename : title }
    var cleanSnippet: String? {
        snippet?
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
    }
}

struct GramStatus: Decodable {
    struct AppEntry: Decodable, Identifiable {
        let key: String
        let name: String
        let desc: String
        let url: String
        let group: String
        let up: Bool
        var id: String { key }
    }
    struct Glance: Decodable {
        struct NextDue: Decodable {
            let name: String
            let due_date: String
            let days_left: Int
        }
        struct NextEvent: Decodable {
            let title: String
            let start: String
            let all_day: Int
        }
        let agendaOpen: Int
        let hasBrief: Bool
        let nextDue: NextDue?
        let nextEvent: NextEvent?
        let overdue: Int
    }
    let apps: [AppEntry]
    let glance: Glance
}

// MARK: - Date helpers

enum Fmt {
    static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    static func today() -> String { ymd.string(from: Date()) }

    static func ymdString(daysFromNow days: Int) -> String {
        ymd.string(from: Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date())
    }

    /// "2026-06-12" -> "Today" / "Tomorrow" / "Fri, Jun 12"
    static func friendlyDay(_ s: String) -> String {
        guard let date = ymd.date(from: String(s.prefix(10))) else { return s }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }
}
