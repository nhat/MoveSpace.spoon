local obj = {}
obj.__index = obj

-- Metadata
obj.name = "MoveSpace"
obj.version = "1.0"
obj.author = "Converted from user script"
obj.license = "MIT"

-- Dependencies
local hotkey = require "hs.hotkey"
local window = require "hs.window"
local spaces = require "hs.spaces"
local hse, hsee, hst = hs.eventtap, hs.eventtap.event, hs.timer

-- Apps needing true mouse drag workaround
local needsDragForSpaceMoveBundleIDs = {
  ["com.jetbrains.intellij"] = true,
  ["com.jetbrains.WebStorm"] = true,
  ["com.jetbrains.PyCharm"] = true,
  ["com.jetbrains.CLion"] = true,
  ["com.jetbrains.Rider"] = true,
  ["com.jetbrains.DataGrip"] = true,
  ["com.jetbrains.RubyMine"] = true,
  ["com.tinyspeck.slackmacgap"] = true,
  -- add more bundle IDs if needed
}

local function needsDragForSpaceMove(win)
  if not win then
    return false
  end
  local app = win:application()
  if not app then
    return false
  end
  return needsDragForSpaceMoveBundleIDs[app:bundleID()] or false
end

local function switchSpace(skip, dir)
  for i = 1, skip do
    hs.eventtap.keyStroke({"ctrl", "fn"}, dir, 0) -- "fn" is a bugfix!
  end
end

local function getGoodFocusedWindow(nofull)
  local win = window.focusedWindow()
  if not win or not win:isStandard() then
    return
  end
  if nofull and win:isFullScreen() then
    return
  end
  return win
end

-- Enhanced drag for non-standard apps
local function simulateWindowDrag(win)
  local zoomRect = hs.geometry(win:zoomButtonRect())
  local dragStart = zoomRect:move({15, -1}).topleft
  local dragEnd = {x = dragStart.x + 1, y = dragStart.y}
  -- Mouse down at dragStart
  hsee.newMouseEvent(hsee.types.leftMouseDown, dragStart):post()
  hs.timer.usleep(15000)
  hsee.newMouseEvent(hsee.types.leftMouseDragged, dragEnd):post()
  hs.timer.usleep(15000)
  return dragEnd
end

function obj.moveWindowOneSpace(dir)
  local win = getGoodFocusedWindow(true)
  if not win then return end

  local screen = win:screen()
  local uuid = screen:getUUID()
  local userSpaces = nil
  for k, v in pairs(spaces.allSpaces()) do
    userSpaces = v
    if k == uuid then break end
  end
  if not userSpaces then return end
  for i = #userSpaces, 1, -1 do
    if spaces.spaceType(userSpaces[i]) ~= "user" then
      table.remove(userSpaces, i)
    end
  end
  if not userSpaces then return end

  local initialSpace = spaces.windowSpaces(win)
  if not initialSpace then return else initialSpace = initialSpace[1] end

  if not ((dir == "right" and initialSpace == userSpaces[#userSpaces]) or (dir == "left" and initialSpace == userSpaces[1])) then
    local currentCursor = hs.mouse.getRelativePosition()
    local dragEnd = nil
    local dragStart = nil

    if needsDragForSpaceMove(win) then
      dragEnd = simulateWindowDrag(win)
    else
      local zoomRect = hs.geometry(win:zoomButtonRect())
      dragStart = zoomRect:move({15, -1}).topleft
      hsee.newMouseEvent(hsee.types.leftMouseDown, dragStart):post()
    end

    switchSpace(1, dir)

    hst.waitUntil(
      function() return spaces.windowSpaces(win)[1] ~= initialSpace end,
      function()
        hs.timer.usleep(10000)
        if needsDragForSpaceMove(win) and dragEnd then
          hsee.newMouseEvent(hsee.types.leftMouseUp, dragEnd):post()
        else
          hsee.newMouseEvent(hsee.types.leftMouseUp, dragStart):post()
        end
        hs.mouse.setRelativePosition(currentCursor)
      end,
      0.05
    )
  end
end

-- Spoon Initialization
function obj:start()
  mash = {"shift", "ctrl"}
  hotkey.bind( mash, "2", function() obj.moveWindowOneSpace("right", true) end)
  hotkey.bind( mash, "1", function() obj.moveWindowOneSpace("left", true) end)
end

return obj
