import SwiftUI

struct SettingsView: View {
    @AppStorage("gramHost") private var host = "192.168.0.202"
    @Environment(\.dismiss) private var dismiss
    @State private var checks: [(name: String, port: Int, ok: Bool?)] = SettingsView.fresh
    @State private var checking = false

    static let fresh: [(name: String, port: Int, ok: Bool?)] = [
        ("gram-home", GramClient.Port.home, nil),
        ("agenda", GramClient.Port.agenda, nil),
        ("calendar", GramClient.Port.calendar, nil),
        ("renewals", GramClient.Port.renewals, nil),
        ("docvault", GramClient.Port.docvault, nil),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Host or IP", text: $host)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(Theme.text)
                    Text("All gram services live on this LAN host; ports are fixed (4320, 4327–4330).")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                } header: {
                    Text("Server").foregroundStyle(Theme.muted)
                }
                .cardRow()

                Section {
                    ForEach(checks.indices, id: \.self) { i in
                        HStack {
                            Text(checks[i].name).foregroundStyle(Theme.text)
                            Spacer()
                            Text(":\(String(checks[i].port))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.muted)
                            switch checks[i].ok {
                            case .some(true): Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.ok)
                            case .some(false): Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.bad)
                            case .none: Image(systemName: "circle.dotted").foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    Button(checking ? "Checking…" : "Run test") {
                        Task { await runChecks() }
                    }
                    .disabled(checking)
                } header: {
                    Text("Connection test").foregroundStyle(Theme.muted)
                }
                .cardRow()
            }
            .gramSheet(Theme.home)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func runChecks() async {
        checking = true
        checks = SettingsView.fresh
        let client = GramClient(host: host)
        for i in checks.indices {
            checks[i].ok = await client.health(port: checks[i].port)
        }
        checking = false
    }
}
