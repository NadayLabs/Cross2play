// Cross2Play — RootView.swift
// Switches between onboarding, installation progress, main app, and error views.

import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.environmentPhase {
            case .pristine:
                OnboardingView(onStartInstall: startInstall)

            case .installing(let step, let progress):
                InstallProgressView(stepTitle: step, progress: progress)

            case .repairing(let step, let progress):
                InstallProgressView(stepTitle: step, progress: progress)

            case .ready:
                MainAppView()

            case .failed(_, let error):
                ErrorView(error: error, onRetry: startInstall)

            case .checking:
                ProgressView("Checking environment...")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .uninstalling:
                ProgressView("Cleaning up...")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await checkInitialState()
        }
    }

    private func checkInitialState() async {
        let manifest = RuntimeManifest.loadFromBundle() ?? RuntimeManifest(
            version: "11.15",
            releaseDate: "2026-08-01",
            wineVersion: "wine-staging 11.15",
            dxmtVersion: "0.9.0",
            downloadURL: URL(string: "https://github.com/Gcenx/winecx/releases/download/crossover-wine-11.15.0/crossover-wine-11.15.0-osx64.tar.xz")!,
            sha256: "4b6ecbb3c59f0f9b6eec733e8ca7da14a66a1e345cb57a419ebfc0673d3257bb",
            unpackedSizeEstimate: 1073741824,
            minimumMacOSVersion: "13.0",
            requiredBinaries: ["bin/wine", "bin/wine64", "bin/wineserver", "bin/wineboot"],
            requiredLibraries: ["lib/libMoltenVK.dylib"]
        )

        let isRuntimeOk = await RuntimeManager.shared.isRuntimeValid(manifest: manifest)
        let primaryBottle = try? await BottleManager.shared.primarySteamBottle()

        await MainActor.run {
            if isRuntimeOk && primaryBottle != nil {
                appState.environmentPhase = .ready
            } else {
                appState.environmentPhase = .pristine
            }
        }
    }

    private func startInstall() {
        appState.environmentPhase = .installing(step: "Starting setup...", progress: 0.05)
        Task {
            do {
                try await InstallationManager.shared.runFirstTimeSetup { step, p in
                    Task { @MainActor in
                        appState.environmentPhase = .installing(step: step, progress: p)
                    }
                }
                await MainActor.run {
                    appState.environmentPhase = .ready
                }
            } catch let error as C2PError {
                await MainActor.run {
                    appState.environmentPhase = .failed(context: "Installation", error: error)
                }
            } catch {
                await MainActor.run {
                    appState.environmentPhase = .failed(context: "Installation", error: .unknown(error.localizedDescription))
                }
            }
        }
    }
}
