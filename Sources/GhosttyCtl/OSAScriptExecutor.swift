import Foundation
import Subprocess

protocol AppleScriptExecuting: Sendable {
  func execute(source: String, arguments: [String]) async throws -> String
}

struct OSAScriptExecutor: AppleScriptExecuting {
  private static let outputLimit = 1_048_576

  func execute(source: String, arguments: [String]) async throws -> String {
    let result = try await Subprocess.run(
      .path("/usr/bin/osascript"),
      arguments: Arguments(["-"] + arguments),
      input: .string(source),
      output: .string(limit: Self.outputLimit),
      error: .string(limit: Self.outputLimit)
    )

    guard result.terminationStatus.isSuccess else {
      let message = result.standardError
        .trimmingCharacters(in: .whitespacesAndNewlines)
      throw OSAScriptError(
        exitStatus: result.terminationStatus.exitStatus,
        message: message.isEmpty ? "AppleScript failed." : message
      )
    }
    return result.standardOutput
  }
}

struct OSAScriptError: Error, LocalizedError, Sendable {
  let exitStatus: Int32
  let message: String

  var errorDescription: String? { message }
}

extension TerminationStatus {
  fileprivate var exitStatus: Int32 {
    switch self {
    case .exited(let code): code
    case .signaled(let signal): 128 + signal
    }
  }
}
