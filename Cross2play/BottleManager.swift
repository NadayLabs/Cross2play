// Cross2Play — BottleManager.swift
// Creates, validates, repairs, and manages multiple Wine bottles.

import Foundation

// MARK: - BottleManager

actor BottleManager {

    static let shared = BottleManager()

    private let paths = PathManager.shared
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    // MARK: - Enumeration

    func allBottles() throws -> [Bottle] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: paths.bottlesRoot, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }
        return entries.compactMap { url -> Bottle? in
            let manifestURL = url.appendingPathComponent(BottleManifest.filename)
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? decoder.decode(BottleManifest.self, from: data) else {
                return nil
            }
            return manifest.bottle
        }
    }

    func primarySteamBottle() throws -> Bottle? {
        try allBottles().first { $0.isPrimarySteamBottle }
    }

    // MARK: - Creation

    func createBottle(
        name: String,
        config: BottleConfig = .steamDefault,
        runtimeVersion: String,
        isPrimarySteamBottle: Bool = false,
        onProgress: (@Sendable (String, Double) -> Void)? = nil
    ) async throws -> Bottle {

        c2pInfo("Creating bottle '\(name)' (runtime: \(runtimeVersion))", subsystem: "BottleManager")
        onProgress?("Preparing environment...", 0.1)

        let bottlePath = paths.bottlePath(name: name)
        let fm = FileManager.default

        if fm.fileExists(atPath: bottlePath.path) {
            if let manifest = try? decoder.decode(BottleManifest.self, from: Data(contentsOf: bottlePath.appendingPathComponent(BottleManifest.filename))) {
                return manifest.bottle
            }
            try? fm.removeItem(at: bottlePath)
        }

        try fm.createDirectory(at: bottlePath, withIntermediateDirectories: true)

        onProgress?("Initializing Wine prefix...", 0.3)
        try await runWineBoot(in: bottlePath, config: config)

        onProgress?("Linking system fonts...", 0.6)
        linkSystemFonts(to: bottlePath)

        onProgress?("Configuring Windows version & display driver...", 0.8)
        try await setWindowsVersion(config.windowsVersion, in: bottlePath, config: config)

        let bottle = Bottle(
            name: name,
            runtimeVersion: runtimeVersion,
            config: config,
            isPrimarySteamBottle: isPrimarySteamBottle
        )

        try saveManifest(for: bottle)
        onProgress?("Bottle ready", 1.0)
        c2pInfo("Bottle '\(name)' created successfully", subsystem: "BottleManager")

        return bottle
    }

    // MARK: - Validation & Repair

    func validateBottle(name: String) -> HealthCheckResult {
        let bottlePath = paths.bottlePath(name: name)
        let fm = FileManager.default

        guard fm.fileExists(atPath: bottlePath.path) else {
            return HealthCheckResult(name: "Bottle '\(name)'", status: .failed("Directory missing"), isBlocking: true)
        }

        let systemReg = bottlePath.appendingPathComponent("system.reg")
        let userReg = bottlePath.appendingPathComponent("user.reg")
        let driveC = bottlePath.appendingPathComponent("drive_c")

        guard fm.fileExists(atPath: systemReg.path),
              fm.fileExists(atPath: userReg.path),
              fm.fileExists(atPath: driveC.path) else {
            return HealthCheckResult(name: "Bottle '\(name)' integrity", status: .failed("Prefix corrupted (missing system.reg/user.reg)"), isBlocking: true)
        }

        return HealthCheckResult(name: "Bottle '\(name)'", status: .passed, isBlocking: false)
    }

    func repair(name: String, onProgress: (@Sendable (String, Double) -> Void)? = nil) async throws {
        c2pInfo("Starting repair for bottle '\(name)'", subsystem: "BottleManager")
        let bottlePath = paths.bottlePath(name: name)

        onProgress?("Stopping processes...", 0.1)
        await killStaleWineServer(bottlePath: bottlePath)

        onProgress?("Linking system fonts...", 0.3)
        linkSystemFonts(to: bottlePath)

        let manifestURL = bottlePath.appendingPathComponent(BottleManifest.filename)
        var config = BottleConfig.steamDefault
        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? decoder.decode(BottleManifest.self, from: data) {
            config = manifest.bottle.config
        }

        onProgress?("Running Wine repair initialization...", 0.5)
        try await runWineBoot(in: bottlePath, config: config)

        onProgress?("Re-applying Mac Driver registry keys...", 0.8)
        await configureMacDriverRegistry(in: bottlePath, config: config)

        onProgress?("Repair complete", 1.0)
        c2pInfo("Repair complete for bottle '\(name)'", subsystem: "BottleManager")
    }

    // MARK: - Helpers

    func saveManifest(for bottle: Bottle) throws {
        let bottlePath = paths.bottlePath(name: bottle.name)
        let manifest = BottleManifest(bottle: bottle)
        let data = try encoder.encode(manifest)
        try data.write(to: bottlePath.appendingPathComponent(BottleManifest.filename))
    }

    func linkSystemFonts(to bottlePath: URL) {
        let fm = FileManager.default
        let bottleFonts = bottlePath.appendingPathComponent("drive_c/windows/Fonts", isDirectory: true)
        try? fm.createDirectory(at: bottleFonts, withIntermediateDirectories: true)

        let macFonts = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental")
        guard let files = try? fm.contentsOfDirectory(at: macFonts, includingPropertiesForKeys: nil) else { return }

        for file in files where file.pathExtension.lowercased() == "ttf" {
            let dest = bottleFonts.appendingPathComponent(file.lastPathComponent)
            if !fm.fileExists(atPath: dest.path) {
                try? fm.createSymbolicLink(at: dest, withDestinationURL: file)
            }
        }
        c2pInfo("Linked macOS system fonts into \(bottleFonts.path)", subsystem: "BottleManager")
    }

    private func runWineBoot(in bottlePath: URL, config: BottleConfig) async throws {
        guard FileManager.default.fileExists(atPath: paths.wineBootExecutable.path) else {
            throw C2PError.runtimeMissing
        }

        var env = config.mergedEnvironment(
            runtimePath: paths.currentRuntime,
            bottlePath: bottlePath
        )
        env["WINEDEBUG"] = "-all"

        let result = try await runProcess(
            executable: paths.wineBootExecutable.path,
            arguments: ["--init"],
            environment: env,
            timeoutSeconds: 180
        )

        guard result.exitCode == 0 else {
            throw C2PError.wineBootFailed(exitCode: result.exitCode)
        }
    }

    private func setWindowsVersion(_ version: WindowsVersion, in bottlePath: URL, config: BottleConfig) async throws {
        let env = config.mergedEnvironment(
            runtimePath: paths.currentRuntime,
            bottlePath: bottlePath
        )

        let regArgs = [
            "add", "HKCU\\Software\\Wine",
            "/v", "Version",
            "/t", "REG_SZ",
            "/d", version.registryValue,
            "/f"
        ]

        _ = try? await runProcess(
            executable: paths.wineRegExecutable.path,
            arguments: ["reg"] + regArgs,
            environment: env,
            timeoutSeconds: 30
        )

        await configureMacDriverRegistry(in: bottlePath, config: config)
    }

    private func configureMacDriverRegistry(in bottlePath: URL, config: BottleConfig) async {
        let env = config.mergedEnvironment(
            runtimePath: paths.currentRuntime,
            bottlePath: bottlePath
        )

        let keysToSet: [(key: String, value: String, type: String, data: String)] = [
            ("HKCU\\Software\\Wine\\Mac Driver", "WindowBackingStore", "REG_SZ", "Y"),
            ("HKCU\\Software\\Wine\\Mac Driver", "Decorated", "REG_SZ", "Y"),
            ("HKCU\\Software\\Wine\\Mac Driver", "Windows", "REG_SZ", "Y"),
            ("HKCU\\Software\\Wine\\Mac Driver", "AllowTakeFocus", "REG_SZ", "Y"),
            ("HKCU\\Software\\Wine\\Mac Driver", "ForceServerSideDecoration", "REG_SZ", "Y"),
            ("HKCU\\Software\\Wine\\Mac Driver", "EnableAppNap", "REG_SZ", "N"),
            ("HKCU\\Software\\Wine\\Direct3D", "csmt", "REG_DWORD", "1")
        ]

        for item in keysToSet {
            let regArgs = [
                "add", item.key,
                "/v", item.value,
                "/t", item.type,
                "/d", item.data,
                "/f"
            ]
            _ = try? await runProcess(
                executable: paths.wineRegExecutable.path,
                arguments: ["reg"] + regArgs,
                environment: env,
                timeoutSeconds: 15
            )
        }
    }

    private func killStaleWineServer(bottlePath: URL) async {
        let wineServerExe = paths.wineServerExecutable
        if FileManager.default.fileExists(atPath: wineServerExe.path) {
            let killProc = Process()
            killProc.executableURL = wineServerExe
            killProc.arguments = ["-k"]
            killProc.environment = ["WINEPREFIX": bottlePath.path]
            try? killProc.run()
            killProc.waitUntilExit()
        }
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        environment: [String: String],
        timeoutSeconds: Double
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            if process.isRunning {
                process.terminate()
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return (
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}
