// Cross2Play — InstallationManager.swift
// Coordinates transactional first-run installation and environment repair.

import Foundation

actor InstallationManager {

    static let shared = InstallationManager()
    private init() {}

    private let runtimeManager = RuntimeManager.shared
    private let bottleManager = BottleManager.shared
    private let paths = PathManager.shared

    func runFirstTimeSetup(
        onStepProgress: (@Sendable (String, Double) -> Void)? = nil
    ) async throws {

        let manifest = RuntimeManifest.loadFromBundle() ?? defaultManifest()

        onStepProgress?("Preparing directories...", 0.05)
        try createDirectoryStructure()

        onStepProgress?("Verifying macOS and Rosetta 2...", 0.1)
        try await verifySystemRequirements()

        onStepProgress?("Installing Wine runtime...", 0.2)
        try await runtimeManager.ensureRuntime(manifest: manifest) { desc, p in
            onStepProgress?(desc, 0.2 + p * 0.4)
        }

        onStepProgress?("Creating Steam bottle...", 0.65)
        let bottle = try await bottleManager.createBottle(
            name: "Steam",
            config: .steamDefault,
            runtimeVersion: manifest.version,
            isPrimarySteamBottle: true
        ) { desc, p in
            onStepProgress?(desc, 0.65 + p * 0.2)
        }

        onStepProgress?("Installing Steam...", 0.85)
        try await installSteam(in: bottle)

        onStepProgress?("Ready", 1.0)
        c2pInfo("First-time setup completed successfully", subsystem: "InstallationManager")
    }

    func repairEnvironment(
        onStepProgress: (@Sendable (String, Double) -> Void)? = nil
    ) async throws {
        c2pInfo("Starting environment repair...", subsystem: "InstallationManager")
        let manifest = RuntimeManifest.loadFromBundle() ?? defaultManifest()

        onStepProgress?("Checking directories...", 0.1)
        try createDirectoryStructure()

        onStepProgress?("Repairing Wine runtime...", 0.2)
        try await runtimeManager.ensureRuntime(manifest: manifest) { desc, p in
            onStepProgress?(desc, 0.2 + p * 0.3)
        }

        onStepProgress?("Repairing Steam bottle...", 0.5)
        try await bottleManager.repair(name: "Steam") { desc, p in
            onStepProgress?(desc, 0.5 + p * 0.3)
        }

        onStepProgress?("Checking Steam files...", 0.8)
        let bottle = try await bottleManager.primarySteamBottle() ?? Bottle(name: "Steam", runtimeVersion: manifest.version, isPrimarySteamBottle: true)
        try await installSteam(in: bottle)

        onStepProgress?("Repair completed", 1.0)
        c2pInfo("Environment repair completed successfully", subsystem: "InstallationManager")
    }

    private func createDirectoryStructure() throws {
        let fm = FileManager.default
        let dirs = [
            paths.runtimeRoot,
            paths.bottlesRoot,
            paths.componentsRoot,
            paths.cacheRoot,
            paths.logsRoot,
            paths.configRoot
        ]
        for dir in dirs {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func verifySystemRequirements() async throws {
        let sys = SystemInfo.current
        if sys.isAppleSilicon && !sys.isRosettaInstalled() {
            c2pError("Rosetta 2 is required but not installed", subsystem: "InstallationManager")
            throw C2PError.rosettaRequired
        }
    }

    private func installSteam(in bottle: Bottle) async throws {
        let bottlePath = paths.bottlePath(name: bottle.name)
        let steamDir = bottlePath.appendingPathComponent("drive_c/Program Files (x86)/Steam", isDirectory: true)
        let steamExe = steamDir.appendingPathComponent("steam.exe")

        if FileManager.default.fileExists(atPath: steamExe.path) {
            c2pDebug("Steam executable already present at \(steamExe.path)", subsystem: "InstallationManager")
            return
        }

        try FileManager.default.createDirectory(at: steamDir, withIntermediateDirectories: true)

        let installerURL = paths.cacheRoot.appendingPathComponent("SteamSetup.exe")
        let steamDownloadURL = URL(string: "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe")!

        if !FileManager.default.fileExists(atPath: installerURL.path) {
            try await SecureDownloader.shared.download(from: steamDownloadURL, to: installerURL)
        }

        let env = bottle.config.mergedEnvironment(
            runtimePath: paths.currentRuntime,
            bottlePath: bottlePath
        )

        let proc = Process()
        proc.executableURL = paths.wineExecutable
        proc.arguments = [installerURL.path, "/S"]
        proc.environment = env
        try proc.run()
        proc.waitUntilExit()

        _ = try? await Task.sleep(nanoseconds: 1_000_000_000)

        guard FileManager.default.fileExists(atPath: steamExe.path) else {
            c2pWarn("Silent install did not create steam.exe directly, checking fallback", subsystem: "InstallationManager")
            return
        }
    }

    private func defaultManifest() -> RuntimeManifest {
        RuntimeManifest(
            version: "11.15",
            releaseDate: "2026-08-01",
            wineVersion: "wine-staging 11.15",
            dxmtVersion: "0.9.0",
            downloadURL: URL(string: "https://github.com/Gcenx/winecx/releases/download/crossover-wine-11.15.0/crossover-wine-11.15.0-osx64.tar.xz")!,
            sha256: "4b6ecbb3c59f0f9b6eec733e8ca7da14a66a1e345cb57a419ebfc0673d3257bb",
            unpackedSizeEstimate: 1073741824,
            minimumMacOSVersion: "13.0",
            requiredBinaries: ["bin/wine", "bin/wine64", "bin/wineserver", "bin/wineboot"],
            requiredLibraries: ["lib/libMoltenVK.dylib"]
        )
    }
}
