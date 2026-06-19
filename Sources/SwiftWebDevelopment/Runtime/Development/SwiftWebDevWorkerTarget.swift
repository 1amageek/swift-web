import Foundation

struct SwiftWebDevWorkerTarget: Sendable, Equatable {
    let host: String
    let port: Int

    var url: String {
        "http://\(host):\(port)"
    }
}
