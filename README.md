# MoveSpace.spoon

A [Hammerspoon](https://www.hammerspoon.org/) Spoon that moves the focused window one macOS Space (Desktop) to the left or right, following the window there automatically.

## Features

- `Shift+Ctrl+2` — move focused window one Space to the right
- `Shift+Ctrl+1` — move focused window one Space to the left
- Silently skips if already at the first or last Space
- Handles three categories of apps differently (see below)
- Restores cursor position after a drag-based move

## Requirements

- [Hammerspoon](https://www.hammerspoon.org/) ≥ 1.0
- Accessibility permissions granted to Hammerspoon
- `hs.spaces` module (included in standard Hammerspoon builds)

## Installation

Copy `MoveSpace.spoon` into `~/.hammerspoon/Spoons/`, then add to your `init.lua`:

```lua
hs.loadSpoon("MoveSpace")
spoon.MoveSpace:start()
```

## How It Works

There are three move strategies depending on the app:

### Direct API (`SPACES_API_IDS`)
Apps that use `NSWindowStyleMaskFullSizeContentView` embed their content into the title bar area. The macOS window server has no exposed title bar region for these apps, so synthetic mouse events can never engage its window-drag tracking. Instead, `hs.spaces.moveWindowToSpace` moves the window directly at the API level.

- **iTerm2**

### Drag simulation with mouseDragged (`DRAG_BUNDLE_IDS`)
Electron and JetBrains apps have custom event loops that need an explicit `leftMouseDragged` event (at the same point as `leftMouseDown`) to register the window as grabbed before the space switch fires.

- IntelliJ IDEA, WebStorm, PyCharm, CLion, Rider, DataGrip, RubyMine
- Slack

### Standard drag simulation (all other apps)
A `leftMouseDown` on the title bar held for 80ms is enough for macOS to track the window during a space switch.

## API

| Method | Description |
|--------|-------------|
| `:start()` | Bind the `Shift+Ctrl+1/2` hotkeys |
| `obj.moveWindowOneSpace(dir)` | Move focused window in direction `"left"` or `"right"` |

## License

MIT
