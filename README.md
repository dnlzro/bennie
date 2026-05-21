# Bennie

Set a solid colour wallpaper that changes automatically based on the system's appearance.

Generates a minimal 1px HEIC image with light/dark appearance metadata. Once set, macOS handles appearance switching natively (no background process required).

## Installation

Download a **pre-built binary** from the [releases page](https://github.com/anomalyco/bennie/releases/latest).

> [!NOTE]
> To avoid macOS Gatekeeper warnings (which may prevent the binary from running), use `xattr -d com.apple.quarantine bennie`.

Or, you can **build from source**:

```bash
swift build -c release
```

After building, the binary will be at `.build/release/bennie`. You can also run directly with `swift run -c release`.

## Quick start

Create a config file at `~/.config/bennie/config.json`:

```json
{"light": "#F9F9F9", "dark": "#191919"}
```

Then apply it:

```bash
bennie
```

## Usage

Override colours inline (bypassing the config file):

```bash
bennie --light "#F2F2F2" --dark "#1A1A1A"
```

Use a custom config path:

```bash
bennie --config ~/.wallpaper.json
```

## How it works

Generates a two-image HEIC with `apple_desktop:apr` XMP metadata (`{"l":0,"d":1}`) telling macOS which image is light mode and which is dark.

## Alternatives

You may find one of these alternatives a better fit for your needs:

- [Equinox](https://github.com/rlxone/Equinox)
  - Graphical user interface
  - Many more features (e.g., time-based and solar position-based transitions)
- [Umbra](https://replay.software/umbra)
  - Graphical user interface
  - Requires background process for wallpaper switching
  - Closed-source

## Credits

Metadata formatting and encoding code derived from [Equinox](https://github.com/rlxone/Equinox).

Name inspired by [Elton John](https://youtu.be/p5rQHoaQpTw?si=7HmhTzlRPOdXv_nN&t=40).
