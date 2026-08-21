import Foundation

final class GeneratedPackageMaterializationTransaction {
  enum RecoveryPhase: String, Codable {
    case prepared
    case installed
  }

  struct RecoveryJournal: Codable {
    let version: Int
    var phase: RecoveryPhase
    let hadGeneratedPackage: Bool
    let hadNativeSources: Bool
    let generatedPackageDirectory: String
    let nativeGeneratedSourceDirectory: String
    let stagingGeneratedPackageDirectory: String
    let stagingNativeSourceDirectory: String
    let generatedPackageBackupDirectory: String
    let nativeGeneratedSourceBackupDirectory: String
  }

  let stagingGeneratedPackageDirectory: URL
  let stagingNativeSourceDirectory: URL
  let generatedPackageBackupDirectory: URL
  let nativeGeneratedSourceBackupDirectory: URL
  let recoveryJournalURL: URL

  private let generatedPackageDirectory: URL
  private let nativeGeneratedSourceDirectory: URL
  private let beforeGeneratedRootCommit: () throws -> Void
  private var rollbackFailed = false

  init(
    generatedPackageDirectory: URL,
    nativeSourceDirectory: URL,
    beforeGeneratedRootCommit: @escaping () throws -> Void = {}
  ) {
    let identifier = UUID().uuidString
    let generatedParent = generatedPackageDirectory.deletingLastPathComponent()
    let nativeParent = nativeSourceDirectory
    self.generatedPackageDirectory = generatedPackageDirectory.standardizedFileURL
    self.nativeGeneratedSourceDirectory = nativeSourceDirectory.appendingPathComponent(
      "ActorSystemGenerated",
      isDirectory: true
    ).standardizedFileURL
    self.stagingGeneratedPackageDirectory = generatedParent.appendingPathComponent(
      ".\(generatedPackageDirectory.lastPathComponent).staging-\(identifier)",
      isDirectory: true
    ).standardizedFileURL
    self.stagingNativeSourceDirectory = nativeParent.appendingPathComponent(
      ".swiftweb-native-staging-\(identifier)",
      isDirectory: true
    ).standardizedFileURL
    self.generatedPackageBackupDirectory = generatedParent.appendingPathComponent(
      ".\(generatedPackageDirectory.lastPathComponent).backup-\(identifier)",
      isDirectory: true
    ).standardizedFileURL
    self.nativeGeneratedSourceBackupDirectory = nativeParent.appendingPathComponent(
      ".ActorSystemGenerated.backup-\(identifier)",
      isDirectory: true
    ).standardizedFileURL
    self.recoveryJournalURL = generatedParent.appendingPathComponent(
      ".swiftweb-materialization-transaction.json",
      isDirectory: false
    ).standardizedFileURL
    self.beforeGeneratedRootCommit = beforeGeneratedRootCommit
  }

  func prepare() throws {
    try recoverInterruptedTransaction()
    try FileManager.default.createDirectory(
      at: stagingGeneratedPackageDirectory,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: stagingNativeSourceDirectory,
      withIntermediateDirectories: true
    )
    if FileManager.default.fileExists(atPath: generatedPackageDirectory.path) {
      try seedDirectoryContents(
        from: generatedPackageDirectory,
        to: stagingGeneratedPackageDirectory
      )
    }
    if FileManager.default.fileExists(atPath: nativeGeneratedSourceDirectory.path) {
      let stagedNativeGeneratedSourceDirectory = stagingNativeSourceDirectory
        .appendingPathComponent("ActorSystemGenerated", isDirectory: true)
      try FileManager.default.createDirectory(
        at: stagedNativeGeneratedSourceDirectory,
        withIntermediateDirectories: true
      )
      try seedDirectoryContents(
        from: nativeGeneratedSourceDirectory,
        to: stagedNativeGeneratedSourceDirectory
      )
    }
  }

