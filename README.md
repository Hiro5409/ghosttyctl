# ghosttyctl

`ghosttyctl` is an unofficial, agent-friendly macOS CLI for inspecting and
controlling Ghostty through its AppleScript API.

The command surface is intentionally narrow. It uses stable Ghostty object IDs,
emits JSON for machine-driven workflows, and accepts terminal input through
standard input. The CLI executes only `/usr/bin/osascript` as a subprocess, has
no daemon or network access, and does not use Accessibility APIs, private APIs,
or the clipboard.

## Requirements

- macOS 14 or later
- Ghostty tip with AppleScript enabled (`brew install --cask ghostty@tip`)
- Xcode 26 or later with Swift 6.2 or later

Commands launch Ghostty in the background when it is not already running. The
first command that controls Ghostty can trigger the macOS Automation permission
prompt.

## Install

Install with Homebrew:

```sh
brew install Hiro5409/tap/ghosttyctl
```

### From source

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift build -c release
```

The binary is written to `.build/release/ghosttyctl`. Install it in a directory
on `PATH`:

```sh
install -d "$HOME/.local/bin"
install -m 0755 .build/release/ghosttyctl "$HOME/.local/bin/ghosttyctl"
```

## Commands

```sh
ghosttyctl list --json
ghosttyctl new-tab --window WINDOW_ID --cwd ~/src/project
ghosttyctl split right --terminal TERMINAL_ID --cwd ~/src/project
ghosttyctl focus TERMINAL_ID
ghosttyctl type --terminal TERMINAL_ID --enter <<'GHOSTTY_INPUT'
git status --short
GHOSTTY_INPUT
ghosttyctl close --terminal TERMINAL_ID
ghosttyctl perform-action toggle_fullscreen --terminal TERMINAL_ID
```

`list` reports the current foreground process ID and local TTY for each
terminal. These values identify local processes and can change while a terminal
is running; they do not expose terminal output or processes beyond an SSH
connection. A process ID of `0` or an empty TTY means the value is unavailable.

`type` reads UTF-8 from standard input. `--enter` sends an Enter key after the
text and can start a terminal process. Successful delivery does not report the
command's exit status or terminal output. Input and action values are passed to
AppleScript as process arguments rather than interpolated into source code.

The executable uses Swift concurrency and the Swift project's `Subprocess`
package for bounded, cancellable `osascript` execution.

Failures are JSON objects on standard error. Invalid arguments and input exit
with status 64; Ghostty, AppleScript, response, and unexpected failures exit
with status 1. The stable `error.code` is intended for automation:

```json
{
  "error": {
    "code": "invalid_arguments",
    "message": "Missing expected argument '--terminal <terminal>'"
  }
}
```

`close` requires a stable terminal ID and closes without confirmation. The CLI
does not read terminal screen contents or expose first-class quit, raw-key, or
mouse subcommands. `perform-action` is an explicit escape hatch and can invoke
state-changing or destructive Ghostty actions.

`focus` and `new-tab` bring Ghostty to the front. Starting Ghostty can also
bring it to the front when the first window is created. `perform-action`
activation depends on the selected action; other current commands do not
explicitly activate Ghostty.

The CLI targets the scripting dictionary shipped by Ghostty tip.

## Development

Select Xcode for command-line tools, install the pinned development tools with
[mise](https://mise.jdx.dev/), then run the same checks as CI:

```sh
mise install
mise run check
```

See the [Ghostty AppleScript documentation](https://ghostty.org/docs/features/applescript)
for the underlying object model and action semantics.

## License

[MIT](LICENSE). This project is not affiliated with or endorsed by the Ghostty
project.
