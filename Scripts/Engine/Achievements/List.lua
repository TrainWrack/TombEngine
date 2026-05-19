--- Achievement list viewer.
-- Opens in FULL freeze mode and renders all achievements as scrollable blocks.
-- A progress bar and a percentage label are drawn at the top of the screen.
-- Hidden achievements that are still locked are collected into a single summary
-- line at the bottom of the list rather than shown individually.
-- @module Engine.Achievements.List
-- @local

local Settings    = require("Engine.Achievements.Settings")
local Block       = require("Engine.Achievements.Block")
local InputModule = require("Engine.Achievements.Input")

local List = {}

-- ============================================================================
-- State
-- ============================================================================

local Defs        = nil   -- injected via List.Init()
local visible     = false
local displayList = {}    -- built each time the list opens
local scrollOffset = 0    -- current scroll position in screen percent
local maxScroll    = 0    -- maximum scroll position

-- Arrow alpha state (smoothly fade in/out).
local arrowUpAlpha   = 0
local arrowDownAlpha = 0

-- ============================================================================
-- Internal helpers
-- ============================================================================

local function PlaySound(soundId)
    if soundId and soundId > 0 then
        
        if not TEN.Sound.IsSoundPlaying(soundId) then
            TEN.Sound.PlaySound(soundId)
        end
    end
end

local function CountUnlocked()
    local count = 0
    for _, def in ipairs(Defs) do
        if GameVars.Engine.Achievements.unlocked[def.id] then
            count = count + 1
        end
    end
    return count
end

