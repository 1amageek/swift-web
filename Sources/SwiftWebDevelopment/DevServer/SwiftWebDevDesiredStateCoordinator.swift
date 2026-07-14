import Foundation
import SwiftWebPackageGeneration

/// Serializes generated-package materialization and Client WASM preparation
/// for a source fingerprint. A fingerprint becomes ready only after every
/// runtime artifact required by that generated package has been built.
package actor SwiftWebDevDesiredStateCoordinator {
    package typealias PackagePreparation = @Sendable () throws -> SwiftWebGeneratedPackage
    package typealias ClientRuntimePreparation = @Sendable (
        SwiftWebGeneratedPackage,
        [String]
    ) throws -> Void

    private let preparePackage: PackagePreparation
    private let prepareClientRuntimes: ClientRuntimePreparation
    private var currentPackage: SwiftWebGeneratedPackage
    private var readyFingerprint: SwiftWebDevSourceFingerprint?

    package init(
        currentPackage: SwiftWebGeneratedPackage,
        readyFingerprint: SwiftWebDevSourceFingerprint? = nil,
        preparePackage: @escaping PackagePreparation,
        prepareClientRuntimes: @escaping ClientRuntimePreparation
    ) {
        self.currentPackage = currentPackage
        self.readyFingerprint = readyFingerprint
        self.preparePackage = preparePackage
        self.prepareClientRuntimes = prepareClientRuntimes
    }

    package func prepare(
        for fingerprint: SwiftWebDevSourceFingerprint,
        changedPaths: [String] = []
    ) throws -> SwiftWebGeneratedPackage {
        guard fingerprint != readyFingerprint else {
            return currentPackage
        }

        let refreshedPackage = try preparePackage()
        try prepareClientRuntimes(refreshedPackage, changedPaths)
        currentPackage = refreshedPackage
        readyFingerprint = fingerprint
        return refreshedPackage
    }
}
