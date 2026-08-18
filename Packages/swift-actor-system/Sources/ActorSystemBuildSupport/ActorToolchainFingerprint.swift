import ActorSystemGeneration
import Foundation

public enum ActorToolchainFingerprint {
    public static func compute(swiftCompiler: URL) throws -> String {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = swiftCompiler
        process.arguments = ["--version"]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !output.isEmpty else {
            throw ActorGenerationError.toolchainFailure(
                command: "\(swiftCompiler.path) --version",
                status: process.terminationStatus,
                output: output
            )
        }
        let high = hash64(output, seed: 0x6c62272e07bb0142)
        let low = hash64(output, seed: 0x62b821756295c58d)
        return "swiftc-\(hex(high))\(hex(low))"
    }

    private static func hash64(_ value: String, seed: UInt64) -> UInt64 {
        var hash = seed
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }

    private static func hex(_ value: UInt64) -> String {
        let unpadded = String(value, radix: 16, uppercase: false)
        return String(repeating: "0", count: 16 - unpadded.count) + unpadded
    }
}