local function BuildDisplayList()
    displayList = {}
    local hiddenLockedCount = 0

    for _, def in ipairs(Defs) do
        local isUnlocked = GameVars.Engine.Achievements.unlocked[def.id] == true
        if def.hidden and not isUnlocked then
            hiddenLockedCount = hiddenLockedCount + 1
        else
            displayList[#displayList + 1] = { def = def, isUnlocked = isUnlocked }
        end
    end

    -- Append a summary entry for still-locked hidden achievements.
    if hiddenLockedCount > 0 then
        displayList[#displayList + 1] = { isSummary = true, count = hiddenLockedCount }
    end
end

local function StepAlpha(current, target, speed)
    if current < target then
        return math.min(current + speed, target)
    else
        return math.max(current - speed, target)
    end
end

local function DrawArrow(rot, x, y, alpha)
    if alpha <= 0 then return end
    local L      = Settings.List
    local color  = TEN.Color(L.arrowColor.r, L.arrowColor.g, L.arrowColor.b, math.floor(alpha))
    local sprite = TEN.View.DisplaySprite(L.arrowObjectId, L.arrowSpriteId,
                                           TEN.Vec2(x, y), rot, L.arrowSize, color)
    sprite:Draw(2, L.arrowAlignMode, L.arrowScaleMode, L.arrowBlendMode)
end

local function DrawProgressBar()
    local total    = (#Defs > 0) and #Defs or 1
    local unlocked = CountUnlocked()
    local progress = unlocked / total   -- 0.0 to 1.0
    local pct      = math.floor(progress * 100)

    local PB = Settings.ProgressBar

    -- Background sprite
    local bgSprite = TEN.View.DisplaySprite(PB.bgObjectId, PB.bgSpriteId,
                                             PB.bgPos, 0, PB.bgSize, PB.bgColor)
    bgSprite:Draw(0, PB.bgAlignMode, PB.bgScaleMode, PB.bgBlendMode)

    -- Fill sprite (width scaled by progress)
    if progress > 0 then
        local fillSize   = TEN.Vec2(PB.fillMaxSize.x * progress, PB.fillMaxSize.y)
        local fillSprite = TEN.View.DisplaySprite(PB.fillObjectId, PB.fillSpriteId,
                                                   PB.fillPos, 0, fillSize, PB.fillColor)
        fillSprite:Draw(1, PB.fillAlignMode, PB.fillScaleMode, PB.fillBlendMode)
    end

    -- Label text: "3 / 10  (30%)"
    local labelText = unlocked .. " / " .. total .. "  (" .. pct .. "%)"
    local px        = TEN.Vec2(TEN.Util.PercentToScreen(PB.labelPos.x, PB.labelPos.y))
    local str       = TEN.Strings.DisplayString(labelText, px,
                                                 PB.labelScale, PB.labelColor,
                                                 false, PB.labelOptions)
    TEN.Strings.ShowString(str, 1 / 30)
end

-- ============================================================================
-- Public
-- ============================================================================

--- Inject the definitions array. Called by Achievements.lua after loading the
-- setup file.
-- @tparam table defs  Ordered array of achievement definition tables.
function List.Init(defs)
    Defs = defs
end

--- Returns true while the list is open (game is frozen).
-- @treturn bool
function List.IsVisible()
    return visible
end

--- Open the achievement list. Enters FULL freeze mode.
function List.Open()
    if visible then return end
    if not Defs then return end

    BuildDisplayList()
    scrollOffset = 0

    -- Calculate maximum scroll so the last row is fully visible.
    local L            = Settings.List
    local totalRows    = math.ceil(#displayList / 2)
    local visibleCount = math.max(1, math.floor((100 - L.startY) / L.blockSpacing))
    maxScroll = math.max(0, (totalRows - visibleCount) * L.blockSpacing)

    InputModule.Reset()
    TEN.Input.ClearAllKeys()
    TEN.Flow.SetFreezeMode(TEN.Flow.FreezeMode.FULL)
    PlaySound(Settings.SoundMap.openList)
    visible = true
end

--- Close the list. Exits freeze mode.
function List.Close()
    if not visible then return end

    InputModule.Reset()
    arrowUpAlpha   = 0
    arrowDownAlpha = 0
    TEN.Input.ClearAllKeys()
    PlaySound(Settings.SoundMap.closeList)
    visible = false
    TEN.Flow.SetFreezeMode(TEN.Flow.FreezeMode.NONE)
end

--- Update scroll offset and handle exit input. Intended for the PREFREEZE callback.
function List.Tick()
    if not visible then return end

    -- Exit
    if TEN.Input.IsKeyHit(Settings.List.exitAction) then
        List.Close()
        return
    end

    -- Scroll with acceleration; only play sound when actually moving.
    local delta      = InputModule.GetScrollDelta()
    local prevOffset = scrollOffset
    scrollOffset = math.max(0, math.min(maxScroll, scrollOffset + delta))
    if scrollOffset ~= prevOffset then
        PlaySound(Settings.SoundMap.scroll)
    end

    -- Update arrow alphas.
    local L = Settings.List
    arrowUpAlpha   = StepAlpha(arrowUpAlpha,   scrollOffset > 0          and 255 or 0, L.arrowFadeSpeed)
    arrowDownAlpha = StepAlpha(arrowDownAlpha, scrollOffset < maxScroll   and 255 or 0, L.arrowFadeSpeed)
end

--- Draw all achievement blocks and the progress bar. Intended for the PREFREEZE callback.
function List.Draw()
    if not visible then return end

    local L = Settings.List

    DrawProgressBar()

    -- Scroll arrows (left side of screen, up arrow rotated 180° vs down arrow)
    DrawArrow(180, L.arrowUpX, L.arrowUpY,   arrowUpAlpha)
    DrawArrow(0,   L.arrowUpX, L.arrowDownY, arrowDownAlpha)

    for i, entry in ipairs(displayList) do
        -- Two-column layout: odd entries go left, even entries go right.
        -- Both entries in the same pair share the same row Y.
        local row    = math.ceil(i / 2)
        local col    = ((i - 1) % 2)           -- 0 = left, 1 = right
        local blockX = (col == 0) and L.col1X or L.col2X
        local blockY = L.startY + (row - 1) * L.blockSpacing - scrollOffset

        -- Cull rows that are entirely off-screen.
        if blockY >= -8 and blockY <= 108 then
            if entry.isSummary then
                -- Summary spans the full width; centre it.
                local text  = string.gsub(L.hiddenCountText, "{n}", tostring(entry.count))
                local px    = TEN.Vec2(TEN.Util.PercentToScreen((L.col1X + L.col2X) / 2, blockY))
                local str   = TEN.Strings.DisplayString(text, px,
                                                         L.hiddenTextScale, L.hiddenTextColor,
                                                         false, L.hiddenTextOptions)
                TEN.Strings.ShowString(str, 1 / 30)
            else
                Block.Draw(entry.def, entry.isUnlocked, blockX, blockY, 255)
            end
        end
    end
end

return List
