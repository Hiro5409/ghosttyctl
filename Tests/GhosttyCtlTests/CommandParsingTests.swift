import ArgumentParser
import Testing

@testable import GhosttyCtl

@Test func splitCommandAcceptsOnlyADeclaredDirection() throws {
  let command = try GhosttyCtl.parseAsRoot([
    "split",
    "right",
    "--terminal", "terminal-1",
  ])

  #expect(command is SplitCommand)
}
