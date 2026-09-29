import ArgumentParser
import Darwin
import Foundation

@main
struct GhosttyCtl: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ghosttyctl",
    abstract: "Inspect and control a running Ghostty instance.",
    version: "0.3.0",
    subcommands: [
      ListCommand.self,
      NewWindowCommand.self,
      NewTabCommand.self,
      SplitCommand.self,
      FocusCommand.self,
      SetTitleCommand.self,
      TypeCommand.self,
      CloseCommand.self,
      ReloadConfigCommand.self,
      UndoCommand.self,
      RedoCommand.self,
      ResetCommand.self,
      MoveTabCommand.self,
      ResizeSplitCommand.self,
      EqualizeSplitsCommand.self,
      CaptureCommand.self,
      PerformActionCommand.self,
    ]
  )

  static func main() async {
    do {
      var command = try await asyncParseAsRoot()
      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch {
      let exitCode = exitCode(for: error)
      if exitCode == .success {
        Output.writeText(fullMessage(for: error), to: .standardOutput)
      } else {
        Output.writeError(
          error,
          code: errorCode(for: error, exitCode: exitCode)
        )
      }
      Darwin.exit(exitCode.rawValue)
    }
  }

  private static func errorCode(
    for error: Error,
    exitCode: ExitCode
  ) -> CLIErrorCode {
    if exitCode == .validationFailure { return .invalidArguments }

    switch error {
    case is GhosttyApplicationNotFoundError: return .ghosttyNotFound
    case is OSAScriptError: return .appleScriptFailed
    case is GhosttyResponseError: return .invalidResponse
    case is CaptureError: return .captureFailed
    default: return .unexpected
    }
  }
}
