import SwiftHTML

enum SwiftWebWasmClientManifestBuilder {
    static func manifest(
        from artifact: RenderArtifact,
        runtime: SwiftWebWasmClientRuntime
    ) -> ClientBundleManifest {
        let bundleID = runtime.runtimeBundleID
        let additionalBundlesByTypeName = Dictionary(
            uniqueKeysWithValues: runtime.additionalBundles.map { ($0.componentTypeName, $0) }
        )
        let components = artifact.hydration.components.map { component in
            let componentBundleID = additionalBundlesByTypeName[component.typeName]?.id
                ?? component.bundleID
                ?? bundleID
            return ClientComponentAsset(
                componentID: component.id,
                typeName: component.typeName,
                bundleID: componentBundleID,
                loadPolicy: component.loadPolicy,
                entrySymbols: [ClientSymbolID(component.typeName)],
                serverSlots: component.serverSlots.map(\.id)
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
}
