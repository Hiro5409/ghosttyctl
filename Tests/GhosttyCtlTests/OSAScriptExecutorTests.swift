import Testing

@testable import GhosttyCtl

@Suite("osascript adapter")
struct OSAScriptExecutorTests {
  @Test func sendsSourceOnStandardInputAndValuesAsArguments() async throws {
    let executor = OSAScriptExecutor()
    let source = """
      on run argv
          return item 1 of argv
      end run
      """

    let output = try await executor.execute(
      source: source,
      arguments: ["hello \"Ghostty\""]
    )

    #expect(output == "hello \"Ghostty\"\n")
  }

  @Test func reportsNonzeroExits() async {
    let executor = OSAScriptExecutor()

    await #expect(throws: OSAScriptError.self) {
      try await executor.execute(
        source: "error \"expected failure\"",
        arguments: []
      )
    }
  }
}
