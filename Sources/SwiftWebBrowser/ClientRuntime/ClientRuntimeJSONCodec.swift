#if canImport(Foundation)
import Foundation
import SwiftHTML
import SwiftWebActors

/// Preserves the native Codable wire shape without executing cross-module
/// Codable witnesses, which trap in the pinned Swift 6.4 Standard WASM runtime.
/// JSON object materialization is intentionally confined to the exported WASM
/// input/output boundary where the host payload already requires owned storage.
enum ClientRuntimeJSONCodec {
    static func decodeBootstrapRequest(from data: Data) throws -> ClientRuntimeBootstrapRequest {
        let root = try object(try JSONSerialization.jsonObject(with: data), path: "$")
        return ClientRuntimeBootstrapRequest(
            hydrationIndex: try hydrationIndex(
                try required(root, "hydrationIndex", path: "$"),
                path: "$.hydrationIndex"
            ),
            documentNodeIDUpperBound: try optionalInt(
                root["documentNodeIDUpperBound"],
                path: "$.documentNodeIDUpperBound"
            ),
            location: try bootstrapLocation(
                try required(root, "location", path: "$"),
                path: "$.location"
            ),
            mode: try bootstrapMode(root["mode"], path: "$.mode"),
            stateSnapshot: try optionalStateSnapshot(
                root["stateSnapshot"],
                path: "$.stateSnapshot"
            ),
            actorBindings: try actorBindings(
                root["actorBindings"],
                path: "$.actorBindings"
            )
        )
    }

    static func decodeEventRequest(from data: Data) throws -> ClientRuntimeEventRequest {
        let root = try object(try JSONSerialization.jsonObject(with: data), path: "$")
        return ClientRuntimeEventRequest(
            handlerID: HandlerID(
                try rawString(
                    try required(root, "handlerID", path: "$"),
                    path: "$.handlerID"
                )
            ),
            event: try domEvent(
                try required(root, "event", path: "$"),
                path: "$.event"
            ),
            componentID: try optionalRawString(root["componentID"], path: "$.componentID")
                .map(ComponentID.init)
        )
    }

    static func decodeStateSnapshot(from data: Data) throws -> StateStoreSnapshot {
        try stateSnapshot(
            JSONSerialization.jsonObject(with: data),
            path: "$"
        )
    }

    static func encode(_ response: ClientRuntimeResponse) throws -> Data {
        var root: [String: Any] = [
            "appliesDOMCommandsInRuntime": response.appliesDOMCommandsInRuntime,
            "atomicStyleRules": response.atomicStyleRules.map {
                ["className": $0.className, "body": $0.body]
            },
        ]
        if let commandBatch = response.commandBatch {
            root["commandBatch"] = commandBatchObject(commandBatch)
        }
        if let hydrationIndex = response.hydrationIndex {
            root["hydrationIndex"] = hydrationIndexObject(hydrationIndex)
        }
        if let error = response.error {
            root["error"] = error
        }
        return try JSONSerialization.data(withJSONObject: root)
    }

    static func encode(_ snapshot: StateStoreSnapshot) throws -> Data {
        try JSONSerialization.data(withJSONObject: stateSnapshotObject(snapshot))
    }

    private static func hydrationIndex(_ value: Any, path: String) throws -> BrowserHydrationIndex {
        let value = try object(value, path: path)
        return BrowserHydrationIndex(
            rootID: HTMLNodeID(
                try rawInt(
                    try required(value, "rootID", path: path),
                    path: "\(path).rootID"
                )
            ),
            nodes: try array(
                try required(value, "nodes", path: path),
                path: "\(path).nodes"
            ).enumerated().map { index, value in
                try hydrationNode(value, path: "\(path).nodes[\(index)]")
            },
            components: try array(
                try required(value, "components", path: path),
                path: "\(path).components"
            ).enumerated().map { index, value in
                try hydrationComponent(value, path: "\(path).components[\(index)]")
            },
            serverSlots: try array(
                value["serverSlots"] ?? [],
                path: "\(path).serverSlots"
            ).enumerated().map { index, value in
                try serverSlot(value, path: "\(path).serverSlots[\(index)]")
            },
            handlers: try array(
                value["handlers"] ?? [],
                path: "\(path).handlers"
            ).enumerated().map { index, value in
                try eventBinding(value, path: "\(path).handlers[\(index)]")
            }
        )
    }

