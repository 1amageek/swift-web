/// A host-neutral async writer that streaming body closures write chunks into.
/// Host adapters bridge this to their native body writer.
public protocol WebBodyWriter: Sendable {
    func write(_ bytes: [UInt8]) async throws
}

extension WebBodyWriter {
    public func write(_ string: String) async throws {
        try await write(Array(string.utf8))
    }
}
