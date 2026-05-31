--- Shared achievement block renderer.
-- Draws a single achievement block (background panel, icon, title, description)
-- at a given center position in screen-percent coordinates.
-- Used by both the popup notification and the list viewer.
-- @module Engine.Achievements.Block
-- @local

local Settings = require("Engine.Achievements.Settings")

local Block = {}

-- ============================================================================
-- Internal helpers
-- ============================================================================

local function DrawSprite(objectId, spriteId, pos, rot, scale, color, layer, alignMode, scaleMode, blendMode)
    local sprite = TEN.View.DisplaySprite(objectId, spriteId, pos, rot, scale, color)
    sprite:Draw(layer, alignMode, scaleMode, blendMode)
end

local function DrawText(text, offsetX, offsetY, baseX, baseY, scale, color, options)
    local px = TEN.Vec2(TEN.Util.PercentToScreen(baseX + offsetX, baseY + offsetY))
    local str = TEN.Strings.DisplayString(text, px, scale, color, false, options)
    TEN.Strings.ShowString(str, 1 / 30)
end

local function ClampAlpha(a)
    return math.floor(math.max(0, math.min(255, a)))
end

-- ============================================================================
-- Public
-- ============================================================================

--- Draw an achievement block centered at (posX, posY) in screen percent.
-- @tparam  table  def        Achievement definition {id, title, description, spriteId, hidden}.
-- @tparam  bool   isUnlocked Whether the achievement has been unlocked.
-- @tparam  number posX       Horizontal center of the block in screen percent (0-100).
-- @tparam  number posY       Vertical center of the block in screen percent (0-100).
-- @tparam  number alpha      Opacity 0-255 for the entire block.
function Block.Draw(def, isUnlocked, posX, posY, alpha)
    local B  = Settings.Block
    local IC = Settings.Icons
    local a  = ClampAlpha(alpha)

    -- isLocked:       any achievement not yet unlocked → use locked icon + grey title colour
    -- isHiddenLocked: hidden AND not unlocked → substitute title text, suppress description
    local isLocked       = not isUnlocked
    local isHiddenLocked = def.hidden and isLocked

    -- Background panel (Vec2 created here from plain numbers)
    local bgColor = TEN.Color(B.bgColor.r, B.bgColor.g, B.bgColor.b, B.bgColor.a * a / 255)
    DrawSprite(B.bgObjectId, B.bgSpriteId, TEN.Vec2(posX, posY), 0, B.bgSize, bgColor,
               0, B.bgAlignMode, B.bgScaleMode, B.bgBlendMode)

    -- Icon: locked sprite for ANY locked achievement, real sprite when unlocked
    local iconSpriteId = isLocked and IC.lockedSpriteId or def.spriteId
    local iconPos      = TEN.Vec2(posX + B.iconOffset.x, posY + B.iconOffset.y)
    local iconColor    = TEN.Color(B.iconColor.r, B.iconColor.g, B.iconColor.b, a)
    DrawSprite(IC.objectId, iconSpriteId, iconPos, 0, B.iconSize, iconColor,
               1, B.iconAlignMode, B.iconScaleMode, B.iconBlendMode)

    -- Title text: "Locked Achievement" for hidden-locked; real title otherwise
    -- Title colour: grey (lockedTitleColor) for any locked achievement; gold when unlocked
    local titleText   = isHiddenLocked and B.lockedTitle or def.title
    local tc          = isLocked and B.lockedTitleColor or B.titleColor
    local titleColor  = TEN.Color(tc.r, tc.g, tc.b, a)
    DrawText(titleText, B.titleOffset.x, B.titleOffset.y, posX, posY,
             B.titleScale, titleColor, B.titleOptions)

    -- Description: only shown for unlocked achievements
    if not isLocked then
        local descColor = TEN.Color(B.descColor.r, B.descColor.g, B.descColor.b, a)
        DrawText(def.description, B.descOffset.x, B.descOffset.y, posX, posY,
                 B.descScale, descColor, B.descOptions)
    end
end

return Block
