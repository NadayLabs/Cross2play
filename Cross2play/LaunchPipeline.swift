// Cross2Play — LaunchPipeline.swift
// Orchestrates pre-launch checks, component installation, profile selection,
// diagnostic observation, and multi-attempt fallbacks.

import Foundation

enum LaunchResult: Sendable {
    case success(trackedProcess: TrackedProcess, profileUsed: CompatibilityProfile)
    case failure(reason: C2PError, attemptsMade: Int)
}

actor LaunchPipeline {

    static let shared = LaunchPipeline()
    private init() {}

    private let supervisor = WineProcessSupervisor.shared
    private let compatEngine = CompatibilityEngine.shared
    private let paths = PathManager.shared
    private let healthMonitor = HealthMonitor.shared
    private let compManager = ComponentManager.shared
    private let diagnosticEngine = BlackScreenDiagnosticEngine.shared

    func launchSteam(
        in bottle: Bottle,
        runtimeManifest: RuntimeManifest,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async -> LaunchResult {

        let healthReport = await healthMonitor.quickCheck(systemInfo: .current)
        if !healthReport.allPassed, let firstBlocker = healthReport.blockingFailures.first {
            return .failure(reason: firstBlocker, attemptsMade: 0)
        }

        await compatEngine.loadDatabase()

        let cacheKey = "\(bottle.name):steam"
        var startingProfile = await compatEngine.lastSuccessfulProfile(forKey: cacheKey)
        if startingProfile == nil {
            startingProfile = await compatEngine.resolveProfile(forAppID: nil)
        }
        let profileToUse = startingProfile ?? .steamDefault

        let fallbackChain = await compatEngine.fallbackChain(startingWith: profileToUse)
        c2pInfo("Launch chain: \(fallbackChain.map(\.name).joined(separator: " → "))", subsystem: "LaunchPipeline")

        var lastError: C2PError = .steamCrashImmediate

        for (attemptIdx, profile) in fallbackChain.prefix(3).enumerated() {
            let attemptNum = attemptIdx + 1
            c2pInfo("Launch attempt \(attemptNum)/\(min(fallbackChain.count, 3)) with profile '\(profile.name)'", subsystem: "LaunchPipeline")
            onProgress?(attemptNum == 1 ? "Starting Steam..." : "Retrying with \(profile.displayName)...")

            await diagnosticEngine.resetSession()

            do {
                try await compManager.ensureComponents(profile.requiredComponents, in: bottle)
            } catch {
                c2pWarn("Component installation failed: \(error)", subsystem: "LaunchPipeline")
            }

            var mergedConfig = bottle.config
            if let gb = profile.graphicsBackend { mergedConfig.graphicsBackend = gb }
            if let wv = profile.windowsVersion { mergedConfig.windowsVersion = wv }
            if let dx = profile.dxmtEnabled { mergedConfig.dxmtEnabled = dx }
            for (k, v) in profile.dllOverrides { mergedConfig.dllOverrides[k] = v }
            for (k, v) in profile.environment { mergedConfig.customEnvironment[k] = v }

            let bottlePath = paths.bottlePath(name: bottle.name)
            let env = mergedConfig.mergedEnvironment(
                runtimePath: paths.currentRuntime,
                bottlePath: bottlePath
            )

            let steamExe = bottlePath.appendingPathComponent("drive_c/Program Files (x86)/Steam/steam.exe")
            guard FileManager.default.fileExists(atPath: steamExe.path) else {
                return .failure(reason: .bottleMissing(name: "Steam executable missing"), attemptsMade: attemptNum)
            }

            var wineArgs: [String] = []
            if let vd = mergedConfig.virtualDesktop, vd.enabled {
                wineArgs += ["explorer.exe", "/desktop=Steam,\(vd.width)x\(vd.height)"]
            }
            wineArgs.append(steamExe.path)
            wineArgs += profile.steamLaunchArguments

            do {
                let tracked = try await supervisor.launch(
                    executable: paths.wineExecutable.path,
                    arguments: wineArgs,
                    environment: env,
                    role: .steam,
                    bottleName: bottle.name,
                    onOutput: { line, isStderr in
                        Task {
                            await self.diagnosticEngine.recordSignal(
                                .wineLogLine(category: isStderr ? "stderr" : "stdout", line: line)
                            )
                        }
                    }
                )

                await diagnosticEngine.recordSignal(.processStarted(pid: tracked.pid))

                let liveness = await healthMonitor.monitorLiveness(
                    process: tracked,
                    criticalWindowSeconds: 1.5
                )

                switch liveness {
                case .started:
                    let isAlive = kill(tracked.pid, 0) == 0
                    let report = await diagnosticEngine.diagnose(
                        isSteam: true,
                        isProcessAlive: isAlive,
                        exitCode: await supervisor.exitCode(for: tracked.id),
                        appID: nil,
                        bottleName: bottle.name,
                        profileName: profile.name,
                        attempt: attemptNum
                    )

                    if report.detectedSymptom == .none {
                        await compatEngine.recordSuccessfulProfile(profile.name, forKey: cacheKey)
                        return .success(trackedProcess: tracked, profileUsed: profile)
                    } else {
                        c2pWarn("Detected symptom \(report.detectedSymptom.rawValue) (cause: \(report.probableCause.rawValue)) — proceeding to fallback", subsystem: "LaunchPipeline")
                        await compatEngine.invalidateSuccessfulProfile(forKey: cacheKey)
                        if report.probableCause == .corruptedWebCache {
                            _ = try? await SteamWebRepairService.shared.repairSteamWebUI(in: bottle.name)
                        }
                        await supervisor.stopAllProcesses(bottleName: bottle.name)
                    }

                case .crashedImmediately(let pid):
                    c2pWarn("Process pid=\(pid) died immediately on attempt \(attemptNum)", subsystem: "LaunchPipeline")
                    lastError = .wineProcessCrashed(pid: pid, exitCode: -1)
                    await supervisor.stopAllProcesses(bottleName: bottle.name)

                case .exitedNormal:
                    return .success(trackedProcess: tracked, profileUsed: profile)
                }

            } catch {
                c2pError("Launch exception on attempt \(attemptNum): \(error)", subsystem: "LaunchPipeline")
                lastError = .unknown(error.localizedDescription)
            }
        }

        return .failure(reason: lastError, attemptsMade: min(fallbackChain.count, 3))
    }
}
