# MoveSpace.spoon

A [Hammerspoon](https://www.hammerspoon.org/) Spoon that moves the focused window one macOS Space (Desktop) to the left or right, following the window there automatically.

## Features

- `Shift+Ctrl+2` — move focused window one Space to the right
- `Shift+Ctrl+1` — move focused window one Space to the left
- Silently skips if already at the first or last Space
- Restores the cursor to its original position after each move

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

Moving a window between Spaces is simulated by holding a synthetic `leftMouseDown` on the title bar while firing the Ctrl+Arrow space-switch shortcut, then releasing with `leftMouseUp`. macOS moves the grabbed window to the new Space.

### App-specific behaviour (`APP_CONFIG`)

Some apps need extra events before the space switch will take effect:

**preDrag apps** (Electron, JetBrains IDEs, Slack, iTerm2): require a zero-delta `leftMouseDragged` event after `leftMouseDown` to engage their internal grab state before the switch fires. Without it, their custom event loops don't register the window as grabbed in time.

**`btnYOffset`** (iTerm2 only): iTerm2's title bar is narrow and sits directly above the tab bar. The drag point is placed a fixed number of pixels *below* the traffic-light buttons rather than beside them, to land in a reliably draggable region.

All other apps work with a plain `leftMouseDown` held for 80 ms.

## API

| Method | Description |
|--------|-------------|
| `:start()` | Bind the `Shift+Ctrl+1/2` hotkeys |
| `obj.moveWindowOneSpace(dir)` | Move focused window in direction `"left"` or `"right"` |

## License

MIT
