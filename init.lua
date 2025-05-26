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

function obj.moveWindowOneSpace(dir)
  local win = getGoodFocusedWindow(true)
  if not win then
    return
  end
  local screen = win:screen()
  local uuid = screen:getUUID()
  local userSpaces = nil
  for k, v in pairs(spaces.allSpaces()) do
    userSpaces = v
    if k == uuid then
      break
    end
  end
  if not userSpaces then
    return
  end

  for i = #userSpaces, 1, -1 do
    if spaces.spaceType(userSpaces[i]) ~= "user" then
      table.remove(userSpaces, i)
    end
  end
  if not userSpaces then
    return
  end

  local initialSpace = spaces.windowSpaces(win)
  if not initialSpace then
    return
  else
    initialSpace = initialSpace[1]
  end

  if not ((dir == "right" and initialSpace == userSpaces[#userSpaces]) or (dir == "left" and initialSpace == userSpaces[1])) then
    local currentCursor = hs.mouse.getRelativePosition()
    local zoomPoint = hs.geometry(win:zoomButtonRect())
    local safePoint = zoomPoint:move({-1, -1}).topleft
    hsee.newMouseEvent(hsee.types.leftMouseDown, safePoint):post()
    switchSpace(1, dir)

    hst.waitUntil(
      function()
        return spaces.windowSpaces(win)[1] ~= initialSpace
      end,
      function()
        hsee.newMouseEvent(hsee.types.leftMouseUp, safePoint):post()
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
