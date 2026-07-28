import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum SwiftWebDevPortAllocator {
    static func allocateLoopbackPort() throws -> Int {
        let socketDescriptor = socket(AF_INET, streamSocketType, 0)
        guard socketDescriptor >= 0 else {
            throw SwiftWebDevRuntimeError.workerPortAllocationFailed
        }
        defer {
            close(socketDescriptor)
        }

        var reuse = Int32(1)
        setsockopt(
            socketDescriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuse,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = sockaddr_in()
        #if canImport(Darwin)
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(
                    socketDescriptor,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard bindResult == 0 else {
            throw SwiftWebDevRuntimeError.workerPortAllocationFailed
        }

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                getsockname(socketDescriptor, socketAddress, &length)
            }
        }
        guard nameResult == 0 else {
            throw SwiftWebDevRuntimeError.workerPortAllocationFailed
        }

        return Int(in_port_t(bigEndian: boundAddress.sin_port))
    }

    private static var streamSocketType: Int32 {
        #if canImport(Darwin)
        SOCK_STREAM
        #elseif canImport(Glibc)
        Int32(SOCK_STREAM.rawValue)
        #endif
    }
}
