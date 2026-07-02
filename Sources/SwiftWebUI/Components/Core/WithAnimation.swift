import SwiftWebUITheme
import SwiftHTML

/// Runs `body`, animating the state changes it makes with the given animation.
///
/// The animation is published on the current ``SwiftHTML/Transaction``; the
/// runtime reads it when it applies the resulting update's DOM changes, so the
/// browser interpolates them. There is no Swift-side animation engine.
///
/// Granularity note: unlike SwiftUI — which scopes the animation to the closure —
/// the web applies an event's changes only after the whole event is handled, so
/// the animation applies to the *entire* resulting update (per-event granularity).
/// Two consequences, by design and not silently:
/// - Other changes made elsewhere in the same event are interpolated with this
///   animation too.
/// - If several `withAnimation` calls run in one event, the last one wins for the
///   whole update; an earlier call's animation does not apply only to its own
///   changes. Use one `withAnimation` per event when the timing must differ.
///
/// Passing `nil` runs `body` without animating. Outside an event being dispatched
/// (e.g. server-side render) there is no transaction to record on, so `body` runs
/// unanimated — correct, because there is no client to interpolate.
@discardableResult
public func withAnimation<Result>(
    _ animation: Animation? = .default,
    _ body: () throws -> Result
) rethrows -> Result {
    Transaction.current?.animation = animation.map {
        TransactionAnimation(css: $0.cssValue, durationMilliseconds: $0.totalDurationMilliseconds)
    }
    return try body()
}
