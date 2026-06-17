import SwiftHTML

enum SwiftWebWasmClientManifestBuilder {
    static func manifest(
        from artifact: RenderArtifact,
        runtime: SwiftWebWasmClientRuntime
    ) -> ClientBundleManifest {
        let bundleID = runtime.runtimeBundleID
        let components = artifact.hydration.components.map { component in
            let additionalBundle = additionalBundle(
                for: component.typeName,
                in: runtime.additionalBundles
            )
            let componentBundleID = additionalBundle?.id
                ?? component.bundleID
                ?? bundleID
            return ClientComponentAsset(
                componentID: component.id,
                typeName: component.typeName,
                bundleID: componentBundleID,
                loadPolicy: component.loadPolicy,
                entrySymbols: [ClientSymbolID(component.typeName)],
                serverSlots: component.serverSlots.map(\.id),
                stateSchemaHash: component.stateSchemaHash,
                environmentSchemaHash: component.environmentSnapshot.schemaHash
            )
        }
        let componentIDsByBundleID = Dictionary(grouping: components, by: \.bundleID)
            .mapValues { records in
                records.map(\.componentID)
            }
        let additionalBundleRecords = runtime.additionalBundles.map { bundle in
            ClientBundleRecord(
                id: bundle.id,
                kind: .component,
                asset: WasmAsset(path: bundle.assetPath),
                symbols: [ClientSymbolID(bundle.componentTypeName)],
                components: componentIDsByBundleID[bundle.id] ?? [],
                loadPolicy: components.first(where: { $0.bundleID == bundle.id })?.loadPolicy ?? .eager
            )
        }

        return ClientBundleManifest(
            runtimeBundleID: bundleID,
            bundles: [
                ClientBundleRecord(
                    id: bundleID,
                    kind: .runtime,
                    asset: WasmAsset(path: runtime.runtimeAssetPath),
                    symbols: [ClientSymbolID("\(bundleID.rawValue).runtime")],
                    components: componentIDsByBundleID[bundleID] ?? [],
                    loadPolicy: .eager
                ),
            ] + additionalBundleRecords,
            components: components,
            serverSlots: artifact.hydration.components.flatMap(\.serverSlots)
        )
    }

    private static func additionalBundle(
        for typeName: String,
        in bundles: [SwiftWebWasmClientBundle]
    ) -> SwiftWebWasmClientBundle? {
        bundles.first { bundle in
            typeName == bundle.componentTypeName
                || typeName.hasSuffix(".\(bundle.componentTypeName)")
                || bundle.componentTypeName.hasSuffix(".\(typeName)")
        }
    }
}
