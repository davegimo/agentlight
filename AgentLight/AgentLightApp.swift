import SwiftUI

@main
struct AgentLightApp: App {
    @StateObject private var store = AgentStore.shared
    @StateObject private var settings = AppSettings.shared
    @State private var showSettings = false

    private let eventServer: EventServer

    init() {
        let server = EventServer { event in
            Task { @MainActor in
                AgentStore.shared.handle(event: event)
            }
        }
        eventServer = server

        do {
            try server.start()
        } catch {
            NSLog("AgentLight: failed to start event server — \(error.localizedDescription)")
        }

        let cursor = CursorProvider()
        Task { @MainActor in
            AgentStore.shared.register(provider: cursor)
            AgentStore.shared.startProviders()
            NotificationService.shared.requestAuthorization()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store, settings: settings, showSettings: $showSettings)
        } label: {
            HStack(spacing: 4) {
                Text(store.aggregateState.emoji)
                Text("AgentLight")
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(settings: settings)
        }
    }
}
