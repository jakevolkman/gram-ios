import SwiftUI

struct HomeView: View {
    @AppStorage("gramHost") private var host = "192.168.0.202"
    @State private var status: GramStatus?
    @State private var error: String?
    @State private var showSettings = false

    private var client: GramClient { GramClient(host: host) }

    var body: some View {
        NavigationStack {
            List {
                if let error { ErrorBanner(message: error) }

                if let glance = status?.glance {
                    Section {
                        GlanceRow(icon: "tray.full.fill", color: Theme.agenda,
                                  label: "Waiting on you",
                                  value: glance.agendaOpen == 0 ? "Nothing" : "\(glance.agendaOpen) item\(glance.agendaOpen == 1 ? "" : "s")")
                            .cardRow()
                        if glance.hasBrief {
                            GlanceRow(icon: "sun.max.fill", color: Theme.warn,
                                      label: "Daily brief", value: "Ready in Agenda")
                                .cardRow()
                        }
                        if let ev = glance.nextEvent {
                            GlanceRow(icon: "calendar", color: Theme.calendar,
                                      label: "Next event",
                                      value: "\(ev.title) · \(Fmt.friendlyDay(ev.start))")
                                .cardRow()
                        }
                        if let due = glance.nextDue {
                            GlanceRow(icon: "arrow.triangle.2.circlepath",
                                      color: due.days_left < 0 ? Theme.bad : Theme.renewals,
                                      label: "Next due",
                                      value: "\(due.name) · \(dueLabel(due.days_left))")
                                .cardRow()
                        }
                        if glance.overdue > 0 {
                            GlanceRow(icon: "exclamationmark.triangle.fill", color: Theme.bad,
                                      label: "Overdue", value: "\(glance.overdue) renewal\(glance.overdue == 1 ? "" : "s")")
                                .cardRow()
                        }
                    } header: {
                        Text("At a glance").foregroundStyle(Theme.muted)
                    }
                }

                if let apps = status?.apps {
                    ForEach(groupNames(apps), id: \.self) { group in
                        Section {
                            ForEach(apps.filter { $0.group == group }) { app in
                                HStack {
                                    Circle()
                                        .fill(app.up ? Theme.ok : Theme.bad)
                                        .frame(width: 9, height: 9)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name).foregroundStyle(Theme.text)
                                        Text(app.desc)
                                            .font(.caption)
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    if let url = URL(string: app.url) {
                                        Link(destination: url) {
                                            Image(systemName: "arrow.up.forward.app")
                                                .foregroundStyle(Theme.muted)
                                        }
                                    }
                                }
                                .cardRow()
                            }
                        } header: {
                            Text(group).foregroundStyle(Theme.muted)
                        }
                    }
                }

                if status == nil && error == nil {
                    Section {
                        ProgressView("Reaching gram…")
                            .frame(maxWidth: .infinity)
                            .tint(Theme.muted)
                            .foregroundStyle(Theme.muted)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .gramScreen(Theme.home)
            .navigationTitle("gram")
            .toolbar {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
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

    private func groupNames(_ apps: [GramStatus.AppEntry]) -> [String] {
        var seen = [String]()
        for a in apps where !seen.contains(a.group) { seen.append(a.group) }
        return seen
    }

    private func load() async {
        do {
            status = try await client.status()
            error = nil
        } catch {
            self.error = "Can't reach gram-home at \(host):4320 — \(error.localizedDescription)"
        }
    }
}

private struct GlanceRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 26)
            Text(label).foregroundStyle(Theme.text)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.trailing)
        }
    }
}
