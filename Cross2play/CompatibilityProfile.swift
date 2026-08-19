// Cross2Play — CompatibilityProfile.swift
// Defines fine-grained compatibility profiles for Steam and Windows games.

import Foundation

struct CompatibilityProfile: Identifiable, Codable, Equatable, Sendable {

    var id: String { name }

    var name: String
    var displayName: String
    var graphicsBackend: GraphicsBackend?
    var windowsVersion: WindowsVersion?
    var dxmtEnabled: Bool?
    var requiredComponents: [String]
    var dllOverrides: [String: DLLOverride]
    var environment: [String: String]
    var steamLaunchArguments: [String]
    var wineArguments: [String]
    var fallbackProfiles: [String]
    var antiCheatWarning: AntiCheatInfo?
    var compatibilityStatus: CompatibilityStatus
    var notes: [String]

    // MARK: - Default profile (Tier 1: Fast Start + Hardware Accelerated Games)

    static var steamDefault: CompatibilityProfile {
        CompatibilityProfile(
            name: "steam-dxmt-default",
            displayName: "Steam (Fast Launch + Metal 3)",
            graphicsBackend: .dxmt,
            windowsVersion: .win10,
            dxmtEnabled: true,
            requiredComponents: [
                "corefonts",
                "vcrun2022",
                "d3dcompiler_47"
            ],
            dllOverrides: [
                "d3d11": .nativeBuiltin,
                "d3d12": .nativeBuiltin,
                "dxgi": .nativeBuiltin
            ],
            environment: [
                "STEAM_COMPAT_CLIENT_INSTALL_PATH": "",
                "STEAM_COMPAT_DATA_PATH": "",
                "WINE_SIMULATE_WRITECOPY": "1"
            ],
            steamLaunchArguments: [
                "-no-cef-sandbox",
                "-cef-disable-gpu-compositing",
                "-cef-disable-gpu",
                "-cef-disable-d3d11"
            ],
            wineArguments: [],
            fallbackProfiles: ["steam-cef-compatibility", "steam-software-fallback"],
            antiCheatWarning: nil,
            compatibilityStatus: .verified,
            notes: ["Full hardware acceleration with Metal 3 for games, instant UI rendering"]
        )
    }

    // MARK: - Tier 2: CEF Compatibility Fallback (Targeted CEF fix)

    static var steamCefCompatibility: CompatibilityProfile {
        CompatibilityProfile(
            name: "steam-cef-compatibility",
            displayName: "Steam (CEF Compatibility)",
            graphicsBackend: .dxmt,
            windowsVersion: .win10,
            dxmtEnabled: true,
            requiredComponents: [
                "corefonts",
                "vcrun2022",
                "d3dcompiler_47"
            ],
            dllOverrides: [
                "d3d11": .nativeBuiltin,
                "d3d12": .nativeBuiltin,
                "dxgi": .nativeBuiltin
            ],
            environment: [
                "STEAM_COMPAT_CLIENT_INSTALL_PATH": "",
                "STEAM_COMPAT_DATA_PATH": "",
                "WINE_SIMULATE_WRITECOPY": "1"
            ],
            steamLaunchArguments: [
                "-no-cef-sandbox",
                "-cef-disable-gpu-compositing",
                "-cef-disable-gpu",
                "-cef-disable-d3d11"
            ],
            wineArguments: [],
            fallbackProfiles: ["steam-software-fallback"],
            antiCheatWarning: nil,
            compatibilityStatus: .playable,
            notes: ["Targeted Chromium CEF GPU workaround for WebHelper"]
        )
    }

    // MARK: - Tier 3: Software Fallback (Safe Mode)

    static var steamSoftwareFallback: CompatibilityProfile {
        CompatibilityProfile(
            name: "steam-software-fallback",
            displayName: "Steam (Software Rendering Safe Mode)",
            graphicsBackend: .software,
            windowsVersion: .win10,
            dxmtEnabled: false,
            requiredComponents: [
                "corefonts",
                "vcrun2022",
                "d3dcompiler_47"
            ],
            dllOverrides: [:],
            environment: [:],
            steamLaunchArguments: [
                "-no-cef-sandbox",
                "-disable-gpu",
                "-disable-gpu-compositing",
                "-no-sandbox"
            ],
            wineArguments: [],
            fallbackProfiles: [],
            antiCheatWarning: nil,
            compatibilityStatus: .experimental,
            notes: ["Software rendering — maximum compatibility, safe mode"]
        )
    }
}

enum CompatibilityStatus: String, Codable, CaseIterable, Sendable {
    case verified     = "verified"
    case playable     = "playable"
    case experimental = "experimental"
    case unsupported  = "unsupported"
    case unknown      = "unknown"

    var badgeText: String {
        switch self {
        case .verified: return "Verified"
        case .playable: return "Playable"
        case .experimental: return "Experimental"
        case .unsupported: return "Unsupported"
        case .unknown: return "Unknown"
        }
    }
}

struct AntiCheatInfo: Codable, Equatable, Sendable {
    let name: String
    let bypassable: Bool
    let warningMessage: String

    static let vanguard = AntiCheatInfo(
        name: "Riot Vanguard",
        bypassable: false,
        warningMessage: "This game uses Riot Vanguard kernel anti-cheat, which does not run under Wine on macOS."
    )

    static let eacKernel = AntiCheatInfo(
        name: "Easy Anti-Cheat (Kernel Mode)",
        bypassable: false,
        warningMessage: "This game requires kernel-level Easy Anti-Cheat and cannot run on macOS."
    )
}

struct GameCompatibilityDatabase: Codable, Sendable {
    let version: String
    let lastUpdated: String
    let entries: [GameCompatibilityEntry]

    private var index: [Int: GameCompatibilityEntry] = [:]

    mutating func buildIndex() {
        index = Dictionary(uniqueKeysWithValues: entries.map { ($0.appID, $0) })
    }

    func entry(forAppID appID: Int) -> GameCompatibilityEntry? {
        index[appID]
    }
}

struct GameCompatibilityEntry: Codable, Sendable {
    let appID: Int
    let name: String
    let status: CompatibilityStatus
    let profile: String
    let antiCheat: AntiCheatInfo?
    let notes: [String]
}
