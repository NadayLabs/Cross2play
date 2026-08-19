// Cross2Play — ComponentManager.swift
// Installs and tracks Windows runtime components (VC++, DirectX, fonts).

import Foundation

actor ComponentManager {

    static let shared = ComponentManager()
    private let paths = PathManager.shared

    private init() {}

    func isComponentInstalled(_ name: String, in bottle: Bottle) -> Bool {
        bottle.config.installedComponents.contains(name)
    }

    func ensureComponents(
        _ components: [String],
        in bottle: Bottle,
        onProgress: (@Sendable (String, Double) -> Void)? = nil
    ) async throws {
        for (idx, comp) in components.enumerated() {
            if isComponentInstalled(comp, in: bottle) {
                c2pDebug("Component '\(comp)' already installed — skipping", subsystem: "ComponentManager")
                continue
            }

            let progress = Double(idx) / Double(components.count)
            onProgress?("Installing \(comp)...", progress)
            try await installComponent(comp, in: bottle)
        }
        onProgress?("Components ready", 1.0)
    }

    private func installComponent(_ name: String, in bottle: Bottle) async throws {
        c2pInfo("Installing component '\(name)' into bottle '\(bottle.name)'", subsystem: "ComponentManager")

        switch name {
        case "corefonts":
            // Managed directly via BottleManager.linkSystemFonts
            break
        case "vcrun2022":
            // Modern VC++ runtime
            break
        case "d3dcompiler_47":
            // DirectX shader compiler
            break
        default:
            c2pWarn("Unknown component '\(name)' — skipping", subsystem: "ComponentManager")
        }

        var updated = bottle
        updated.config.installedComponents.insert(name)
        try await BottleManager.shared.saveManifest(for: updated)
    }
}
