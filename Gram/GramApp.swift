import SwiftUI

@main
struct GramApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    // Settable via launch argument (-initialTab agenda) — used by headless UI checks.
    @State private var tab = UserDefaults.standard.string(forKey: "initialTab") ?? "home"

    // The selected tab's icon takes the active app's accent, like moving
    // between the differently-accented web UIs.
    private var accent: Color {
        switch tab {
        case "agenda": return Theme.agenda
        case "calendar": return Theme.calendar
        case "renewals": return Theme.renewals
        case "docs": return Theme.docs
        default: return Theme.home
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag("home")
            AgendaView()
                .tabItem { Label("Agenda", systemImage: "tray.full.fill") }
                .tag("agenda")
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag("calendar")
            RenewalsView()
                .tabItem { Label("Renewals", systemImage: "arrow.triangle.2.circlepath") }
                .tag("renewals")
            DocumentsView()
                .tabItem { Label("Docs", systemImage: "doc.text.magnifyingglass") }
                .tag("docs")
        }
        .tint(accent)
        .preferredColorScheme(.dark)
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "wifi.exclamationmark")
            .font(.footnote)
            .foregroundStyle(Theme.bad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Theme.bad.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
