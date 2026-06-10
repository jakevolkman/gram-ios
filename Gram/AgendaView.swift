import SwiftUI

struct AgendaView: View {
    @AppStorage("gramHost") private var host = "192.168.0.202"
    @State private var filter = "open"          // open | snoozed | resolved
    @State private var items: [AgendaItem] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var showAdd = false
    @State private var selected: AgendaItem?

    private var client: GramClient { GramClient(host: host) }

    var body: some View {
        NavigationStack {
            List {
                if let error { ErrorBanner(message: error) }

                Picker("Filter", selection: $filter) {
                    Text("Open").tag("open")
                    Text("Snoozed").tag("snoozed")
                    Text("Resolved").tag("resolved")
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if loaded && items.isEmpty && error == nil {
                    Text(filter == "open" ? "Nothing waiting on you 🎉" : "Nothing here.")
                        .foregroundStyle(Theme.muted)
                        .cardRow()
                }

                ForEach(items) { item in
                    Button { selected = item } label: { AgendaRow(item: item, filter: filter) }
                        .buttonStyle(.plain)
                        .cardRow()
                        .swipeActions(edge: .leading) {
                            if filter != "resolved" {
                                Button { Task { await resolve(item, "done") } } label: {
                                    Label("Done", systemImage: "checkmark")
                                }.tint(Theme.ok)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if filter != "resolved" {
                                Button { Task { await resolve(item, "dismissed") } } label: {
                                    Label("Dismiss", systemImage: "xmark")
                                }.tint(Theme.bad)
                                if filter == "open" {
                                    Button { Task { await snooze(item, days: 1) } } label: {
                                        Label("Snooze 1d", systemImage: "zzz")
                                    }.tint(.indigo)
                                }
                            }
                        }
                }
            }
            .listStyle(.insetGrouped)
            .gramScreen(Theme.agenda)
            .navigationTitle("Agenda")
            .toolbar {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showAdd) {
                AddAgendaSheet { title, body, urgency in
                    Task {
                        try? await client.addAgendaItem(title: title, body: body, urgency: urgency)
                        await load()
                    }
                }
            }
            .sheet(item: $selected) { item in
                AgendaDetailSheet(item: item, readOnly: filter == "resolved") { action, decision in
                    Task {
                        if let action { try? await client.resolveAgendaItem(id: item.id, action: action, decision: decision) }
                        selected = nil
                        await load()
                    }
                } onSnooze: { days in
                    Task {
                        try? await client.snoozeAgendaItem(id: item.id, days: days)
                        selected = nil
                        await load()
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .onChange(of: filter) { Task { await load() } }
            .onChange(of: host) { Task { await load() } }
        }
    }

    private func load() async {
        do {
            items = try await client.agendaItems(status: filter)
            error = nil
        } catch {
            self.error = "Agenda unreachable (\(host):4330)"
        }
        loaded = true
    }

    private func resolve(_ item: AgendaItem, _ action: String) async {
        try? await client.resolveAgendaItem(id: item.id, action: action, decision: "")
        await load()
    }

    private func snooze(_ item: AgendaItem, days: Int) async {
        try? await client.snoozeAgendaItem(id: item.id, days: days)
        await load()
    }
}

private struct AgendaRow: View {
    let item: AgendaItem
    let filter: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if item.urgency == "high" {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Theme.bad)
                } else if item.urgency == "low" {
                    Image(systemName: "arrow.down.circle").foregroundStyle(Theme.muted)
                }
                Text(item.title)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
            }
            if !item.body.isEmpty {
                Text(item.body).font(.subheadline).foregroundStyle(Theme.muted).lineLimit(2)
            }
            HStack(spacing: 8) {
                if item.source != "manual" {
                    Chip(text: item.source, color: Theme.agenda)
                }
                if filter == "resolved" {
                    Text(item.status == "done" ? "✓ done" : "✕ dismissed")
                        .font(.caption)
                        .foregroundStyle(item.status == "done" ? Theme.ok : Theme.muted)
                }
                if filter == "snoozed" && !item.snooze_until.isEmpty {
                    Text("until \(Fmt.friendlyDay(item.snooze_until))")
                        .font(.caption).foregroundStyle(.indigo)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AgendaDetailSheet: View {
    let item: AgendaItem
    let readOnly: Bool
    let onAction: (String?, String) -> Void
    var onSnooze: (Int) -> Void = { _ in }
    @State private var decision = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(item.title).font(.headline).foregroundStyle(Theme.text)
                    if !item.body.isEmpty { Text(item.body).foregroundStyle(Theme.text) }
                    if !item.url.isEmpty, let url = URL(string: item.url) {
                        Link(item.url, destination: url).font(.footnote)
                    }
                    LabeledContent("Source") { Text(item.source).foregroundStyle(Theme.muted) }
                    LabeledContent("Created") { Text(item.created_at).foregroundStyle(Theme.muted) }
                }
                .cardRow()
                if readOnly {
                    Section {
                        LabeledContent("Status") { Text(item.status).foregroundStyle(Theme.muted) }
                        if !item.decision.isEmpty { Text(item.decision).foregroundStyle(Theme.text) }
                    } header: {
                        Text("Outcome").foregroundStyle(Theme.muted)
                    }
                    .cardRow()
                } else {
                    Section {
                        TextField("e.g. paid it / not interested", text: $decision, axis: .vertical)
                    } header: {
                        Text("Your decision (optional note)").foregroundStyle(Theme.muted)
                    }
                    .cardRow()
                    Section {
                        Button { onAction("done", decision) } label: {
                            Label("Mark done", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Theme.ok)
                        }
                        Button { onAction("dismissed", decision) } label: {
                            Label("Dismiss", systemImage: "xmark.circle")
                                .foregroundStyle(Theme.bad)
                        }
                    }
                    .cardRow()
                    if item.status == "open" {
                        Section {
                            HStack {
                                ForEach([1, 3, 7], id: \.self) { d in
                                    Button("\(d) day\(d == 1 ? "" : "s")") { onSnooze(d) }
                                        .buttonStyle(.bordered)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        } header: {
                            Text("Snooze").foregroundStyle(Theme.muted)
                        }
                        .cardRow()
                    }
                }
            }
            .gramSheet(Theme.agenda)
            .navigationTitle("Agenda item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Close") { onAction(nil, "") } }
        }
    }
}

private struct AddAgendaSheet: View {
    let onAdd: (String, String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var body_ = ""
    @State private var urgency = "normal"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Details", text: $body_, axis: .vertical)
                    Picker("Urgency", selection: $urgency) {
                        Text("Low").tag("low")
                        Text("Normal").tag("normal")
                        Text("High").tag("high")
                    }
                }
                .cardRow()
            }
            .gramSheet(Theme.agenda)
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd(title, body_, urgency); dismiss() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
