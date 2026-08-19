// Cross2Play — Cross2playApp.swift
// Main application lifecycle and window configuration.

import SwiftUI

@main
struct Cross2playApp: App {

    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .frame(minWidth: 900, idealWidth: 1050, maxWidth: .infinity,
                       minHeight: 600, idealHeight: 700, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .help) {
                Button("Cross2Play GitHub...") {
                    if let url = URL(string: "https://github.com/NadayLabs/Cross2play") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
