/// Type-erased storage that recovers values without unconstrained dynamic
/// casting, which Embedded Swift does not support. Values are wrapped in a
/// generic final class and recovered by class cast; each store's write path
/// guarantees the slot's box type matches its key, so recovery is sound by
/// construction.
package protocol AnyRuntimeBox: AnyObject, Sendable {}

package final class RuntimeBox<Value: Sendable>: AnyRuntimeBox {
    package let value: Value

    package init(_ value: Value) {
        self.value = value
    }
}

/// Recovers a boxed value. `nil` when the box holds a different type — on
/// Embedded the type invariant is enforced by each store's write path and
/// violations trap in the class downcast. A free function because Embedded
/// Swift cannot call generic methods on existential receivers.
package func unboxRuntimeValue<Value: Sendable>(
    _ box: any AnyRuntimeBox,
    as type: Value.Type = Value.self
) -> Value? {
    #if hasFeature(Embedded)
    unsafeDowncast(box, to: RuntimeBox<Value>.self).value
    #else
    (box as? RuntimeBox<Value>)?.value
    #endif
}

/// Diagnostic-only type naming shared with parameter binding; Embedded Swift
/// has no type reflection.
package enum RuntimeTypeLabel {
    package static func of(_ type: Any.Type) -> String {
        #if hasFeature(Embedded)
        "declared type"
        #else
        String(describing: type)
        #endif
    }
}
