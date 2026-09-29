import Testing

@testable import GhosttyCtl

@Suite("Ghostty")
struct GhosttyTests {
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
