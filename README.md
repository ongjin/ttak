# Ttak (딱)

A lightweight macOS daemon that eliminates the input source switching delay. Switch between Korean and English instantly.

## Problem

macOS introduces a ~0.2-0.3 second delay when using Caps Lock to toggle input sources. The OS needs time to distinguish a "tap" (switch input) from a "long press" (Caps Lock). This delay causes frequent typing errors during fast input.

## How Ttak Solves It

Ttak installs a low-level event tap (`CGEventTap`) to intercept key events before the OS processes them. When it detects a tap of the trigger key, it immediately switches the input source via the Carbon `TISSelectInputSource` API — bypassing the OS delay entirely.

If the Carbon API fails (a known macOS bug with CJKV input sources), Ttak automatically falls back to simulating the system shortcut key (Fn+Space).

## Features

- **Zero delay** — Input source switches instantly on key tap
- **Lightweight** — Under 5MB memory, 0% idle CPU, ~100KB binary
- **Zero config** — Works immediately with Right Command as the trigger key
- **CJKV-safe** — Detects `TISSelectInputSource` failures and auto-falls back to shortcut simulation
- **Caps Lock support** — Use Caps Lock as the trigger key (LED toggle suppressed)
- **Homebrew ready** — Install and manage via `brew services`

## Installation

### Homebrew

```bash
brew tap user/ttak
brew install ttak
```

Start the service (runs at login automatically):

```bash
brew services start ttak
```

### Build from Source

```bash
git clone https://github.com/user/ttak.git
cd ttak
swift build -c release
sudo cp .build/release/ttak /usr/local/bin/
```

Or use the install script:

```bash
./scripts/install.sh
```

## First Run: Grant Accessibility Permission

Ttak needs Accessibility permission to intercept keyboard events. On first launch, macOS will prompt you to grant access.

1. Open **System Settings**
2. Go to **Privacy & Security > Accessibility**
3. Find `ttak` in the list and **enable** it
4. Restart ttak (`brew services restart ttak` or kill and relaunch)

> Without this permission, Ttak cannot create the event tap and will exit with an error.

## Usage

```bash
# Run directly (foreground)
ttak

# Run with debug logging
ttak --verbose

# Use a custom config file
ttak --config ~/my-config.json

# Print version
ttak --version
```

For production use, run via `brew services` or as a LaunchAgent.

## Configuration

Config file: `~/.config/ttak/config.json` (optional — Ttak works without it)

```json
{
  "triggerKey": "rightCommand",
  "inputSources": [
    "com.apple.keylayout.ABC",
    "com.apple.inputmethod.Korean.2SetKorean"
  ],
  "holdThreshold": 300,
  "debounceInterval": 100,
  "verbose": false
}
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `triggerKey` | `"rightCommand"` | `"rightCommand"`, `"capsLock"`, or `"rightOption"` |
| `inputSources` | ABC / Korean 2-Set | Two input source IDs to toggle between |
| `holdThreshold` | `300` (ms) | Max press duration to register as a tap |
| `debounceInterval` | `100` (ms) | Min interval between consecutive toggles |
| `verbose` | `false` | Log debug info to stderr |

### Finding Your Input Source IDs

```bash
defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleEnabledInputSources
```

## How It Works

```
Key Press → CGEventTap (session level)
         → State Machine (tap vs hold, combo detection)
         → TISSelectInputSource (primary)
         → Verification (re-query current source)
         → Shortcut Simulation (fallback if TIS fails 3x)
```

1. A `CGEventTap` monitors `flagsChanged` and `keyDown` events
2. The state machine tracks whether the trigger key was tapped cleanly (no other key pressed, within hold threshold)
3. On a clean tap, `TISSelectInputSource` is called to switch the input source
4. If verification fails 3 consecutive times (CJKV bug), Ttak permanently switches to simulating Fn+Space

## Uninstall

```bash
# Homebrew
brew services stop ttak
brew uninstall ttak

# Manual
./scripts/uninstall.sh
```

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permission

## Tech Stack

- **Language**: Swift 5.9
- **Frameworks**: CoreGraphics, Carbon, ApplicationServices
- **Build**: Swift Package Manager

## Known Limitations

- **Secure Input**: Cannot intercept keys in password fields (macOS security policy)
- **Two sources only**: Toggles between exactly 2 configured input sources
- **Remote Desktop**: May not function over remote desktop sessions

## License

MIT
