import SwiftUI

struct CalendarView: View {
    @AppStorage("gramHost") private var host = "192.168.0.202"
    @State private var events: [CalendarEvent] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var showAdd = false

    private var client: GramClient { GramClient(host: host) }

    private var days: [(day: String, events: [CalendarEvent])] {
        let grouped = Dictionary(grouping: events, by: \.dayKey)
        return grouped.keys.sorted().map { ($0, grouped[$0]!.sorted { $0.start < $1.start }) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let error { ErrorBanner(message: error) }
                if loaded && events.isEmpty && error == nil {
                    Text("Nothing in the next 60 days.")
                        .foregroundStyle(Theme.muted)
                        .cardRow()
                }

                ForEach(days, id: \.day) { day in
                    Section {
                        ForEach(day.events) { ev in
                            HStack(alignment: .top, spacing: 12) {
                                Text(ev.timeLabel)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Fmt.friendlyDay(day.day) == "Today" ? Theme.warn : Theme.calendar)
                                    .frame(width: 52, alignment: .leading)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ev.title).foregroundStyle(Theme.text)
                                    if !ev.location.isEmpty {
                                        Label(ev.location, systemImage: "mappin.and.ellipse")
                                            .font(.caption).foregroundStyle(Theme.muted)
                                    }
                                    if !ev.description.isEmpty {
                                        Text(ev.description)
                                            .font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
                                    }
                                    if ev.source != "manual" && ev.source != "ios" {
                                        Chip(text: ev.source, color: Theme.calendar)
                                    }
                                }
                            }
                            .cardRow()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        try? await client.deleteEvent(id: ev.id)
                                        await load()
                                    }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    } header: {
                        Text(Fmt.friendlyDay(day.day))
                            .foregroundStyle(Fmt.friendlyDay(day.day) == "Today" ? Theme.warn : Theme.muted)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .gramScreen(Theme.calendar)
            .navigationTitle("Calendar")
            .toolbar {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showAdd) {
                AddEventSheet { title, start, end, location, desc in
                    Task {
                        try? await client.addEvent(title: title, start: start, end: end,
                                                   location: location, description: desc)
                        await load()
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .onChange(of: host) { Task { await load() } }
        }
    }

    private func load() async {
        do {
            events = try await client.events(from: Fmt.today(), to: Fmt.ymdString(daysFromNow: 60))
            error = nil
        } catch {
            self.error = "Calendar unreachable (\(host):4328)"
        }
        loaded = true
    }
}

private struct AddEventSheet: View {
    let onAdd: (String, String, String, String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var location = ""
    @State private var desc = ""
    @State private var allDay = false
    @State private var start = Date()
    @State private var hasEnd = false
    @State private var end = Date().addingTimeInterval(3600)

    // Server stores floating local times: YYYY-MM-DD or YYYY-MM-DDTHH:MM
    private func fmt(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = allDay ? "yyyy-MM-dd" : "yyyy-MM-dd'T'HH:mm"
        return f.string(from: d)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    Toggle("All day", isOn: $allDay)
                    DatePicker("Starts", selection: $start,
                               displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                    Toggle("Has end", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("Ends", selection: $end,
                                   displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                    }
                    TextField("Location", text: $location)
                    TextField("Notes", text: $desc, axis: .vertical)
                }
                .cardRow()
            }
            .gramSheet(Theme.calendar)
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(title, fmt(start), hasEnd ? fmt(end) : "", location, desc)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
