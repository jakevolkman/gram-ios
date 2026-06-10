# gram for iOS

Native SwiftUI client for the [gram suite](https://jakevolkman.com) — a
self-hosted collection of life-paperwork services. LAN-only — it talks straight
to the services on your home server (host configurable in Settings, ports
fixed), no auth, no tunnel, exactly like the web UIs.

| Tab | Service | Port | What you can do |
|---|---|---|---|
| Home | gram-home | 4320 | Glance pills (agenda count, brief, next event, next due, overdue) + per-app up/down dots |
| Agenda | agenda | 4330 | Swipe to done/dismiss/snooze, decision notes, open/snoozed/resolved filters, add items |
| Calendar | calendar | 4328 | Next 60 days grouped by day, add events (floating local times), swipe to delete |
| Renewals | renewals | 4329 | Days-left coloring, swipe to complete (rolls recurring due dates server-side) or archive, add obligations |
| Docs | docvault | 4327 | FTS search with snippets, inline PDF/image viewer, share sheet |

## Building (requires a Mac with Xcode 16+)

1. Clone (or copy) this folder onto the Mac.
2. Open `Gram.xcodeproj` in Xcode.
3. Select the **Gram** target → Signing & Capabilities → pick your Team
   (a free personal Apple ID works; apps re-sign every 7 days, or use a
   paid account for 1 year).
4. Plug in the iPhone, select it as the run destination, hit Run.
   First install on a free account: on the phone, Settings → General →
   VPN & Device Management → trust the developer certificate.

## Notes

- First launch will show the iOS **Local Network** permission prompt — allow
  it, or every request fails silently.
- Plain-HTTP works because the Info.plist sets `NSAllowsLocalNetworking` and
  the targets are raw LAN IPs (exempt from App Transport Security).
- The host is stored in `@AppStorage("gramHost")`; change it in the gear icon
  on the Home tab. Settings also has a per-service health check.
- Ports are constants in `Gram/API.swift` (`GramClient.Port`), mirroring
  gram-home's `APPS` table.
- No external dependencies; the project uses Xcode 16 buildable folders, so
  adding a Swift file to `Gram/` adds it to the target automatically.