    private static func hydrationNode(_ value: Any, path: String) throws -> BrowserHydrationNodeRecord {
        let value = try object(value, path: path)
        guard
            let roleValue = try optionalString(value["role"], path: "\(path).role"),
            let role = BrowserHydrationNodeRole(rawValue: roleValue)
        else {
            throw ClientRuntimeJSONCodecError.invalidValue(
                path: "\(path).role",
                expected: "browser hydration node role"
            )
        }
        return BrowserHydrationNodeRecord(
            id: HTMLNodeID(
                try rawInt(
                    try required(value, "id", path: path),
                    path: "\(path).id"
                )
            ),
            parentID: try optionalRawInt(value["parentID"], path: "\(path).parentID")
                .map(HTMLNodeID.init),
            childIDs: try array(
                value["childIDs"] ?? [],
                path: "\(path).childIDs"
            ).enumerated().map { index, value in
                HTMLNodeID(try rawInt(value, path: "\(path).childIDs[\(index)]"))
            },
            role: role,
            name: try optionalString(value["name"], path: "\(path).name"),
            text: try optionalString(value["text"], path: "\(path).text"),
            componentID: try optionalRawString(
                value["componentID"],
                path: "\(path).componentID"
            ).map(ComponentID.init),
            serverSlotID: try optionalRawString(
                value["serverSlotID"],
                path: "\(path).serverSlotID"
            ).map { ServerSlotID($0) },
            attributes: try array(
                value["attributes"] ?? [],
                path: "\(path).attributes"
            ).enumerated().map { index, value in
                try attribute(value, path: "\(path).attributes[\(index)]")
            },
            eventBindings: try array(
                value["eventBindings"] ?? [],
                path: "\(path).eventBindings"
            ).enumerated().map { index, value in
                try eventBinding(value, path: "\(path).eventBindings[\(index)]")
            },
            key: try optionalKey(value["key"], path: "\(path).key"),
            fingerprint: NodeFingerprint(
                try rawUInt64(
                    try required(value, "fingerprint", path: path),
                    path: "\(path).fingerprint"
                )
            )
        )
    }

    private static func hydrationComponent(
        _ value: Any,
        path: String
    ) throws -> BrowserHydrationComponentRecord {
        let value = try object(value, path: path)
        guard
            let loadPolicyValue = try optionalString(
                value["loadPolicy"],
                path: "\(path).loadPolicy"
            ),
            let loadPolicy = ClientLoadPolicy(rawValue: loadPolicyValue)
        else {
            throw ClientRuntimeJSONCodecError.invalidValue(
                path: "\(path).loadPolicy",
                expected: "client load policy"
            )
        }
        return BrowserHydrationComponentRecord(
            id: ComponentID(
                try rawString(
                    try required(value, "id", path: path),
                    path: "\(path).id"
                )
            ),
            typeName: try string(
                try required(value, "typeName", path: path),
                path: "\(path).typeName"
            ),
            path: try string(
                try required(value, "path", path: path),
                path: "\(path).path"
            ),
            nodeID: HTMLNodeID(
                try rawInt(
                    try required(value, "nodeID", path: path),
                    path: "\(path).nodeID"
                )
            ),
            bundleID: try optionalRawString(
                value["bundleID"],
                path: "\(path).bundleID"
            ).map { ClientBundleID($0) },
            loadPolicy: loadPolicy,
            serverSlotIDs: try array(
                value["serverSlotIDs"] ?? [],
                path: "\(path).serverSlotIDs"
            ).enumerated().map { index, value in
                ServerSlotID(
                    try rawString(value, path: "\(path).serverSlotIDs[\(index)]")
                )
            },
            stateSlots: try array(
                value["stateSlots"] ?? [],
                path: "\(path).stateSlots"
            ).enumerated().map { index, value in
                try stateSlot(value, path: "\(path).stateSlots[\(index)]")
            },
            environmentSnapshot: try environmentSnapshot(
                value["environmentSnapshot"] ?? ["values": []],
                path: "\(path).environmentSnapshot"
            )
        )
    }

