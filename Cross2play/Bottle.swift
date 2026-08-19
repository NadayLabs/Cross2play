// Cross2Play — Bottle.swift
// Models a Wine prefix ("bottle"), its configuration, and its lifecycle.

import Foundation

// MARK: - Bottle

struct Bottle: Identifiable, Codable, Equatable, Sendable {

    let id: UUID
    var name: String
    var createdAt: Date
    var lastLaunchedAt: Date?
    var runtimeVersion: String
    var config: BottleConfig
    var isPrimarySteamBottle: Bool

    init(
        name: String,
        runtimeVersion: String,
        config: BottleConfig = .steamDefault,
        isPrimarySteamBottle: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.runtimeVersion = runtimeVersion
        self.config = config
        self.isPrimarySteamBottle = isPrimarySteamBottle
    }
}

// MARK: - BottleConfig

struct BottleConfig: Codable, Equatable, Sendable {

    var windowsVersion: WindowsVersion
    var graphicsBackend: GraphicsBackend
    var dxmtEnabled: Bool
    var msyncEnabled: Bool
    var esyncEnabled: Bool
    var retinaScaling: Bool
    var virtualDesktop: VirtualDesktopConfig?
    var dllOverrides: [String: DLLOverride]
    var customEnvironment: [String: String]
    var installedComponents: Set<String>
    var performancePreset: PerformancePreset

    static var steamDefault: BottleConfig {
        BottleConfig(
            windowsVersion: .win10,
            graphicsBackend: .dxmt,
            dxmtEnabled: true,
            msyncEnabled: true,
            esyncEnabled: true,
            retinaScaling: false,
            virtualDesktop: nil,
            dllOverrides: [
                "d3d11": .nativeBuiltin,
                "d3d12": .nativeBuiltin,
                "dxgi": .nativeBuiltin
            ],
            customEnvironment: [
                "WINE_SIMULATE_WRITECOPY": "1"
            ],
            installedComponents: [],
            performancePreset: .automatic
        )
    }

    /// Returns a merged environment dictionary for launching Wine processes.
    func mergedEnvironment(
        runtimePath: URL,
        bottlePath: URL
    ) -> [String: String] {

        var env = ProcessInfo.processInfo.environment

        // Core Wine paths
        env["WINEPREFIX"] = bottlePath.path
        env["WINELOADER"] = runtimePath.appendingPathComponent("bin/wine").path
        env["WINESERVER"] = runtimePath.appendingPathComponent("bin/wineserver").path
        env["WINEDLLPATH"] = runtimePath.appendingPathComponent("lib/wine").path

        let binPath = runtimePath.appendingPathComponent("bin").path
        let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "\(binPath):\(existingPath)"

        let libPath = runtimePath.appendingPathComponent("lib").path
        let existingDyld = env["DYLD_FALLBACK_LIBRARY_PATH"] ?? ""
        env["DYLD_FALLBACK_LIBRARY_PATH"] = existingDyld.isEmpty ? libPath : "\(libPath):\(existingDyld)"

        // Sync primitives
        if msyncEnabled { env["WINEMSYNC"] = "1" }
        if esyncEnabled { env["WINEESYNC"] = "1" }

        // Graphics backend
        switch graphicsBackend {
        case .dxmt:
            if dxmtEnabled {
                env["DXMT_CONFIG"] = "d3d11.metalBackend=1;d3d11.asyncPipeline=1;d3d11.maxFeatureLevel=11_1"
                env["STAGING_SHARED_MEMORY"] = "1"
            }
        case .dxvk:
            env["DXVK_CONFIG_FILE"] = bottlePath.appendingPathComponent("dxvk.conf").path
        case .wineD3D:
            env["WINE_D3D_CONFIG"] = "renderer=gl"
        case .software:
            env["LIBGL_ALWAYS_SOFTWARE"] = "1"
        }

        // Apply performance preset optimizations
        performancePreset.applyTo(env: &env)

        // Custom user variables
        for (k, v) in customEnvironment {
            env[k] = v
        }

        // DLL overrides via WINEDLLOVERRIDES
        let overrideStrings = dllOverrides.map { "\($0.key)=\($0.value.rawValue)" }
        if !overrideStrings.isEmpty {
            let existing = env["WINEDLLOVERRIDES"] ?? ""
            let joined = overrideStrings.joined(separator: ";")
            env["WINEDLLOVERRIDES"] = existing.isEmpty ? joined : "\(existing);\(joined)"
        }

        return env
    }
}

// MARK: - Supporting Enums & Structs

enum WindowsVersion: String, Codable, CaseIterable, Sendable {
    case win7  = "Windows 7"
    case win10 = "Windows 10"
    case win11 = "Windows 11"

    var registryValue: String {
        switch self {
        case .win7:  return "win7"
        case .win10: return "win10"
        case .win11: return "win11"
        }
    }
}

enum GraphicsBackend: String, Codable, CaseIterable, Sendable {
    case dxmt      = "DXMT (Metal 3)"
    case dxvk      = "DXVK (Vulkan)"
    case wineD3D   = "WineD3D (OpenGL)"
    case software  = "Software Rendering"

    var displayName: String { rawValue }
}

enum DLLOverride: String, Codable, Sendable {
    case native = "native"
    case builtin = "builtin"
    case nativeBuiltin = "native,builtin"
    case builtinNative = "builtin,native"
    case disabled = ""
}

struct VirtualDesktopConfig: Codable, Equatable, Sendable {
    var enabled: Bool
    var width: Int
    var height: Int

    static let hd = VirtualDesktopConfig(enabled: true, width: 1920, height: 1080)
}

enum PerformancePreset: String, Codable, CaseIterable, Sendable {
    case automatic = "Automatic"
    case performance = "Performance"
    case compatibility = "Compatibility"

    var displayName: String { rawValue }

    func applyTo(env: inout [String: String]) {
        switch self {
        case .automatic, .performance:
            let existingDxmt = env["DXMT_CONFIG"] ?? "d3d11.metalBackend=1"
            env["DXMT_CONFIG"] = "\(existingDxmt);d3d11.asyncPipeline=1;d3d11.maxFeatureLevel=11_1"
            env["STAGING_SHARED_MEMORY"] = "1"
            env["WINEESYNC"] = "1"
            env["WINEMSYNC"] = "1"
            env["WINE_LARGE_ADDRESS_AWARE"] = "1"
            env["MVK_CONFIG_RES_MIN_ALIGNMENT"] = "1"
        case .compatibility:
            env["WINEESYNC"] = "0"
            env["WINEMSYNC"] = "0"
            env["DXMT_CONFIG"] = ""
        }
    }
}

// MARK: - BottleManifest

struct BottleManifest: Codable, Sendable {
    static let filename = "bottle.json"
    let manifestVersion: Int
    var bottle: Bottle

    init(bottle: Bottle) {
        self.manifestVersion = 1
        self.bottle = bottle
    }
}