  func commit() throws {
    let fileManager = FileManager.default
    let stagedNativeGeneratedSourceDirectory = stagingNativeSourceDirectory
      .appendingPathComponent("ActorSystemGenerated", isDirectory: true)
    var journal = RecoveryJournal(
      version: 1,
      phase: .prepared,
      hadGeneratedPackage: fileManager.fileExists(atPath: generatedPackageDirectory.path),
      hadNativeSources: fileManager.fileExists(atPath: nativeGeneratedSourceDirectory.path),
      generatedPackageDirectory: generatedPackageDirectory.path,
      nativeGeneratedSourceDirectory: nativeGeneratedSourceDirectory.path,
      stagingGeneratedPackageDirectory: stagingGeneratedPackageDirectory.path,
      stagingNativeSourceDirectory: stagingNativeSourceDirectory.path,
      generatedPackageBackupDirectory: generatedPackageBackupDirectory.path,
      nativeGeneratedSourceBackupDirectory: nativeGeneratedSourceBackupDirectory.path
    )
    try writeJournal(journal)

    do {
      if journal.hadGeneratedPackage {
        try fileManager.moveItem(
          at: generatedPackageDirectory,
          to: generatedPackageBackupDirectory
        )
      }
      if journal.hadNativeSources {
        try fileManager.moveItem(
          at: nativeGeneratedSourceDirectory,
          to: nativeGeneratedSourceBackupDirectory
        )
      }
      if fileManager.fileExists(atPath: stagedNativeGeneratedSourceDirectory.path) {
        try fileManager.moveItem(
          at: stagedNativeGeneratedSourceDirectory,
          to: nativeGeneratedSourceDirectory
        )
      }
      try beforeGeneratedRootCommit()
      try fileManager.moveItem(
        at: stagingGeneratedPackageDirectory,
        to: generatedPackageDirectory
      )
      journal.phase = .installed
      try writeJournal(journal)
    } catch {
      let originalError = error
      do {
        try rollbackPreparedTransaction(journal)
      } catch {
        rollbackFailed = true
        throw SwiftWebGeneratedPackageMaterializerError.materializationRollbackFailed(
          original: String(describing: originalError),
          rollback: String(describing: error)
        )
      }
      throw originalError
    }

    do {
      try transferReusablePackageState(
        from: generatedPackageBackupDirectory,
        to: generatedPackageDirectory
      )
      try finalizeInstalledTransaction(journal)
    } catch {
      throw SwiftWebGeneratedPackageMaterializerError.materializationCleanupFailed(
        stagingGeneratedPackageDirectory,
        String(describing: error)
      )
    }
  }

  func discardPreparedArtifacts() throws {
    guard !rollbackFailed else {
      return
    }
    let fileWriter = GeneratedPackageFileWriter()
    for directory in [
      stagingGeneratedPackageDirectory,
      stagingNativeSourceDirectory,
      generatedPackageBackupDirectory,
      nativeGeneratedSourceBackupDirectory,
    ] where FileManager.default.fileExists(atPath: directory.path) {
      try fileWriter.removeGeneratedItem(at: directory)
    }
  }