    private static func serverSlot(_ value: Any, path: String) throws -> ServerSlotRecord {
        let value = try object(value, path: path)
        return ServerSlotRecord(
            id: ServerSlotID(
                try rawString(
                    try required(value, "id", path: path),
                    path: "\(path).id"
                )
            ),
            ownerComponentID: ComponentID(
                try rawString(
                    try required(value, "ownerComponentID", path: path),
                    path: "\(path).ownerComponentID"
                )
            ),
            componentType: try string(
                try required(value, "componentType", path: path),
                path: "\(path).componentType"
            ),
            path: try string(
                try required(value, "path", path: path),
                path: "\(path).path"
            ),
            nodeID: HTMLNodeID(
                try rawInt(
                    try required(value, "nodeID", path: path),
                    path: "\(path).nodeID"
                )
            )
        )
    }

    private static func eventBinding(
        _ value: Any,
        path: String
    ) throws -> BrowserHydrationEventBinding {
        let value = try object(value, path: path)
        return BrowserHydrationEventBinding(
            nodeID: HTMLNodeID(
                try rawInt(
                    try required(value, "nodeID", path: path),
                    path: "\(path).nodeID"
                )
            ),
            handlerID: HandlerID(
                try rawString(
                    try required(value, "handlerID", path: path),
                    path: "\(path).handlerID"
                )
            ),
            eventName: try string(
                try required(value, "eventName", path: path),
                path: "\(path).eventName"
            ),
            componentID: try optionalRawString(
                value["componentID"],
                path: "\(path).componentID"
            ).map(ComponentID.init)
        )
    }

    private static func attribute(_ value: Any, path: String) throws -> HTMLAttributeRecord {
        let value = try object(value, path: path)
        return HTMLAttributeRecord(
            name: try string(
                try required(value, "name", path: path),
                path: "\(path).name"
            ),
            value: try optionalString(value["value"], path: "\(path).value"),
            kind: try attributeKind(
                try required(value, "kind", path: path),
                path: "\(path).kind"
            ),
            handlerID: try optionalRawString(
                value["handlerID"],
                path: "\(path).handlerID"
            ).map(HandlerID.init),
            eventName: try optionalString(value["eventName"], path: "\(path).eventName")
        )
    }

    private static func attributeKind(_ value: Any, path: String) throws -> HTMLAttributeKind {
        let name: String
        if let string = value as? String {
            name = string
        } else {
            let value = try object(value, path: path)
            guard let first = value.keys.first else {
                throw ClientRuntimeJSONCodecError.invalidValue(
                    path: path,
                    expected: "HTML attribute kind"
                )
            }
            name = first
        }
        switch name {
        case "string": return .string
        case "boolean": return .boolean
        case "tokenList": return .tokenList
        case "url": return .url
        case "urlList": return .urlList
        case "propertyBinding": return .propertyBinding
        case "eventBinding": return .eventBinding
        case "raw": return .raw
        default:
            throw ClientRuntimeJSONCodecError.unsupportedValue(path: path, value: name)
        }
    }

