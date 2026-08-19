// Cross2Play — SystemInfo.swift
// Detects hardware and OS characteristics without hardcoding assumptions.

import Foundation

struct SystemInfo: Equatable, Sendable {

    let macOSVersion: OperatingSystemVersion
    let macOSVersionString: String
    let macOSBuildNumber: String
    let architecture: Architecture
    let appleSiliconChip: AppleSiliconGeneration
    let cpuCoreCount: Int
    let totalRAMBytes: UInt64
    let metalSupported: Bool

    static func == (lhs: SystemInfo, rhs: SystemInfo) -> Bool {
        lhs.macOSVersion.majorVersion == rhs.macOSVersion.majorVersion &&
        lhs.macOSVersion.minorVersion == rhs.macOSVersion.minorVersion &&
        lhs.macOSVersion.patchVersion == rhs.macOSVersion.patchVersion &&
        lhs.macOSBuildNumber == rhs.macOSBuildNumber &&
        lhs.architecture == rhs.architecture &&
        lhs.appleSiliconChip == rhs.appleSiliconChip &&
        lhs.cpuCoreCount == rhs.cpuCoreCount &&
        lhs.totalRAMBytes == rhs.totalRAMBytes &&
        lhs.metalSupported == rhs.metalSupported
    }

    enum Architecture: String, Sendable {
        case arm64 = "arm64"
        case x86_64 = "x86_64"
        case unknown = "unknown"
    }

    enum AppleSiliconGeneration: String, Sendable {
        case m1 = "Apple M1"
        case m2 = "Apple M2"
        case m3 = "Apple M3"
        case m4 = "Apple M4"
        case intel = "Intel"
        case unknown = "Apple Silicon"
    }

    var formattedRAM: String {
        let gb = Double(totalRAMBytes) / 1_073_741_824.0
        return String(format: "%.1fGB RAM", gb)
    }

    var isAppleSilicon: Bool { architecture == .arm64 }

    static var current: SystemInfo {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "Version \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var build = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &build, &size, nil, 0)
        let buildStr = String(cString: build)

        #if arch(arm64)
        let arch = Architecture.arm64
        #elseif arch(x86_64)
        let arch = Architecture.x86_64
        #else
        let arch = Architecture.unknown
        #endif

        let chip = detectChip()
        let cores = ProcessInfo.processInfo.processorCount
        let ram = ProcessInfo.processInfo.physicalMemory

        return SystemInfo(
            macOSVersion: osVersion,
            macOSVersionString: osVersionString,
            macOSBuildNumber: buildStr,
            architecture: arch,
            appleSiliconChip: chip,
            cpuCoreCount: cores,
            totalRAMBytes: ram,
            metalSupported: true
        )
    }

    private static func detectChip() -> AppleSiliconGeneration {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let brandStr = String(cString: brand)

        if brandStr.contains("M1") { return .m1 }
        if brandStr.contains("M2") { return .m2 }
        if brandStr.contains("M3") { return .m3 }
        if brandStr.contains("M4") { return .m4 }
        if brandStr.contains("Intel") { return .intel }
        return .unknown
    }

    func isRosettaInstalled() -> Bool {
        #if arch(arm64)
        let oahd = URL(fileURLWithPath: "/Library/Apple/usr/libexec/oah/oahd")
        return FileManager.default.fileExists(atPath: oahd.path)
        #else
        return true
        #endif
    }
}
