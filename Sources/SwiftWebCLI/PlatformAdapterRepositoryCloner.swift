import Foundation

protocol PlatformAdapterRepositoryCloning {
    func clone(_ reference: PlatformAdapterReference, to checkoutDirectory: URL) throws
}

struct GitPlatformAdapterRepositoryCloner: PlatformAdapterRepositoryCloning {
    func clone(_ reference: PlatformAdapterReference, to checkoutDirectory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "git",
            "clone",
            "--depth",
            "1",
            reference.repositoryURL,
            checkoutDirectory.path,
        ]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "git clone failed"
            throw CLIError(
                message: "failed to clone platform adapter \(reference.repositorySlug): \(message)",
                exitCode: 69
            )
        }
    }
}
