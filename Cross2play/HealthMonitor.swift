// Cross2Play — HealthMonitor.swift
// Health validation and post-launch liveness monitoring.

import Foundation

struct HealthCheckResult: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let status: Status
    let isBlocking: Bool

    enum Status: Sendable {
        case passed
        case warning(String)
        case failed(String)
    }

    var isPassed: Bool {
        if case .passed = status { return true }
        return false
    }
}

struct HealthReport: Sendable {
    let checks: [HealthCheckResult]
    var allPassed: Bool { checks.allSatisfy { $0.isPassed || !$0.isBlocking } }
    var blockingFailures: [C2PError] {
        checks.compactMap { check -> C2PError? in
            guard check.isBlocking else { return nil }
            switch check.status {
            case .failed(let reason): return .unknown("\(check.name): \(reason)")
            default: return nil
            }
        }
    }
}

enum LivenessEvent: Sendable {
    case started(pid: Int32)
    case crashedImmediately(pid: Int32)
    case exitedNormal(pid: Int32, code: Int32)
}

actor HealthMonitor {

    static let shared = HealthMonitor()
    private let paths = PathManager.shared

    private init() {}

    func quickCheck(systemInfo: SystemInfo) async -> HealthReport {
        var checks: [HealthCheckResult] = []

        if !systemInfo.isAppleSilicon {
            checks.append(HealthCheckResult(name: "Apple Silicon", status: .warning("Running on non-Apple Silicon Mac"), isBlocking: false))
        } else {
            checks.append(HealthCheckResult(name: "Apple Silicon", status: .passed, isBlocking: false))
        }

        if systemInfo.isAppleSilicon && !systemInfo.isRosettaInstalled() {
            checks.append(HealthCheckResult(name: "Rosetta 2", status: .failed("Rosetta 2 is not installed"), isBlocking: true))
        } else {
            checks.append(HealthCheckResult(name: "Rosetta 2", status: .passed, isBlocking: false))
        }

        let report = HealthReport(checks: checks)
        c2pDebug("Quick health check passed", subsystem: "HealthMonitor")
        return report
    }

    func monitorLiveness(
        process: TrackedProcess,
        criticalWindowSeconds: Double = 1.5
    ) async -> LivenessEvent {
        c2pDebug("Monitoring liveness for pid=\(process.pid)", subsystem: "HealthMonitor")

        let intervalMs: UInt64 = 250_000_000
        let iterations = max(1, Int(criticalWindowSeconds / 0.25))
        for _ in 0..<iterations {
            try? await Task.sleep(nanoseconds: intervalMs)

            let isAlive = kill(process.pid, 0) == 0
            if !isAlive {
                try? await Task.sleep(nanoseconds: 100_000_000)
                let exitCode = await WineProcessSupervisor.shared.exitCode(for: process.id)
                if exitCode == 0 {
                    c2pInfo("Process pid=\(process.pid) exited gracefully (code 0) within critical window", subsystem: "HealthMonitor")
                    return .started(pid: process.pid)
                } else {
                    c2pError("Process pid=\(process.pid) died within critical window with code \(exitCode ?? -1)", subsystem: "HealthMonitor")
                    return .crashedImmediately(pid: process.pid)
                }
            }
        }

        c2pInfo("Process pid=\(process.pid) survived critical window — considered started", subsystem: "HealthMonitor")
        return .started(pid: process.pid)
    }
}
