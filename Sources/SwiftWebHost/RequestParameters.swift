/// A source of named request parameters — path segments or query pairs —
/// exposing fully decoded raw strings plus the shared typed accessors.
///
/// Values convert through `LosslessStringConvertible` ("one wire string, one
/// value"), so standard types work as-is and domain types opt in by adopting
/// the standard-library protocol. `RawRepresentable` types whose raw value is
/// itself losslessly convertible (string/int enums) work without any adoption
/// via the dedicated overloads.
public protocol RequestParameters: Sendable {
    /// The first value for `name`, or nil when the parameter is absent.
    /// Implementations hand out fully decoded values (percent escapes
    /// already resolved).
    func rawValue(_ name: String) -> String?
    /// Every value for `name` in wire order (repeated query keys).
    func rawValues(_ name: String) -> [String]
}

extension RequestParameters {
    // MARK: LosslessStringConvertible

    public func require<Value: LosslessStringConvertible>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws(ParameterError) -> Value {
        guard let raw = rawValue(name) else {
            throw .missing(name: name)
        }
        return try convert(raw, name: name)
    }

    public func value<Value: LosslessStringConvertible>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws(ParameterError) -> Value? {
        guard let raw = rawValue(name) else {
            return nil
        }
        return try convert(raw, name: name) as Value
    }

    public func value<Value: LosslessStringConvertible>(
        _ name: String,
        default defaultValue: Value
    ) throws(ParameterError) -> Value {
        guard let raw = rawValue(name) else {
            return defaultValue
        }
        return try convert(raw, name: name)
    }

    public func values<Value: LosslessStringConvertible>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws(ParameterError) -> [Value] {
        var result: [Value] = []
        for raw in rawValues(name) {
            result.append(try convert(raw, name: name))
        }
        return result
    }

    public func values<Value: LosslessStringConvertible>(
        _ name: String,
        default defaultValue: [Value]
    ) throws(ParameterError) -> [Value] {
        let raw = rawValues(name)
        if raw.isEmpty {
            return defaultValue
        }
        var result: [Value] = []
        for element in raw {
            result.append(try convert(element, name: name))
        }
        return result
    }

    private func convert<Value: LosslessStringConvertible>(
        _ raw: String,
        name: String
    ) throws(ParameterError) -> Value {
        guard let value = Value(raw) else {
            throw .invalid(name: name, value: raw, type: TypeName.of(Value.self))
        }
        return value
    }

    // MARK: RawRepresentable (string/int enums, zero adoption required)

    public func require<Value: RawRepresentable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws(ParameterError) -> Value where Value.RawValue: LosslessStringConvertible {
        guard let raw = rawValue(name) else {
            throw .missing(name: name)
        }
        return try convertRaw(raw, name: name)
    }

    public func value<Value: RawRepresentable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws(ParameterError) -> Value? where Value.RawValue: LosslessStringConvertible {
        guard let raw = rawValue(name) else {
            return nil
        }
        return try convertRaw(raw, name: name) as Value
    }

    public func value<Value: RawRepresentable>(
        _ name: String,
        default defaultValue: Value
    ) throws(ParameterError) -> Value where Value.RawValue: LosslessStringConvertible {
        guard let raw = rawValue(name) else {
            return defaultValue
        }
        return try convertRaw(raw, name: name)
    }

    public func values<Value: RawRepresentable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws(ParameterError) -> [Value] where Value.RawValue: LosslessStringConvertible {
        var result: [Value] = []
        for raw in rawValues(name) {
            result.append(try convertRaw(raw, name: name))
        }
        return result
    }

    public func values<Value: RawRepresentable>(
        _ name: String,
        default defaultValue: [Value]
    ) throws(ParameterError) -> [Value] where Value.RawValue: LosslessStringConvertible {
        let raw = rawValues(name)
        if raw.isEmpty {
            return defaultValue
        }
        var result: [Value] = []
        for element in raw {
            result.append(try convertRaw(element, name: name))
        }
        return result
    }

    private func convertRaw<Value: RawRepresentable>(
        _ raw: String,
        name: String
    ) throws(ParameterError) -> Value where Value.RawValue: LosslessStringConvertible {
        guard let rawValue = Value.RawValue(raw), let value = Value(rawValue: rawValue) else {
            throw .invalid(name: name, value: raw, type: TypeName.of(Value.self))
        }
        return value
    }
}

/// Diagnostic-only type naming; Embedded Swift has no type reflection.
enum TypeName {
    static func of(_ type: Any.Type) -> String {
        #if hasFeature(Embedded)
        "declared type"
        #else
        String(describing: type)
        #endif
    }
}
