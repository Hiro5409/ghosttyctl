import ArgumentParser

@main
struct GhosttyCtl: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ghosttyctl",
    abstract: "Inspect and control a running Ghostty instance.",
    version: "0.1.0",
    subcommands: [
      ListCommand.self,
      NewTabCommand.self,
      SplitCommand.self,
      FocusCommand.self,
      TypeCommand.self,
      PerformActionCommand.self,
    ]
  )
}
