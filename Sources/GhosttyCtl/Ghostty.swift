import AppKit
import Darwin

struct Ghostty: Sendable {
  private static let bundleIdentifier = "com.mitchellh.ghostty"

  private let executor: any AppleScriptExecuting
  private let clipboard: any ClipboardAccess
  private let isRunning: @Sendable () -> Bool
  private let launch: @Sendable () async throws -> Void

  init() {
    let scriptExecutor = OSAScriptExecutor()
    self.executor = scriptExecutor
    self.clipboard = SystemClipboard()
    self.isRunning = {
      !NSRunningApplication.runningApplications(
        withBundleIdentifier: Self.bundleIdentifier
      ).isEmpty
    }
    self.launch = {
      let workspace = NSWorkspace.shared
      guard
        let applicationURL = workspace.urlForApplication(
          withBundleIdentifier: Self.bundleIdentifier
        )
      else {
        throw GhosttyApplicationNotFoundError()
      }

      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = false
      _ = try await workspace.openApplication(
        at: applicationURL,
        configuration: configuration
      )
      _ = try await scriptExecutor.execute(
        source: GhosttyScripts.ensureWindow,
        arguments: []
      )
    }
  }

  init(
    executor: any AppleScriptExecuting,
    clipboard: any ClipboardAccess = SystemClipboard(),
    isRunning: @escaping @Sendable () -> Bool = { true },
    launch: @escaping @Sendable () async throws -> Void = { return }
  ) {
    self.executor = executor
    self.clipboard = clipboard
    self.isRunning = isRunning
    self.launch = launch
  }

  func list() async throws -> [TerminalSnapshot] {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.list,
      arguments: []
    )
    return try RecordCodec.terminals(from: output)
  }

  func type(
    _ text: String,
    terminalID: String?,
    enter: Bool
  ) async throws -> TerminalReference {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.type,
      arguments: [terminalID ?? "", text, enter ? "true" : "false"]
    )
    return TerminalReference(terminalID: RecordCodec.identifier(from: output))
  }

  func newTab(
    windowID: String?,
    workingDirectory: String?
  ) async throws -> TerminalReference {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.newTab,
      arguments: [windowID ?? "", workingDirectory ?? ""]
    )
    return TerminalReference(terminalID: RecordCodec.identifier(from: output))
  }

  func newWindow(workingDirectory: String?) async throws -> WindowReference {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.newWindow,
      arguments: [workingDirectory ?? ""]
    )
    return try RecordCodec.windowReference(from: output)
  }

  func split(
    terminalID: String?,
    direction: SplitDirection,
    workingDirectory: String?
  ) async throws -> TerminalReference {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.split,
      arguments: [terminalID ?? "", direction.rawValue, workingDirectory ?? ""]
    )
    return TerminalReference(terminalID: RecordCodec.identifier(from: output))
  }

  func focus(terminalID: String) async throws -> TerminalReference {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.focus,
      arguments: [terminalID]
    )
    return TerminalReference(terminalID: RecordCodec.identifier(from: output))
  }

  func close(terminalID: String) async throws -> TerminalReference {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.close,
      arguments: [terminalID]
    )
    return TerminalReference(terminalID: RecordCodec.identifier(from: output))
  }

  func close(tabID: String) async throws -> TabReference {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.closeTab,
      arguments: [tabID]
    )
    return TabReference(tabID: RecordCodec.identifier(from: output))
  }

  func close(windowID: String) async throws -> WindowIDReference {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.closeWindow,
      arguments: [windowID]
    )
    return WindowIDReference(windowID: RecordCodec.identifier(from: output))
  }

  func performAction(
    _ action: String,
    terminalID: String?
  ) async throws -> ActionResult {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.performAction,
      arguments: [terminalID ?? "", action]
    )
    return try RecordCodec.actionResult(from: output)
  }

  func setTabTitle(_ title: String, tabID: String?) async throws -> ActionResult {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.setTabTitle,
      arguments: [tabID ?? "", title]
    )
    return try RecordCodec.actionResult(from: output)
  }

  func moveTab(tabID: String, offset: Int) async throws -> ActionResult {
    try await ensureRunning()
    let output = try await executor.execute(
      source: GhosttyScripts.moveTab,
      arguments: [tabID, String(offset)]
    )
    return try RecordCodec.actionResult(from: output)
  }

  func capture(
    _ scope: CaptureScope,
    terminalID: String?
  ) async throws -> String {
    let snapshot = await clipboard.snapshot()
    let result = try await performAction(scope.action, terminalID: terminalID)
    guard result.performed else { throw CaptureError.actionNotPerformed }

    let clipboardValue = await clipboard.stringValue()
    guard clipboardValue.changeCount != snapshot.changeCount else { return "" }
    guard let path = clipboardValue.text else {
      throw CaptureError.clipboardUnavailable
    }

    let ownsClipboardChange =
      clipboardValue.changeCount == snapshot.changeCount + 1

    let fileURL = try captureFileURL(for: path, scope: scope)
    let capturedText = Result {
      let data = try Data(contentsOf: fileURL)
      guard let text = String(data: data, encoding: .utf8) else {
        throw CaptureError.invalidUTF8
      }
      return text
    }

    if ownsClipboardChange {
      removeCapture(at: fileURL)
      await clipboard.restore(
        snapshot,
        ifChangeCountIs: clipboardValue.changeCount
      )
    }
    return try capturedText.get()
  }

  private func captureFileURL(for path: String, scope: CaptureScope) throws -> URL {
    let sourceURL = URL(fileURLWithPath: path).standardizedFileURL
    guard
      let resourceValues = try? sourceURL.resourceValues(
        forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
      )
    else {
      throw CaptureError.unsafeTemporaryFile
    }
    guard resourceValues.isRegularFile == true,
      resourceValues.isSymbolicLink != true
    else {
      throw CaptureError.unsafeTemporaryFile
    }

    let fileURL = sourceURL.resolvingSymlinksInPath()
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .standardizedFileURL
      .resolvingSymlinksInPath()
    let captureDirectory = fileURL.deletingLastPathComponent()

    guard fileURL.lastPathComponent == scope.captureFileName,
      captureDirectory.deletingLastPathComponent() == temporaryDirectory
    else {
      throw CaptureError.unsafeTemporaryFile
    }
    return fileURL
  }

  private func removeCapture(at fileURL: URL) {
    _ = fileURL.withUnsafeFileSystemRepresentation { path in
      guard let path else { return -1 }
      return Int(Darwin.unlink(path))
    }
    _ = fileURL.deletingLastPathComponent().withUnsafeFileSystemRepresentation {
      path in
      guard let path else { return -1 }
      return Int(Darwin.rmdir(path))
    }
  }

  private func ensureRunning() async throws {
    guard !isRunning() else { return }
    try await launch()
  }
}
