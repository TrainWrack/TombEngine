--- Settings for the PhotoMode module.
-- Reads colors from RingInventory.Settings where available.
-- @module Engine.PhotoMode.Settings
-- @local

local RingSettings = require("Engine.RingInventory.Settings")

local Settings = {}

-- ============================================================================
-- Colors (inherited from Ring Inventory where possible)
-- ============================================================================

Settings.ColorMap =
{
    plainText    = RingSettings.ColorMap.plainText,
    headerText   = RingSettings.ColorMap.headerText,
    optionText   = RingSettings.ColorMap.optionText,
    neutral      = RingSettings.ColorMap.neutral,
    dimmed       = Color(120, 120, 120, 255),
    highlight    = Color(255, 255, 80, 255),
}

-- ============================================================================
-- Sounds
-- ============================================================================

Settings.SoundMap =
{
    menuSelect = RingSettings.SoundMap.menuSelect,
    menuChoose = RingSettings.SoundMap.menuChoose,
    menuRotate = RingSettings.SoundMap.menuRotate,
}

-- ============================================================================
-- Animation
-- ============================================================================

Settings.Animation =
{
    transitionSpeed = RingSettings.Animation.transitionSpeed,
    fadeSpeed        = RingSettings.Animation.transitionSpeed,
}

-- ============================================================================
-- Camera Defaults
-- ============================================================================

Settings.Camera =
{
    meshName         = "pm_CameraMesh",
    targetName       = "pm_CameraTarget",
    meshIndex        = 0,
    targetIndex      = 0,
    defaultMoveSpeed = 64,
    minMoveSpeed     = 8,
    maxMoveSpeed     = 512,
    moveSpeedStep    = 8,
    defaultLookSpeed = 2.0,
    minLookSpeed     = 0.5,
    maxLookSpeed     = 5.0,
    lookSpeedStep    = 0.5,
    offsetForward    = -512,
    offsetUp         = -256,
    targetForward    = 512,
    targetUp         = -256,
}

-- ============================================================================
-- Lens Defaults
-- ============================================================================

Settings.Lens =
{
    defaultFOV  = 90,
    minFOV      = 30,
    maxFOV      = 120,
    fovStep     = 2,
    defaultRoll = 0,
    minRoll     = -45,
    maxRoll     = 45,
    rollStep    = 1,
}

-- ============================================================================
-- Player
-- ============================================================================

Settings.Player =
{
    moveSpeed    = 64,
    rotateSpeed  = 2,
}

-- ============================================================================
-- Light Defaults
-- ============================================================================

Settings.Light =
{
    defaultRadius  = 20,
    minRadius      = 1,
    maxRadius      = 80,
    radiusStep     = 1,
    defaultShadows = false,
    defaultEnabled = false,
    lightName      = "PHOTO_MODE_LIGHT",
    colorPresets   =
    {
        { name = "White",   color = TEN.Color(255, 255, 255) },
        { name = "Warm",    color = TEN.Color(255, 220, 180) },
        { name = "Cool",    color = TEN.Color(180, 210, 255) },
        { name = "Red",     color = TEN.Color(255, 80, 80) },
        { name = "Green",   color = TEN.Color(80, 255, 80) },
        { name = "Blue",    color = TEN.Color(80, 80, 255) },
        { name = "Magenta", color = TEN.Color(255, 80, 255) },
    },
    sourceNames = { "Manual", "Follow Camera", "Follow Lara" },
}

-- ============================================================================
-- Filter / Tint Presets
-- ============================================================================

Settings.Filters =
{
    presets =
    {
        { name = "Off",        mode = TEN.View.PostProcessMode.NONE },
        { name = "Monochrome", mode = TEN.View.PostProcessMode.MONOCHROME },
        { name = "Negative",   mode = TEN.View.PostProcessMode.NEGATIVE },
        { name = "Exclusion",  mode = TEN.View.PostProcessMode.EXCLUSION },
    },
    tints =
    {
        { name = "Neutral", color = TEN.Color(255, 255, 255) },
        { name = "Warm",    color = TEN.Color(255, 230, 200) },
        { name = "Cool",    color = TEN.Color(200, 220, 255) },
        { name = "Green",   color = TEN.Color(200, 255, 200) },
        { name = "Magenta", color = TEN.Color(255, 200, 255) },
    },
}

-- ============================================================================
-- Outfit / Weapon Presets
-- ============================================================================

Settings.Outfits =
{
    { name = "Default",        objID = nil },
    { name = "Alternate Skin", objID = TEN.Objects.ObjID.LARA_SKIN },
}

Settings.Weapons =
{
    { name = "Default",  meshIndices = {} },
    { name = "Pistols",  meshIndices = {1, 4} },
    { name = "Shotgun",  meshIndices = {7} },
    { name = "Unarmed",  meshIndices = {} },
}

-- ============================================================================
-- Frames (full-screen sprite overlays)
-- ============================================================================

Settings.Frames =
{
    objectID  = TEN.Objects.ObjID.CUSTOM_SPRITES,
    position  = TEN.Vec2(50, 50),
    rotation  = 0,
    scale     = TEN.Vec2(100, 100),
    alignMode = TEN.View.AlignMode.CENTER,
    scaleMode = TEN.View.ScaleMode.STRETCH,
    blendMode = TEN.Effects.BlendID.ALPHA_BLEND,
    color     = TEN.Color(255, 255, 255),
    alpha     = 255,
    presets   =
    {
        { name = "None",    spriteID = -1 },
        { name = "Frame 1", spriteID = 0 },
        { name = "Frame 2", spriteID = 1 },
        { name = "Frame 3", spriteID = 2 },
    },
}

-- ============================================================================
-- Entry
-- ============================================================================

Settings.Entry =
{
    holdFrames = 15,  -- Walk + Inventory held for N frames to enter
}

return Settings
