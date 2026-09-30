import Foundation
import Testing

@testable import GhosttyCtl

@Suite("Ghostty")
struct GhosttyTests {
  @Test func newWindowReturnsStableIDsAndKeepsWorkingDirectoryAsData() async throws {
    let workingDirectory = "/tmp/Agent's work"
    let executor = RecordingAppleScriptExecutor(
      output: "window-1\ttab-1\tterminal-1\n"
    )
    let ghostty = Ghostty(executor: executor)

    let result = try await ghostty.newWindow(workingDirectory: workingDirectory)
    let invocation = try #require(await executor.invocations.first)

    #expect(
      result
        == WindowReference(
          windowID: "window-1",
          tabID: "tab-1",
          terminalID: "terminal-1"
        )
    )
    #expect(invocation.arguments == [workingDirectory])
    #expect(!invocation.source.contains(workingDirectory))
  }

  @Test func typeKeepsTextAndEnterAsSeparateAppleScriptArguments() async throws {
    let payload = "printf '\"hello\"'\\path\n"
    let executor = RecordingAppleScriptExecutor(output: "terminal-1\n")
    let ghostty = Ghostty(executor: executor)

    let result = try await ghostty.type(
      payload,
      terminalID: "terminal-1",
      enter: true
    )
    let invocation = try #require(await executor.invocations.first)

    #expect(result == TerminalReference(terminalID: "terminal-1"))
    #expect(invocation.arguments == ["terminal-1", payload, "true"])
    #expect(!invocation.source.contains(payload))
  }

  @Test func performActionPassesTheActionAsData() async throws {
    let action = "set_tab_title:Agent's work"
    let executor = RecordingAppleScriptExecutor(output: "terminal-1\ttrue\n")
    let ghostty = Ghostty(executor: executor)

    let result = try await ghostty.performAction(action, terminalID: nil)
    let invocation = try #require(await executor.invocations.first)

    #expect(result == ActionResult(terminalID: "terminal-1", performed: true))
    #expect(invocation.arguments == ["", action])
    #expect(!invocation.source.contains(action))
  }

  @Test func setTabTitleTargetsTheStableTabIDAndPassesTheTitleAsData() async throws {
    let title = "Agent's work"
    let executor = RecordingAppleScriptExecutor(output: "terminal-1\ttrue\n")
    let ghostty = Ghostty(executor: executor)

    let result = try await ghostty.setTabTitle(title, tabID: "tab-1")
    let invocation = try #require(await executor.invocations.first)

    #expect(result == ActionResult(terminalID: "terminal-1", performed: true))
    #expect(invocation.arguments == ["tab-1", title])
    #expect(!invocation.source.contains(title))
  }

  @Test func moveTabTargetsTheStableTabIDAndPassesTheOffsetAsData() async throws {
    let executor = RecordingAppleScriptExecutor(output: "terminal-1\ttrue\n")
    let ghostty = Ghostty(executor: executor)

    let result = try await ghostty.moveTab(tabID: "tab-1", offset: -1)
    let invocation = try #require(await executor.invocations.first)

    #expect(result == ActionResult(terminalID: "terminal-1", performed: true))
    #expect(invocation.arguments == ["tab-1", "-1"])
    #expect(!invocation.source.contains("tab-1"))
  }

  @Test func captureReturnsTextRestoresClipboardAndRemovesTemporaryFile() async throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("screen.txt")
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("captured output\n".utf8).write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    let clipboard = TestClipboard(text: "original clipboard")
    let executor = CaptureAppleScriptExecutor(
      clipboard: clipboard,
      capturedPath: fileURL.path
    )
    let ghostty = Ghostty(executor: executor, clipboard: clipboard)

    let text = try await ghostty.capture(.screen, terminalID: "terminal-1")
    let invocation = try #require(await executor.invocations.first)

    #expect(text == "captured output\n")
    #expect(await clipboard.text == "original clipboard")
    #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    #expect(invocation.arguments == ["terminal-1", "write_screen_file:copy,plain"])
  }

  @Test func captureReturnsEmptyTextWhenTheScopeHasNoContent() async throws {
    let clipboard = TestClipboard(text: "original clipboard")
    let executor = RecordingAppleScriptExecutor(output: "terminal-1\ttrue\n")
    let ghostty = Ghostty(executor: executor, clipboard: clipboard)

    let text = try await ghostty.capture(.selection, terminalID: "terminal-1")

    #expect(text.isEmpty)
    #expect(await clipboard.text == "original clipboard")
  }

  @Test func captureDoesNotDeleteAPathThatIsNotARegularCaptureFile() async throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("screen.txt")
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )
    let sentinelURL = directoryURL.appendingPathComponent("keep")
    try Data().write(to: sentinelURL)
    defer { try? FileManager.default.removeItem(at: directoryURL.deletingLastPathComponent()) }

    let clipboard = TestClipboard(text: "original clipboard")
    let executor = CaptureAppleScriptExecutor(
      clipboard: clipboard,
      capturedPath: directoryURL.path
    )
    let ghostty = Ghostty(executor: executor, clipboard: clipboard)

    do {
      _ = try await ghostty.capture(.screen, terminalID: "terminal-1")
      Issue.record("Expected capture to reject a directory path")
    } catch {
      #expect(error is CaptureError)
    }

    #expect(FileManager.default.fileExists(atPath: sentinelURL.path))
    #expect(await clipboard.text == directoryURL.path)
  }

  @Test func captureCleansUpAnOwnedFileWhenDecodingFails() async throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("screen.txt")
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data([0xFF]).write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    let clipboard = TestClipboard(text: "original clipboard")
    let executor = CaptureAppleScriptExecutor(
      clipboard: clipboard,
      capturedPath: fileURL.path
    )
    let ghostty = Ghostty(executor: executor, clipboard: clipboard)

    do {
      _ = try await ghostty.capture(.screen, terminalID: "terminal-1")
      Issue.record("Expected capture to reject invalid UTF-8")
    } catch {
      #expect(error is CaptureError)
    }

    #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    #expect(!FileManager.default.fileExists(atPath: fileURL.deletingLastPathComponent().path))
    #expect(await clipboard.text == "original clipboard")
  }

  @Test func captureDoesNotRestoreOrDeleteAfterAConcurrentClipboardChange() async throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("screen.txt")
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("captured output\n".utf8).write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    let clipboard = TestClipboard(text: "original clipboard")
    let executor = CaptureAppleScriptExecutor(
      clipboard: clipboard,
      capturedPath: fileURL.path,
      changeBeforeCapture: true
    )
    let ghostty = Ghostty(executor: executor, clipboard: clipboard)

    let text = try await ghostty.capture(.screen, terminalID: "terminal-1")

    #expect(text == "captured output\n")
    #expect(await clipboard.text == fileURL.path)
    #expect(FileManager.default.fileExists(atPath: fileURL.path))
  }

  @Test func closeTargetsExactlyTheRequestedTerminal() async throws {
    let executor = RecordingAppleScriptExecutor(output: "terminal-1\n")
    let ghostty = Ghostty(executor: executor)

    let result = try await ghostty.close(terminalID: "terminal-1")
    let invocation = try #require(await executor.invocations.first)

    #expect(result == TerminalReference(terminalID: "terminal-1"))
    #expect(invocation.arguments == ["terminal-1"])
    #expect(invocation.source == GhosttyScripts.close)
  }

  @Test func closeScopesTargetStableIDsWithNativeCommands() async throws {
    let tabExecutor = RecordingAppleScriptExecutor(output: "tab-1\n")
    _ = try await Ghostty(executor: tabExecutor).close(tabID: "tab-1")
    let tabInvocation = try #require(await tabExecutor.invocations.first)

    #expect(tabInvocation.arguments == ["tab-1"])
    #expect(tabInvocation.source == GhosttyScripts.closeTab)

    let windowExecutor = RecordingAppleScriptExecutor(output: "window-1\n")
    _ = try await Ghostty(executor: windowExecutor).close(
      windowID: "window-1"
    )
    let windowInvocation = try #require(await windowExecutor.invocations.first)

    #expect(windowInvocation.arguments == ["window-1"])
    #expect(windowInvocation.source == GhosttyScripts.closeWindow)
  }

  @Test func doesNotLaunchGhosttyWhenItIsAlreadyRunning() async throws {
    let launchState = LaunchState()
    let executor = RecordingAppleScriptExecutor(output: "terminal-1\n")
    let ghostty = Ghostty(
      executor: executor,
      isRunning: { true },
      launch: { await launchState.recordLaunch() }
    )

    _ = try await ghostty.focus(terminalID: "terminal-1")

    #expect(await launchState.launchCount == 0)
  }

  @Test func launchesGhosttyBeforeExecutingACommandWhenItIsNotRunning() async throws {
    let launchState = LaunchState()
    let executor = LaunchAwareAppleScriptExecutor(
      launchState: launchState,
      output: "terminal-1\n"
    )
    let ghostty = Ghostty(
      executor: executor,
      isRunning: { false },
      launch: { await launchState.recordLaunch() }
    )

    let result = try await ghostty.focus(terminalID: "terminal-1")

    #expect(result == TerminalReference(terminalID: "terminal-1"))
    #expect(await launchState.launchCount == 1)
  }
}

