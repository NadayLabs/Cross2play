// Cross2Play — WineProcessSupervisor.swift
// Tracks all spawned Wine processes, manages their lifecycle, and provides graceful shutdown.

import Foundation

enum ProcessRole: String, Codable, Sendable {
    case steam = "steam"
    case game = "game"
    case wineBoot = "wineboot"
    case wineCfg = "winecfg"
    case winetricks = "winetricks"
    case wineServer = "wineserver"
    case helper = "helper"
}

struct TrackedProcess: Identifiable, Sendable {
    let id: UUID
    let pid: Int32
    let role: ProcessRole
    let bottleName: String
    let launchedAt: Date
    var terminatedAt: Date?
    var exitCode: Int32?

    var isAlive: Bool {
        guard terminatedAt == nil else { return false }
        return kill(pid, 0) == 0
    }
}

actor WineProcessSupervisor {

    static let shared = WineProcessSupervisor()
    private init() {}

    private var trackedProcesses: [UUID: TrackedProcess] = [:]
    private var processHandles: [UUID: Process] = [:]

    func launch(
        executable: String,
        arguments: [String],
        environment: [String: String],
        role: ProcessRole,
        bottleName: String,
        onOutput: (@Sendable (String, Bool) -> Void)? = nil
    ) async throws -> TrackedProcess {

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let onOutput = onOutput {
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                    onOutput(line, false)
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                    onOutput(line, true)
                }
            }
        }

        try process.run()

        let tracked = TrackedProcess(
            id: UUID(),
            pid: process.processIdentifier,
            role: role,
            bottleName: bottleName,
            launchedAt: Date()
        )

        trackedProcesses[tracked.id] = tracked
        processHandles[tracked.id] = process

        let trackID = tracked.id
        Task.detached {
            process.waitUntilExit()
            await self.handleTermination(trackID: trackID, exitCode: process.terminationStatus)
        }

        c2pInfo("Launched \(role.rawValue) pid=\(process.processIdentifier) bottle=\(bottleName)", subsystem: "WineProcess")
        return tracked
    }

    private func handleTermination(trackID: UUID, exitCode: Int32) {
        guard var process = trackedProcesses[trackID] else { return }
        process.terminatedAt = Date()
        process.exitCode = exitCode
        trackedProcesses[trackID] = process
        processHandles.removeValue(forKey: trackID)
        c2pInfo("Process pid=\(process.pid) (\(process.role.rawValue)) exited with code \(exitCode)", subsystem: "WineProcess")
    }

    var runningProcesses: [TrackedProcess] {
        trackedProcesses.values.filter { $0.isAlive }
    }

    func exitCode(for id: UUID) -> Int32? {
        trackedProcesses[id]?.exitCode
    }

    func stopProcess(id: UUID) async {
        guard let handle = processHandles[id],
              let tracked = trackedProcesses[id],
              tracked.isAlive else { return }

        c2pInfo("Stopping process pid=\(tracked.pid)", subsystem: "WineProcess")
        handle.terminate()

        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if !handle.isRunning { return }
        }

        kill(tracked.pid, SIGKILL)
    }

    func stopAllProcesses(bottleName: String) async {
        let toStop = processHandles.filter { id, _ in
            trackedProcesses[id]?.bottleName == bottleName && trackedProcesses[id]?.isAlive == true
        }
        for (id, _) in toStop {
            await stopProcess(id: id)
        }

        let bottlePath = PathManager.shared.bottlePath(name: bottleName)
        let wineServerExe = PathManager.shared.wineServerExecutable
        if FileManager.default.fileExists(atPath: wineServerExe.path) {
            let killProc = Process()
            killProc.executableURL = wineServerExe
            killProc.arguments = ["-k"]
            killProc.environment = ["WINEPREFIX": bottlePath.path]
            try? killProc.run()
            killProc.waitUntilExit()
            c2pInfo("Terminated all bottle processes via wineserver -k for '\(bottleName)'", subsystem: "WineProcess")
        }
    }
}
