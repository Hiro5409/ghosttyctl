import Foundation

enum RecordCodec {
  static func terminals(from output: String) throws -> [TerminalSnapshot] {
    guard !output.isEmpty else { return [] }

    return
      try output
      .split(separator: "\n", omittingEmptySubsequences: true)
      .map(parseTerminal)
  }

  static func identifier(from output: String) -> String {
    output.trimmingCharacters(in: .newlines)
  }

  static func actionResult(from output: String) throws -> ActionResult {
    let fields =
      output
      .trimmingCharacters(in: .newlines)
      .split(separator: "\t", omittingEmptySubsequences: false)
      .map(String.init)

    guard fields.count == 2, let performed = Bool(fields[1]) else {
      throw GhosttyResponseError.invalidActionResult(output)
    }
    return ActionResult(terminalID: fields[0], performed: performed)
  }

  private static func parseTerminal(_ line: Substring) throws -> TerminalSnapshot {
    let fields =
      line
      .split(separator: "\t", omittingEmptySubsequences: false)
      .map { unescape(String($0)) }

    guard fields.count == 10,
      let tabIndex = Int(fields[4]),
      let tabSelected = Bool(fields[5]),
      let focused = Bool(fields[9])
    else {
      throw GhosttyResponseError.invalidListRecord(String(line))
    }

    return TerminalSnapshot(
      windowID: fields[0],
      windowName: fields[1],
      tabID: fields[2],
      tabName: fields[3],
      tabIndex: tabIndex,
      tabSelected: tabSelected,
      terminalID: fields[6],
      terminalName: fields[7],
      workingDirectory: fields[8],
      focused: focused
    )
  }

  private static func unescape(_ value: String) -> String {
    var result = ""
    var escaping = false

    for character in value {
      if escaping {
        switch character {
        case "t": result.append("\t")
        case "n": result.append("\n")
        case "r": result.append("\r")
        case "\\": result.append("\\")
        default:
          result.append("\\")
          result.append(character)
        }
        escaping = false
      } else if character == "\\" {
        escaping = true
      } else {
        result.append(character)
      }
    }

    if escaping {
      result.append("\\")
    }
    return result
  }
}
