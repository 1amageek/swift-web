import SwiftHTML
import Synchronization

public struct CoordinateSpace: Sendable, Equatable {
    private let name: String

    public init(_ name: String) {
        self.name = name
    }

    public static let local = CoordinateSpace("local")
    public static let global = CoordinateSpace("global")

    public static func named(_ name: String) -> CoordinateSpace {
        CoordinateSpace(name)
    }

    var cssName: String {
        name
    }
}

public enum HoverPhase: Sendable, Equatable {
    case active(CGPoint)
    case ended
}

private final class TapGestureRuntimeState: Sendable {
    private let count = Mutex(0)

    func registerClick(requiredCount: Int) -> Bool {
        guard requiredCount > 1 else {
            return true
        }
        return count.withLock { count in
            count += 1
            guard count >= requiredCount else {
                return false
            }
            count = 0
            return true
        }
    }
}

public struct TapGestureModifier: ComponentModifier {
    private let count: Int
    private let action: () -> Void
    private let runtimeState = TapGestureRuntimeState()

    init(count: Int, action: @escaping () -> Void) {
        self.count = max(count, 1)
        self.action = action
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        let requiredCount = count
        let runtimeState = self.runtimeState
        Element(
            "div",
            attributes: [
                .class("swui-modifier swui-attribute swui-semantic-modifier"),
                .data("tap-count", "\(requiredCount)"),
                .onClick {
                    if runtimeState.registerClick(requiredCount: requiredCount) {
                        action()
                    }
                },
            ]
        ) {
            content
        }
    }
}

private struct LongPressGestureRuntimeValue: Sendable {
    var generation: Int = 0
    var isPressing = false
    var didFire = false
    var startX: Double?
    var startY: Double?
}

private final class LongPressGestureRuntimeState: Sendable {
    private let storage = Mutex(LongPressGestureRuntimeValue())

    func begin(at event: DOMEvent) -> Int {
        storage.withLock { state in
            state.generation += 1
            state.isPressing = true
            state.didFire = false
            state.startX = event.clientX
            state.startY = event.clientY
            return state.generation
        }
    }

    func fire(generation: Int) -> Bool {
        storage.withLock { state in
            guard state.generation == generation, state.isPressing, !state.didFire else {
                return false
            }
            state.didFire = true
            return true
        }
    }

    func cancel() -> Bool {
        storage.withLock { state in
            guard state.isPressing else {
                return false
            }
            state.isPressing = false
            return true
        }
    }

    func cancelIfMovedBeyondLimit(event: DOMEvent, maximumDistance: Double) -> Bool {
        storage.withLock { state in
            guard state.isPressing,
                  let startX = state.startX,
                  let startY = state.startY,
                  let x = event.clientX,
                  let y = event.clientY
            else {
                return false
            }
            let dx = x - startX
            let dy = y - startY
            guard dx * dx + dy * dy > maximumDistance * maximumDistance else {
                return false
            }
            state.isPressing = false
            return true
        }
    }
}

public struct LongPressGestureModifier: ComponentModifier {
    private let minimumDuration: Double
    private let maximumDistance: WebUILength
    private let pressing: (@Sendable (Bool) -> Void)?
    private let action: @Sendable () -> Void
    private let runtimeState = LongPressGestureRuntimeState()

    init(
        minimumDuration: Double,
        maximumDistance: WebUILength,
        pressing: (@Sendable (Bool) -> Void)?,
        action: @escaping @Sendable () -> Void
    ) {
        self.minimumDuration = max(minimumDuration, 0)
        self.maximumDistance = maximumDistance
        self.pressing = pressing
        self.action = action
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        let runtimeState = self.runtimeState
        let nanoseconds = UInt64(minimumDuration * 1_000_000_000)
        let maximumDistance = maximumDistance.pixelValue
        let pressing = self.pressing
        let action = self.action
        Element(
            "div",
            attributes: [
                .class("swui-modifier swui-attribute swui-semantic-modifier"),
                .data("long-press-minimum-duration", trimmedNumber(minimumDuration)),
                .data("long-press-maximum-distance", self.maximumDistance.cssValue),
                .onPointerDown { event in
                    let generation = runtimeState.begin(at: event)
                    pressing?(true)

                    Task {
                        do {
                            try await Task.sleep(nanoseconds: nanoseconds)
                        } catch {
                            return
                        }
                        if runtimeState.fire(generation: generation) {
                            action()
                        }
                    }
                },
                .onPointerMove { event in
                    guard let maximumDistance,
                          runtimeState.cancelIfMovedBeyondLimit(event: event, maximumDistance: maximumDistance)
                    else {
                        return
                    }
                    pressing?(false)
                },
                .onPointerUp { _ in
                    guard runtimeState.cancel() else {
                        return
                    }
                    pressing?(false)
                },
                .onPointerLeave { _ in
                    guard runtimeState.cancel() else {
                        return
                    }
                    pressing?(false)
                },
            ]
        ) {
            content
        }
    }
}

