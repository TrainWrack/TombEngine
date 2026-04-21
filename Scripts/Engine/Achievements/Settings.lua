--- Settings for the Achievements module.
-- Edit this file to customise the visual appearance and behaviour of achievement
-- blocks, the slide-in popup, the list viewer, the progress bar and sounds.
--
-- All screen positions and sizes use screen-percent units (0-100).
-- @module Engine.Achievements.Settings
-- @local

local Settings = {}

-- ============================================================================
-- Sounds
-- ============================================================================
-- Set any value to 0 to disable that sound.

Settings.SoundMap =
{
    unlock    = 114,   -- played when Achievements.Unlock() is called
    openList  = 109,   -- played when the list opens
    closeList = 109,   -- played when the list closes
    scroll    = 108,   -- played on each scroll step (optional; can be noisy)
}

-- ============================================================================
-- Achievement Icons
-- ============================================================================
-- All per-achievement icons and the locked mystery icon come from the
-- ACHIEVEMENT_SPRITES object slot.
--   spriteId == 0   : locked / mystery icon  (used for hidden-locked entries)
--   spriteId == 1+  : individual achievement icons, matching 'spriteId' in the
--                     setup file (AchievementSetup.lua).

Settings.Icons =
{
    objectId       = TEN.Objects.ObjID.MOTORBOAT_FOAM_SPRITES,
    lockedSpriteId = 0,
}

-- ============================================================================
-- Achievement Block
-- ============================================================================
-- The block is the visual unit shared by both the popup and the list.
-- Positions are screen-percent offsets applied to the block's center point.

Settings.Block =
{
    -- Background panel sprite.
    -- Point bgObjectId / bgSpriteId at whichever sprite slot holds your
    -- block background graphic (separate from ACHIEVEMENT_SPRITES).
    bgObjectId  = TEN.Objects.ObjID.MOTORBOAT_FOAM_SPRITES,
    bgSpriteId  = 5,
    bgColor     = TEN.Color(128, 128, 128, 128),
    bgSize      = TEN.Vec2(45, 12),
    bgAlignMode = TEN.View.AlignMode.CENTER,
    bgScaleMode = TEN.View.ScaleMode.STRETCH,
    bgBlendMode = TEN.Effects.BlendID.ALPHA_BLEND,

    -- Icon (drawn to the left of the text).
    iconOffset  = TEN.Vec2(-17, 0),
    iconSize    = TEN.Vec2(10, 10),
    iconColor   = TEN.Color(255, 255, 255),
    iconAlignMode = TEN.View.AlignMode.CENTER,
    iconScaleMode = TEN.View.ScaleMode.FIT,
    iconBlendMode = TEN.Effects.BlendID.ALPHA_BLEND,

    -- Title text.
    titleOffset       = TEN.Vec2(-10, -2),
    titleScale        = 0.7,
    titleColor        = TEN.Color(255, 220, 100),   -- colour for unlocked achievements
    lockedTitleColor  = TEN.Color(140, 140, 140),   -- grey colour for locked achievements
    titleOptions      = { TEN.Strings.DisplayStringOption.SHADOW, TEN.Strings.DisplayStringOption.VERTICAL_CENTER },

    -- Description text (hidden when the achievement is hidden and locked).
    descOffset   = TEN.Vec2(-10, 2),
    descScale    = 0.55,
    descColor    = TEN.Color(200, 200, 200),
    descOptions  = { TEN.Strings.DisplayStringOption.SHADOW, TEN.Strings.DisplayStringOption.VERTICAL_CENTER },

    -- Text substituted for the real title on hidden-locked achievements.
    lockedTitle  = "Locked Achievement",
}

-- ============================================================================
-- Popup Notification
-- ============================================================================
-- The popup block slides up from below the screen at the bottom-right,
-- holds for holdTime seconds, then slides back down.
-- posX / startPosY / targetPosY are in screen percent.

Settings.Popup =
{
    posX       = 75,     -- horizontal center of the popup block
    startPosY  = 115,    -- Y when off-screen (below the viewport)
    targetPosY = 94,     -- Y when fully visible
    slideSpeed = 0.12,   -- lerp factor per frame (0-1; higher = snappier)
    alphaSpeed = 0.20,   -- lerp factor per frame for alpha
    holdTime   = 3.0,    -- seconds the popup stays visible before sliding out
    sound      = Settings.SoundMap.unlock,      -- sound ID played on unlock (0 = silence)
}

