import Foundation
import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class SwiftWebDevPublishedWasmArtifacts: Sendable {
    struct AssetRepresentation: Sendable, Equatable {
        let fileURL: URL
        let contentEncoding: String?
    }

    struct OpenedAsset {
        let fileHandle: FileHandle
        let contentEncoding: String?
        let byteCount: Int64
    }

    static let assetRoutePrefix = "/__swiftweb/dev/wasm"
    static let retainedGenerationCount = 8

    private let rootDirectory: URL
    private let generationDirectory: URL
    private let currentLink: URL
    private let previousDestination: String?

    private init(
        rootDirectory: URL,
        generationDirectory: URL,
        currentLink: URL,
        previousDestination: String?
    ) {
        self.rootDirectory = rootDirectory
        self.generationDirectory = generationDirectory
        self.currentLink = currentLink
        self.previousDestination = previousDestination
    }

    static func rootDirectory(for configuration: SwiftWebDevRuntimeConfiguration) -> URL {
        let scratchRoot = SwiftWebDevWasmScratchDirectory.resolve(from: configuration.scratchDirectory)
            ?? configuration.packageDirectory
                .appendingPathComponent(".build", isDirectory: true)
                .appendingPathComponent("swiftweb", isDirectory: true)
        return scratchRoot
            .appendingPathComponent("published-wasm", isDirectory: true)
            .standardizedFileURL
    }

    static func stage(
        runtimes: [SwiftWebGeneratedWasmRuntime],
        contentHashesByProduct: [String: String],
        artifactURL: (SwiftWebGeneratedWasmRuntime) throws -> URL,
        configuration: SwiftWebDevRuntimeConfiguration
    ) throws -> SwiftWebDevPublishedWasmArtifacts {
        let fileManager = FileManager.default
        let rootDirectory = Self.rootDirectory(for: configuration)
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let generationName = "generation-\(UUID().uuidString)"
        let generationDirectory = rootDirectory.appendingPathComponent(
            generationName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: generationDirectory, withIntermediateDirectories: true)
        do {
            for runtime in runtimes {
                guard contentHashesByProduct[runtime.productName] != nil else {
                    throw SwiftWebDevPublishedWasmArtifactError.missingContentHash(
                        product: runtime.productName
                    )
                }
                let sourceURL = try artifactURL(runtime)
                let destinationURL = generationDirectory.appendingPathComponent(
                    "\(runtime.productName).wasm"
                )
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                for suffix in [".gz", ".br"] {
                    let compressedSource = URL(fileURLWithPath: sourceURL.path + suffix)
                    guard fileManager.fileExists(atPath: compressedSource.path) else {
                        continue
                    }
                    try fileManager.copyItem(
                        at: compressedSource,
                        to: URL(fileURLWithPath: destinationURL.path + suffix)
                    )
                }
            }
            let metadata = SwiftWebDevPublishedWasmGenerationMetadata(
                generationID: generationName,
                contentHashesByProduct: contentHashesByProduct
            )
            let metadataData = try JSONEncoder().encode(metadata)
            try metadataData.write(
                to: generationDirectory.appendingPathComponent(
                    SwiftWebDevPublishedWasmGenerationMetadata.fileName
                ),
                options: .atomic
            )
        } catch {
            do {
                try fileManager.removeItem(at: generationDirectory)
            } catch {
                // Preserve the original staging failure.
            }
            throw error
        }

        let currentLink = rootDirectory.appendingPathComponent("current")
        let previousDestination: String?
        do {
            previousDestination = try fileManager.destinationOfSymbolicLink(atPath: currentLink.path)
        } catch {
            previousDestination = nil
        }
        return SwiftWebDevPublishedWasmArtifacts(
            rootDirectory: rootDirectory,
            generationDirectory: generationDirectory,
            currentLink: currentLink,
            previousDestination: previousDestination
        )
    }

    func commit() throws {
        try replaceCurrentLink(with: generationDirectory.lastPathComponent)
    }

    func rollback() throws {
        if let previousDestination {
            try replaceCurrentLink(with: previousDestination)
        } else if FileManager.default.fileExists(atPath: currentLink.path) {
            try FileManager.default.removeItem(at: currentLink)
        }
        if FileManager.default.fileExists(atPath: generationDirectory.path) {
            try FileManager.default.removeItem(at: generationDirectory)
        }
    }

    func finish() throws {
        let temporaryLink = temporaryLinkURL()
        if FileManager.default.fileExists(atPath: temporaryLink.path) {
            try FileManager.default.removeItem(at: temporaryLink)
        }
        try Self.pruneGenerations(in: rootDirectory)
    }

    func assetPath(productName: String, contentHash: String) -> String {
        "\(Self.assetRoutePrefix)/\(generationDirectory.lastPathComponent)/\(productName).wasm?v=\(contentHash)"
    }

    var generationID: String {
        generationDirectory.lastPathComponent
    }

    static func currentGenerationID(in rootDirectory: URL) throws -> String? {
        let currentLink = rootDirectory.appendingPathComponent("current")
        guard FileManager.default.fileExists(atPath: currentLink.path) else {
            return nil
        }
        let destination = try FileManager.default.destinationOfSymbolicLink(
            atPath: currentLink.path
        )
        try validateGenerationID(destination)
        return destination
    }

    static func acquireLease(
        rootDirectory: URL,
        generationID: String,
        processIdentifier: Int32
    ) throws -> URL {
        try validateGenerationID(generationID)
        let generationDirectory = rootDirectory.appendingPathComponent(
            generationID,
            isDirectory: true
        )
        guard FileManager.default.fileExists(atPath: generationDirectory.path) else {
            throw SwiftWebDevPublishedWasmArtifactError.generationUnavailable(generationID)
        }
        let leaseURL = generationDirectory.appendingPathComponent(
            ".lease-\(processIdentifier)"
        )
        try Data(String(processIdentifier).utf8).write(to: leaseURL, options: .atomic)
        return leaseURL
    }

    static func resolveAsset(
        rootDirectory: URL,
        generationID: String,
        productName: String,
        requestedContentHash: String
    ) throws -> URL {
        try validateGenerationID(generationID)
        try validateProductName(productName)
        let generationDirectory = rootDirectory.appendingPathComponent(
            generationID,
            isDirectory: true
        )
        let metadataURL = generationDirectory.appendingPathComponent(
            SwiftWebDevPublishedWasmGenerationMetadata.fileName
        )
        let metadataData: Data
        do {
            metadataData = try Data(contentsOf: metadataURL)
        } catch {
            if isFileNotFound(error) {
                throw SwiftWebDevPublishedWasmArtifactError.generationUnavailable(generationID)
            }
            throw SwiftWebDevPublishedWasmArtifactError.artifactReadFailed(
                product: productName,
                generation: generationID,
                reason: String(describing: error)
            )
        }
        let metadata: SwiftWebDevPublishedWasmGenerationMetadata
        do {
            metadata = try JSONDecoder().decode(
                SwiftWebDevPublishedWasmGenerationMetadata.self,
                from: metadataData
            )
        } catch {
            throw SwiftWebDevPublishedWasmArtifactError.artifactReadFailed(
                product: productName,
                generation: generationID,
                reason: String(describing: error)
            )
        }
        guard metadata.generationID == generationID else {
            throw SwiftWebDevPublishedWasmArtifactError.generationUnavailable(generationID)
        }
        guard let expectedHash = metadata.contentHashesByProduct[productName] else {
            throw SwiftWebDevPublishedWasmArtifactError.artifactUnavailable(
                product: productName,
                generation: generationID
            )
        }
        guard expectedHash == requestedContentHash else {
            throw SwiftWebDevPublishedWasmArtifactError.contentHashMismatch(
                expected: expectedHash,
                requested: requestedContentHash
            )
        }
        let artifactURL = generationDirectory.appendingPathComponent(
            "\(productName).wasm"
        )
        guard FileManager.default.fileExists(atPath: artifactURL.path) else {
            throw SwiftWebDevPublishedWasmArtifactError.artifactUnavailable(
                product: productName,
                generation: generationID
            )
        }
        return artifactURL
    }

    static func openAsset(
        rootDirectory: URL,
        generationID: String,
        productName: String,
        requestedContentHash: String,
        acceptEncoding: String
    ) throws -> OpenedAsset {
        let artifactURL = try resolveAsset(
            rootDirectory: rootDirectory,
            generationID: generationID,
            productName: productName,
            requestedContentHash: requestedContentHash
        )
        let representation = selectRepresentation(
            for: artifactURL,
            acceptEncoding: acceptEncoding
        )
        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forReadingFrom: representation.fileURL)
        } catch {
            if isFileNotFound(error) {
                throw SwiftWebDevPublishedWasmArtifactError.generationUnavailable(generationID)
            }
            throw SwiftWebDevPublishedWasmArtifactError.artifactReadFailed(
                product: productName,
                generation: generationID,
                reason: String(describing: error)
            )
        }
        var fileStatus = stat()
        guard fstat(fileHandle.fileDescriptor, &fileStatus) == 0, fileStatus.st_size >= 0 else {
            let code = errno
            do {
                try fileHandle.close()
            } catch {
                // Preserve the descriptor inspection failure.
            }
            throw SwiftWebDevPublishedWasmArtifactError.artifactReadFailed(
                product: productName,
                generation: generationID,
                reason: String(cString: strerror(code))
            )
        }
        return OpenedAsset(
            fileHandle: fileHandle,
            contentEncoding: representation.contentEncoding,
            byteCount: Int64(fileStatus.st_size)
        )
    }

    static func selectRepresentation(
        for artifactURL: URL,
        acceptEncoding: String
    ) -> AssetRepresentation {
        let brotliURL = URL(fileURLWithPath: artifactURL.path + ".br")
        let gzipURL = URL(fileURLWithPath: artifactURL.path + ".gz")
        let brotliQuality = acceptedEncodingQuality("br", in: acceptEncoding)
        let gzipQuality = acceptedEncodingQuality("gzip", in: acceptEncoding)

        if FileManager.default.fileExists(atPath: brotliURL.path),
           brotliQuality > 0,
           brotliQuality >= gzipQuality
        {
            return AssetRepresentation(fileURL: brotliURL, contentEncoding: "br")
        }
        if FileManager.default.fileExists(atPath: gzipURL.path), gzipQuality > 0 {
            return AssetRepresentation(fileURL: gzipURL, contentEncoding: "gzip")
        }
        return AssetRepresentation(fileURL: artifactURL, contentEncoding: nil)
    }

    private func replaceCurrentLink(with destination: String) throws {
        let fileManager = FileManager.default
        let temporaryLink = temporaryLinkURL()
        if fileManager.fileExists(atPath: temporaryLink.path) {
            try fileManager.removeItem(at: temporaryLink)
        }
        try fileManager.createSymbolicLink(
            atPath: temporaryLink.path,
            withDestinationPath: destination
        )
        guard rename(temporaryLink.path, currentLink.path) == 0 else {
            let code = errno
            try fileManager.removeItem(at: temporaryLink)
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
    }

    private func temporaryLinkURL() -> URL {
        rootDirectory.appendingPathComponent("current.next")
    }

    private static func validateGenerationID(_ generationID: String) throws {
        let prefix = "generation-"
        guard generationID.hasPrefix(prefix),
              UUID(uuidString: String(generationID.dropFirst(prefix.count))) != nil,
              !generationID.contains("/"),
              !generationID.contains(".")
        else {
            throw SwiftWebDevPublishedWasmArtifactError.invalidGenerationID(generationID)
        }
    }

    private static func validateProductName(_ productName: String) throws {
        guard !productName.isEmpty,
              productName.allSatisfy({ character in
                  character.isASCII
                      && (character.isLetter
                          || character.isNumber
                          || character == "-"
                          || character == "_")
              })
        else {
            throw SwiftWebDevPublishedWasmArtifactError.invalidProductName(productName)
        }
    }

    private static func acceptedEncodingQuality(_ encoding: String, in header: String) -> Double {
        let normalizedEncoding = encoding.lowercased()
        var explicitQuality: Double?
        var wildcardQuality: Double?
        for value in header.lowercased().split(separator: ",") {
            let parts = value.split(separator: ";").map(trimmedWhitespace)
            guard let name = parts.first, name == normalizedEncoding || name == "*" else {
                continue
            }
            let quality = parts.dropFirst().compactMap(qualityParameter).first ?? 1
            if name == normalizedEncoding {
                explicitQuality = max(explicitQuality ?? 0, quality)
            } else {
                wildcardQuality = max(wildcardQuality ?? 0, quality)
            }
        }
        return explicitQuality ?? wildcardQuality ?? 0
    }

    private static func qualityParameter(_ value: String) -> Double? {
        let parts = value.split(separator: "=", maxSplits: 1).map(trimmedWhitespace)
        guard parts.count == 2, parts[0] == "q", let quality = Double(parts[1]) else {
            return nil
        }
        return min(max(quality, 0), 1)
    }

    private static func trimmedWhitespace(_ value: Substring) -> String {
        var slice = value
        while let first = slice.first, first.isWhitespace {
            slice = slice.dropFirst()
        }
        while let last = slice.last, last.isWhitespace {
            slice = slice.dropLast()
        }
        return String(slice)
    }

    private static func isFileNotFound(_ error: any Error) -> Bool {
        if let posixError = error as? POSIXError, posixError.code == .ENOENT {
            return true
        }
        let cocoaError = error as NSError
        return cocoaError.domain == NSCocoaErrorDomain
            && (cocoaError.code == NSFileNoSuchFileError
                || cocoaError.code == NSFileReadNoSuchFileError)
    }

    private static func pruneGenerations(in rootDirectory: URL) throws {
        let fileManager = FileManager.default
        let currentGeneration = try currentGenerationID(in: rootDirectory)
        let contents = try fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        var generations: [(url: URL, modified: Date)] = []
        for url in contents where url.lastPathComponent.hasPrefix("generation-") {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            guard values.isDirectory == true else {
                continue
            }
            generations.append((url, values.contentModificationDate ?? .distantPast))
        }
        generations.sort { $0.modified > $1.modified }
        let newest = Set(generations.prefix(retainedGenerationCount).map { $0.url.lastPathComponent })

        for generation in generations {
            let generationID = generation.url.lastPathComponent
            guard generationID != currentGeneration,
                  !newest.contains(generationID),
                  !hasLiveLease(in: generation.url)
            else {
                continue
            }
            try fileManager.removeItem(at: generation.url)
        }
    }

    private static func hasLiveLease(in generationDirectory: URL) -> Bool {
        let fileManager = FileManager.default
        let leaseURLs: [URL]
        do {
            leaseURLs = try fileManager.contentsOfDirectory(
                at: generationDirectory,
                includingPropertiesForKeys: nil,
                options: []
            ).filter { $0.lastPathComponent.hasPrefix(".lease-") }
        } catch {
            return true
        }
        for leaseURL in leaseURLs {
            let rawPID = leaseURL.lastPathComponent.dropFirst(".lease-".count)
            guard let processIdentifier = Int32(rawPID) else {
                return true
            }
            if kill(processIdentifier, 0) == 0 || errno == EPERM {
                return true
            }
            do {
                try fileManager.removeItem(at: leaseURL)
            } catch {
                return true
            }
        }
        return false
    }
}
