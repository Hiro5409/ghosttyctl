import Foundation
import Testing

@Suite("CLI")
struct CLITests {
  @Test func closeRequiresATerminalAndReportsAJSONError() throws {
    let result = try runCLI(["close"])
    let response = try JSONDecoder().decode(
      ErrorResponse.self,
      from: Data(result.standardError.utf8)
    )

    #expect(result.exitStatus == 64)
    #expect(result.standardOutput.isEmpty)
    #expect(response.error.code == "invalid_arguments")
    #expect(response.error.message.contains("--terminal"))
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
