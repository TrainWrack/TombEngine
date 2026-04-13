--- State management for the PhotoMode module.
-- Tracks the current mode (Camera, Player, Light) and all mutable photo mode state.
-- @module Engine.PhotoMode.States
-- @local

local Settings = require("Engine.PhotoMode.Settings")

local States = {}

-- ============================================================================
-- Control Modes
-- ============================================================================

States.Mode =
{
    CAMERA = 1,
    PLAYER = 2,
    LIGHT  = 3,
}

States.ModeNames = { "Camera", "Player", "Light" }

-- ============================================================================
-- Light Source Modes
-- ============================================================================

States.LightSource =
{
    MANUAL        = 1,
    FOLLOW_CAMERA = 2,
    FOLLOW_LARA   = 3,
}

-- ============================================================================
-- Runtime State (reset on entry, restored on exit)
-- ============================================================================

local State = {
    active         = false,
    entryHoldCount = 0,
    hideUI         = false,

    -- Snapshot of Lara / view state captured on entry
    snapshot = nil,

    -- Camera moveables (set by Camera module)
    cameraMesh   = nil,
    cameraTarget = nil,

    -- Current control mode
    controlMode = States.Mode.CAMERA,

    -- Camera settings
    moveSpeed   = Settings.Camera.defaultMoveSpeed,
    lookSpeed   = Settings.Camera.defaultLookSpeed,
    collisionOn = true,

    -- Lens
    fov  = Settings.Lens.defaultFOV,
    roll = Settings.Lens.defaultRoll,

    -- Pose
    animIndex = 1,

    -- Light
    lightEnabled    = Settings.Light.defaultEnabled,
    lightSource     = States.LightSource.MANUAL,
    lightPos        = TEN.Vec3(0, 0, 0),
    lightRadius     = Settings.Light.defaultRadius,
    lightShadows    = Settings.Light.defaultShadows,
    lightColorIndex = 1,

    -- Filters
    filterIndex    = 1,
    filterStrength = 1.0,
    tintIndex      = 1,

    -- Outfit / Weapons
    swappedMeshes       = {},
    swappedWeaponMeshes = {},
    outfitIndex         = 1,
    weaponIndex         = 1,

    -- Frame overlay
    frameIndex = 1, -- index into Settings.Frames.presets (1 = None)

    -- Expressions
    expressionIndex         = 1,
    swappedExpressionMeshes = {},

    -- Depth of Field (placeholder)
    dofEnabled       = false,
    dofFocusDistance = Settings.DepthOfField.defaultFocusDistance,
    dofBlurStrength  = Settings.DepthOfField.defaultBlurStrength,

    -- Entry camera state (for Reset Camera)
    entryCamPos    = nil,
    entryTargetPos = nil,
    entryFov       = Settings.Lens.defaultFOV,
    entryRoll      = Settings.Lens.defaultRoll,
    entryLight     = nil,

    -- Sunglasses
    sunglassesEnabled = false,
}

-- ============================================================================
-- Accessors
-- ============================================================================

function States.Get()
    return State
end

function States.IsActive()
    return State.active
end

function States.SetActive(v)
    State.active = v
end

function States.GetMode()
    return State.controlMode
end

function States.SetMode(mode)
    State.controlMode = mode
end

function States.GetModeName()
    return States.ModeNames[State.controlMode] or "Unknown"
end

-- ============================================================================
-- Snapshot Capture / Restore
-- ============================================================================

function States.CaptureSnapshot()
    local snap = {}

    snap.laraPos      = Lara:GetPosition()
    snap.laraRot      = Lara:GetRotation()
    snap.laraVelocity = Lara:GetVelocity()
    snap.laraAnim     = Lara:GetAnim()
    snap.laraAnimSlot = Lara:GetAnimSlot()
    snap.laraFrame    = Lara:GetFrame()
    snap.laraState    = Lara:GetState()

    snap.fov  = TEN.View.GetFOV()
    snap.roll = 0

    -- Holster state
    local left, right, back = Lara:GetHolsterWeapon()
    snap.holsterLeft  = left
    snap.holsterRight = right
    snap.holsterBack  = back

    snap.filterIndex    = 1
    snap.filterStrength = 1.0
    snap.tintIndex      = 1
    snap.camPos         = nil
    snap.targetPos      = nil
    snap.hideUI         = false
    snap.swappedMeshes  = {}

    State.snapshot = snap
    return snap
end

function States.RestoreSnapshot()
    local snap = State.snapshot
    if not snap then return end

    Lara:SetPosition(snap.laraPos)
    Lara:SetRotation(snap.laraRot)
    Lara:SetVelocity(snap.laraVelocity)
    pcall(function() Lara:SetAnim(snap.laraAnim, snap.laraAnimSlot) end)
    pcall(function() Lara:SetFrame(snap.laraFrame) end)
    pcall(function() Lara:SetState(snap.laraState) end)

    -- Restore swapped meshes (outfit - skinned)
    for _, meshIdx in ipairs(State.swappedMeshes) do
        pcall(function() Lara:UnswapSkinnedMesh(meshIdx) end)
    end

    -- Restore swapped meshes (weapon - per-mesh)
    for _, meshIdx in ipairs(State.swappedWeaponMeshes) do
        pcall(function() Lara:UnswapMesh(meshIdx) end)
    end

    -- Restore swapped meshes (expression - per-mesh)
    for _, meshIdx in ipairs(State.swappedExpressionMeshes) do
        pcall(function() Lara:UnswapMesh(meshIdx) end)
    end

    -- Restore holster state
    pcall(function()
        Lara:SetHolsterWeapon(snap.holsterLeft, snap.holsterRight, snap.holsterBack)
    end)

    TEN.View.SetFOV(snap.fov)
    TEN.View.SetRoll(0)

    -- Reset post-process
    pcall(function()
        TEN.View.SetPostProcessMode(Settings.Filters.presets[1].mode)
        TEN.View.SetPostProcessStrength(1.0)
        TEN.View.SetPostProcessTint(Settings.Filters.tints[1].color)
    end)
end

-- ============================================================================
-- Reset to Entry Defaults
-- ============================================================================

function States.ResetToEntry()
    State.controlMode   = States.Mode.CAMERA
    State.moveSpeed     = Settings.Camera.defaultMoveSpeed
    State.lookSpeed     = Settings.Camera.defaultLookSpeed
    State.collisionOn   = true
    State.fov           = State.snapshot and State.snapshot.fov or Settings.Lens.defaultFOV
    State.roll          = Settings.Lens.defaultRoll
    State.animIndex     = 1
    State.lightEnabled  = Settings.Light.defaultEnabled
    State.lightSource   = States.LightSource.MANUAL
    State.lightRadius   = Settings.Light.defaultRadius
    State.lightShadows  = Settings.Light.defaultShadows
    State.lightColorIndex = 1
    State.filterIndex   = 1
    State.filterStrength = 1.0
    State.tintIndex     = 1
    State.hideUI             = false
    State.swappedMeshes       = {}
    State.swappedWeaponMeshes = {}
    State.outfitIndex         = 1
    State.weaponIndex         = 1
    State.expressionIndex         = 1
    State.swappedExpressionMeshes = {}
    State.dofEnabled       = Settings.DepthOfField.defaultEnabled
    State.dofFocusDistance = Settings.DepthOfField.defaultFocusDistance
    State.dofBlurStrength  = Settings.DepthOfField.defaultBlurStrength
    State.frameIndex        = 1
    State.sunglassesEnabled = false
    State.entryHoldCount    = 0
end

return States
