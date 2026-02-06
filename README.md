# Ttak (딱)

A lightweight macOS menu bar app that eliminates the input source switching delay. Switch between Korean and English instantly.

## Problem

macOS introduces a ~0.2-0.3 second delay when using Caps Lock to toggle input sources. The OS needs time to distinguish a "tap" (switch input) from a "long press" (Caps Lock). This delay causes frequent typing errors during fast input.

## How Ttak Solves It

Ttak installs a low-level event tap (`CGEventTap`) to intercept key events before the OS processes them. When it detects a tap of the trigger key, it immediately switches the input source — bypassing the OS delay entirely.

## Features

- **Zero delay** — Input source switches instantly on key tap
- **Menu bar app** — Lives in the menu bar, no Dock icon
- **Lightweight** — Under 5MB memory, 0% idle CPU, ~100KB binary
- **Zero config** — Works immediately with Right Command as the trigger key
- **CJKV-safe** — Detects `TISSelectInputSource` failures and auto-falls back to shortcut simulation
- **Caps Lock support** — Use Caps Lock as the trigger key (LED toggle suppressed)

## Installation

### Homebrew Cask (Recommended)

```bash
brew tap ongjin/ttak
brew install --cask ttak
```

### Build from Source

```bash
git clone https://github.com/ongjin/ttak.git
cd ttak
./scripts/build-app.sh
open .build/Ttak.app
```

Or install to /Applications:

```bash
./scripts/install.sh
```

## First Run: Grant Accessibility Permission

On first launch, Ttak will ask for Accessibility permission.

1. Click **"Open System Settings"** in the alert dialog
2. Find **Ttak** in the Accessibility list and **enable** it
3. Ttak will activate automatically — no restart needed

> Without this permission, Ttak cannot intercept keyboard events.

## Menu Bar

After launching, a keyboard icon (⌨) appears in the menu bar. Click it to see:

- **Status** — Active, Waiting for Permission, or Error
- **Input sources** — The two sources being toggled (e.g., English ↔ Korean)
- **Trigger key** — Which key triggers the toggle
- **Quit** — Stop Ttak

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
  "debounceInterval": 100
}
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `triggerKey` | `"rightCommand"` | `"rightCommand"`, `"capsLock"`, or `"rightOption"` |
| `inputSources` | ABC / Korean 2-Set | Two input source IDs to toggle between |
| `holdThreshold` | `300` (ms) | Max press duration to register as a tap |
| `debounceInterval` | `100` (ms) | Min interval between consecutive toggles |

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
2. The state machine detects clean taps (no other key pressed, within hold threshold)
3. On a clean tap, `TISSelectInputSource` switches the input source
4. If verification fails 3 consecutive times (CJKV bug), falls back to simulating Fn+Space

## Uninstall

```bash
# Homebrew
brew uninstall --cask ttak

# Manual
./scripts/uninstall.sh
```

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permission

## Tech Stack

- **Language**: Swift 5.9
- **Frameworks**: AppKit, CoreGraphics, Carbon
- **Build**: Swift Package Manager + build script

## Known Limitations

- **Secure Input**: Cannot intercept keys in password fields (macOS security policy)
- **Two sources only**: Toggles between exactly 2 configured input sources
- **Remote Desktop**: May not function over remote desktop sessions

## License

MIT
