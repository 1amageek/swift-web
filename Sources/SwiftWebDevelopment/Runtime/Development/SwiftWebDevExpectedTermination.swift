import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

enum SwiftWebDevExpectedTermination {
    static func isExpected(_ error: any Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let channelError = error as? ChannelError {
            switch channelError {
            case .ioOnClosedChannel, .alreadyClosed, .inputClosed, .outputClosed, .eof:
                return true
            default:
                return false
            }
        }

        if let parserError = error as? HTTPParserError {
            switch parserError {
            case .invalidEOFState, .closedConnection:
                return true
            default:
                return false
            }
        }

        if let clientError = error as? HTTPClientError {
            switch clientError {
            case .cancelled, .remoteConnectionClosed, .requestStreamCancelled, .alreadyShutdown:
                return true
            default:
                return false
            }
        }

        let description = String(describing: error)
        return description.contains("stream ended at an unexpected time")
            || description.contains("I/O on closed channel")
            || description.contains("HTTPClientError.cancelled")
            || description.contains("HTTPClientError.remoteConnectionClosed")
            || description.contains("HTTPClientError.requestStreamCancelled")
            || description.contains("HTTPClientError.alreadyShutdown")
    }
}
