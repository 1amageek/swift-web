import SwiftHTML

/// A compact open-addressed map specialized for nonnegative hydration node
/// identifiers. It avoids the Standard WASM Dictionary runtime path while
/// retaining constant-time lookup and insertion for large DOMs.
struct NodeMap: Sendable {
    private static let minimumCapacity = 16

    private var keyStorage: [Int?] = Array(repeating: nil, count: minimumCapacity)
    private var valueStorage: [Int] = Array(repeating: 0, count: minimumCapacity)
    private(set) var count = 0

    var keys: [HTMLNodeID] {
        keyStorage.compactMap { $0 }.sorted().map(HTMLNodeID.init)
    }

    var values: [HTMLNodeID] {
        keys.compactMap { self[$0] }
    }

    var isEmpty: Bool {
        count == 0
    }

    subscript(_ key: HTMLNodeID) -> HTMLNodeID? {
        get {
            guard let slot = existingSlot(for: key.rawValue) else {
                return nil
            }
            return HTMLNodeID(valueStorage[slot])
        }
        set {
            guard let newValue else {
                removeValue(for: key.rawValue)
                return
            }
            ensureCapacityForInsertion()
            let slot = insertionSlot(for: key.rawValue)
            if keyStorage[slot] == nil {
                keyStorage[slot] = key.rawValue
                count += 1
            }
            valueStorage[slot] = newValue.rawValue
        }
    }

    func inverted() -> NodeMap {
        var result = NodeMap()
        for slot in keyStorage.indices {
            guard let key = keyStorage[slot] else {
                continue
            }
            let value = HTMLNodeID(valueStorage[slot])
            precondition(result[value] == nil, "Duplicate value in NodeMap")
            result[value] = HTMLNodeID(key)
        }
        return result
    }

    private mutating func ensureCapacityForInsertion() {
        guard (count + 1) * 10 >= keyStorage.count * 7 else {
            return
        }
        let oldKeys = keyStorage
        let oldValues = valueStorage
        keyStorage = Array(repeating: nil, count: oldKeys.count * 2)
        valueStorage = Array(repeating: 0, count: oldValues.count * 2)
        count = 0
        for slot in oldKeys.indices {
            guard let key = oldKeys[slot] else {
                continue
            }
            self[HTMLNodeID(key)] = HTMLNodeID(oldValues[slot])
        }
    }

    private mutating func removeValue(for key: Int) {
        guard let removedSlot = existingSlot(for: key) else {
            return
        }
        keyStorage[removedSlot] = nil
        count -= 1

        var slot = (removedSlot + 1) & (keyStorage.count - 1)
        while let displacedKey = keyStorage[slot] {
            let displacedValue = valueStorage[slot]
            keyStorage[slot] = nil
            count -= 1
            self[HTMLNodeID(displacedKey)] = HTMLNodeID(displacedValue)
            slot = (slot + 1) & (keyStorage.count - 1)
        }
    }

    private func existingSlot(for key: Int) -> Int? {
        var slot = hash(key) & (keyStorage.count - 1)
        while let storedKey = keyStorage[slot] {
            if storedKey == key {
                return slot
            }
            slot = (slot + 1) & (keyStorage.count - 1)
        }
        return nil
    }

    private func insertionSlot(for key: Int) -> Int {
        var slot = hash(key) & (keyStorage.count - 1)
        while let storedKey = keyStorage[slot], storedKey != key {
            slot = (slot + 1) & (keyStorage.count - 1)
        }
        return slot
    }

    private func hash(_ value: Int) -> Int {
        Int(truncatingIfNeeded: UInt(truncatingIfNeeded: value) &* UInt(2_654_435_761))
    }
}

/// Set counterpart to `NodeMap`, sharing the same WASM-safe storage strategy.
struct NodeIDSet: Sendable {
    private var storage = NodeMap()

    init(_ values: [HTMLNodeID] = []) {
        for value in values {
            insert(value)
        }
    }

    func contains(_ value: HTMLNodeID) -> Bool {
        storage[value] != nil
    }

    @discardableResult
    mutating func insert(_ value: HTMLNodeID) -> Bool {
        let inserted = storage[value] == nil
        storage[value] = value
        return inserted
    }
}
