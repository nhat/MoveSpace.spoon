# MoveSpace.spoon

A [Hammerspoon](https://www.hammerspoon.org/) Spoon that moves the focused window one macOS Space (Desktop) to the left or right, following the window there automatically.

## Features

- `Shift+Ctrl+2` — move focused window one Space to the right
- `Shift+Ctrl+1` — move focused window one Space to the left
- Silently skips if already at the first or last Space
- Handles apps that require a drag workaround (Electron, JetBrains IDEs, Slack) — these apps don't respond to the standard `moveToSpace` API, so the Spoon simulates a title-bar drag instead
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

## Supported Apps (Drag Workaround)

These bundle IDs trigger the drag-based move path:

- IntelliJ IDEA
- WebStorm
- PyCharm
- CLion
- Rider
- DataGrip
- RubyMine
- Slack

All other apps use the faster direct `moveToSpace` approach.

## API

| Method | Description |
|--------|-------------|
| `:start()` | Bind the `Shift+Ctrl+1/2` hotkeys |
| `obj.moveWindowOneSpace(dir)` | Move focused window in direction `"left"` or `"right"` |

## License

MIT
