import SwiftWebUITheme
import SwiftHTML

/// An animation. Lowers to the timing half of a CSS `transition`
/// (`<duration> <timing-function> <delay>`), published to a subtree through the
/// inherited `--swui-animation` custom property. The browser performs the
/// interpolation — there is no Swift-side animation engine.
public struct Animation: Sendable, Equatable {
    private let timingFunction: TimingFunction
    private let duration: Double
    private let delaySeconds: Double

    private init(timingFunction: TimingFunction, duration: Double, delaySeconds: Double = 0) {
        self.timingFunction = timingFunction
        self.duration = duration
        self.delaySeconds = delaySeconds
    }

    private static let standardDuration = 0.35

    /// The framework default: a standard ease-in-out.
    public static let `default` = Animation(timingFunction: .easeInOut, duration: standardDuration)

    public static let easeInOut = Animation(timingFunction: .easeInOut, duration: standardDuration)
    public static let easeIn = Animation(timingFunction: .easeIn, duration: standardDuration)
    public static let easeOut = Animation(timingFunction: .easeOut, duration: standardDuration)
    public static let linear = Animation(timingFunction: .linear, duration: standardDuration)
    /// A spring, approximated as a sampled `linear()` easing (see `TimingFunction.spring`).
    public static let spring = Animation.spring()

    public static func easeInOut(duration: Double) -> Animation {
        Animation(timingFunction: .easeInOut, duration: duration)
    }

    public static func easeIn(duration: Double) -> Animation {
        Animation(timingFunction: .easeIn, duration: duration)
    }

    public static func easeOut(duration: Double) -> Animation {
        Animation(timingFunction: .easeOut, duration: duration)
    }

    public static func linear(duration: Double) -> Animation {
        Animation(timingFunction: .linear, duration: duration)
    }

    public static func spring(duration: Double = 0.5, bounce: Double = 0.0) -> Animation {
        Animation(timingFunction: .spring(bounce: bounce), duration: duration)
    }

    public func delay(_ seconds: Double) -> Animation {
        Animation(timingFunction: timingFunction, duration: duration, delaySeconds: delaySeconds + seconds)
    }

    public func speed(_ multiplier: Double) -> Animation {
        guard multiplier > 0 else { return self }
        return Animation(
            timingFunction: timingFunction,
            duration: duration / multiplier,
            delaySeconds: delaySeconds / multiplier
        )
    }

    /// The `transition` shorthand tail (`<duration> <timing-function> <delay>`),
    /// used as the value of the inherited `--swui-animation` custom property.
    var cssValue: String {
        "\(Self.seconds(duration)) \(timingFunction.cssValue) \(Self.seconds(delaySeconds))"
    }

    /// Total wall-clock length (delay + duration) in milliseconds. Used by the
    /// runtime to time a removal transition before it detaches the node.
    var totalDurationMilliseconds: Int {
        Int(((duration + delaySeconds) * 1000).rounded())
    }

    private static func seconds(_ value: Double) -> String {
        let milliseconds = (value * 1000).rounded()
        if milliseconds == 0 {
            return "0s"
        }
        let rounded = milliseconds / 1000
        if rounded == rounded.rounded() {
            return "\(Int(rounded))s"
        }
        return "\(rounded)s"
    }
}
