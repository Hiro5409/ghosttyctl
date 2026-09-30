import Foundation
import Testing

@testable import GhosttyCtl

@Suite("CLI")
struct CLITests {
  @Test func moveTabAcceptsANegativeOffsetOption() throws {
    let command = try MoveTabCommand.parse([
      "--tab", "tab-1", "--offset", "-1",
    ])

    #expect(command.tab == "tab-1")
    #expect(command.offset == -1)
  }

  @Test(
    arguments: [
      [],
      ["--terminal", "terminal-1", "--tab", "tab-1"],
    ]
  )
  func closeRequiresExactlyOneTarget(arguments: [String]) throws {
    let result = try runCLI(["close"] + arguments)
    let response = try JSONDecoder().decode(
      ErrorResponse.self,
      from: Data(result.standardError.utf8)
    )

    #expect(result.exitStatus == 64)
    #expect(result.standardOutput.isEmpty)
    #expect(response.error.code == "invalid_arguments")
    #expect(response.error.message.contains("exactly one"))
  }
}

private struct ErrorResponse: Decodable {
  struct Detail: Decodable {
    let code: String
    let message: String
  }

  let error: Detail
}

private struct CLIResult {
  let exitStatus: Int32
  let standardOutput: String
  let standardError: String
}

private func runCLI(_ arguments: [String]) throws -> CLIResult {
  let process = Process()
  let standardOutput = Pipe()
  let standardError = Pipe()
  process.executableURL = try executableURL()
  process.arguments = arguments
  process.standardOutput = standardOutput
  process.standardError = standardError

  try process.run()
  process.waitUntilExit()

  return CLIResult(
    exitStatus: process.terminationStatus,
    standardOutput: String(
      decoding: standardOutput.fileHandleForReading.readDataToEndOfFile(),
      as: UTF8.self
    ),
    standardError: String(
      decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
      as: UTF8.self
    )
  )
}

private func executableURL() throws -> URL {
  let packageDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let executable =
    packageDirectory
    .appendingPathComponent(".build/debug/ghosttyctl")

  guard FileManager.default.isExecutableFile(atPath: executable.path) else {
    throw ExecutableNotFoundError()
  }
  return executable
}

private struct ExecutableNotFoundError: Error {}
