import SwiftHTML

struct ServerSlotIDMap: Sendable {
    private struct Entry: Sendable {
        let source: ServerSlotID
        let target: ServerSlotID
    }

    private var entries: [Entry] = []

    mutating func appendUnsorted(_ target: ServerSlotID, for source: ServerSlotID) {
        entries.append(Entry(source: source, target: target))
    }

    mutating func prepareForLookup() {
        entries.sort { $0.source.rawValue < $1.source.rawValue }
    }

    subscript(_ source: ServerSlotID) -> ServerSlotID? {
        var lowerBound = 0
        var upperBound = entries.count
        while lowerBound < upperBound {
            let midpoint = lowerBound + (upperBound - lowerBound) / 2
            if entries[midpoint].source.rawValue < source.rawValue {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }
        guard lowerBound < entries.count, entries[lowerBound].source == source else {
            return nil
        }
        return entries[lowerBound].target
    }

    func forEach(_ body: (ServerSlotID, ServerSlotID) -> Void) {
        for entry in entries {
            body(entry.source, entry.target)
        }
    }
}
