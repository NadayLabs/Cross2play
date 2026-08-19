// Cross2Play — GraphicsCompatibilityResolver.swift
// Determines the game's actual graphics API, validates available runtime backends,
// and produces targeted compatibility profiles without blind overrides.

import Foundation

enum GameGraphicsAPI: String, Codable, Sendable {
    case d3d9 = "Direct3D 9"
    case d3d10 = "Direct3D 10"
    case d3d11 = "Direct3D 11"
    case d3d12 = "Direct3D 12"
    case vulkan = "Vulkan"
    case openGL = "OpenGL"
    case unknown = "Unknown"
}

enum GraphicsBackendTarget: String, Codable, Sendable {
    case dxmtMetal = "DXMT (Metal 3 Accelerated)"
    case wineD3DMetal = "WineD3D (Metal / MoltenVK)"
    case vkd3dMoltenVK = "VKD3D (Vulkan on MoltenVK)"
    case softwareRenderer = "Software Renderer (Fallback)"
    case unsupported = "Unsupported Backend"
}

struct BackendResolutionResult: Sendable {
    let detectedAPI: GameGraphicsAPI
    let selectedBackend: GraphicsBackendTarget
    let isSupported: Bool
    let requiredDLLOverrides: [String: DLLOverride]
    let recommendedEnvironment: [String: String]
    let warnings: [String]
}

actor GraphicsCompatibilityResolver {

    static let shared = GraphicsCompatibilityResolver()
    private init() {}

    private let paths = PathManager.shared

    func resolveBackend(
        executableURL: URL?,
        appID: Int?,
        databaseEntry: GameCompatibilityEntry?
    ) async -> BackendResolutionResult {

        let detectedAPI = detectAPI(fromExecutable: executableURL, databaseEntry: databaseEntry)

        var backend: GraphicsBackendTarget = .wineD3DMetal
        var overrides: [String: DLLOverride] = [:]
        var env: [String: String] = [:]
        var warnings: [String] = []
        var supported = true

        switch detectedAPI {
        case .d3d11, .d3d10:
            if isDXMTAvailable() {
                backend = .dxmtMetal
                overrides = [
                    "d3d11": .nativeBuiltin,
                    "d3d10": .nativeBuiltin,
                    "dxgi": .nativeBuiltin
                ]
                env["DXMT_CONFIG"] = "d3d11.metalBackend=1;d3d11.asyncPipeline=1"
            } else {
                backend = .wineD3DMetal
                overrides = [:]
                warnings.append("DXMT not found in runtime — using WineD3D Metal fallback")
            }

        case .d3d9:
            backend = .wineD3DMetal
            overrides = ["d3d9": .builtin]

        case .d3d12:
            if isVKD3DAvailable() {
                backend = .vkd3dMoltenVK
                overrides = [
                    "d3d12": .nativeBuiltin,
                    "dxgi": .nativeBuiltin
                ]
                env["VKD3D_CONFIG"] = "dxr11"
            } else {
                backend = .unsupported
                supported = false
                warnings.append("Direct3D 12 backend is currently not available for this title. DXMT cannot run D3D12 games.")
            }

        case .vulkan:
            backend = .wineD3DMetal
            overrides = ["vulkan-1": .nativeBuiltin]

        case .openGL, .unknown:
            backend = .wineD3DMetal
            overrides = [:]
        }

        c2pInfo("Graphics resolved: API=\(detectedAPI.rawValue) Backend=\(backend.rawValue) Supported=\(supported)", subsystem: "GraphicsResolver")

        return BackendResolutionResult(
            detectedAPI: detectedAPI,
            selectedBackend: backend,
            isSupported: supported,
            requiredDLLOverrides: overrides,
            recommendedEnvironment: env,
            warnings: warnings
        )
    }

    private func detectAPI(fromExecutable url: URL?, databaseEntry: GameCompatibilityEntry?) -> GameGraphicsAPI {
        if let profile = databaseEntry?.profile.lowercased() {
            if profile.contains("d3d12") { return .d3d12 }
            if profile.contains("dxmt") || profile.contains("d3d11") { return .d3d11 }
            if profile.contains("d3d9") { return .d3d9 }
            if profile.contains("vulkan") { return .vulkan }
        }

        if let exeURL = url, let data = try? Data(contentsOf: exeURL) {
            let str = String(decoding: data.prefix(500000), as: UTF8.self).lowercased()
            if str.contains("d3d12.dll") { return .d3d12 }
            if str.contains("d3d11.dll") { return .d3d11 }
            if str.contains("d3d10.dll") { return .d3d10 }
            if str.contains("d3d9.dll") { return .d3d9 }
            if str.contains("vulkan-1.dll") { return .vulkan }
            if str.contains("opengl32.dll") { return .openGL }
        }

        return .d3d11
    }

    private func isDXMTAvailable() -> Bool {
        let dxmtDylib = paths.currentRuntime.appendingPathComponent("lib/dxmt.dylib")
        let wineD3D11 = paths.currentRuntime.appendingPathComponent("lib/wine/x86_64-windows/d3d11.dll")
        return FileManager.default.fileExists(atPath: dxmtDylib.path) || FileManager.default.fileExists(atPath: wineD3D11.path)
    }

    private func isVKD3DAvailable() -> Bool {
        let vkd3d = paths.currentRuntime.appendingPathComponent("lib/wine/x86_64-windows/d3d12.dll")
        return FileManager.default.fileExists(atPath: vkd3d.path)
    }
}
