--External Modules
local Constants = require("Engine.RingInventory.Constants")
local Ring
local Settings = require("Engine.RingInventory.Settings")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP

--CONSTANTS
local BG_LAYER = 0
local ALPHA_SPEED = Constants.TEXT_ALPHA_SPEED

-- Background state
local bgAlpha  = 0
local bgTarget = 0

-- Arrows state
local arrowUpAlpha    = 0
local arrowUpTarget   = 0
local arrowDownAlpha  = 0
local arrowDownTarget = 0
local arrowVisible = true

local Sprites = {}

-- ============================================================
--  Private
-- ============================================================

local function DrawArrow(list, alpha)
    for _, entry in ipairs(list) do
        local entrySprite = TEN.View.DisplaySprite(
            TEN.Objects.ObjID.MISC_SPRITES,
            3,
            entry[2],
            entry[1],
            Vec2(3, 3),
            Utilities.ColorCombine(COLOR_MAP.NORMAL_FONT, alpha)
        )
        entrySprite:Draw(-8, View.AlignMode.CENTER, View.ScaleMode.FIT, TEN.Effects.BlendID.ALPHA_BLEND)
    end
end

local function DrawArrows()
    
    local arrowsUp = {
        {0, Vec2(5, 5)},
        {0, Vec2(95, 5)},
    }

    local arrowsDown = {
        {180, Vec2(5, 95)},
        {180, Vec2(95, 95)},
    }

    if arrowUpAlpha > 0 then
        DrawArrow(arrowsUp, arrowUpAlpha)
    end

    if arrowDownAlpha > 0 then
        DrawArrow(arrowsDown, arrowDownAlpha)
    end

end

local function DrawBackground(alpha)

    if Settings.BACKGROUND.ENABLE then
        local capped    = math.min(alpha, Settings.BACKGROUND.ALPHA)
        local bgColor   = Utilities.ColorCombine(Settings.BACKGROUND.COLOR, capped)
        local bgSprite  = TEN.View.DisplaySprite(
            Settings.BACKGROUND.OBJECTID,
            Settings.BACKGROUND.SPRITEID,
            Settings.BACKGROUND.POSITION,
            Settings.BACKGROUND.ROTATION,
            Settings.BACKGROUND.SCALE,
            bgColor
        )
        bgSprite:Draw(BG_LAYER, Settings.BACKGROUND.ALIGN_MODE, Settings.BACKGROUND.SCALE_MODE, Settings.BACKGROUND.BLEND_MODE)
    end

end

-- ============================================================
--  Background controls
-- ============================================================

function Sprites.ShowBackground()
    bgTarget = 255
end

function Sprites.HideBackground()
    bgTarget = 0
end

-- ============================================================
--  Arrows controls
-- ============================================================

function Sprites.ShowArrows()
    arrowVisible = true
    arrowUpTarget   = 255
    arrowDownTarget = 255
end

function Sprites.HideArrows()
    arrowVisible = false
    arrowUpTarget   = 0
    arrowDownTarget = 0
end

function Sprites.ShowArrowsUp()
    arrowUpTarget = 255
end

function Sprites.HideArrowsUp()
    arrowUpTarget = 0
end

function Sprites.ShowArrowsDown()
    arrowDownTarget = 255
end

function Sprites.HideArrowsDown()
    arrowDownTarget = 0
end

-- ============================================================
--  Update
-- ============================================================

local function StepAlpha(current, target)
    if current < target then
        return math.min(current + ALPHA_SPEED, target)
    elseif current > target then
        return math.max(current - ALPHA_SPEED, target)
    end
    return current
end

function Sprites.Update(selectedRing)
    
    if not Ring then
        Ring = require("Engine.RingInventory.Ring")
    end

    if arrowVisible then
        -- Up arrows hide on PUZZLE, COMBINE, AMMO
        if selectedRing == Ring.TYPE.PUZZLE or
        selectedRing == Ring.TYPE.COMBINE or
        selectedRing == Ring.TYPE.AMMO then
            arrowUpTarget = 0
        else
            arrowUpTarget = 255
        end

        -- Down arrows hide on OPTIONS, COMBINE, AMMO
        if selectedRing == Ring.TYPE.OPTIONS or
        selectedRing == Ring.TYPE.COMBINE or
        selectedRing == Ring.TYPE.AMMO then
            arrowDownTarget = 0
        else
            arrowDownTarget = 255
        end
    end
    
    bgAlpha        = StepAlpha(bgAlpha,        bgTarget)
    arrowUpAlpha   = StepAlpha(arrowUpAlpha,   arrowUpTarget)
    arrowDownAlpha = StepAlpha(arrowDownAlpha, arrowDownTarget)
end

-- ============================================================
--  Draw — call after Update
-- ============================================================

function Sprites.Draw()
    if bgAlpha > 0 then
        DrawBackground(bgAlpha)
    end

    DrawArrows()
end

-- ============================================================
--  Clear — snap both to hidden instantly
-- ============================================================

function Sprites.Clear()
    bgAlpha         = 0
    bgTarget        = 0
    arrowUpAlpha    = 0
    arrowUpTarget   = 0
    arrowDownAlpha  = 0
    arrowDownTarget = 0
    arrowVisible = false
end

return Sprites