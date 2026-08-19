// Cross2Play — PathManager.swift
// Single source of truth for all filesystem paths.

import Foundation

final class PathManager: Sendable {

    static let shared = PathManager()
    private init() {}

    var appSupportRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cross2play", isDirectory: true)
    }

    var runtimeRoot: URL { appSupportRoot.appendingPathComponent("Runtime", isDirectory: true) }
    var currentRuntime: URL { runtimeRoot.appendingPathComponent("current", isDirectory: true) }
    var bottlesRoot: URL { appSupportRoot.appendingPathComponent("Bottles", isDirectory: true) }
    var componentsRoot: URL { appSupportRoot.appendingPathComponent("Components", isDirectory: true) }
    var cacheRoot: URL { appSupportRoot.appendingPathComponent("Cache", isDirectory: true) }
    var logsRoot: URL { appSupportRoot.appendingPathComponent("Logs", isDirectory: true) }
    var configRoot: URL { appSupportRoot.appendingPathComponent("Config", isDirectory: true) }

    func bottlePath(name: String) -> URL {
        bottlesRoot.appendingPathComponent(name, isDirectory: true)
    }

    var wineExecutable: URL { currentRuntime.appendingPathComponent("bin/wine") }
    var wine64Executable: URL { currentRuntime.appendingPathComponent("bin/wine64") }
    var wineServerExecutable: URL { currentRuntime.appendingPathComponent("bin/wineserver") }
    var wineBootExecutable: URL { currentRuntime.appendingPathComponent("bin/wineboot") }
    var wineCfgExecutable: URL { currentRuntime.appendingPathComponent("bin/winecfg") }
    var wineRegExecutable: URL { currentRuntime.appendingPathComponent("bin/wine") }

    var legacyAppSupportPath: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cross2Play", isDirectory: true)
    }
}
