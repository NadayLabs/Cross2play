// Cross2Play — SteamWebRepairService.swift
// Targeted surgical repair for Steam CEF/WebHelper caches without deleting user data or game libraries.

import Foundation

final class SteamWebRepairService: Sendable {

    static let shared = SteamWebRepairService()
    private init() {}

    private let paths = PathManager.shared

    func repairSteamWebUI(in bottleName: String) async throws -> Int {
        let bottlePath = paths.bottlePath(name: bottleName)
        let fm = FileManager.default

        var cleanedItemCount = 0

        let htmlCache = bottlePath.appendingPathComponent("drive_c/users")
        if let userDirs = try? fm.contentsOfDirectory(at: htmlCache, includingPropertiesForKeys: nil) {
            for userDir in userDirs {
                let userHtmlCache = userDir.appendingPathComponent("AppData/Local/Steam/htmlcache")
                if fm.fileExists(atPath: userHtmlCache.path) {
                    try? fm.removeItem(at: userHtmlCache)
                    cleanedItemCount += 1
                    c2pInfo("Purged Steam htmlcache at \(userHtmlCache.path)", subsystem: "SteamWebRepair")
                }

                let userCefCache = userDir.appendingPathComponent("AppData/Local/CEF")
                if fm.fileExists(atPath: userCefCache.path) {
                    try? fm.removeItem(at: userCefCache)
                    cleanedItemCount += 1
                    c2pInfo("Purged CEF cache at \(userCefCache.path)", subsystem: "SteamWebRepair")
                }
            }
        }

        let steamDumps = bottlePath.appendingPathComponent("drive_c/Program Files (x86)/Steam/dumps")
        if fm.fileExists(atPath: steamDumps.path) {
            let files = (try? fm.contentsOfDirectory(at: steamDumps, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension.lowercased() == "dmp" {
                try? fm.removeItem(at: file)
                cleanedItemCount += 1
            }
        }

        let crashLock = bottlePath.appendingPathComponent("drive_c/Program Files (x86)/Steam/.crash")
        if fm.fileExists(atPath: crashLock.path) {
            try? fm.removeItem(at: crashLock)
            cleanedItemCount += 1
        }

        c2pInfo("Steam Web UI repair complete. Cleaned \(cleanedItemCount) items.", subsystem: "SteamWebRepair")
        return cleanedItemCount
    }
}
