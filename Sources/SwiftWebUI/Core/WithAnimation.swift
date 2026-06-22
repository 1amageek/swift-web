import SwiftHTML

/// Runs `body`, animating the state changes it makes with the given animation.
///
/// The animation is published on the current ``SwiftHTML/Transaction``; the
/// runtime reads it when it applies the resulting update's DOM changes, so the
/// browser interpolates them. There is no Swift-side animation engine.
///
/// Granularity note: unlike SwiftUI — which scopes the animation to the closure —
/// the web applies an event's changes only after the whole event is handled, so
/// the animation applies to the entire resulting update (per-event granularity).
/// Other changes made in the same event are interpolated with the same animation.
/// Passing `nil` runs `body` without animating.
public func withAnimation<Result>(
    _ animation: Animation? = .default,
    _ body: () throws -> Result
) rethrows -> Result {
    Transaction.current?.animation = animation.map {
        TransactionAnimation(css: $0.cssValue, durationMilliseconds: $0.totalDurationMilliseconds)
    }
    return try body()
}
