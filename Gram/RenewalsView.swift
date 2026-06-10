import SwiftUI

struct RenewalsView: View {
    @AppStorage("gramHost") private var host = "192.168.0.202"
    @State private var obligations: [Obligation] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var showAdd = false

    private var client: GramClient { GramClient(host: host) }

    var body: some View {
        NavigationStack {
            List {
                if let error { ErrorBanner(message: error) }
                if loaded && obligations.isEmpty && error == nil {
                    Text("No active obligations.")
                        .foregroundStyle(Theme.muted)
                        .cardRow()
                }

                ForEach(obligations) { ob in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ob.name).fontWeight(.medium).foregroundStyle(Theme.text)
                            HStack(spacing: 8) {
                                if !ob.category.isEmpty {
                                    Chip(text: ob.category, color: Theme.renewals)
                                }
                                Text(ob.recurLabel).font(.caption).foregroundStyle(Theme.muted)
                            }
                            if !ob.notes.isEmpty {
                                Text(ob.notes).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(dueLabel(ob.days_left))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(dueColor(ob.days_left))
                            Text(ob.due_date).font(.caption2).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.vertical, 2)
                    .cardRow()
                    .swipeActions(edge: .leading) {
                        Button {
                            Task {
                                _ = try? await client.completeObligation(id: ob.id)
                                await load()
                            }
                        } label: { Label("Complete", systemImage: "checkmark") }
                            .tint(Theme.ok)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                try? await client.archiveObligation(id: ob.id)
                                await load()
                            }
                        } label: { Label("Archive", systemImage: "archivebox") }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .gramScreen(Theme.renewals)
            .navigationTitle("Renewals")
            .toolbar {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showAdd) {
                AddObligationSheet { name, due, category, notes, recur, interval in
                    Task {
                        try? await client.addObligation(name: name, dueDate: due, category: category,
                                                        notes: notes, recur: recur, recurInterval: interval)
                        await load()
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .onChange(of: host) { Task { await load() } }
        }
    }

    private func dueLabel(_ days: Int) -> String {
        if days < 0 { return "\(-days)d overdue" }
        if days == 0 { return "due today" }
        return "in \(days)d"
    }

    private func dueColor(_ days: Int) -> Color {
        if days < 0 { return Theme.bad }
        if days <= 7 { return Theme.warn }
        return Theme.ok
    }

    private func load() async {
        do {
            obligations = try await client.obligations()
            error = nil
        } catch {
            self.error = "Renewals unreachable (\(host):4329)"
        }
        loaded = true
    }
}

private struct AddObligationSheet: View {
    let onAdd: (String, String, String, String, String, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = ""
    @State private var notes = ""
    @State private var due = Date()
    @State private var recur = "none"
    @State private var interval = 1

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Car registration)", text: $name)
                    DatePicker("Due", selection: $due, displayedComponents: [.date])
                    Picker("Repeats", selection: $recur) {
                        Text("Never").tag("none")
                        Text("Days").tag("days")
                        Text("Monthly").tag("monthly")
                        Text("Quarterly").tag("quarterly")
                        Text("Yearly").tag("yearly")
                    }
                    if recur != "none" {
                        Stepper("Every \(interval)", value: $interval, in: 1...36)
                    }
                    TextField("Category", text: $category)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
                .cardRow()
            }
            .gramSheet(Theme.renewals)
            .navigationTitle("New obligation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name, Fmt.ymd.string(from: due), category, notes, recur, interval)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
