// Cross2Play — CompatibilityEngine.swift
// Resolves the best CompatibilityProfile for a game and drives the fallback chain.

import Foundation

actor CompatibilityEngine {

    static let shared = CompatibilityEngine()
    private init() {}

    private var database: GameCompatibilityDatabase?
    private var profileCache: [String: CompatibilityProfile] = [:]
    private var successfulProfiles: [String: String] = [:]

    func loadDatabase() {
        if let url = Bundle.main.url(forResource: "GameCompatibility", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           var db = try? JSONDecoder().decode(GameCompatibilityDatabase.self, from: data) {
            db.buildIndex()
            self.database = db
            c2pInfo("Loaded compatibility database v\(db.version) with \(db.entries.count) entries", subsystem: "CompatibilityEngine")
        } else {
            c2pWarn("GameCompatibility.json not found — using defaults only", subsystem: "CompatibilityEngine")
        }

        registerProfile(.steamDefault)
        registerProfile(.steamCefCompatibility)
        registerProfile(.steamSoftwareFallback)
    }

    func resolveProfile(forAppID appID: Int?) -> CompatibilityProfile {
        if let appID = appID,
           let entry = database?.entry(forAppID: appID),
           let profile = profileCache[entry.profile] {
            c2pInfo("Resolved profile '\(profile.name)' for AppID \(appID)", subsystem: "CompatibilityEngine")
            return profile
        }
        c2pInfo("No specific profile for AppID \(appID?.description ?? "nil") — using steam-dxmt-default", subsystem: "CompatibilityEngine")
        return .steamDefault
    }

    func antiCheatWarning(forAppID appID: Int) -> AntiCheatInfo? {
        database?.entry(forAppID: appID)?.antiCheat
    }

    func compatibilityStatus(forAppID appID: Int) -> CompatibilityStatus {
        database?.entry(forAppID: appID)?.status ?? .unknown
    }

    func fallbackChain(startingWith profile: CompatibilityProfile) -> [CompatibilityProfile] {
        var chain: [CompatibilityProfile] = [profile]
        var seen: Set<String> = [profile.name]

        var current = profile
        while let nextName = current.fallbackProfiles.first,
              !seen.contains(nextName),
              let next = profileCache[nextName] {
            chain.append(next)
            seen.insert(nextName)
            current = next
        }

        return chain
    }

    func recordSuccessfulProfile(_ profileName: String, forKey key: String) {
        successfulProfiles[key] = profileName
        c2pInfo("Recorded successful profile '\(profileName)' for key '\(key)'", subsystem: "CompatibilityEngine")
    }

    func invalidateSuccessfulProfile(forKey key: String) {
        successfulProfiles.removeValue(forKey: key)
        c2pInfo("Invalidated cached profile for key '\(key)'", subsystem: "CompatibilityEngine")
    }

    func lastSuccessfulProfile(forKey key: String) -> CompatibilityProfile? {
        guard let name = successfulProfiles[key] else { return nil }
        return profileCache[name]
    }

    func registerProfile(_ profile: CompatibilityProfile) {
        profileCache[profile.name] = profile
    }
}