public extension WebUIAttributeMutableHTML {
    func on(_ eventName: String, _ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.event(eventName, handler))
    }

    func onSubmit(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onSubmit(handler))
    }

    func onKeyDown(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onKeyDown(handler))
    }

    func onKeyUp(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onKeyUp(handler))
    }

    func onFocus(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onFocus(handler))
    }

    func onBlur(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onBlur(handler))
    }

    func onMouseDown(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onMouseDown(handler))
    }

    func onMouseUp(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onMouseUp(handler))
    }

    func onMouseMove(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onMouseMove(handler))
    }

    func onMouseEnter(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onMouseEnter(handler))
    }

    func onMouseLeave(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onMouseLeave(handler))
    }

    func onPointerDown(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onPointerDown(handler))
    }

    func onPointerUp(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onPointerUp(handler))
    }

    func onPointerMove(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onPointerMove(handler))
    }

    func onPointerEnter(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onPointerEnter(handler))
    }

    func onPointerLeave(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onPointerLeave(handler))
    }

    func onDragStart(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onDragStart(handler))
    }

    func onDragOver(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onDragOver(handler))
    }

    func onDrop(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onDrop(handler))
    }

    func onReset(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onReset(handler))
    }

    func onInvalid(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onInvalid(handler))
    }

    func onLoad(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onLoad(handler))
    }

    func onError(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onError(handler))
    }

    func onScroll(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onScroll(handler))
    }
}

public extension HTML {
    func onAppear(perform action: (() -> Void)? = nil) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("lifecycle", "appear"),
            .event("appear") { _ in action?() },
        ], role: .semantic))
    }

    func onDisappear(perform action: (() -> Void)? = nil) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("lifecycle", "disappear"),
            .event("disappear") { _ in action?() },
        ], role: .semantic))
    }

    func task(
        priority: TaskPriority? = nil,
        _ action: @escaping @Sendable () async -> Void
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("task", "true"),
            .data("task-priority", priority?.description ?? "default"),
            .event("appear") { _ in
                Task(priority: priority) {
                    await action()
                }
            },
        ], role: .semantic))
    }

    func task<ID>(
        id value: ID,
        priority: TaskPriority? = nil,
        _ action: @escaping @Sendable () async -> Void
    ) -> ModifiedContent<Self, HTMLAttributeModifier> where ID: Equatable & Sendable {
        modifier(HTMLAttributeModifier([
            .data("task", "true"),
            .data("task-id", "\(value)"),
            .data("task-priority", priority?.description ?? "default"),
            .event("appear") { _ in
                Task(priority: priority) {
                    await action()
                }
            },
        ], role: .semantic))
    }

    func onTapGesture(
        count: Int = 1,
        perform action: @escaping () -> Void
    ) -> ModifiedContent<Self, TapGestureModifier> {
        modifier(TapGestureModifier(count: count, action: action))
    }

    func onLongPressGesture(
        minimumDuration: Double = 0.5,
        maximumDistance: WebUILength = 10,
        pressing: (@Sendable (Bool) -> Void)? = nil,
        perform action: @escaping @Sendable () -> Void
    ) -> ModifiedContent<Self, LongPressGestureModifier> {
        modifier(LongPressGestureModifier(
            minimumDuration: minimumDuration,
            maximumDistance: maximumDistance,
            pressing: pressing,
            action: action
        ))
    }

    func onHover(
        perform action: @escaping (Bool) -> Void
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .onMouseEnter { _ in action(true) },
            .onMouseLeave { _ in action(false) },
        ], role: .semantic))
    }

    func onContinuousHover(
        coordinateSpace: CoordinateSpace = .local,
        perform action: @escaping (HoverPhase) -> Void
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .data("hover-coordinate-space", coordinateSpace.cssName),
            .onMouseMove { event in
                action(.active(CGPoint(
                    x: .css("\(trimmedNumber(event.clientX ?? 0))px"),
                    y: .css("\(trimmedNumber(event.clientY ?? 0))px")
                )))
            },
            .onMouseLeave { _ in action(.ended) },
        ], role: .semantic))
    }

    func help(_ text: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .title(text),
            .aria("description", text),
        ], role: .semantic))
    }
}

private extension WebUILength {
    var pixelValue: Double? {
        switch self {
        case .css(var value):
            if value.hasSuffix("px") {
                value.removeLast(2)
            }
            return Double(value)
        case .infinity:
            return nil
        }
    }
}

extension TaskPriority {
    var description: String {
        switch self {
        case .high:
            "high"
        case .medium:
            "medium"
        case .low:
            "low"
        case .background:
            "background"
        default:
            "default"
        }
    }
}