-- ============================================================================
-- Achievement List Viewer
-- ============================================================================
-- Opened via Achievements.ShowAchievementList(); enters FULL freeze mode.

Settings.List =
{
    col1X         = 27,   -- horizontal center of the left column (screen %)
    col2X         = 73,   -- horizontal center of the right column (screen %)
    startY        = 15,   -- Y of the first row center (screen %)
    blockSpacing  = 15,   -- vertical gap between row centers (screen %)

    -- Scroll acceleration: speed starts at scrollSpeed and increases by
    -- scrollAccel per frame while the key is held, capped at maxScrollSpeed.
    scrollSpeed    = 0.5,
    scrollAccel    = 0.03,
    maxScrollSpeed = 3.0,

    -- Action used to close the list.
    exitAction = TEN.Input.ActionID.INVENTORY,

    -- Summary line shown at the bottom for still-locked hidden achievements.
    -- Use {n} as a placeholder for the count.
    hiddenCountText    = "{n} Hidden Achievement(s)",
    hiddenTextScale    = 0.7,
    hiddenTextColor    = TEN.Color(150, 150, 150),
    hiddenTextOptions  = { TEN.Strings.DisplayStringOption.SHADOW,
                           TEN.Strings.DisplayStringOption.CENTER },

    -- Scroll arrows drawn on the left side of the screen.
    -- objectId / spriteId point at whichever sprite slot holds your arrow graphic.
    arrowObjectId  = TEN.Objects.ObjID.MOTORBOAT_FOAM_SPRITES,
    arrowSpriteId  = 0,
    arrowSize      = TEN.Vec2(5, 5),
    arrowColor     = TEN.Color(255, 255, 255),
    arrowAlignMode = TEN.View.AlignMode.CENTER,
    arrowScaleMode = TEN.View.ScaleMode.FIT,
    arrowBlendMode = TEN.Effects.BlendID.ALPHABLEND,
    arrowUpX       = 5,    -- screen % X for both arrows
    arrowUpY       = 10,   -- screen % Y for the up arrow
    arrowDownY     = 90,   -- screen % Y for the down arrow
    arrowFadeSpeed = 20,   -- alpha steps per frame (0-255)
}

-- ============================================================================
-- Progress Bar
-- ============================================================================
-- Drawn directly during the freeze frame (PREFREEZE).
-- Background and fill sprites use separate object/sprite references.

Settings.ProgressBar =
{
    -- Background sprite (full width of the bar).
    bgObjectId  = TEN.Objects.ObjID.CUSTOM_BAR_GRAPHICS,
    bgSpriteId  = 0,
    bgColor     = TEN.Color(60, 60, 60),
    bgPos       = TEN.Vec2(75, 7),
    bgSize      = TEN.Vec2(20, 3),
    bgAlignMode = TEN.View.AlignMode.CENTER_LEFT,
    bgScaleMode = TEN.View.ScaleMode.STRETCH,
    bgBlendMode = TEN.Effects.BlendID.ALPHA_BLEND,

    -- Fill sprite (width scaled by progress fraction 0-1).
    fillObjectId  = TEN.Objects.ObjID.CUSTOM_BAR_GRAPHICS,
    fillSpriteId  = 1,
    fillColor     = TEN.Color(100, 220, 100),
    fillPos       = TEN.Vec2(75.2, 7),
    fillMaxSize   = TEN.Vec2(19.6, 2.4),
    fillAlignMode = TEN.View.AlignMode.CENTER_LEFT,
    fillScaleMode = TEN.View.ScaleMode.STRETCH,
    fillBlendMode = TEN.Effects.BlendID.ALPHA_BLEND,

    -- Label drawn above the bar: "3 / 10  (30%)".
    labelPos     = TEN.Vec2(85, 4),
    labelScale   = 0.55,
    labelColor   = TEN.Color(255, 255, 255),
    labelOptions = { TEN.Strings.DisplayStringOption.SHADOW,
                     TEN.Strings.DisplayStringOption.CENTER },
}

return Settings
