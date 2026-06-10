import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// Mirrors the CSS custom properties shared by every gram web UI,
// plus the per-app accent each one sets.
enum Theme {
    static let bg = Color(hex: 0x0F1115)
    static let panel = Color(hex: 0x171A21)
    static let card = Color(hex: 0x1A1E26)
    static let border = Color(hex: 0x2A2F3A)
    static let text = Color(hex: 0xE8EAF0)
    static let muted = Color(hex: 0x8A93A5)
    static let ok = Color(hex: 0x4ADE80)
    static let warn = Color(hex: 0xFBBF24)
    static let bad = Color(hex: 0xF87171)

    static let home = Color(hex: 0xF0ABFC)      // gram-home
    static let agenda = Color(hex: 0x5EEAD4)    // agenda
    static let calendar = Color(hex: 0x93C5FD)  // calendar
    static let renewals = Color(hex: 0xFB923C)  // renewals
    static let docs = Color(hex: 0xFBBF24)      // docvault
}

// The web UIs' little rounded tag (source, category, urgency).
struct Chip: View {
    let text: String
    var color: Color = Theme.muted

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.5))
    }
}

extension View {
    // Apply to the List/Form of a tab screen: gram background, app accent,
    // panel-colored tab bar.
    func gramScreen(_ accent: Color) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(accent)
            .toolbarBackground(Theme.panel, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }

    // Apply to the Form of a presented sheet (sheets are their own
    // presentation, so they don't inherit the root's color scheme).
    func gramSheet(_ accent: Color) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(accent)
            .preferredColorScheme(.dark)
    }

    func cardRow() -> some View {
        self
            .listRowBackground(Theme.card)
            .listRowSeparatorTint(Theme.border)
    }
}
