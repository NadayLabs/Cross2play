// Cross2Play — MainAppView.swift
// Main navigation view with sidebar and content tabs.

import SwiftUI

struct MainAppView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .library
    @State private var isLaunchingSteam: Bool = false

    enum Tab: String, CaseIterable, Identifiable {
        case library = "Library"
        case settings = "Settings"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                Label(
                    tab.rawValue,
                    systemImage: tab == .library ? "gamecontroller.fill" : "gearshape.fill"
                )
                .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            Group {
                switch selectedTab {
                case .library:
                    LibraryView(
                        onLaunchSteam: launchSteam,
                        isLaunching: isLaunchingSteam
                    )
                case .settings:
                    SettingsView(onRepair: runRepair)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func launchSteam() {
        guard !isLaunchingSteam else { return }
        isLaunchingSteam = true
        appState.appendUserLog("Launching Steam...")

        Task {
            defer { isLaunchingSteam = false }

            guard let bottle = try? await BottleManager.shared.primarySteamBottle() else {
                appState.lastError = .bottleMissing(name: "Steam")
                return
            }

            var resolvedManifest = RuntimeManifest.loadFromBundle()
            if resolvedManifest == nil {
                resolvedManifest = await RuntimeManager.shared.activeRuntimeManifest()
            }

            guard let manifest = resolvedManifest else {
                appState.lastError = .runtimeMissing
                return
            }

            let result = await LaunchPipeline.shared.launchSteam(
                in: bottle,
                runtimeManifest: manifest
            )

            switch result {
            case .success(let proc, let profile):
                appState.appendUserLog("Steam started successfully (PID \(proc.pid)) using profile: \(profile.displayName)")
            case .failure(let error, let attempts):
                appState.appendUserLog("Steam launch failed after \(attempts) attempts: \(error.userMessage)")
                appState.lastError = error
            }
        }
    }

    private func runRepair() {
        appState.environmentPhase = .repairing(step: "Starting repair...", progress: 0.1)
        Task {
            do {
                try await InstallationManager.shared.repairEnvironment { step, p in
                    Task { @MainActor in
                        appState.environmentPhase = .repairing(step: step, progress: p)
                    }
                }
                await MainActor.run {
                    appState.environmentPhase = .ready
                }
            } catch let error as C2PError {
                await MainActor.run {
                    appState.environmentPhase = .failed(context: "Repair", error: error)
                }
            } catch {
                await MainActor.run {
                    appState.environmentPhase = .failed(context: "Repair", error: .unknown(error.localizedDescription))
                }
            }
        }
    }
}
