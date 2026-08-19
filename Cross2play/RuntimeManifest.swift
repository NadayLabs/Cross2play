// Cross2Play — RuntimeManifest.swift
// Models the Wine runtime versioning and packaging metadata.

import Foundation

struct RuntimeManifest: Codable, Sendable {
    let version: String
    let releaseDate: String
    let wineVersion: String
    let dxmtVersion: String
    let downloadURL: URL
    let sha256: String
    let unpackedSizeEstimate: Int64
    let minimumMacOSVersion: String
    let requiredBinaries: [String]
    let requiredLibraries: [String]

    static func loadFromBundle() -> RuntimeManifest? {
        guard let url = Bundle.main.url(forResource: "RuntimeManifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(RuntimeManifest.self, from: data) else {
            return nil
        }
        return manifest
    }
}
