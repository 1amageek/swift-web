import SwiftHTML

package enum SwiftWebWasmClientManifestBuilder {
    package static func manifest(
        from artifact: RenderArtifact,
        runtime: SwiftWebWasmClientRuntime
    ) -> ClientBundleManifest {
        let bundleID = runtime.runtimeBundleID
        let components = artifact.hydration.components.map { component in
            let additionalBundle = additionalBundle(
                for: component,
                in: runtime.additionalBundles
            )
            let componentBundleID = additionalBundle?.id
                ?? bundleID
            return ClientComponentAsset(
                componentID: component.id,
                typeName: component.typeName,
                bundleID: componentBundleID,
                loadPolicy: component.loadPolicy,
                entrySymbols: [ClientSymbolID(component.typeName)],
                serverSlots: component.serverSlots.map { $0.id },
                stateSchemaHash: component.stateSchemaHash,
                environmentSchemaHash: component.environmentSnapshot.schemaHash
            )
        }
        let componentIDsByBundleID = Dictionary(grouping: components, by: { $0.bundleID })
            .mapValues { records in
                records.map { $0.componentID }
            }
        let additionalBundleRecords = runtime.additionalBundles.map { bundle in
            ClientBundleRecord(
                id: bundle.id,
                kind: .component,
                asset: WasmAsset(path: bundle.assetPath),
                symbols: bundle.componentTypeNames.map { ClientSymbolID($0) },
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
            serverSlots: artifact.hydration.components.flatMap { $0.serverSlots }
        )
    }

    private static func additionalBundle(
        for component: HydrationComponentRecord,
        in bundles: [SwiftWebWasmClientBundle]
    ) -> SwiftWebWasmClientBundle? {
        bundles.first { bundle in
            if component.bundleID == bundle.id {
                return true
            }
            return bundle.componentTypeNames.contains { typeName in
                component.typeName == typeName
                    || component.typeName.hasSuffix(".\(typeName)")
                    || typeName.hasSuffix(".\(component.typeName)")
            }
        }
    }
}
