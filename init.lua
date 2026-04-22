--[[
MoveSpace: Move focused window to another macOS Space (Desktop),
handling apps that need special drag logic (Electron, JetBrains, Slack, etc).
--]]

local obj = {}
obj.__index = obj

local hotkey = require "hs.hotkey"
local window = require "hs.window"
local spaces = require "hs.spaces"
local hsee = hs.eventtap.event
local hst  = hs.timer

-- Apps that need a zero-delta mouseDragged event to register the grab state
local DRAG_BUNDLE_IDS = {
  ["com.jetbrains.intellij"]    = true,
  ["com.jetbrains.WebStorm"]    = true,
  ["com.jetbrains.PyCharm"]     = true,
  ["com.jetbrains.CLion"]       = true,
  ["com.jetbrains.Rider"]       = true,
  ["com.jetbrains.DataGrip"]    = true,
  ["com.jetbrains.RubyMine"]    = true,
  ["com.tinyspeck.slackmacgap"] = true,
}

-- Standard apps only need mouseDown held, but macOS must process it before the
-- space switch fires — SWITCH_US is the gap that prevents the timing race.
local GRAB_US       = 60000  -- µs between mouseDown and mouseDragged (drag apps only)
local SWITCH_US     = 80000  -- µs between grab-complete and switchSpace (all apps)
local RELEASE_US    = 20000  -- µs before mouseUp after window confirmed moved
local POLL_INTERVAL = 0.05   -- s: polling frequency for window-moved check
local POLL_TIMEOUT  = 2.0    -- s: give up if window hasn't moved

local moveInProgress = false

local function appNeedsDrag(win)
  local app = win and win:application()
  return app and DRAG_BUNDLE_IDS[app:bundleID()] or false
end

local function windowIsSticky(win)
  local ids = spaces.windowSpaces(win)
  return type(ids) == "table" and #ids > 1
end

local function getUserSpaces(win)
  local uuid = win:screen():getUUID()
  local all  = spaces.allSpaces()[uuid]
  if not all then return nil end
  local filtered = {}
  for _, id in ipairs(all) do
    if spaces.spaceType(id) == "user" then table.insert(filtered, id) end
  end
  return filtered
end

local function getValidWindow()
  local win = window.focusedWindow()
  if not win or not win:isStandard() or win:isFullScreen() then return nil end
  return win
end

local function switchSpace(dir)
  hs.eventtap.keyStroke({"ctrl", "fn"}, dir, 0)
end

-- Returns the adjacent space ID, or nil if already at the boundary
local function getTargetSpace(userSpaces, currentSpace, dir)
  for i, id in ipairs(userSpaces) do
    if id == currentSpace then
      return userSpaces[dir == "right" and i + 1 or i - 1]
    end
  end
  return nil
end

local function safeDragPoint(win)
  local zbr = win:zoomButtonRect()
  if not zbr then return nil end
  local pt = hs.geometry(zbr):move({15, -1}).topleft
  -- Clamp below the menu bar so the event lands inside the window
  local sf = win:screen():frame()
  pt.y = math.max(sf.y + 2, pt.y)
  return pt
end

local function performMove(win, initialSpace, dir)
  local prevCursor = hs.mouse.getRelativePosition()
  local dragPoint  = safeDragPoint(win)
  if not dragPoint then
    moveInProgress = false
    return
  end

  -- Grab the window: mouseDown on title bar, then settle before switching space.
  -- Drag apps also need a zero-delta mouseDragged to engage their grab state.
  hsee.newMouseEvent(hsee.types.leftMouseDown, dragPoint):post()
  if appNeedsDrag(win) then
    hs.timer.usleep(GRAB_US)
    hsee.newMouseEvent(hsee.types.leftMouseDragged, dragPoint):post()
  end
  hs.timer.usleep(SWITCH_US)

  switchSpace(dir)

  local deadline = hst.secondsSinceEpoch() + POLL_TIMEOUT
  hst.waitUntil(
    function()
      if hst.secondsSinceEpoch() >= deadline then return true end
      local cur = spaces.windowSpaces(win)
      return cur and cur[1] and cur[1] ~= initialSpace
    end,
    function()
      hs.timer.usleep(RELEASE_US)
      hsee.newMouseEvent(hsee.types.leftMouseUp, dragPoint):post()
      hs.mouse.setRelativePosition(prevCursor)
      moveInProgress = false
    end,
    POLL_INTERVAL
  )
end

function obj.moveWindowOneSpace(dir)
  if moveInProgress then return end

  local win = getValidWindow()
  if not win or windowIsSticky(win) then return end

  local userSpaces    = getUserSpaces(win)
  local initialSpaces = spaces.windowSpaces(win)
  local initialSpace  = initialSpaces and initialSpaces[1]
  if not initialSpace or not userSpaces then return end

  local targetSpace = getTargetSpace(userSpaces, initialSpace, dir)
  if not targetSpace then return end

  moveInProgress = true
  performMove(win, initialSpace, dir)
end

function obj:start()
  local mash = {"shift", "ctrl"}
  hotkey.bind(mash, "2", function() obj.moveWindowOneSpace("right") end)
  hotkey.bind(mash, "1", function() obj.moveWindowOneSpace("left") end)
  return self
end

return obj
