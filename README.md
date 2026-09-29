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
- Ghostty 1.3.1 or a compatible later build with AppleScript enabled
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
ghosttyctl perform-action toggle_fullscreen --terminal TERMINAL_ID
```

`type` reads UTF-8 from standard input. `--enter` sends an Enter key after the
text and can start a terminal process. Successful delivery does not report the
command's exit status or terminal output. Input and action values are passed to
AppleScript as process arguments rather than interpolated into source code.

The executable uses Swift concurrency and the Swift project's `Subprocess`
package for bounded, cancellable `osascript` execution.

The CLI does not read terminal screen contents. It has no first-class close,
quit, raw-key, or mouse subcommands. `perform-action` is an explicit escape
hatch and can invoke state-changing or destructive Ghostty actions such as
`close_surface`. Only `focus` brings Ghostty to the front; other commands leave
the current application active.

Ghostty documents AppleScript as a preview feature. Compatibility is verified
against the scripting dictionary for each supported Ghostty release.

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
