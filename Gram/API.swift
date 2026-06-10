import Foundation

// One client for the whole suite. Every service is plain HTTP on the LAN,
// same host, different port — exactly mirroring gram-home's APPS table.
struct GramClient {
    var host: String

    enum Port {
        static let home = 4320
        static let docvault = 4327
        static let calendar = 4328
        static let renewals = 4329
        static let agenda = 4330
    }

    enum APIError: LocalizedError {
        case http(Int, String)
        var errorDescription: String? {
            switch self {
            case .http(let code, let body): return "HTTP \(code): \(body)"
            }
        }
    }

    func url(port: Int, path: String, query: [URLQueryItem] = []) -> URL {
        var c = URLComponents()
        c.scheme = "http"
        c.host = host
        c.port = port
        c.path = path
        if !query.isEmpty { c.queryItems = query }
        return c.url!
    }

    private func check(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    func get<T: Decodable>(_ type: T.Type, port: Int, path: String, query: [URLQueryItem] = []) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(from: url(port: port, path: path, query: query))
        try check(resp, data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    @discardableResult
    func send<T: Decodable>(_ type: T.Type, method: String = "POST", port: Int, path: String,
                            body: [String: Any]? = nil) async throws -> T {
        var req = URLRequest(url: url(port: port, path: path))
        req.httpMethod = method
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp, data)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct OkResponse: Decodable {
    let ok: Bool?
    let id: Int?
}

// MARK: - Service calls

extension GramClient {
    // gram-home
    func status() async throws -> GramStatus {
        try await get(GramStatus.self, port: Port.home, path: "/api/status")
    }

    func health(port: Int) async -> Bool {
        do {
            _ = try await get(OkResponse.self, port: port, path: "/api/health")
            return true
        } catch { return false }
    }

    // agenda
    func agendaItems(status: String) async throws -> [AgendaItem] {
        try await get([AgendaItem].self, port: Port.agenda, path: "/api/items",
                      query: [URLQueryItem(name: "status", value: status)])
    }

    func resolveAgendaItem(id: Int, action: String, decision: String) async throws {
        try await send(OkResponse.self, port: Port.agenda, path: "/api/items/\(id)/resolve",
                       body: ["action": action, "decision": decision])
    }

    func snoozeAgendaItem(id: Int, days: Int) async throws {
        try await send(OkResponse.self, port: Port.agenda, path: "/api/items/\(id)/snooze",
                       body: ["days": days])
    }

    func addAgendaItem(title: String, body: String, urgency: String) async throws {
        try await send(OkResponse.self, port: Port.agenda, path: "/api/items",
                       body: ["title": title, "body": body, "urgency": urgency, "source": "ios"])
    }

    // calendar
    func events(from: String, to: String) async throws -> [CalendarEvent] {
        try await get([CalendarEvent].self, port: Port.calendar, path: "/api/events",
                      query: [URLQueryItem(name: "from", value: from), URLQueryItem(name: "to", value: to)])
    }

    func addEvent(title: String, start: String, end: String, location: String, description: String) async throws {
        try await send(CalendarEvent.self, port: Port.calendar, path: "/api/events",
                       body: ["title": title, "start": start, "end": end,
                              "location": location, "description": description, "source": "ios"])
    }

    func deleteEvent(id: Int) async throws {
        try await send(OkResponse.self, method: "DELETE", port: Port.calendar, path: "/api/events/\(id)")
    }

    // renewals
    func obligations() async throws -> [Obligation] {
        try await get([Obligation].self, port: Port.renewals, path: "/api/obligations")
    }

    func completeObligation(id: Int) async throws -> Obligation {
        try await send(Obligation.self, port: Port.renewals, path: "/api/obligations/\(id)/complete")
    }

    func addObligation(name: String, dueDate: String, category: String, notes: String,
                       recur: String, recurInterval: Int) async throws {
        try await send(Obligation.self, port: Port.renewals, path: "/api/obligations",
                       body: ["name": name, "due_date": dueDate, "category": category,
                              "notes": notes, "recur": recur, "recur_interval": recurInterval,
                              "source": "ios"])
    }

    func archiveObligation(id: Int) async throws {
        try await send(OkResponse.self, method: "DELETE", port: Port.renewals, path: "/api/obligations/\(id)")
    }

    // docvault
    func docs(query: String, limit: Int = 100) async throws -> [Doc] {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        return try await get([Doc].self, port: Port.docvault, path: "/api/docs", query: items)
    }

    func docFileURL(id: Int) -> URL {
        url(port: Port.docvault, path: "/api/docs/\(id)/file")
    }
}
