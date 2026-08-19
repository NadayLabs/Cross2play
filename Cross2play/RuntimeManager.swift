// Cross2Play — RuntimeManager.swift
// Downloads, validates, unpacks, and manages Wine runtime versions.

import Foundation

actor RuntimeManager {

    static let shared = RuntimeManager()
    private let paths = PathManager.shared
    private let downloader = SecureDownloader.shared

    private init() {}

    func activeRuntimeManifest() -> RuntimeManifest? {
        let manifestURL = paths.currentRuntime.appendingPathComponent("runtime.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(RuntimeManifest.self, from: data) else {
            return nil
        }
        return manifest
    }

    func isRuntimeValid(manifest: RuntimeManifest) -> Bool {
        let fm = FileManager.default
        let current = paths.currentRuntime

        for binary in manifest.requiredBinaries {
            let binURL = current.appendingPathComponent(binary)
            guard fm.fileExists(atPath: binURL.path), fm.isExecutableFile(atPath: binURL.path) else {
                return false
            }
        }

        for library in manifest.requiredLibraries {
            let libURL = current.appendingPathComponent(library)
            guard fm.fileExists(atPath: libURL.path) else {
                return false
            }
        }

        return true
    }

    func ensureRuntime(
        manifest: RuntimeManifest,
        onProgress: (@Sendable (String, Double) -> Void)? = nil
    ) async throws {
        if isRuntimeValid(manifest: manifest) {
            c2pDebug("Runtime v\(manifest.version) is valid and ready", subsystem: "RuntimeManager")
            onProgress?("Runtime ready", 1.0)
            return
        }

        c2pInfo("Runtime missing or invalid — initiating installation", subsystem: "RuntimeManager")
        try await installRuntime(manifest: manifest, onProgress: onProgress)
    }

    private func installRuntime(
        manifest: RuntimeManifest,
        onProgress: (@Sendable (String, Double) -> Void)? = nil
    ) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.cacheRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: paths.runtimeRoot, withIntermediateDirectories: true)

        let archiveURL = paths.cacheRoot.appendingPathComponent("runtime-\(manifest.version).tar.xz")

        onProgress?("Downloading Wine runtime...", 0.1)
        try await downloader.download(
            from: manifest.downloadURL,
            to: archiveURL,
            expectedSHA256: manifest.sha256,
            onProgress: { p in
                onProgress?("Downloading Wine runtime (\(Int(p * 100))%)...", 0.1 + p * 0.5)
            }
        )

        onProgress?("Extracting runtime...", 0.65)
        let stagingURL = paths.runtimeRoot.appendingPathComponent("staging-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: stagingURL) }
        try fm.createDirectory(at: stagingURL, withIntermediateDirectories: true)

        let extractResult = try await runTarExtract(archiveURL: archiveURL, destination: stagingURL)
        guard extractResult == 0 else {
            throw C2PError.runtimeExtractionFailed(reason: "tar exit \(extractResult)")
        }

        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: stagingURL.appendingPathComponent("runtime.json"))

        onProgress?("Finalizing runtime...", 0.9)
        let versionedDir = paths.runtimeRoot.appendingPathComponent(manifest.version)
        try? fm.removeItem(at: versionedDir)
        try fm.moveItem(at: stagingURL, to: versionedDir)

        let currentSymlink = paths.currentRuntime
        try? fm.removeItem(at: currentSymlink)
        try fm.createSymbolicLink(at: currentSymlink, withDestinationURL: versionedDir)

        guard isRuntimeValid(manifest: manifest) else {
            throw C2PError.runtimeValidationFailed(reason: "Extracted runtime failed integrity checks")
        }

        onProgress?("Runtime ready", 1.0)
        c2pInfo("Runtime v\(manifest.version) successfully installed and activated", subsystem: "RuntimeManager")
    }

    private func runTarExtract(archiveURL: URL, destination: URL) async throws -> Int32 {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        proc.arguments = ["-xjf", archiveURL.path, "-C", destination.path, "--strip-components=1"]
        try proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus
    }
}
