--[[
MoveSpace: Move focused window to another macOS Space (Desktop),
handling apps that need special drag logic (Electron, JetBrains, Slack, etc).
--]]

local obj = {}
obj.__index = obj

-- Dependencies
local hotkey = require "hs.hotkey"
local window = require "hs.window"
local spaces = require "hs.spaces"
local hsee, hst = hs.eventtap.event, hs.timer

-- Bundles needing drag workaround
local needsDragBundleIDs = {
  ["com.jetbrains.intellij"] = true,
  ["com.jetbrains.WebStorm"] = true,
  ["com.jetbrains.PyCharm"] = true,
  ["com.jetbrains.CLion"] = true,
  ["com.jetbrains.Rider"] = true,
  ["com.jetbrains.DataGrip"] = true,
  ["com.jetbrains.RubyMine"] = true,
  ["com.tinyspeck.slackmacgap"] = true,
}

-- Utilities
local function appNeedsDrag(win)
  if not win then return false end
  local app = win:application()
  return app and needsDragBundleIDs[app:bundleID()] or false
end

local function windowIsSticky(win)
  local spaceIDs = spaces.windowSpaces(win)
  return type(spaceIDs) == "table" and #spaceIDs > 1
end

local function safeDragPoint(win)
  local rect = hs.geometry(win:zoomButtonRect())
  return rect:move({15, -1}).topleft
end

local function getUserSpaces(win)
  local screen = win:screen()
  local uuid = screen:getUUID()
  local userSpaces = spaces.allSpaces()[uuid]
  if not userSpaces then return nil end
  -- Filter to user spaces only
  local filtered = {}
  for _, id in ipairs(userSpaces) do
    if spaces.spaceType(id) == "user" then table.insert(filtered, id) end
  end
  return filtered
end

local function getValidWindow()
  local win = window.focusedWindow()
  if not win or not win:isStandard() or win:isFullScreen() then return nil end
  return win
end

local function simulateNoMoveDrag(point)
  hsee.newMouseEvent(hsee.types.leftMouseDown, point):post()
  hs.timer.usleep(15000)
  hsee.newMouseEvent(hsee.types.leftMouseDragged, point):post()
  hs.timer.usleep(15000)
end

local function simulateSimpleMouseDown(point)
  hsee.newMouseEvent(hsee.types.leftMouseDown, point):post()
end

local function switchSpace(dir)
  hs.eventtap.keyStroke({"ctrl", "fn"}, dir, 0) -- fn is for macOS to register the keys
end

local function waitForWindowMoved(win, initialSpace, dragPoint, prevCursor)
  hst.waitUntil(
    function()
      local cur = spaces.windowSpaces(win)
      return cur and cur[1] ~= initialSpace
    end,
    function()
      hs.timer.usleep(10000)
      hsee.newMouseEvent(hsee.types.leftMouseUp, dragPoint):post()
      hs.mouse.setRelativePosition(prevCursor)
    end,
    0.05
  )
end

local function canMoveWindow(userSpaces, initialSpace, dir)
  if not userSpaces or #userSpaces == 0 or not initialSpace then return false end

  local first, last = userSpaces[1], userSpaces[#userSpaces]
  if (dir == "right" and initialSpace == last) or (dir == "left" and initialSpace == first) then
    return false
  end

  return true
end

function obj.moveWindowOneSpace(dir)
  local win = getValidWindow()
  if not win or windowIsSticky(win) then return end

  local userSpaces = getUserSpaces(win)
  local initialSpaces = spaces.windowSpaces(win)
  local initialSpace = initialSpaces and initialSpaces[1] or nil

  if not canMoveWindow(userSpaces, initialSpace, dir) then return end

  local prevCursor = hs.mouse.getRelativePosition()
  local dragPoint = safeDragPoint(win)

  if appNeedsDrag(win) then
    simulateNoMoveDrag(dragPoint)
  else
    simulateSimpleMouseDown(dragPoint)
  end

  switchSpace(dir)
  waitForWindowMoved(win, initialSpace, dragPoint, prevCursor)
end

function obj:start()
  local mash = {"shift", "ctrl"}
  hotkey.bind(mash, "2", function() obj.moveWindowOneSpace("right") end)
  hotkey.bind(mash, "1", function() obj.moveWindowOneSpace("left") end)
  return self
end

return obj
