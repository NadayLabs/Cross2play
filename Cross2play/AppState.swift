// Cross2Play — AppState.swift
// Central observable state machine for the entire application.

import Foundation
import Observation

// MARK: - EnvironmentPhase

enum EnvironmentPhase: Equatable {
    case pristine
    case checking
    case installing(step: String, progress: Double)
    case ready
    case failed(context: String, error: C2PError)
    case repairing(step: String, progress: Double)
    case uninstalling
}

// MARK: - BottlePhase

enum BottlePhase: Equatable {
    case missing
    case creating
    case ready
    case launching
    case running
    case repairing
    case failed(C2PError)
}

// MARK: - InstallStep

struct InstallStep: Identifiable, Equatable {
    let id: UUID
    let name: String
    var status: StepStatus
    var detail: String?

    enum StepStatus: Equatable {
        case pending
        case running
        case done
        case skipped
        case failed(String)
    }

    init(name: String, detail: String? = nil) {
        self.id = UUID()
        self.name = name
        self.status = .pending
        self.detail = detail
    }
}

// MARK: - C2PError

enum C2PError: Error, Equatable {
    case runtimeDownloadFailed(reason: String)
    case runtimeChecksumMismatch(expected: String, got: String)
    case runtimeExtractionFailed(reason: String)
    case runtimeValidationFailed(reason: String)
    case runtimeMissing
    case bottleCreationFailed(reason: String)
    case bottleCorrupted(path: String)
    case bottleMissing(name: String)
    case wineBootFailed(exitCode: Int32)
    case wineProcessCrashed(pid: Int32, exitCode: Int32)
    case wineZombieDetected(pid: Int32)
    case wineLockDetected(path: String)
    case steamDownloadFailed(reason: String)
    case steamLaunchFailed(reason: String)
    case steamCrashImmediate
    case componentInstallFailed(name: String, reason: String)
    case graphicsBackendUnavailable(backend: String)
    case blackScreenDetected
    case whiteScreenDetected
    case networkTimeout
    case networkOffline
    case insufficientDiskSpace(required: Int64, available: Int64)
    case rosettaRequired
    case rosettaInstallFailed
    case migrationFailed(reason: String)
    case unknown(String)

    var userMessage: String {
        switch self {
        case .runtimeDownloadFailed(let r): return "Could not download Wine runtime: \(r)"
        case .runtimeChecksumMismatch: return "Downloaded runtime was corrupted (checksum mismatch). Retrying download..."
        case .runtimeExtractionFailed(let r): return "Could not extract Wine runtime: \(r)"
        case .runtimeValidationFailed(let r): return "Wine runtime is invalid: \(r)"
        case .runtimeMissing: return "Wine runtime is missing. Please click Repair."
        case .bottleCreationFailed(let r): return "Could not create Wine bottle: \(r)"
        case .bottleCorrupted: return "The Steam bottle is corrupted. Please click Repair."
        case .bottleMissing(let n): return "Bottle '\(n)' was not found."
        case .wineBootFailed(let c): return "Wine initialization failed (exit \(c))."
        case .wineProcessCrashed(let p, let c): return "Process (PID \(p)) crashed with exit code \(c)."
        case .wineZombieDetected(let p): return "Stale Wine process detected (PID \(p)). Cleaning up..."
        case .wineLockDetected: return "Wine prefix is locked by another process."
        case .steamDownloadFailed(let r): return "Could not download Steam installer: \(r)"
        case .steamLaunchFailed(let r): return "Steam launch failed: \(r)"
        case .steamCrashImmediate: return "Steam crashed immediately after launch."
        case .componentInstallFailed(let n, let r): return "Could not install \(n): \(r)"
        case .graphicsBackendUnavailable(let b): return "Graphics backend '\(b)' is not supported."
        case .blackScreenDetected: return "A black screen rendering issue was detected."
        case .whiteScreenDetected: return "A white screen rendering issue was detected."
        case .networkTimeout: return "Network request timed out. Please check your connection."
        case .networkOffline: return "You appear to be offline."
        case .insufficientDiskSpace(let req, let avail):
            let reqGB = Double(req) / 1_073_741_824.0
            let availGB = Double(avail) / 1_073_741_824.0
            return String(format: "Insufficient disk space: %.1f GB required, only %.1f GB available.", reqGB, availGB)
        case .rosettaRequired: return "Rosetta 2 is required to run Windows games on Apple Silicon."
        case .rosettaInstallFailed: return "Could not install Rosetta 2."
        case .migrationFailed(let r): return "Could not migrate existing installation: \(r)"
        case .unknown(let r): return r
        }
    }

    var isRecoverableByRepair: Bool {
        switch self {
        case .networkOffline, .insufficientDiskSpace, .rosettaRequired: return false
        default: return true
        }
    }
}

// MARK: - AppState

@Observable
final class AppState: @unchecked Sendable {

    static let shared = AppState()

    var environmentPhase: EnvironmentPhase = .pristine
    var bottlePhase: BottlePhase = .missing
    var installSteps: [InstallStep] = []
    var currentInstallStepIndex: Int = 0
    var systemInfo: SystemInfo = .current
    var lastError: C2PError?
    var userLogLines: [String] = []
    var isAdvancedMode: Bool = false

    private init() {}

    @MainActor
    func appendUserLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        userLogLines.append("[\(timestamp)] \(message)")
        if userLogLines.count > 500 { userLogLines.removeFirst(100) }
    }

    @MainActor
    func reset() {
        environmentPhase = .pristine
        bottlePhase = .missing
        installSteps = []
        currentInstallStepIndex = 0
        lastError = nil
    }
}