private actor RecordingAppleScriptExecutor: AppleScriptExecuting {
  struct Invocation: Equatable, Sendable {
    let source: String
    let arguments: [String]
  }

  let output: String
  private(set) var invocations: [Invocation] = []

  init(output: String) {
    self.output = output
  }

  func execute(source: String, arguments: [String]) -> String {
    invocations.append(Invocation(source: source, arguments: arguments))
    return output
  }
}

private actor LaunchState {
  private(set) var launchCount = 0

  var hasLaunched: Bool { launchCount > 0 }

  func recordLaunch() {
    launchCount += 1
  }
}

private actor LaunchAwareAppleScriptExecutor: AppleScriptExecuting {
  enum Error: Swift.Error {
    case executedBeforeLaunch
  }

  let launchState: LaunchState
  let output: String

  init(launchState: LaunchState, output: String) {
    self.launchState = launchState
    self.output = output
  }

  func execute(source _: String, arguments _: [String]) async throws -> String {
    guard await launchState.hasLaunched else {
      throw Error.executedBeforeLaunch
    }
    return output
  }
}

private actor TestClipboard: ClipboardAccess {
  private(set) var text: String
  private var changeCount = 1

  init(text: String) {
    self.text = text
  }

  func snapshot() -> ClipboardSnapshot {
    ClipboardSnapshot(
      changeCount: changeCount,
      items: [
        ClipboardItemSnapshot(
          representations: [
            ClipboardRepresentation(
              type: "public.utf8-plain-text",
              data: Data(text.utf8)
            )
          ]
        )
      ]
    )
  }

  func stringValue() -> ClipboardValue {
    ClipboardValue(text: text, changeCount: changeCount)
  }

  func restore(
    _ snapshot: ClipboardSnapshot,
    ifChangeCountIs expectedChangeCount: Int
  ) {
    guard changeCount == expectedChangeCount else { return }
    guard
      let data = snapshot.items.first?.representations.first(where: {
        $0.type == "public.utf8-plain-text"
      })?.data
    else { return }
    text = String(decoding: data, as: UTF8.self)
    changeCount += 1
  }

  func replace(with text: String) {
    self.text = text
    changeCount += 1
  }
}

private actor CaptureAppleScriptExecutor: AppleScriptExecuting {
  let clipboard: TestClipboard
  let capturedPath: String
  let changeBeforeCapture: Bool
  private(set) var invocations: [RecordingAppleScriptExecutor.Invocation] = []

  init(
    clipboard: TestClipboard,
    capturedPath: String,
    changeBeforeCapture: Bool = false
  ) {
    self.clipboard = clipboard
    self.capturedPath = capturedPath
    self.changeBeforeCapture = changeBeforeCapture
  }

  func execute(source: String, arguments: [String]) async -> String {
    invocations.append(.init(source: source, arguments: arguments))
    if changeBeforeCapture {
      await clipboard.replace(with: "concurrent clipboard")
    }
    await clipboard.replace(with: capturedPath)
    return "terminal-1\ttrue\n"
  }
}
