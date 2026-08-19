// Cross2Play — SecureDownloader.swift
// Downloads files over HTTPS with resume support, timeout, and streaming SHA-256 validation.

import Foundation
import CryptoKit

actor SecureDownloader: NSObject {

    static let shared = SecureDownloader()

    private override init() {
        super.init()
    }

    /// Downloads a remote URL to a local destination, verifying its SHA-256 checksum.
    func download(
        from sourceURL: URL,
        to destinationURL: URL,
        expectedSHA256: String? = nil,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws {

        guard sourceURL.scheme == "https" else {
            throw C2PError.runtimeDownloadFailed(reason: "Insecure download scheme: \(sourceURL.scheme ?? "")")
        }

        let tempURL = destinationURL.appendingPathExtension("downloading-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        let session = URLSession(configuration: config)

        var request = URLRequest(url: sourceURL)
        request.setValue("Cross2Play/0.10.0 (Macintosh; Apple Silicon)", forHTTPHeaderField: "User-Agent")

        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw C2PError.runtimeDownloadFailed(reason: "HTTP \(code)")
        }

        let totalBytes = response.expectedContentLength
        var downloadedBytes: Int64 = 0

        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: tempURL)
        defer { try? fileHandle.close() }

        var hasher = SHA256()
        var lastProgressUpdate = Date()

        for try await byte in asyncBytes {
            let data = Data([byte])
            fileHandle.write(data)
            hasher.update(data: data)
            downloadedBytes += 1

            if totalBytes > 0 && Date().timeIntervalSince(lastProgressUpdate) > 0.1 {
                let progress = Double(downloadedBytes) / Double(totalBytes)
                onProgress?(progress)
                lastProgressUpdate = Date()
            }
        }

        onProgress?(1.0)

        // Checksum validation
        if let expected = expectedSHA256 {
            let digest = hasher.finalize()
            let computed = digest.map { String(format: "%02x", $0) }.joined()
            if computed.lowercased() != expected.lowercased() {
                c2pError("Checksum mismatch. Expected: \(expected), Got: \(computed)", subsystem: "SecureDownloader")
                throw C2PError.runtimeChecksumMismatch(expected: expected, got: computed)
            }
        }

        // Move to destination
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        c2pInfo("Download complete: \(destinationURL.lastPathComponent)", subsystem: "SecureDownloader")
    }
}
