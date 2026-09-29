import Foundation

struct TerminalSnapshot: Encodable, Equatable, Sendable {
  let windowID: String
  let windowName: String
  let tabID: String
  let tabName: String
  let tabIndex: Int
  let tabSelected: Bool
  let terminalID: String
  let terminalName: String
  let workingDirectory: String
  let focused: Bool
}

struct TerminalReference: Encodable, Equatable, Sendable {
  let terminalID: String
}

struct ActionResult: Encodable, Equatable, Sendable {
  let terminalID: String
  let performed: Bool
}

enum SplitDirection: String, CaseIterable, Sendable {
  case right
  case left
  case down
  case up
}

struct GhosttyApplicationNotFoundError: LocalizedError, Sendable {
  var errorDescription: String? {
    "Ghostty is not installed. Install Ghostty and try again."
  }
}

enum GhosttyResponseError: Error, Sendable {
  case invalidListRecord(String)
  case invalidActionResult(String)
}
