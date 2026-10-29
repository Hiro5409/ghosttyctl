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

struct TabReference: Encodable, Equatable, Sendable {
  let tabID: String
}

struct WindowIDReference: Encodable, Equatable, Sendable {
  let windowID: String
}

struct WindowReference: Encodable, Equatable, Sendable {
  let windowID: String
  let tabID: String
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

enum CaptureScope: String, Sendable {
  case screen
  case scrollback
  case selection

  var action: String {
    "write_\(rawValue)_file:copy,plain"
  }

  var captureFileName: String {
    switch self {
    case .screen: "screen.txt"
    case .scrollback: "history.txt"
    case .selection: "selection.txt"
    }
  }
}

struct GhosttyApplicationNotFoundError: LocalizedError, Sendable {
  var errorDescription: String? {
    "Ghostty is not installed. Install Ghostty and try again."
  }
}

enum CaptureError: LocalizedError, Sendable {
  case actionNotPerformed
  case clipboardUnavailable
  case unsafeTemporaryFile
  case invalidUTF8

  var errorDescription: String? {
    switch self {
    case .actionNotPerformed:
      "Ghostty did not capture the requested terminal content."
    case .clipboardUnavailable:
      "Ghostty did not place a captured file path on the clipboard."
    case .unsafeTemporaryFile:
      "Ghostty returned an unexpected capture file path."
    case .invalidUTF8:
      "Ghostty captured content that is not valid UTF-8."
    }
  }
}

enum GhosttyResponseError: LocalizedError, Sendable {
  case invalidListRecord(String)
  case invalidActionResult(String)
  case invalidWindowReference(String)

  var errorDescription: String? {
    switch self {
    case .invalidListRecord:
      "Ghostty returned invalid terminal metadata."
    case .invalidActionResult:
      "Ghostty returned an invalid action result."
    case .invalidWindowReference:
      "Ghostty returned invalid window metadata."
    }
  }
}