  private func recoverInterruptedTransaction() throws {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: recoveryJournalURL.path) else {
      return
    }
    do {
      let journal = try JSONDecoder().decode(
        RecoveryJournal.self,
        from: Data(contentsOf: recoveryJournalURL)
      )
      try validate(journal)
      switch journal.phase {
      case .prepared:
        try rollbackPreparedTransaction(journal)
      case .installed:
        try finalizeInstalledTransaction(journal)
      }
    } catch {
      throw SwiftWebGeneratedPackageMaterializerError.materializationRecoveryFailed(
        recoveryJournalURL,
        String(describing: error)
      )
    }
  }

  private func validate(_ journal: RecoveryJournal) throws {
    let generatedParent = generatedPackageDirectory.deletingLastPathComponent()
    let nativeParent = nativeGeneratedSourceDirectory.deletingLastPathComponent()
    let stagingGenerated = URL(
      fileURLWithPath: journal.stagingGeneratedPackageDirectory,
      isDirectory: true
    ).standardizedFileURL
    let stagingNative = URL(
      fileURLWithPath: journal.stagingNativeSourceDirectory,
      isDirectory: true
    ).standardizedFileURL
    let backupGenerated = URL(
      fileURLWithPath: journal.generatedPackageBackupDirectory,
      isDirectory: true
    ).standardizedFileURL
    let backupNative = URL(
      fileURLWithPath: journal.nativeGeneratedSourceBackupDirectory,
      isDirectory: true
    ).standardizedFileURL
    guard journal.version == 1,
      URL(
        fileURLWithPath: journal.generatedPackageDirectory,
        isDirectory: true
      ).standardizedFileURL
        == generatedPackageDirectory,
      URL(
        fileURLWithPath: journal.nativeGeneratedSourceDirectory,
        isDirectory: true
      ).standardizedFileURL
        == nativeGeneratedSourceDirectory,
      isOwnedTransactionPath(
        stagingGenerated,
        parent: generatedParent,
        prefix: ".\(generatedPackageDirectory.lastPathComponent).staging-"
      ),
      isOwnedTransactionPath(
        backupGenerated,
        parent: generatedParent,
        prefix: ".\(generatedPackageDirectory.lastPathComponent).backup-"
      ),
      isOwnedTransactionPath(
        stagingNative,
        parent: nativeParent,
        prefix: ".swiftweb-native-staging-"
      ),
      isOwnedTransactionPath(
        backupNative,
        parent: nativeParent,
        prefix: ".ActorSystemGenerated.backup-"
      )
    else {
      throw SwiftWebGeneratedPackageMaterializerError.materializationRecoveryFailed(
        recoveryJournalURL,
        "journal does not belong to the requested generated roots"
      )
    }
  }

  private func isOwnedTransactionPath(
    _ url: URL,
    parent: URL,
    prefix: String
  ) -> Bool {
    url.deletingLastPathComponent() == parent
      && url.lastPathComponent.hasPrefix(prefix)
      && url.lastPathComponent.count > prefix.count
  }

  private func writeJournal(_ journal: RecoveryJournal) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(journal).write(to: recoveryJournalURL, options: .atomic)
  }

  private func rollbackPreparedTransaction(_ journal: RecoveryJournal) throws {
    let fileManager = FileManager.default
    var failures: [String] = []

    func attempt(_ operation: String, _ body: () throws -> Void) {
      do {
        try body()
      } catch {
        failures.append("\(operation): \(error)")
      }
    }

    attempt("restore native generated sources") {
      try restoreOriginalRoot(
        live: URL(fileURLWithPath: journal.nativeGeneratedSourceDirectory),
        backup: URL(fileURLWithPath: journal.nativeGeneratedSourceBackupDirectory),
        hadOriginal: journal.hadNativeSources
      )
    }
    attempt("restore generated package") {
      try restoreOriginalRoot(
        live: URL(fileURLWithPath: journal.generatedPackageDirectory),
        backup: URL(fileURLWithPath: journal.generatedPackageBackupDirectory),
        hadOriginal: journal.hadGeneratedPackage
      )
    }

    guard failures.isEmpty else {
      throw SwiftWebGeneratedPackageMaterializerError.materializationRecoveryFailed(
        recoveryJournalURL,
        failures.joined(separator: "; ")
      )
    }

    for directory in [
      URL(fileURLWithPath: journal.stagingGeneratedPackageDirectory),
      URL(fileURLWithPath: journal.stagingNativeSourceDirectory),
      URL(fileURLWithPath: journal.generatedPackageBackupDirectory),
      URL(fileURLWithPath: journal.nativeGeneratedSourceBackupDirectory),
    ] where fileManager.fileExists(atPath: directory.path) {
      attempt("remove \(directory.path)") {
        try GeneratedPackageFileWriter().removeGeneratedItem(at: directory)
      }
    }
    if failures.isEmpty, fileManager.fileExists(atPath: recoveryJournalURL.path) {
      attempt("remove recovery journal") {
        try fileManager.removeItem(at: recoveryJournalURL)
      }
    }
    guard failures.isEmpty else {
      throw SwiftWebGeneratedPackageMaterializerError.materializationRecoveryFailed(
        recoveryJournalURL,
        failures.joined(separator: "; ")
      )
    }
  }

  private func restoreOriginalRoot(
    live: URL,
    backup: URL,
    hadOriginal: Bool
  ) throws {
    let fileManager = FileManager.default
    guard hadOriginal else {
      for candidate in [live, backup]
      where fileManager.fileExists(atPath: candidate.path) {
        try GeneratedPackageFileWriter().removeGeneratedItem(at: candidate)
      }
      return
    }
    if fileManager.fileExists(atPath: backup.path) {
      if fileManager.fileExists(atPath: live.path) {
        try GeneratedPackageFileWriter().removeGeneratedItem(at: live)
      }
      try fileManager.moveItem(at: backup, to: live)
      return
    }
    guard fileManager.fileExists(atPath: live.path) else {
      throw SwiftWebGeneratedPackageMaterializerError.materializationRecoveryFailed(
        recoveryJournalURL,
        "original root and backup are both missing at \(live.path)"
      )
    }
  }

  private func finalizeInstalledTransaction(_ journal: RecoveryJournal) throws {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: journal.generatedPackageDirectory) else {
      throw SwiftWebGeneratedPackageMaterializerError.materializationRecoveryFailed(
        recoveryJournalURL,
        "installed generated package is missing at \(journal.generatedPackageDirectory)"
      )
    }
    var failures: [String] = []
    for directory in [
      URL(fileURLWithPath: journal.stagingGeneratedPackageDirectory),
      URL(fileURLWithPath: journal.stagingNativeSourceDirectory),
      URL(fileURLWithPath: journal.generatedPackageBackupDirectory),
      URL(fileURLWithPath: journal.nativeGeneratedSourceBackupDirectory),
    ] where fileManager.fileExists(atPath: directory.path) {
      do {
        try GeneratedPackageFileWriter().removeGeneratedItem(at: directory)
      } catch {
        failures.append("remove \(directory.path): \(error)")
      }
    }
    guard failures.isEmpty else {
      throw SwiftWebGeneratedPackageMaterializerError.materializationRecoveryFailed(
        recoveryJournalURL,
        failures.joined(separator: "; ")
      )
    }
    if fileManager.fileExists(atPath: recoveryJournalURL.path) {
      try fileManager.removeItem(at: recoveryJournalURL)
    }
  }

  private func seedDirectoryContents(
    from sourceDirectory: URL,
    to destinationDirectory: URL
  ) throws {
    let children = try FileManager.default.contentsOfDirectory(
      at: sourceDirectory,
      includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
      options: []
    )
    for child in children where child.lastPathComponent != ".build"
      && child.lastPathComponent != ".swiftpm" {
      let destination = destinationDirectory.appendingPathComponent(
        child.lastPathComponent,
        isDirectory: false
      )
      let values = try child.resourceValues(
        forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
      )
      if values.isDirectory == true, values.isSymbolicLink != true {
        try FileManager.default.createDirectory(
          at: destination,
          withIntermediateDirectories: true
        )
        try seedDirectoryContents(from: child, to: destination)
      } else {
        try FileManager.default.copyItem(at: child, to: destination)
      }
    }
  }

  private func transferReusablePackageState(
    from previousGeneratedPackageDirectory: URL,
    to installedGeneratedPackageDirectory: URL
  ) throws {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: previousGeneratedPackageDirectory.path) else {
      return
    }
    try transferReusableStateDirectories(
      from: previousGeneratedPackageDirectory,
      to: installedGeneratedPackageDirectory
    )
    for packageName in ["server", "dev", "wasm"] {
      let previousPackage = previousGeneratedPackageDirectory.appendingPathComponent(
        packageName,
        isDirectory: true
      )
      let installedPackage = installedGeneratedPackageDirectory.appendingPathComponent(
        packageName,
        isDirectory: true
      )
      let previousManifest = previousPackage.appendingPathComponent("Package.swift")
      let installedManifest = installedPackage.appendingPathComponent("Package.swift")
      guard fileManager.fileExists(atPath: previousManifest.path),
        fileManager.fileExists(atPath: installedManifest.path),
        try Data(contentsOf: previousManifest) == Data(contentsOf: installedManifest)
      else {
        continue
      }
      try transferReusableStateDirectories(
        from: previousPackage,
        to: installedPackage
      )
    }
  }

  private func transferReusableStateDirectories(
    from previousDirectory: URL,
    to installedDirectory: URL
  ) throws {
    let fileManager = FileManager.default
    for stateName in [".build", ".swiftpm"] {
      let previous = previousDirectory.appendingPathComponent(stateName, isDirectory: true)
      let installed = installedDirectory.appendingPathComponent(stateName, isDirectory: true)
      guard fileManager.fileExists(atPath: previous.path),
        !fileManager.fileExists(atPath: installed.path)
      else {
        continue
      }
      try fileManager.moveItem(at: previous, to: installed)
    }
  }
}
