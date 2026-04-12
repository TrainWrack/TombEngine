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
    animIndex = 0,
    animFrame = 0,

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
    swappedMeshes = {},
    outfitIndex   = 1,
    weaponIndex   = 1,

    -- Frame overlay
    frameIndex = 1, -- index into Settings.Frames.presets (1 = None)

    -- Entry camera state (for Reset Camera)
    entryCamPos    = nil,
    entryTargetPos = nil,
    entryFov       = Settings.Lens.defaultFOV,
    entryRoll      = Settings.Lens.defaultRoll,
    entryLight     = nil,
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

    -- Restore swapped meshes
    for _, meshIdx in ipairs(State.swappedMeshes) do
        pcall(function() Lara:UnswapSkinnedMesh(meshIdx) end)
    end

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
    State.animIndex     = State.snapshot and State.snapshot.laraAnim or 0
    State.animFrame     = State.snapshot and State.snapshot.laraFrame or 0
    State.lightEnabled  = Settings.Light.defaultEnabled
    State.lightSource   = States.LightSource.MANUAL
    State.lightRadius   = Settings.Light.defaultRadius
    State.lightShadows  = Settings.Light.defaultShadows
    State.lightColorIndex = 1
    State.filterIndex   = 1
    State.filterStrength = 1.0
    State.tintIndex     = 1
    State.hideUI        = false
    State.swappedMeshes = {}
    State.outfitIndex   = 1
    State.weaponIndex   = 1
    State.frameIndex    = 1
    State.entryHoldCount = 0
end

return States
