import SwiftHTML

/// A WASM-safe open-addressed index for child positions during reconciliation.
struct NodePositionMap: Sendable {
    private static let minimumCapacity = 16

    private var keyStorage: [Int?] = Array(repeating: nil, count: minimumCapacity)
    private var valueStorage: [Int] = Array(repeating: 0, count: minimumCapacity)
    private var count = 0

    subscript(_ key: HTMLNodeID) -> Int? {
        get {
            guard let slot = existingSlot(for: key.rawValue) else {
                return nil
            }
            return valueStorage[slot]
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
            valueStorage[slot] = newValue
        }
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
            self[HTMLNodeID(key)] = oldValues[slot]
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
            self[HTMLNodeID(displacedKey)] = displacedValue
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
