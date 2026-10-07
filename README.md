# ghosttyctl

`ghosttyctl` is an unofficial, agent-friendly macOS CLI for inspecting and
controlling Ghostty through its AppleScript API.

The command surface is intentionally narrow. It uses stable Ghostty object IDs,
emits JSON for machine-driven workflows, and accepts terminal input through
standard input. The CLI executes only `/usr/bin/osascript` as a subprocess, has
no daemon or network access, and does not use Accessibility APIs or private
APIs. Terminal content capture briefly uses the general clipboard because
Ghostty exposes captured file paths through that channel.

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
ghosttyctl new-window --cwd ~/src/project
ghosttyctl new-tab --window WINDOW_ID --cwd ~/src/project
ghosttyctl split right --terminal TERMINAL_ID --cwd ~/src/project
ghosttyctl focus TERMINAL_ID
ghosttyctl set-title 'API server' --tab TAB_ID
ghosttyctl type --terminal TERMINAL_ID --enter <<'GHOSTTY_INPUT'
git status --short
GHOSTTY_INPUT
ghosttyctl close --terminal TERMINAL_ID
ghosttyctl close --tab TAB_ID
ghosttyctl close --window WINDOW_ID
ghosttyctl move-tab --tab TAB_ID --offset -1
ghosttyctl resize-split left 20 --terminal TERMINAL_ID
ghosttyctl equalize-splits --terminal TERMINAL_ID
ghosttyctl reload-config
ghosttyctl reset --terminal TERMINAL_ID
ghosttyctl undo
ghosttyctl redo
ghosttyctl capture screen --terminal TERMINAL_ID
ghosttyctl capture scrollback --terminal TERMINAL_ID
ghosttyctl capture selection --terminal TERMINAL_ID
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

`set-title` sets a persistent tab title override. An empty title clears the
override. `move-tab` addresses the tab by stable ID and preserves the previously
selected tab.

`capture` writes UTF-8 terminal content directly to standard output. Ghostty
creates a mode-0600 temporary file; the CLI accepts only its expected regular-
file path shape inside the current user's temporary directory. When Ghostty is
the only clipboard writer during capture, the CLI removes the file and its empty
directory and restores all clipboard representations in their original order.
When another write is observed, the captured file and path are left intact
instead of restoring stale clipboard contents. An empty scope emits empty
output. The scopes are the complete written buffer including scrollback
(`screen`), scrollback history excluding the current screen (`scrollback`), and
current selection.

The executable uses Swift concurrency and the Swift project's `Subprocess`
package for bounded, cancellable `osascript` execution.

Failures are JSON objects on standard error. Invalid arguments and input exit
with status 64; Ghostty, AppleScript, response, and unexpected failures exit
with status 1. The stable `error.code` is intended for automation:

```json
{
  "error": {
    "code": "invalid_arguments",
    "message": "Specify exactly one of --terminal, --tab, or --window."
  }
}
```

`close` requires exactly one stable terminal, tab, or window ID. Every scope
disappears immediately without a confirmation dialog. Its processes can remain
alive until Ghostty's undo timeout expires so the close can be undone. `undo`
and `redo` operate on Ghostty's shared, time-limited macOS lifecycle history for
windows, tabs, and splits; they are not target scoped and require a live
terminal to dispatch the action. `reload-config` is also application-wide.
`reset` can disrupt a running TUI. The CLI does not expose first-class quit,
raw-key, or mouse subcommands. `perform-action` is an explicit escape hatch and
can invoke state-changing or destructive Ghostty actions.

`focus`, `new-window`, and `new-tab` bring Ghostty to the front. Starting Ghostty
can also bring it to the front when the first window is created.
`perform-action` activation depends on the selected action; other current
commands do not explicitly activate Ghostty.

The CLI targets the scripting dictionary shipped by Ghostty tip.

## Development

[mise](https://mise.jdx.dev/) installs the pinned development tools, and
Lefthook installs the Git hooks:

```sh
mise install
mise exec -- lefthook install
mise run check
```

`mise run check` runs the same code checks as CI: the tests, a release build, a
`--version` smoke run, and the static checks. The tests need Xcode. When
`xcode-select -p` names another developer directory, select Xcode for the shell
that runs the checks and Git instead of changing the system default:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

The pre-commit hook scans the staged changes for secrets and runs
`mise run lint`. The pre-push hook runs `mise run check` and scans the committed
history for secrets on every push, including a tag push. The hooks call mise
themselves, so they work in a shell where mise is not activated.

Swift Package Manager has no dependency audit command, so dependencies are
checked on GitHub: Dependency Review checks each pull request, and Dependabot
proposes updates.

See the [Ghostty AppleScript documentation](https://ghostty.org/docs/features/applescript)
for the underlying object model and action semantics.

## Release

A maintainer releases from `main`: set `version` in
`Sources/GhosttyCtl/GhosttyCtl.swift`, merge that change, then push an annotated
tag for that version from the merged commit:

```sh
git tag -a v1.2.3 --cleanup=verbatim -F - <<'NOTES'
## Changes

- Describe a change a user will notice.
NOTES
git push origin v1.2.3
```

The tag message becomes the GitHub release notes. Git reads it from standard
input, and `--cleanup=verbatim` keeps lines that start with `#`, such as
Markdown headings, which Git otherwise strips as comments.

The tag starts the Release workflow, which verifies that the tag is annotated
and belongs to `main`, runs CI on the tagged commit, verifies that the built
executable reports the tagged version, and then publishes an immutable GitHub
release without assets. Homebrew builds from the tag, so the formula in
[Hiro5409/homebrew-tap](https://github.com/Hiro5409/homebrew-tap) moves to the
new tag separately.

To retry a failed run, re-run its failed jobs; a release already published for
the same commit passes. A tag that fails verification has no release, so delete
it, fix the cause, and push it again:

```sh
git push --delete origin v1.2.3
git tag --delete v1.2.3
```

A published release locks its tag, so a new version corrects a published
release.

## License

[MIT](LICENSE). This project is not affiliated with or endorsed by the Ghostty
project.
