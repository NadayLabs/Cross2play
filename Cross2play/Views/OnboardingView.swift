// Cross2Play — OnboardingView.swift
// First-run screen welcoming the user and kicking off automatic setup.

import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    let onStartInstall: () -> Void

    var body: some View {
        VStack(spacing: 36) {
            VStack(spacing: 16) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Welcome to Cross2Play")
                    .font(.system(size: 32, weight: .bold))

                Text("Play your favorite Windows games directly on your Mac with native Apple Silicon acceleration.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "bolt.fill",
                    title: "Metal 3 Accelerated",
                    subtitle: "Zero overhead with modern Direct3D 11 to Metal translation"
                )
                FeatureRow(
                    icon: "sparkles",
                    title: "Zero Configuration",
                    subtitle: "Automated Wine management, prefixes, and dependencies"
                )
                FeatureRow(
                    icon: "cpu.fill",
                    title: appState.systemInfo.appleSiliconChip.rawValue,
                    subtitle: "\(appState.systemInfo.cpuCoreCount) CPU cores, \(appState.systemInfo.formattedRAM) detected"
                )
            }
            .frame(maxWidth: 420)

            PrimaryGradientButton(
                title: "Install & Get Started",
                icon: "arrow.right.circle.fill",
                action: onStartInstall
            )
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
