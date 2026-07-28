import SwiftHTML

struct HandlerRuntimeMap: Sendable {
    private struct Entry: Sendable {
        let handlerID: HandlerID
        let componentID: ComponentID?
        let runtimeIndex: Int
    }

    private var entries: [Entry] = []

    mutating func appendUnsorted(
        _ runtimeIndex: Int,
        for handlerID: HandlerID,
        componentID: ComponentID?
    ) {
        entries.append(Entry(
            handlerID: handlerID,
            componentID: componentID,
            runtimeIndex: runtimeIndex
        ))
    }

    mutating func prepareForLookup() {
        entries.sort { left, right in
            if left.handlerID.rawValue != right.handlerID.rawValue {
                return left.handlerID.rawValue < right.handlerID.rawValue
            }
            return (left.componentID?.rawValue ?? "") < (right.componentID?.rawValue ?? "")
        }
    }

    func runtimeIndex(
        for handlerID: HandlerID,
        componentID: ComponentID?
    ) -> Int? {
        guard let componentID else {
            return uniqueRuntimeIndex(for: handlerID)
        }
        let lowerBound = firstIndex(for: handlerID)
        var index = lowerBound
        while index < entries.count, entries[index].handlerID == handlerID {
            if entries[index].componentID == componentID {
                return entries[index].runtimeIndex
            }
            index += 1
        }
        return nil
    }

    private func uniqueRuntimeIndex(for handlerID: HandlerID) -> Int? {
        let lowerBound = firstIndex(for: handlerID)
        guard lowerBound < entries.count, entries[lowerBound].handlerID == handlerID else {
            return nil
        }
        let runtimeIndex = entries[lowerBound].runtimeIndex
        var index = lowerBound + 1
        while index < entries.count, entries[index].handlerID == handlerID {
            guard entries[index].runtimeIndex == runtimeIndex else {
                return nil
            }
            index += 1
        }
        return runtimeIndex
    }

    private func firstIndex(for handlerID: HandlerID) -> Int {
        var lowerBound = 0
        var upperBound = entries.count
        while lowerBound < upperBound {
            let midpoint = lowerBound + (upperBound - lowerBound) / 2
            if entries[midpoint].handlerID.rawValue < handlerID.rawValue {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }
        return lowerBound
    }
}
