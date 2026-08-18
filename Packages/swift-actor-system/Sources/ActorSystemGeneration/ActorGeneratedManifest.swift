import Foundation

public struct ActorGeneratedManifest: Codable, Hashable, Sendable {
    private struct Header: Decodable {
        let formatVersion: Int
    }
    public struct InputSource: Codable, Hashable, Sendable {
        public let relativePath: String
        public let contentDigest: String
        public let replacedActorNames: [String]
        public let replacedPortableTypeNames: [String]

        public init(
            relativePath: String,
            contentDigest: String,
            replacedActorNames: [String],
            replacedPortableTypeNames: [String]
        ) {
            self.relativePath = relativePath
            self.contentDigest = contentDigest
            self.replacedActorNames = replacedActorNames
            self.replacedPortableTypeNames = replacedPortableTypeNames
        }
    }

    public struct GeneratedFile: Codable, Hashable, Sendable {
        public let relativePath: String
        public let contentDigest: String

        public init(relativePath: String, contentDigest: String) {
            self.relativePath = relativePath
            self.contentDigest = contentDigest
        }
    }

    public struct DependencySchema: Codable, Hashable, Sendable {
        public let packageIdentity: String
        public let moduleName: String
        public let contentDigest: String
        public let bootstrapTypeName: String

        public init(
            packageIdentity: String,
            moduleName: String,
            contentDigest: String,
            bootstrapTypeName: String
        ) {
            self.packageIdentity = packageIdentity
            self.moduleName = moduleName
            self.contentDigest = contentDigest
            self.bootstrapTypeName = bootstrapTypeName
        }
    }

    public static let currentFormatVersion = 2

    public let formatVersion: Int
    public let packageIdentity: String
    public let moduleName: String
    public let profile: ActorGenerationProfile
    public let toolchainFingerprint: String
    public let sourceRoot: String
    public let inputSources: [InputSource]
    public let generatedFiles: [GeneratedFile]
    public let dependencySchemas: [DependencySchema]
    public let schemaContentDigest: String
    public let schemaModuleTypeName: String
    public let bootstrapTypeName: String?

    public init(
        formatVersion: Int = ActorGeneratedManifest.currentFormatVersion,
        packageIdentity: String,
        moduleName: String,
        profile: ActorGenerationProfile,
        toolchainFingerprint: String,
        sourceRoot: String,
        inputSources: [InputSource],
        generatedFiles: [GeneratedFile],
        dependencySchemas: [DependencySchema],
        schemaContentDigest: String,
        schemaModuleTypeName: String,
        bootstrapTypeName: String?
    ) {
        self.formatVersion = formatVersion
        self.packageIdentity = packageIdentity
        self.moduleName = moduleName
        self.profile = profile
        self.toolchainFingerprint = toolchainFingerprint
        self.sourceRoot = sourceRoot
        self.inputSources = inputSources
        self.generatedFiles = generatedFiles
        self.dependencySchemas = dependencySchemas
        self.schemaContentDigest = schemaContentDigest
        self.schemaModuleTypeName = schemaModuleTypeName
        self.bootstrapTypeName = bootstrapTypeName
    }

    public static func load(from url: URL) throws -> ActorGeneratedManifest {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let header = try decoder.decode(Header.self, from: data)
        guard header.formatVersion == currentFormatVersion else {
            throw ActorGenerationError.schemaConflict(
                reason: "Generated manifest format \(header.formatVersion) is unsupported"
            )
        }
        return try decoder.decode(ActorGeneratedManifest.self, from: data)
    }

    public func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public func verifyGeneratedFiles(in outputDirectory: URL) throws {
        for file in generatedFiles {
            let url = outputDirectory.appendingPathComponent(file.relativePath)
            let contents: String
            do {
                contents = try String(contentsOf: url, encoding: .utf8)
            } catch {
                throw ActorGenerationError.sourceWriteFailure(
                    path: url.path,
                    reason: "Generated file listed by the manifest is unavailable: \(error)"
                )
            }
            guard ActorStableHash.digest(contents) == file.contentDigest else {
                throw ActorGenerationError.sourceWriteFailure(
                    path: url.path,
                    reason: "Generated file digest does not match its manifest"
                )
            }
        }
    }
}
