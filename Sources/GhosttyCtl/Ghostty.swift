import AppKit

struct Ghostty: Sendable {
  private static let bundleIdentifier = "com.mitchellh.ghostty"

  private let executor: any AppleScriptExecuting
  private let isRunning: @Sendable () -> Bool
  private let launch: @Sendable () async throws -> Void

  init() {
    let scriptExecutor = OSAScriptExecutor()
    self.executor = scriptExecutor
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
    isRunning: @escaping @Sendable () -> Bool = { true },
    launch: @escaping @Sendable () async throws -> Void = { return }
  ) {
    self.executor = executor
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

  private func ensureRunning() async throws {
    guard !isRunning() else { return }
    try await launch()
  }
}
