#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

#if hasFeature(Embedded)
typealias ClientRuntimeWireData = [UInt8]
#else
typealias ClientRuntimeWireData = Data
#endif

enum ClientRuntimeWireDataFactory {
    static func copy(pointer: UInt32, length: UInt32) throws -> ClientRuntimeWireData {
        guard let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer)) else {
            throw ClientRuntimeEntrypointError.invalidInputPointer
        }
        #if hasFeature(Embedded)
        return Array(UnsafeRawBufferPointer(start: rawPointer, count: Int(length)))
        #else
        return Data(bytes: rawPointer, count: Int(length))
        #endif
    }

    static func utf8(_ value: String) -> ClientRuntimeWireData {
        #if hasFeature(Embedded)
        return Array(value.utf8)
        #else
        return Data(value.utf8)
        #endif
    }
}
