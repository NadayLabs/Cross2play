// Cross2Play — BlackScreenDiagnosticEngine.swift
// Real-time multi-signal analysis, error categorization, symptom diagnosis, and structured JSON reporting.

import Foundation

enum BlackScreenSymptom: String, Codable, Sendable {
    case steamWebHelperBlank = "steam_webhelper_blank"
    case gameWindowBlack = "game_window_black"
    case blackScreenThenCrash = "black_screen_then_crash"
    case blackScreenWithAudio = "black_screen_with_audio"
    case invisibleWindow = "invisible_window"
    case none = "none"
}

enum ProbableCause: String, Codable, Sendable {
    case cefGpuProcess = "cef_gpu_process_failure"
    case cefSandbox = "cef_sandbox_restriction"
    case corruptedWebCache = "corrupted_web_cache"
    case missingFonts = "missing_directwrite_fonts"
    case dxgiPresentationFailure = "dxgi_swapchain_presentation_failure"
    case exclusiveFullscreenIssue = "exclusive_fullscreen_unsupported"
    case dpiResolutionMismatch = "dpi_resolution_mismatch"
    case missingWindowsRuntime = "missing_windows_runtime"
    case unsupportedD3D12 = "unsupported_d3d12_api"
    case antiCheatBlocked = "anticheat_blocked"
    case staleProcessConflict = "stale_process_conflict"
    case unknown = "unknown"

    var userRemediationHint: String {
        switch self {
        case .cefGpuProcess: return "Retrying Steam with compatible web rendering engine..."
        case .cefSandbox: return "Adjusting browser sandbox permissions..."
        case .corruptedWebCache: return "Repairing Steam web cache..."
        case .missingFonts: return "Restoring Windows font mapping..."
        case .dxgiPresentationFailure: return "Switching to compatible graphics swapchain..."
        case .exclusiveFullscreenIssue: return "Switching to borderless windowed mode..."
        case .dpiResolutionMismatch: return "Adjusting display resolution and scaling..."
        case .missingWindowsRuntime: return "Installing required Visual C++ / DirectX components..."
        case .unsupportedD3D12: return "DirectX 12 is currently not supported by this game's configuration."
        case .antiCheatBlocked: return "This game requires a Windows kernel anti-cheat not supported on macOS."
        case .staleProcessConflict: return "Cleaning up lingering background processes..."
        case .unknown: return "Attempting safe compatibility profile..."
        }
    }
}

enum LaunchSignal: Sendable {
    case processStarted(pid: Int32)
    case childProcessSpawned(name: String, pid: Int32)
    case windowInitialized(x: Int, y: Int, width: Int, height: Int)
    case graphicsSurfacePresented
    case processExited(code: Int32)
    case wineLogLine(category: String, line: String)
}

struct DiagnosticReport: Codable, Sendable {
    let timestamp: Date
    let appID: Int?
    let bottleName: String
    let profileName: String
    let processAlive: Bool
    let detectedSymptom: BlackScreenSymptom
    let probableCause: ProbableCause
    let attemptNumber: Int
    let observedSignals: [String]
    let errorSnippets: [String]
    let recommendedAction: String
}

