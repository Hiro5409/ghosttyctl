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

struct NewWindowCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "new-window",
    abstract: "Create a window and return its stable IDs."
  )

  @Option(name: .customLong("cwd"), help: "Initial working directory.")
  var workingDirectory: String?

  mutating func run() async throws {
    let result = try await Ghostty().newWindow(
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

struct SetTitleCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "set-title",
    abstract: "Set a persistent tab title."
  )

  @Argument(help: "Title text. An empty string clears the title.")
  var title: String

  @Option(help: "Stable tab ID. Defaults to the selected tab.")
  var tab: String?

  mutating func run() async throws {
    let result = try await Ghostty().setTabTitle(title, tabID: tab)
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
    abstract: "Close a terminal, tab, or window by stable ID."
  )

  @Option(help: "Stable terminal ID to close without confirmation.")
  var terminal: String?

  @Option(help: "Stable tab ID to close.")
  var tab: String?

  @Option(help: "Stable window ID to close.")
  var window: String?

  mutating func validate() throws {
    let targetCount = [terminal, tab, window].compactMap { $0 }.count
    guard targetCount == 1 else {
      throw ValidationError(
        "Specify exactly one of --terminal, --tab, or --window."
      )
    }
  }

  mutating func run() async throws {
    let ghostty = Ghostty()
    if let terminal {
      try Output.write(await ghostty.close(terminalID: terminal))
    } else if let tab {
      try Output.write(await ghostty.close(tabID: tab))
    } else if let window {
      try Output.write(await ghostty.close(windowID: window))
    }
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

struct ReloadConfigCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reload-config",
    abstract: "Reload the Ghostty configuration."
  )

  mutating func run() async throws {
    try await runAction("reload_config", terminalID: nil)
  }
}

struct UndoCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "undo",
    abstract: "Undo a recent window, tab, or split lifecycle action."
  )

  mutating func run() async throws {
    try await runAction("undo", terminalID: nil)
  }
}

struct RedoCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "redo",
    abstract: "Redo a recently undone lifecycle action."
  )

  mutating func run() async throws {
    try await runAction("redo", terminalID: nil)
  }
}

struct ResetCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reset",
    abstract: "Reset a terminal by stable ID."
  )

  @Option(help: "Stable terminal ID. Defaults to the focused terminal.")
  var terminal: String?

  mutating func run() async throws {
    try await runAction("reset", terminalID: terminal)
  }
}

struct MoveTabCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "move-tab",
    abstract: "Move a tab by a relative offset."
  )

  @Option(
    parsing: .unconditional,
    help: "Relative tab offset. Positive moves forward; negative moves backward."
  )
  var offset: Int

  @Option(help: "Stable tab ID to move.")
  var tab: String

  mutating func run() async throws {
    let result = try await Ghostty().moveTab(tabID: tab, offset: offset)
    try Output.write(result)
  }
}

struct ResizeSplitCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "resize-split",
    abstract: "Resize a split in a direction by a pixel amount."
  )

  @Argument(help: "Resize direction: right, left, down, or up.")
  var direction: SplitDirection

  @Argument(help: "Resize amount in pixels.")
  var pixels: UInt16

  @Option(help: "Stable terminal ID. Defaults to the focused terminal.")
  var terminal: String?

  mutating func run() async throws {
    try await runAction(
      "resize_split:\(direction.rawValue),\(pixels)",
      terminalID: terminal
    )
  }
}

struct EqualizeSplitsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "equalize-splits",
    abstract: "Equalize all split sizes in the current window."
  )

  @Option(help: "Stable terminal ID. Defaults to the focused terminal.")
  var terminal: String?

  mutating func run() async throws {
    try await runAction("equalize_splits", terminalID: terminal)
  }
}

struct CaptureCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "capture",
    abstract: "Write terminal content to standard output."
  )

  @Argument(help: "Content scope: screen, scrollback, or selection.")
  var scope: CaptureScope

  @Option(help: "Stable terminal ID. Defaults to the focused terminal.")
  var terminal: String?

  mutating func run() async throws {
    let text = try await Ghostty().capture(scope, terminalID: terminal)
    Output.writeRaw(text)
  }
}

private func runAction(_ action: String, terminalID: String?) async throws {
  let result = try await Ghostty().performAction(action, terminalID: terminalID)
  try Output.write(result)
}

extension SplitDirection: ExpressibleByArgument {}
extension CaptureScope: ExpressibleByArgument {}

extension String {
  fileprivate var expandingTildeInPath: String {
    (self as NSString).expandingTildeInPath
  }
}
