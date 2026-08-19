// Cross2Play — DiagnosticExporter.swift
// Generates sanitized diagnostic reports for troubleshooting and GitHub issues.

import Foundation

final class DiagnosticExporter: Sendable {

    static let shared = DiagnosticExporter()
    private init() {}

    private let paths = PathManager.shared

    func generateReport(
        bottle: Bottle?,
        lastError: C2PError?
    ) async -> String {

        let sys = SystemInfo.current
        let runtime = await RuntimeManager.shared.activeRuntimeManifest()
        let logURL = paths.logsRoot.appendingPathComponent("cross2play.log")
        let recentLogs = (try? String(contentsOf: logURL, encoding: .utf8))?
            .components(separatedBy: .newlines)
            .suffix(50)
            .joined(separator: "\n") ?? "No logs available"

        return """
        # Cross2Play Diagnostic Report
        Generated: \(ISO8601DateFormatter().string(from: Date()))

        ## System Information
        - macOS: \(sys.macOSVersionString) (Build \(sys.macOSBuildNumber))
        - Architecture: \(sys.architecture.rawValue)
        - Chip: \(sys.appleSiliconChip.rawValue)
        - Cores: \(sys.cpuCoreCount)
        - Memory: \(sys.formattedRAM)
        - Rosetta 2 Installed: \(sys.isRosettaInstalled())

        ## Runtime Configuration
        - Runtime Version: \(runtime?.version ?? "Not installed")
        - Wine Version: \(runtime?.wineVersion ?? "Unknown")
        - DXMT Version: \(runtime?.dxmtVersion ?? "Unknown")

        ## Bottle Configuration
        - Bottle Name: \(bottle?.name ?? "None")
        - Windows Version: \(bottle?.config.windowsVersion.rawValue ?? "Default")
        - Graphics Backend: \(bottle?.config.graphicsBackend.displayName ?? "Default")
        - DXMT Enabled: \(bottle?.config.dxmtEnabled ?? false)
        - MSync Enabled: \(bottle?.config.msyncEnabled ?? false)
        - Performance Preset: \(bottle?.config.performancePreset.displayName ?? "Default")

        ## Last Error
        \(lastError?.userMessage ?? "None")

        ## Recent Logs (Last 50 lines)
        ```text
        \(recentLogs)
        ```
        """
    }
}
