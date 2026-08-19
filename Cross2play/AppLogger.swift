// Cross2Play — AppLogger.swift
// Dual-level structured logger. Sanitizes sensitive data.

import Foundation
import os.log

enum LogLevel: String {
    case debug = "DEBUG"
    case info  = "INFO"
    case warn  = "WARN"
    case error = "ERROR"
}

final class AppLogger: @unchecked Sendable {

    static let shared = AppLogger()
    private let logQueue = DispatchQueue(label: "com.cross2play.logger", qos: .utility)
    private var logFileURL: URL?

    private init() {
        let logsDir = PathManager.shared.logsRoot
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        logFileURL = logsDir.appendingPathComponent("cross2play.log")
    }

    func log(_ level: LogLevel, message: String, subsystem: String = "App") {
        let sanitized = sanitize(message)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] [\(subsystem)] \(sanitized)\n"

        // OSLog
        let osLog = OSLog(subsystem: "com.cross2play", category: subsystem)
        let osType: OSLogType
        switch level {
        case .debug: osType = .debug
        case .info:  osType = .info
        case .warn:  osType = .default
        case .error: osType = .error
        }
        os_log("%{public}@", log: osLog, type: osType, "[\(subsystem)] \(sanitized)")

        // Append to file
        logQueue.async {
            guard let url = self.logFileURL else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) {
                    handle.write(data)
                }
                try? handle.close()
            } else {
                try? line.data(using: .utf8)?.write(to: url)
            }
        }

        // Print to console in debug
        #if DEBUG
        print("[\(level.rawValue)] [\(subsystem)] \(sanitized)")
        #endif
    }

    private func sanitize(_ str: String) -> String {
        var s = str
        // Redact tokens, passwords, cookies
        let patterns = [
            #"(password[=:]\s*)[^\s&]+"#,
            #"(token[=:]\s*)[^\s&]+"#,
            #"(key[=:]\s*)[^\s&]+"#,
            #"(ghp_[a-zA-Z0-9]+)"#,
            #"(Bearer\s+)[^\s]+"#
        ]
        for p in patterns {
            s = s.replacingOccurrences(of: p, with: "$1[REDACTED]", options: .regularExpression)
        }
        return s
    }
}

func c2pDebug(_ msg: String, subsystem: String = "App") { AppLogger.shared.log(.debug, message: msg, subsystem: subsystem) }
func c2pInfo(_ msg: String, subsystem: String = "App")  { AppLogger.shared.log(.info, message: msg, subsystem: subsystem) }
func c2pWarn(_ msg: String, subsystem: String = "App")  { AppLogger.shared.log(.warn, message: msg, subsystem: subsystem) }
func c2pError(_ msg: String, subsystem: String = "App") { AppLogger.shared.log(.error, message: msg, subsystem: subsystem) }
