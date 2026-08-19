// Cross2Play — LibraryView.swift
// Games and Steam launcher view with status and launch button.

import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    let onLaunchSteam: () -> Void
    var isLaunching: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header Hero
                GlassCard {
                    HStack(spacing: 24) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Steam for Windows")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Environment: Steam Bottle (Metal 3 DXMT) • Ready")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        PrimaryGradientButton(
                            title: isLaunching ? "Starting..." : "Launch Steam",
                            icon: "play.fill",
                            action: onLaunchSteam,
                            isLoading: isLaunching
                        )
                    }
                }

                // Quick Launch Info
                VStack(alignment: .leading, spacing: 14) {
                    Text("System Status")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        StatusCard(
                            icon: "cpu",
                            title: "Hardware",
                            value: "\(appState.systemInfo.appleSiliconChip.rawValue) (\(appState.systemInfo.formattedRAM))"
                        )
                        StatusCard(
                            icon: "waveform.path.ecg",
                            title: "Graphics",
                            value: "Metal 3 Accelerated"
                        )
                        StatusCard(
                            icon: "checkmark.shield.fill",
                            title: "Wine Runtime",
                            value: "Wine-Staging 11.15"
                        )
                    }
                }
            }
            .padding(28)
        }
    }
}

private struct StatusCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