actor BlackScreenDiagnosticEngine {

    static let shared = BlackScreenDiagnosticEngine()
    private init() {}

    private var currentSignals: [String] = []
    private var collectedErrors: [String] = []
    private var isGraphicsPresented: Bool = false
    private var hasValidWindowCoords: Bool = false
    private var webHelperSpawned: Bool = false
    private var rendererChildSpawned: Bool = false

    func resetSession() {
        currentSignals.removeAll()
        collectedErrors.removeAll()
        isGraphicsPresented = false
        hasValidWindowCoords = false
        webHelperSpawned = false
        rendererChildSpawned = false
    }

    func recordSignal(_ signal: LaunchSignal) {
        switch signal {
        case .processStarted(let pid):
            currentSignals.append("PROCESS_STARTED(pid:\(pid))")

        case .childProcessSpawned(let name, let pid):
            currentSignals.append("CHILD_SPAWNED(\(name), pid:\(pid))")
            if name.lowercased().contains("steamwebhelper") { webHelperSpawned = true }
            if name.lowercased().contains("renderer") { rendererChildSpawned = true }

        case .windowInitialized(let x, let y, let w, let h):
            currentSignals.append("WINDOW_INIT(pos:\(x),\(y) size:\(w)x\(h))")
            if x >= 0 && x < 10000 && y >= 0 && y < 10000 && w > 100 && h > 100 {
                hasValidWindowCoords = true
            }

        case .graphicsSurfacePresented:
            currentSignals.append("GRAPHICS_SURFACE_PRESENTED")
            isGraphicsPresented = true

        case .processExited(let code):
            currentSignals.append("PROCESS_EXITED(code:\(code))")

        case .wineLogLine(let category, let line):
            let lower = line.lowercased()
            if lower.contains("window") || lower.contains("desktoplogin") || lower.contains("steam") || lower.contains("macdrv") {
                hasValidWindowCoords = true
            }
            if lower.contains("swapchain") || lower.contains("present") || lower.contains("surface") || lower.contains("moltenvk") {
                isGraphicsPresented = true
            }
            if isDiagnosticWorthyError(line) {
                collectedErrors.append("[\(category)] \(line)")
            }
        }
    }

    func diagnose(
        isSteam: Bool,
        isProcessAlive: Bool,
        exitCode: Int32?,
        appID: Int?,
        bottleName: String,
        profileName: String,
        attempt: Int
    ) -> DiagnosticReport {

        var symptom: BlackScreenSymptom = .none
        var cause: ProbableCause = .unknown

        if !isProcessAlive, let code = exitCode, code != 0 {
            symptom = .blackScreenThenCrash
            cause = diagnoseCrashCause()
        } else if isSteam {
            let errors = collectedErrors.joined(separator: " ")
            if errors.contains("populateRenderer11DeviceCaps") || errors.contains("killing unresponsive browser") || errors.contains("angle") || errors.contains("EGL") {
                symptom = .steamWebHelperBlank
                cause = .cefGpuProcess
            } else if errors.contains("htmlcache") || errors.contains("Lock file exists") {
                symptom = .steamWebHelperBlank
                cause = .corruptedWebCache
            } else if errors.contains("dwrite") || errors.contains("font") {
                symptom = .steamWebHelperBlank
                cause = .missingFonts
            } else if !isProcessAlive {
                symptom = .blackScreenThenCrash
                cause = .unknown
            } else {
                symptom = .none
                cause = .unknown
            }
        } else {
            let errors = collectedErrors.joined(separator: " ")
            if errors.contains("d3d12") || errors.contains("vkd3d") {
                symptom = .gameWindowBlack
                cause = .unsupportedD3D12
            } else if errors.contains("CreateSwapChain") || errors.contains("dxgi") {
                symptom = .gameWindowBlack
                cause = .dxgiPresentationFailure
            } else if isProcessAlive {
                symptom = .none
                cause = .unknown
            } else {
                symptom = .blackScreenThenCrash
                cause = .unknown
            }
        }

        let report = DiagnosticReport(
            timestamp: Date(),
            appID: appID,
            bottleName: bottleName,
            profileName: profileName,
            processAlive: isProcessAlive,
            detectedSymptom: symptom,
            probableCause: cause,
            attemptNumber: attempt,
            observedSignals: currentSignals,
            errorSnippets: Array(collectedErrors.suffix(10)),
            recommendedAction: cause.userRemediationHint
        )

        c2pInfo("Diagnostic result: symptom=\(symptom.rawValue), cause=\(cause.rawValue)", subsystem: "DiagnosticEngine")
        return report
    }

    private func diagnoseCrashCause() -> ProbableCause {
        let errors = collectedErrors.joined(separator: " ")
        if errors.contains("import_dll") || errors.contains("msvcp") || errors.contains("vcruntime") {
            return .missingWindowsRuntime
        }
        if errors.contains("d3d12") {
            return .unsupportedD3D12
        }
        if errors.contains("EasyAntiCheat") || errors.contains("BattlEye") || errors.contains("Vanguard") {
            return .antiCheatBlocked
        }
        return .unknown
    }

    private func isDiagnosticWorthyError(_ line: String) -> Bool {
        let keywords = [
            "err:d3d:", "err:dxgi:", "err:d3d12:", "err:vulkan:",
            "populateRenderer11DeviceCaps", "eglCreateContext",
            "err:module:import_dll", "err:seh:raise_exception",
            "killing unresponsive browser", "Assertion Failed",
            "Page fault", "Access violation"
        ]
        return keywords.contains { line.contains($0) }
    }
}
