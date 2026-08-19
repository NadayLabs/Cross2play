// Cross2Play — InstallProgressView.swift
// Shows transactional progress during environment preparation or repair.

import SwiftUI

struct InstallProgressView: View {
    @Environment(AppState.self) private var appState
    let stepTitle: String
    let progress: Double

    var body: some View {
        VStack(spacing: 32) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: 12) {
                Text(stepTitle)
                    .font(.title3)
                    .fontWeight(.semibold)

                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .frame(width: 380)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Please wait while Cross2Play prepares your Windows gaming environment.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}