    private static func optionalKey(_ value: Any?, path: String) throws -> Key? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        let objectValue = try object(value, path: path)
        return Key(
            rawValue: try string(
                try required(objectValue, "rawValue", path: path),
                path: "\(path).rawValue"
            ),
            identity: try string(
                try required(objectValue, "identity", path: path),
                path: "\(path).identity"
            )
        )
    }

    private static func stateSlot(_ value: Any, path: String) throws -> StateSlotRecord {
        let value = try object(value, path: path)
        let sourceValue = try object(
            try required(value, "source", path: path),
            path: "\(path).source"
        )
        return StateSlotRecord(
            id: StateSlotID(
                try rawString(
                    try required(value, "id", path: path),
                    path: "\(path).id"
                )
            ),
            componentID: ComponentID(
                try rawString(
                    try required(value, "componentID", path: path),
                    path: "\(path).componentID"
                )
            ),
            valueType: try string(
                try required(value, "valueType", path: path),
                path: "\(path).valueType"
            ),
            source: StateSourceLocation(
                fileID: try string(
                    try required(sourceValue, "fileID", path: "\(path).source"),
                    path: "\(path).source.fileID"
                ),
                line: UInt(
                    try int(
                        try required(sourceValue, "line", path: "\(path).source"),
                        path: "\(path).source.line"
                    )
                ),
                column: UInt(
                    try int(
                        try required(sourceValue, "column", path: "\(path).source"),
                        path: "\(path).source.column"
                    )
                )
            )
        )
    }

    private static func environmentSnapshot(
        _ value: Any,
        path: String
    ) throws -> ClientEnvironmentSnapshot {
        let value = try object(value, path: path)
        return ClientEnvironmentSnapshot(
            values: try array(
                value["values"] ?? [],
                path: "\(path).values"
            ).enumerated().map { index, value in
                let itemPath = "\(path).values[\(index)]"
                let value = try object(value, path: itemPath)
                return ClientEnvironmentSnapshotValue(
                    key: try string(
                        try required(value, "key", path: itemPath),
                        path: "\(itemPath).key"
                    ),
                    valueType: try string(
                        try required(value, "valueType", path: itemPath),
                        path: "\(itemPath).valueType"
                    ),
                    encoding: try string(
                        try required(value, "encoding", path: itemPath),
                        path: "\(itemPath).encoding"
                    ),
                    encodedValue: try string(
                        try required(value, "encodedValue", path: itemPath),
                        path: "\(itemPath).encodedValue"
                    )
                )
            }
        )
    }

    private static func bootstrapLocation(
        _ value: Any,
        path: String
    ) throws -> ClientRuntimeBootstrapLocation {
        let value = try object(value, path: path)
        return ClientRuntimeBootstrapLocation(
            href: try string(
                try required(value, "href", path: path),
                path: "\(path).href"
            ),
            search: try string(
                try required(value, "search", path: path),
                path: "\(path).search"
            )
        )
    }

    private static func bootstrapMode(
        _ value: Any?,
        path: String
    ) throws -> ClientRuntimeBootstrapMode? {
        guard let rawValue = try optionalString(value, path: path) else {
            return nil
        }
        guard let mode = ClientRuntimeBootstrapMode(rawValue: rawValue) else {
            throw ClientRuntimeJSONCodecError.unsupportedValue(path: path, value: rawValue)
        }
        return mode
    }

    private static func actorBindings(
        _ value: Any?,
        path: String
    ) throws -> [SwiftWebActorBindingRecord] {
        try array(value ?? [], path: path).enumerated().map { index, value in
            let itemPath = "\(path)[\(index)]"
            let value = try object(value, path: itemPath)
            return SwiftWebActorBindingRecord(
                contractKey: try string(
                    try required(value, "contractKey", path: itemPath),
                    path: "\(itemPath).contractKey"
                ),
                actorID: try string(
                    try required(value, "actorID", path: itemPath),
                    path: "\(itemPath).actorID"
                )
            )
        }
    }

    private static func optionalStateSnapshot(
        _ value: Any?,
        path: String
    ) throws -> StateStoreSnapshot? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        return try stateSnapshot(value, path: path)
    }

    private static func stateSnapshot(_ value: Any, path: String) throws -> StateStoreSnapshot {
        let value = try object(value, path: path)
        let valuesObject = try object(
            try required(value, "values", path: path),
            path: "\(path).values"
        )
        var values: [String: StateSnapshotValue] = [:]
        values.reserveCapacity(valuesObject.count)
        for (key, rawValue) in valuesObject {
            let itemPath = "\(path).values.\(key)"
            let rawValue = try object(rawValue, path: itemPath)
            values[key] = StateSnapshotValue(
                valueType: try string(
                    try required(rawValue, "valueType", path: itemPath),
                    path: "\(itemPath).valueType"
                ),
                encoding: try string(
                    try required(rawValue, "encoding", path: itemPath),
                    path: "\(itemPath).encoding"
                ),
                encodedValue: try string(
                    try required(rawValue, "encodedValue", path: itemPath),
                    path: "\(itemPath).encodedValue"
                )
            )
        }
        return StateStoreSnapshot(
            schemaHash: try string(
                try required(value, "schemaHash", path: path),
                path: "\(path).schemaHash"
            ),
            values: values
        )
    }

    private static func domEvent(_ value: Any, path: String) throws -> DOMEvent {
        let value = try object(value, path: path)
        var metadata: [String: String] = [:]
        if let rawMetadata = value["metadata"], !(rawMetadata is NSNull) {
            let metadataObject = try object(rawMetadata, path: "\(path).metadata")
            metadata.reserveCapacity(metadataObject.count)
            for (key, value) in metadataObject {
                metadata[key] = try string(value, path: "\(path).metadata.\(key)")
            }
        }
        return DOMEvent(
            value: try optionalString(value["value"], path: "\(path).value"),
            checked: try optionalBool(value["checked"], path: "\(path).checked"),
            key: try optionalString(value["key"], path: "\(path).key"),
            code: try optionalString(value["code"], path: "\(path).code"),
            inputType: try optionalString(value["inputType"], path: "\(path).inputType"),
            clientX: try optionalDouble(value["clientX"], path: "\(path).clientX"),
            clientY: try optionalDouble(value["clientY"], path: "\(path).clientY"),
            metadata: metadata
        )
    }

    private static func commandBatchObject(_ batch: BrowserDOMCommandBatch) -> [String: Any] {
        ["commands": batch.commands.map(commandObject)]
    }

    private static func commandObject(_ command: BrowserDOMCommand) -> [String: Any] {
        switch command {
        case .replaceNode(let node, let replacement):
            ["replaceNode": ["node": nodeObject(node), "replacement": nodeObject(replacement)]]
        case .replaceSubtree(let node, let html):
            ["replaceSubtree": ["node": nodeObject(node), "html": html]]
        case .updateText(let node, let value):
            ["updateText": ["node": nodeObject(node), "value": value]]
        case .updateComment(let node, let value):
            ["updateComment": ["node": nodeObject(node), "value": value]]
        case .updateAttributes(let node, let attributes):
            [
                "updateAttributes": [
                    "node": nodeObject(node),
                    "attributes": attributes.map(attributeObject),
                ],
            ]
        case .setProperty(let node, let name, let value):
            [
                "setProperty": [
                    "node": nodeObject(node),
                    "name": name,
                    "value": (value ?? NSNull()) as Any,
                ],
            ]
        case .insertNode(let parent, let index, let node):
            [
                "insertNode": [
                    "parent": nodeObject(parent),
                    "index": index,
                    "node": nodeObject(node),
                ],
            ]
        case .insertHTML(let parent, let index, let html):
            ["insertHTML": ["parent": nodeObject(parent), "index": index, "html": html]]
        case .remove(let parent, let index, let node):
            [
                "remove": [
                    "parent": nodeObject(parent),
                    "index": index,
                    "node": nodeObject(node),
                ],
            ]
        case .move(let parent, let from, let to, let key):
            [
                "move": [
                    "parent": nodeObject(parent),
                    "from": from,
                    "to": to,
                    "key": keyObject(key),
                ],
            ]
        case .moveKeyed(let parent, let key, let to):
            ["moveKeyed": ["parent": nodeObject(parent), "key": keyObject(key), "to": to]]
        }
    }

    private static func hydrationIndexObject(_ index: BrowserHydrationIndex) -> [String: Any] {
        [
            "rootID": nodeObject(index.rootID),
            "nodes": index.nodes.map(hydrationNodeObject),
            "components": index.components.map(hydrationComponentObject),
            "serverSlots": index.serverSlots.map(serverSlotObject),
            "handlers": index.handlers.map(eventBindingObject),
        ]
    }

    private static func hydrationNodeObject(_ node: BrowserHydrationNodeRecord) -> [String: Any] {
        var value: [String: Any] = [
            "id": nodeObject(node.id),
            "childIDs": node.childIDs.map(nodeObject),
            "role": node.role.rawValue,
            "attributes": node.attributes.map(attributeObject),
            "eventBindings": node.eventBindings.map(eventBindingObject),
            "fingerprint": ["rawValue": node.fingerprint.rawValue],
        ]
        if let parentID = node.parentID {
            value["parentID"] = nodeObject(parentID)
        }
        if let name = node.name {
            value["name"] = name
        }
        if let text = node.text {
            value["text"] = text
        }
        if let componentID = node.componentID {
            value["componentID"] = componentObject(componentID)
        }
        if let serverSlotID = node.serverSlotID {
            value["serverSlotID"] = serverSlotID.rawValue
        }
        if let key = node.key {
            value["key"] = keyObject(key)
        }
        return value
    }

    private static func hydrationComponentObject(
        _ component: BrowserHydrationComponentRecord
    ) -> [String: Any] {
        var value: [String: Any] = [
            "id": componentObject(component.id),
            "typeName": component.typeName,
            "path": component.path,
            "nodeID": nodeObject(component.nodeID),
            "loadPolicy": component.loadPolicy.rawValue,
            "serverSlotIDs": component.serverSlotIDs.map { $0.rawValue },
            "stateSlots": component.stateSlots.map(stateSlotObject),
            "environmentSnapshot": environmentSnapshotObject(component.environmentSnapshot),
        ]
        if let bundleID = component.bundleID {
            value["bundleID"] = bundleID.rawValue
        }
        return value
    }

    private static func serverSlotObject(_ slot: ServerSlotRecord) -> [String: Any] {
        [
            "id": slot.id.rawValue,
            "ownerComponentID": componentObject(slot.ownerComponentID),
            "componentType": slot.componentType,
            "path": slot.path,
            "nodeID": nodeObject(slot.nodeID),
        ]
    }

    private static func eventBindingObject(
        _ binding: BrowserHydrationEventBinding
    ) -> [String: Any] {
        var value: [String: Any] = [
            "nodeID": nodeObject(binding.nodeID),
            "handlerID": handlerObject(binding.handlerID),
            "eventName": binding.eventName,
        ]
        if let componentID = binding.componentID {
            value["componentID"] = componentObject(componentID)
        }
        return value
    }

    private static func attributeObject(_ attribute: HTMLAttributeRecord) -> [String: Any] {
        var value: [String: Any] = [
            "name": attribute.name,
            "kind": [attributeKindName(attribute.kind): [:] as [String: Any]],
        ]
        if let attributeValue = attribute.value {
            value["value"] = attributeValue
        }
        if let handlerID = attribute.handlerID {
            value["handlerID"] = handlerObject(handlerID)
        }
        if let eventName = attribute.eventName {
            value["eventName"] = eventName
        }
        return value
    }

    private static func attributeKindName(_ kind: HTMLAttributeKind) -> String {
        switch kind {
        case .string: "string"
        case .boolean: "boolean"
        case .tokenList: "tokenList"
        case .url: "url"
        case .urlList: "urlList"
        case .propertyBinding: "propertyBinding"
        case .eventBinding: "eventBinding"
        case .raw: "raw"
        }
    }

    private static func stateSlotObject(_ slot: StateSlotRecord) -> [String: Any] {
        [
            "id": ["rawValue": slot.id.rawValue],
            "componentID": componentObject(slot.componentID),
            "valueType": slot.valueType,
            "source": [
                "fileID": slot.source.fileID,
                "line": Int(slot.source.line),
                "column": Int(slot.source.column),
            ],
        ]
    }

    private static func environmentSnapshotObject(
        _ snapshot: ClientEnvironmentSnapshot
    ) -> [String: Any] {
        [
            "values": snapshot.values.map { value in
                [
                    "key": value.key,
                    "valueType": value.valueType,
                    "encoding": value.encoding,
                    "encodedValue": value.encodedValue,
                ]
            },
        ]
    }

    private static func stateSnapshotObject(_ snapshot: StateStoreSnapshot) -> [String: Any] {
        var values: [String: Any] = [:]
        values.reserveCapacity(snapshot.values.count)
        for (key, value) in snapshot.values {
            values[key] = [
                "valueType": value.valueType,
                "encoding": value.encoding,
                "encodedValue": value.encodedValue,
            ]
        }
        return [
            "schemaHash": snapshot.schemaHash,
            "values": values,
        ]
    }

    private static func nodeObject(_ id: HTMLNodeID) -> [String: Any] {
        ["rawValue": id.rawValue]
    }

    private static func componentObject(_ id: ComponentID) -> [String: Any] {
        ["rawValue": id.rawValue]
    }

    private static func handlerObject(_ id: HandlerID) -> [String: Any] {
        ["rawValue": id.rawValue]
    }

    private static func keyObject(_ key: Key) -> [String: Any] {
        ["rawValue": key.rawValue, "identity": key.identity]
    }

    private static func required(
        _ object: [String: Any],
        _ key: String,
        path: String
    ) throws -> Any {
        guard let value = object[key], !(value is NSNull) else {
            throw ClientRuntimeJSONCodecError.invalidValue(
                path: "\(path).\(key)",
                expected: "value"
            )
        }
        return value
    }

    private static func object(_ value: Any, path: String) throws -> [String: Any] {
        guard let value = value as? [String: Any] else {
            throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "object")
        }
        return value
    }

    private static func array(_ value: Any, path: String) throws -> [Any] {
        guard let value = value as? [Any] else {
            throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "array")
        }
        return value
    }

    private static func string(_ value: Any, path: String) throws -> String {
        guard let value = value as? String else {
            throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "string")
        }
        return value
    }

    private static func optionalString(_ value: Any?, path: String) throws -> String? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        return try string(value, path: path)
    }

    private static func int(_ value: Any, path: String) throws -> Int {
        if let number = value as? NSNumber,
           !isJSONBoolean(number),
           let integer = Int(number.stringValue)
        {
            return integer
        }
        throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "integer")
    }

    private static func optionalInt(_ value: Any?, path: String) throws -> Int? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        return try int(value, path: path)
    }

    private static func uint64(_ value: Any, path: String) throws -> UInt64 {
        if let number = value as? NSNumber,
           !isJSONBoolean(number),
           let integer = UInt64(number.stringValue)
        {
            return integer
        }
        throw ClientRuntimeJSONCodecError.invalidValue(
            path: path,
            expected: "unsigned integer"
        )
    }

    private static func optionalBool(_ value: Any?, path: String) throws -> Bool? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        if let number = value as? NSNumber, isJSONBoolean(number) {
            return number.boolValue
        }
        throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "boolean")
    }

    private static func optionalDouble(_ value: Any?, path: String) throws -> Double? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        if let number = value as? NSNumber,
           !isJSONBoolean(number),
           let number = Double(number.stringValue),
           number.isFinite
        {
            return number
        }
        throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "number")
    }

    private static func isJSONBoolean(_ value: NSNumber) -> Bool {
        String(cString: value.objCType) == "c"
    }

    private static func rawString(_ value: Any, path: String) throws -> String {
        if let value = value as? String {
            return value
        }
        let value = try object(value, path: path)
        return try string(
            try required(value, "rawValue", path: path),
            path: "\(path).rawValue"
        )
    }

    private static func optionalRawString(_ value: Any?, path: String) throws -> String? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        return try rawString(value, path: path)
    }

    private static func rawInt(_ value: Any, path: String) throws -> Int {
        if value is NSNumber || value is Int {
            return try int(value, path: path)
        }
        let value = try object(value, path: path)
        return try int(
            try required(value, "rawValue", path: path),
            path: "\(path).rawValue"
        )
    }

    private static func optionalRawInt(_ value: Any?, path: String) throws -> Int? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        return try rawInt(value, path: path)
    }

    private static func rawUInt64(_ value: Any, path: String) throws -> UInt64 {
        if value is NSNumber || value is UInt64 {
            return try uint64(value, path: path)
        }
        let value = try object(value, path: path)
        return try uint64(
            try required(value, "rawValue", path: path),
            path: "\(path).rawValue"
        )
    }
}
#endif
