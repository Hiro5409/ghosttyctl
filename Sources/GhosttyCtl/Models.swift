import Foundation

struct TerminalSnapshot: Encodable, Sendable {
  let windowID: String
  let windowName: String
  let tabID: String
  let tabName: String
  let tabIndex: Int
  let tabSelected: Bool
  let terminalID: String
  let terminalName: String
  let workingDirectory: String
  let pid: Int
  let tty: String
  let focused: Bool
}

struct TerminalReference: Encodable, Equatable, Sendable {
  let terminalID: String
}

struct ActionResult: Encodable, Equatable, Sendable {
  let terminalID: String
  let performed: Bool
}

enum SplitDirection: String, Sendable {
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

enum GhosttyResponseError: LocalizedError, Sendable {
  case invalidListRecord(String)
  case invalidActionResult(String)

  var errorDescription: String? {
    switch self {
    case .invalidListRecord:
      "Ghostty returned invalid terminal metadata."
    case .invalidActionResult:
      "Ghostty returned an invalid action result."
    }
  }
}
