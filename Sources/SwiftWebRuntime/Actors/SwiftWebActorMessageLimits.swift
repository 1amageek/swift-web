/// Resource limits for actor messages carried by the shared SwiftWeb runtime.
///
/// A SwiftWeb actor may carry a large typed service payload. The payload
/// allowance covers four mebibytes of application data plus portable-actor
/// framing, while the frame allowance also covers the outer actor envelope.
package enum SwiftWebActorMessageLimits {
    package static let maximumPayloadBytes = (4 * 1_024 * 1_024) + (64 * 1_024)
    package static let maximumFrameBytes = maximumPayloadBytes + (64 * 1_024)
}
