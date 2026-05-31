--- Scroll input handler with hold-time acceleration for the achievement list.
-- Call Input.GetScrollDelta() once per frame inside the list tick.
-- Positive delta = scroll down (toward later entries).
-- Negative delta = scroll up (toward earlier entries).
-- @module Engine.Achievements.Input
-- @local

local Settings = require("Engine.Achievements.Settings")

local Input = {}

local holdFramesFwd  = 0
local holdFramesBack = 0

-- ============================================================================
-- Public
-- ============================================================================

--- Returns the scroll delta (screen %) for this frame and updates hold counters.
-- @treturn number Delta to add to the current scrollOffset.
function Input.GetScrollDelta()
    local L = Settings.List

    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.FORWARD) then
        holdFramesFwd  = holdFramesFwd + 1
        holdFramesBack = 0
        local speed = math.min(L.scrollSpeed + holdFramesFwd * L.scrollAccel, L.maxScrollSpeed)
        return -speed   -- FORWARD / up = negative (scroll toward top)

    elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.BACK) then
        holdFramesBack = holdFramesBack + 1
        holdFramesFwd  = 0
        local speed = math.min(L.scrollSpeed + holdFramesBack * L.scrollAccel, L.maxScrollSpeed)
        return speed    -- BACK / down = positive (scroll toward bottom)

    else
        holdFramesFwd  = 0
        holdFramesBack = 0
        return 0
    end
end

--- Reset all hold counters. Call this when the list closes.
function Input.Reset()
    holdFramesFwd  = 0
    holdFramesBack = 0
end

return Input
