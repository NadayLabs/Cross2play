// Cross2Play — ErrorView.swift
// User-friendly error screen with clear repair and retry actions.

import SwiftUI

struct ErrorView: View {
    @Environment(AppState.self) private var appState
    let error: C2PError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(error.userMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            HStack(spacing: 16) {
                if error.isRecoverableByRepair {
                    PrimaryGradientButton(
                        title: "Repair & Retry",
                        icon: "wrench.and.screwdriver.fill",
                        action: onRetry
                    )
                } else {
                    PrimaryGradientButton(
                        title: "Retry",
                        icon: "arrow.clockwise",
                        action: onRetry
                    )
                }

                SecondaryGlassButton(
                    title: "Show Logs",
                    icon: "doc.text.fill"
                ) {
                    let logURL = PathManager.shared.logsRoot.appendingPathComponent("cross2play.log")
                    NSWorkspace.shared.open(logURL)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
