// Cross2Play — SettingsView.swift
// Settings and Advanced developer diagnostics.

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    let onRepair: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings & Maintenance")
                    .font(.title2)
                    .fontWeight(.bold)

                // Maintenance section
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Maintenance & Repair")
                            .font(.headline)

                        Text("If Steam or games fail to launch properly, Cross2Play can verify and repair all runtime files and prefixes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 14) {
                            SecondaryGlassButton(
                                title: "Repair Environment",
                                icon: "wrench.and.screwdriver"
                            ) {
                                onRepair()
                            }

                            SecondaryGlassButton(
                                title: "Clear Web/Shader Cache",
                                icon: "trash"
                            ) {
                                Task {
                                    _ = try? await SteamWebRepairService.shared.repairSteamWebUI(in: "Steam")
                                }
                            }
                        }
                    }
                }

                // Advanced Diagnostics Toggle
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Advanced Mode")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: Bindable(appState).isAdvancedMode)
                                .labelsHidden()
                        }

                        Text("Enable advanced diagnostic logs and developer tools.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if appState.isAdvancedMode {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent User Activity:")
                                    .font(.caption)
                                    .fontWeight(.bold)

                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 4) {
                                        ForEach(appState.userLogLines.suffix(20), id: \.self) { line in
                                            Text(line)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .frame(height: 120)
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}
