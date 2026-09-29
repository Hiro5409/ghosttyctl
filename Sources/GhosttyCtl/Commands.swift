import ArgumentParser
import Foundation

struct ListCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List terminal surfaces and their stable IDs."
  )

  @Flag(help: "Emit JSON instead of the compact human-readable format.")
  var json = false

  mutating func run() async throws {
    let terminals = try await Ghostty().list()
    if json {
      try Output.write(terminals)
      return
    }

    for terminal in terminals {
      let marker = terminal.focused ? "*" : " "
      print(
        "\(marker) \(terminal.terminalID)  pid=\(terminal.pid) tty=\(terminal.tty)  \(terminal.windowName) / \(terminal.tabName)  \(terminal.workingDirectory)"
      )
    }
  }
}

struct NewTabCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "new-tab",
    abstract: "Create a tab in the front or selected window."
  )

  @Option(help: "Stable window ID. Defaults to the front window.")
  var window: String?

  @Option(name: .customLong("cwd"), help: "Initial working directory.")
  var workingDirectory: String?

  mutating func run() async throws {
    let result = try await Ghostty().newTab(
      windowID: window,
      workingDirectory: workingDirectory?.expandingTildeInPath
    )
    try Output.write(result)
  }
}

struct SplitCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "split",
    abstract: "Split a terminal surface."
  )

  @Argument(help: "Split direction: right, left, down, or up.")
  var direction: SplitDirection

  @Option(help: "Stable terminal ID. Defaults to the focused terminal.")
  var terminal: String?

  @Option(name: .customLong("cwd"), help: "Initial working directory.")
  var workingDirectory: String?

  mutating func run() async throws {
    let result = try await Ghostty().split(
      terminalID: terminal,
      direction: direction,
      workingDirectory: workingDirectory?.expandingTildeInPath
    )
    try Output.write(result)
  }
}

struct FocusCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "focus",
    abstract: "Focus a terminal by stable ID."
  )

  @Argument(help: "Stable terminal ID.")
  var terminalID: String

  mutating func run() async throws {
    let result = try await Ghostty().focus(terminalID: terminalID)
    try Output.write(result)
  }
}

struct TypeCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "type",
    abstract: "Send standard input to a terminal as paste-style input."
  )

  @Option(help: "Stable terminal ID. Defaults to the focused terminal.")
  var terminal: String?

  @Flag(help: "Append a newline to the input.")
  var enter = false

  mutating func run() async throws {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let text = String(data: data, encoding: .utf8) else {
      throw ValidationError("Standard input must be valid UTF-8.")
    }
    let result = try await Ghostty().type(
      text,
      terminalID: terminal,
      enter: enter
    )
    try Output.write(result)
  }
}

struct CloseCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "close",
    abstract: "Close a terminal by stable ID."
  )

  @Option(help: "Stable terminal ID to close.")
  var terminal: String

  mutating func run() async throws {
    let result = try await Ghostty().close(terminalID: terminal)
    try Output.write(result)
  }
}

struct PerformActionCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "perform-action",
    abstract: "Perform a Ghostty keybind action."
  )

  @Argument(help: "Ghostty keybind action string.")
  var action: String

  @Option(help: "Stable terminal ID. Defaults to the focused terminal.")
  var terminal: String?

  mutating func run() async throws {
    let result = try await Ghostty().performAction(
      action,
      terminalID: terminal
    )
    try Output.write(result)
  }
}

extension SplitDirection: ExpressibleByArgument {}

extension String {
  fileprivate var expandingTildeInPath: String {
    (self as NSString).expandingTildeInPath
  }
}
