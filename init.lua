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

-- Per-app drag configuration.
-- btnYOffset: drag point is horizontally centered on the zoom button, this many
--   px below its bottom edge (zbr.y + zbr.h + offset). Omit to use the default
--   strategy: 15px right and 1px above the zoom button top-left.
-- preDrag: fire a zero-delta mouseDragged before the space switch to engage the
--   app's grab state (needed for Electron IPC / JetBrains event loop latency).
local APP_CONFIG = {
  ["com.googlecode.iterm2"]     = { btnYOffset = 15, preDrag = true },
  ["com.jetbrains.intellij"]    = { preDrag = true },
  ["com.jetbrains.WebStorm"]    = { preDrag = true },
  ["com.jetbrains.PyCharm"]     = { preDrag = true },
  ["com.jetbrains.CLion"]       = { preDrag = true },
  ["com.jetbrains.Rider"]       = { preDrag = true },
  ["com.jetbrains.DataGrip"]    = { preDrag = true },
  ["com.jetbrains.RubyMine"]    = { preDrag = true },
  ["com.tinyspeck.slackmacgap"] = { preDrag = true },
}

local GRAB_US       = 60000  -- µs between mouseDown and mouseDragged (drag apps only)
local SWITCH_US     = 80000  -- µs between grab-complete and switchSpace (all apps)
local RELEASE_US    = 2000   -- µs before mouseUp after window confirmed moved
local POLL_INTERVAL = 0.05   -- s: polling frequency for window-moved check
local POLL_TIMEOUT  = 2.0    -- s: give up if window hasn't moved

local moveInProgress = false

local function getBundleID(win)
  local app = win and win:application()
  return app and app:bundleID()
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

local function getTargetSpace(userSpaces, currentSpace, dir)
  for i, id in ipairs(userSpaces) do
    if id == currentSpace then
      return userSpaces[dir == "right" and i + 1 or i - 1]
    end
  end
  return nil
end

local function safeDragPoint(win, cfg)
  local zbr = win:zoomButtonRect()
  if not zbr then return nil end
  if cfg and cfg.btnYOffset then
    return {
      x = zbr.x + math.floor(zbr.w / 2),
      y = zbr.y + zbr.h + cfg.btnYOffset,
    }
  end
  local sf = win:screen():frame()
  local pt = hs.geometry(zbr):move({15, -1}).topleft
  pt.y = math.max(sf.y + 2, pt.y)
  return pt
end

local function performMove(win, cfg, initialSpace, dir)
  local prevCursor = hs.mouse.getRelativePosition()
  local dragPoint  = safeDragPoint(win, cfg)
  if not dragPoint then
    moveInProgress = false
    return
  end

  hsee.newMouseEvent(hsee.types.leftMouseDown, dragPoint):post()
  if cfg and cfg.preDrag then
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
  if not win then return end

  local initialSpaces = spaces.windowSpaces(win)
  if type(initialSpaces) ~= "table" or #initialSpaces > 1 then return end
  local initialSpace = initialSpaces[1]

  local userSpaces = getUserSpaces(win)
  if not userSpaces then return end

  if not getTargetSpace(userSpaces, initialSpace, dir) then return end

  local cfg = APP_CONFIG[getBundleID(win)]
  moveInProgress = true
  performMove(win, cfg, initialSpace, dir)
end

function obj:start()
  local mash = {"shift", "ctrl"}
  hotkey.bind(mash, "2", function() obj.moveWindowOneSpace("right") end)
  hotkey.bind(mash, "1", function() obj.moveWindowOneSpace("left") end)
  return self
end

return obj
