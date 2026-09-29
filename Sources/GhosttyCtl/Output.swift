import ArgumentParser
import Foundation

enum CLIErrorCode: String, Encodable {
  case invalidArguments = "invalid_arguments"
  case ghosttyNotFound = "ghostty_not_found"
  case appleScriptFailed = "applescript_failed"
  case invalidResponse = "invalid_response"
  case captureFailed = "capture_failed"
  case unexpected = "unexpected_error"
}

private struct CLIErrorResponse: Encodable {
  struct Detail: Encodable {
    let code: CLIErrorCode
    let message: String
  }

  let error: Detail
}

enum Output {
  static func write<Value: Encodable>(_ value: Value) throws {
    let data = try encoded(value)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
  }

  static func writeError(_ error: Error, code: CLIErrorCode) {
    let response = CLIErrorResponse(
      error: .init(
        code: code,
        message: GhosttyCtl.message(for: error)
      )
    )
    guard let data = try? encoded(response) else { return }
    FileHandle.standardError.write(data)
    FileHandle.standardError.write(Data("\n".utf8))
  }

  static func writeText(_ text: String, to file: FileHandle) {
    file.write(Data(text.utf8))
    guard !text.hasSuffix("\n") else { return }
    file.write(Data("\n".utf8))
  }

  static func writeRaw(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
  }

  private static func encoded<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(value)
  }
}
