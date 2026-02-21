-----
--- Lua Photo Mode (Object Camera) for TombEngine.
-- Provides a fully featured in-game photo mode with camera control, player posing,
-- dynamic lighting, post-process filters, and outfit management.
--
-- To use Photo Mode in a level script:
--
--    local PhotoMode = require("Engine.PhotoMode")
--
-- Photo Mode will automatically register its callbacks. Entry is triggered by
-- holding Walk + Inventory simultaneously. While active, the game is frozen and
-- all controls are routed through the Photo Mode menu.
--
-- @luautil PhotoMode

local PhotoMode = {}

LevelFuncs.Engine.PhotoMode = {}

-------------------------------------------------------------------------------
-- Constants & Configuration
-------------------------------------------------------------------------------

local CAMERA_MESH_NAME    = "pm_CameraMesh"
local CAMERA_TARGET_NAME  = "pm_CameraTarget"
local PHOTO_MODE_LIGHT    = "PHOTO_MODE_LIGHT"

local CAMERA_MESH_INDEX   = 0
local TARGET_MESH_INDEX   = 0

local ENTRY_HOLD_FRAMES   = 15 -- Both Walk+Inventory held for N frames to enter.

-- Camera
local DEFAULT_MOVE_SPEED     = 64
local DEFAULT_LOOK_SPEED     = 2.0
local MIN_MOVE_SPEED         = 8
local MAX_MOVE_SPEED         = 512
local MOVE_SPEED_STEP        = 8
local MIN_LOOK_SPEED         = 0.5
local MAX_LOOK_SPEED         = 5.0
local LOOK_SPEED_STEP        = 0.5

-- FOV
local DEFAULT_FOV     = 90
local MIN_FOV         = 30
local MAX_FOV         = 120
local FOV_STEP        = 2

-- Roll (engine doesn't have SetRoll; this is a placeholder for future support)
local DEFAULT_ROLL    = 0
local MIN_ROLL        = -45
local MAX_ROLL        = 45
local ROLL_STEP       = 1

-- Light
local DEFAULT_LIGHT_RADIUS   = 20  -- In "clicks" (256 world units each)
local MIN_LIGHT_RADIUS       = 1
local MAX_LIGHT_RADIUS       = 80
local LIGHT_RADIUS_STEP      = 1
local DEFAULT_LIGHT_SHADOWS  = false
local DEFAULT_LIGHT_ENABLED  = false

-- Camera initial offsets relative to Lara (world units)
local CAM_OFFSET_FORWARD  = -512
local CAM_OFFSET_UP       = -256
local TARGET_OFFSET_FORWARD = 512
local TARGET_OFFSET_UP      = -256

-- Player move speed
local PLAYER_MOVE_SPEED = 64

-- Light color presets
local COLOR_PRESETS = {
    { name = "White",   color = TEN.Color(255, 255, 255) },
    { name = "Warm",    color = TEN.Color(255, 220, 180) },
    { name = "Cool",    color = TEN.Color(180, 210, 255) },
    { name = "Red",     color = TEN.Color(255, 80, 80) },
    { name = "Green",   color = TEN.Color(80, 255, 80) },
    { name = "Blue",    color = TEN.Color(80, 80, 255) },
    { name = "Magenta", color = TEN.Color(255, 80, 255) },
}

-- Filter tint presets
local TINT_PRESETS = {
    { name = "Neutral", color = TEN.Color(255, 255, 255) },
    { name = "Warm",    color = TEN.Color(255, 230, 200) },
    { name = "Cool",    color = TEN.Color(200, 220, 255) },
    { name = "Green",   color = TEN.Color(200, 255, 200) },
    { name = "Magenta", color = TEN.Color(255, 200, 255) },
}

-- Post-process filter names and modes
local FILTER_PRESETS = {
    { name = "Off",         mode = TEN.View.PostProcessMode.NONE },
    { name = "Monochrome",  mode = TEN.View.PostProcessMode.MONOCHROME },
    { name = "Negative",    mode = TEN.View.PostProcessMode.NEGATIVE },
    { name = "Exclusion",   mode = TEN.View.PostProcessMode.EXCLUSION },
}

-- Outfit presets (ObjID slots for SwapSkinnedMesh; level must have these loaded)
-- Users can extend this table for their custom outfits.
local OUTFIT_PRESETS = {
    { name = "Default", objID = nil },                              -- nil = reset (no swap)
    { name = "Alternate Skin",  objID = TEN.Objects.ObjID.LARA_SKIN },     -- Example alternate skin
}

-- Weapon mesh presets (mesh indices to swap for weapon visibility)
-- These map to common weapon mesh slots. Users should customize for their level.
local WEAPON_PRESETS = {
    { name = "Default",   meshIndices = {} },         -- nil = reset all
    { name = "Pistols",   meshIndices = {1, 4} },     -- Common holster mesh indices
    { name = "Shotgun",   meshIndices = {7} },
    { name = "Unarmed",   meshIndices = {} },
}

-- UI colors
local UI_COLOR_NORMAL     = TEN.Color(200, 200, 200)
local UI_COLOR_HIGHLIGHT  = TEN.Color(255, 255, 80)
local UI_COLOR_CATEGORY   = TEN.Color(255, 180, 50)
local UI_COLOR_TITLE      = TEN.Color(255, 255, 255)
local UI_COLOR_DIMMED     = TEN.Color(120, 120, 120)

-- UI layout
local UI_LEFT_X           = 3   -- Percent from left
local UI_TOP_Y            = 8   -- Percent from top
local UI_LINE_HEIGHT      = 3.2 -- Percent between lines
local UI_SCALE            = 0.8

-- Control mode enum
local CTRL_CAMERA  = 1
local CTRL_PLAYER  = 2
local CTRL_NAMES   = { "Camera", "Player" }

-- Light source enum
local LSRC_MANUAL        = 1
local LSRC_FOLLOW_CAMERA = 2
local LSRC_FOLLOW_LARA   = 3
local LSRC_NAMES         = { "Manual", "Follow Camera", "Follow Lara" }

-------------------------------------------------------------------------------
-- Internal State
-------------------------------------------------------------------------------

local State = {
    active = false,
    entryHoldCount = 0,
    uiDirty = true,
    hideUI = false,

    -- Snapshot (captured on entry, restored on exit)
    snapshot = nil,

    -- Camera moveables
    cameraMesh = nil,
    cameraTarget = nil,
    cameraCreated = false,

    -- Current settings
    controlMode = CTRL_CAMERA,
    moveSpeed = DEFAULT_MOVE_SPEED,
    lookSpeed = DEFAULT_LOOK_SPEED,
    collisionOn = true,

    -- Lens
    fov = DEFAULT_FOV,
    roll = DEFAULT_ROLL,

    -- Pose
    animIndex = 0,
    animFrame = 0,

    -- Light
    lightEnabled = DEFAULT_LIGHT_ENABLED,
    lightSource = LSRC_MANUAL,
    lightPos = TEN.Vec3(0, 0, 0),
    lightRadius = DEFAULT_LIGHT_RADIUS,
    lightShadows = DEFAULT_LIGHT_SHADOWS,
    lightColorIndex = 1,

    -- Filters
    filterIndex = 1,
    filterStrength = 1.0,
    tintIndex = 1,

    -- Outfit
    -- (Tracked as list of swapped mesh indices for restoration)
    swappedMeshes = {},
    outfitIndex = 1,
    weaponIndex = 1,

    -- Menu navigation
    categoryIndex = 1,
    optionIndex = 1,

    -- Entry camera state (for Reset Camera)
    entryCamPos = nil,
    entryTargetPos = nil,
    entryFov = DEFAULT_FOV,
    entryRoll = DEFAULT_ROLL,

    -- Entry light state (for Reset Light)
    entryLight = nil,

    -- Display strings cache
    displayStrings = {},
}

-------------------------------------------------------------------------------
-- Menu Definition
-------------------------------------------------------------------------------

-- Option types
local OPT_SLIDER   = "slider"
local OPT_SELECTOR = "selector"
local OPT_TOGGLE   = "toggle"
local OPT_BUTTON   = "button"
local OPT_DISPLAY  = "display"

-- Build menu structure. Each category has a name and a list of options.
-- Options reference getter/setter functions defined below.
local function BuildMenu()
    return {
        {
            name = "Camera",
            options = {
                { label = "Control Mode", type = OPT_SELECTOR,
                  items = CTRL_NAMES,
                  get = function() return State.controlMode end,
                  set = function(v) State.controlMode = v end },
                { label = "Move Speed", type = OPT_SLIDER,
                  min = MIN_MOVE_SPEED, max = MAX_MOVE_SPEED, step = MOVE_SPEED_STEP,
                  get = function() return State.moveSpeed end,
                  set = function(v) State.moveSpeed = v end },
                { label = "Look Sensitivity", type = OPT_SLIDER,
                  min = MIN_LOOK_SPEED, max = MAX_LOOK_SPEED, step = LOOK_SPEED_STEP,
                  get = function() return State.lookSpeed end,
                  set = function(v) State.lookSpeed = v end,
                  format = function(v) return string.format("%.1f", v) end },
                { label = "Collision", type = OPT_TOGGLE,
                  get = function() return State.collisionOn end,
                  set = function(v) State.collisionOn = v end },
                { label = "Reset Camera", type = OPT_BUTTON,
                  action = function() ResetCamera() end },
            },
        },
        {
            name = "Lens",
            options = {
                { label = "FOV", type = OPT_SLIDER,
                  min = MIN_FOV, max = MAX_FOV, step = FOV_STEP,
                  get = function() return State.fov end,
                  set = function(v)
                      State.fov = v
                      TEN.View.SetFOV(v)
                  end },
                { label = "Roll (N/A)", type = OPT_DISPLAY,
                  get = function() return tostring(State.roll) .. " (unsupported)" end },
                { label = "Reset Lens", type = OPT_BUTTON,
                  action = function() ResetLens() end },
            },
        },
        {
            name = "Pose",
            options = {
                { label = "Anim Index", type = OPT_SLIDER,
                  min = 0, max = 999, step = 1,
                  get = function() return State.animIndex end,
                  set = function(v) SetPoseAnim(v) end },
                { label = "Frame", type = OPT_SLIDER,
                  min = 0, max = 999, step = 1,
                  get = function() return State.animFrame end,
                  set = function(v) SetPoseFrame(v) end },
                { label = "Reset Pose", type = OPT_BUTTON,
                  action = function() ResetPose() end },
            },
        },
        {
            name = "Outfit / Weapons",
            options = {
                { label = "Outfit", type = OPT_SELECTOR,
                  items = (function()
                      local t = {}
                      for _, o in ipairs(OUTFIT_PRESETS) do t[#t + 1] = o.name end
                      return t
                  end)(),
                  get = function() return State.outfitIndex end,
                  set = function(v) ApplyOutfit(v) end },
                { label = "Weapons", type = OPT_SELECTOR,
                  items = (function()
                      local t = {}
                      for _, w in ipairs(WEAPON_PRESETS) do t[#t + 1] = w.name end
                      return t
                  end)(),
                  get = function() return State.weaponIndex end,
                  set = function(v) ApplyWeapon(v) end },
                { label = "Reset Appearance", type = OPT_BUTTON,
                  action = function() ResetAppearance() end },
            },
        },
        {
            name = "Filters",
            options = {
                { label = "Filter Preset", type = OPT_SELECTOR,
                  items = (function()
                      local t = {}
                      for _, f in ipairs(FILTER_PRESETS) do t[#t + 1] = f.name end
                      return t
                  end)(),
                  get = function() return State.filterIndex end,
                  set = function(v)
                      State.filterIndex = v
                      TEN.View.SetPostProcessMode(FILTER_PRESETS[v].mode)
                  end },
                { label = "Strength", type = OPT_SLIDER,
                  min = 0.0, max = 1.0, step = 0.05,
                  get = function() return State.filterStrength end,
                  set = function(v)
                      State.filterStrength = v
                      TEN.View.SetPostProcessStrength(v)
                  end,
                  format = function(v) return string.format("%.2f", v) end },
                { label = "Tint Preset", type = OPT_SELECTOR,
                  items = (function()
                      local t = {}
                      for _, p in ipairs(TINT_PRESETS) do t[#t + 1] = p.name end
                      return t
                  end)(),
                  get = function() return State.tintIndex end,
                  set = function(v)
                      State.tintIndex = v
                      TEN.View.SetPostProcessTint(TINT_PRESETS[v].color)
                  end },
                { label = "Reset Filters", type = OPT_BUTTON,
                  action = function() ResetFilters() end },
            },
        },
        {
            name = "Light",
            options = {
                { label = "Enabled", type = OPT_TOGGLE,
                  get = function() return State.lightEnabled end,
                  set = function(v) State.lightEnabled = v end },
                { label = "Source", type = OPT_SELECTOR,
                  items = LSRC_NAMES,
                  get = function() return State.lightSource end,
                  set = function(v) State.lightSource = v end },
                { label = "Place at Camera", type = OPT_BUTTON,
                  action = function() PlaceLightAtCamera() end },
                { label = "Place at Lara", type = OPT_BUTTON,
                  action = function() PlaceLightAtLara() end },
                { label = "Radius", type = OPT_SLIDER,
                  min = MIN_LIGHT_RADIUS, max = MAX_LIGHT_RADIUS, step = LIGHT_RADIUS_STEP,
                  get = function() return State.lightRadius end,
                  set = function(v) State.lightRadius = v end },
                { label = "Shadows", type = OPT_TOGGLE,
                  get = function() return State.lightShadows end,
                  set = function(v) State.lightShadows = v end },
                { label = "Color Preset", type = OPT_SELECTOR,
                  items = (function()
                      local t = {}
                      for _, c in ipairs(COLOR_PRESETS) do t[#t + 1] = c.name end
                      return t
                  end)(),
                  get = function() return State.lightColorIndex end,
                  set = function(v) State.lightColorIndex = v end },
                { label = "Reset Light", type = OPT_BUTTON,
                  action = function() ResetLight() end },
            },
        },
        {
            name = "UI",
            options = {
                { label = "Hide UI", type = OPT_TOGGLE,
                  get = function() return State.hideUI end,
                  set = function(v)
                      State.hideUI = v
                      State.uiDirty = true
                  end },
                { label = "Exit Photo Mode", type = OPT_BUTTON,
                  action = function() ExitPhotoMode() end },
            },
        },
    }
end

local Menu = nil -- Populated on first use / entry

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

--- Clamp a number between min and max.
local function Clamp(val, lo, hi)
    if val < lo then return lo end
    if val > hi then return hi end
    return val
end

--- Round a number to a given number of decimal places.
local function Round(val, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(val * mult + 0.5) / mult
end

--- Compute a forward direction vector from a Y-axis rotation angle (degrees).
local function ForwardFromYaw(yawDeg)
    local rad = math.rad(yawDeg)
    return TEN.Vec3(math.sin(rad), 0, math.cos(rad))
end

--- Compute a right direction vector from a Y-axis rotation angle (degrees).
local function RightFromYaw(yawDeg)
    local rad = math.rad(yawDeg + 90)
    return TEN.Vec3(math.sin(rad), 0, math.cos(rad))
end

--- Get the normalized direction from camera to target.
local function GetCameraDirection()
    if not State.cameraMesh or not State.cameraTarget then
        return TEN.Vec3(0, 0, 1)
    end
    local cp = State.cameraMesh:GetPosition()
    local tp = State.cameraTarget:GetPosition()
    local dx = tp.x - cp.x
    local dy = tp.y - cp.y
    local dz = tp.z - cp.z
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 1 then return TEN.Vec3(0, 0, 1) end
    return TEN.Vec3(dx / len, dy / len, dz / len)
end

--- Check if a position is inside solid geometry using Collision.Probe.
local function IsInsideSolid(pos)
    local ok, probe = pcall(TEN.Collision.Probe, pos)
    if not ok then return false end
    return probe:IsInsideSolidGeometry()
end

--- Safely move a moveable to newPos, checking collision if enabled.
--- Returns true if the move was applied, false if blocked.
local function SafeMove(moveable, newPos)
    if State.collisionOn then
        if IsInsideSolid(newPos) then
            return false
        end
    end
    moveable:SetPosition(newPos)
    return true
end

--- Vec3 addition helper.
local function Vec3Add(a, b)
    return TEN.Vec3(a.x + b.x, a.y + b.y, a.z + b.z)
end

--- Vec3 scale helper.
local function Vec3Scale(v, s)
    return TEN.Vec3(v.x * s, v.y * s, v.z * s)
end

-------------------------------------------------------------------------------
-- Snapshot: Capture & Restore
-------------------------------------------------------------------------------

local function CaptureSnapshot()

    local snap = {}

    -- Lara state
    snap.laraPos = Lara:GetPosition()
    snap.laraRot = Lara:GetRotation()
    snap.laraVelocity = Lara:GetVelocity()
    snap.laraAnim = Lara:GetAnim()
    snap.laraAnimSlot = Lara:GetAnimSlot()
    snap.laraFrame = Lara:GetFrame()
    snap.laraState = Lara:GetState()

    -- View
    snap.fov = TEN.View.GetFOV()
    -- No GetRoll available
    snap.roll = 0

    -- Post-process (no Lua getters; store defaults or current UI state)
    snap.filterIndex = 1
    snap.filterStrength = 1.0
    snap.tintIndex = 1

    -- Camera positions will be set after initial placement
    snap.camPos = nil
    snap.targetPos = nil

    -- Light defaults
    snap.lightEnabled = DEFAULT_LIGHT_ENABLED
    snap.lightSource = LSRC_MANUAL
    snap.lightPos = TEN.Vec3(0, 0, 0)
    snap.lightRadius = DEFAULT_LIGHT_RADIUS
    snap.lightShadows = DEFAULT_LIGHT_SHADOWS
    snap.lightColorIndex = 1

    -- UI
    snap.hideUI = false

    -- Swapped meshes (empty on entry)
    snap.swappedMeshes = {}

    return snap
end

local function RestoreSnapshot()
    local snap = State.snapshot
    if not snap then return end

   
    Lara:SetPosition(snap.laraPos)
    Lara:SetRotation(snap.laraRot)
    Lara:SetVelocity(snap.laraVelocity)
    -- Restore animation with slot
    pcall(function()
        Lara:SetAnim(snap.laraAnim, snap.laraAnimSlot)
    end)
    pcall(function()
        Lara:SetFrame(snap.laraFrame)
    end)
    pcall(function()
        Lara:SetState(snap.laraState)
    end)

    -- Restore swapped meshes
    for _, meshIdx in ipairs(State.swappedMeshes) do
        pcall(function()
            Lara:UnswapSkinnedMesh(meshIdx)
        end)
    end

    -- Restore FOV
    TEN.View.SetFOV(snap.fov)

    -- Restore post-process
    pcall(function()
        TEN.View.SetPostProcessMode(FILTER_PRESETS[1].mode)
        TEN.View.SetPostProcessStrength(1.0)
        TEN.View.SetPostProcessTint(TINT_PRESETS[1].color)
    end)
end

-------------------------------------------------------------------------------
-- Camera Moveable Management
-------------------------------------------------------------------------------

local function GetOrCreateMoveable(name)
    
    local mov = TEN.Objects.IsNameInUse(name)
    if mov then return TEN.Objects.GetMoveableByName(name), false end

    -- Create a CAMERA_TARGET type moveable at Lara's position
    local pos = Lara:GetPosition()
    local rot = TEN.Rotation(0, 0, 0)
    local room = Lara:GetRoomNumber()

    local ok, newMov = pcall(TEN.Objects.Moveable,
        TEN.Objects.ObjID.CAMERA_TARGET, name, pos, rot, room)
    if ok and newMov then
        newMov:Enable()
        return newMov, true
    end

    return nil, false
end

local function InitCameraObjects()
    local camMesh, camCreated = GetOrCreateMoveable(CAMERA_MESH_NAME)
    local camTarget, targetCreated = GetOrCreateMoveable(CAMERA_TARGET_NAME)

    State.cameraMesh = camMesh
    State.cameraTarget = camTarget
    State.cameraCreated = camCreated or targetCreated

    if not camMesh or not camTarget then
        TEN.Util.PrintLog("PhotoMode: Failed to create camera objects.", TEN.Util.LogLevel.ERROR)
        return false
    end

    return true
end

local function PlaceCameraInitial()
    if not State.cameraMesh or not State.cameraTarget then return end

    local laraPos = Lara:GetPosition()
    local laraRot = Lara:GetRotation()
    local yaw = laraRot.y

    local fwd = ForwardFromYaw(yaw)

    -- Camera behind Lara
    local camPos = TEN.Vec3(
        laraPos.x + fwd.x * CAM_OFFSET_FORWARD,
        laraPos.y + CAM_OFFSET_UP,
        laraPos.z + fwd.z * CAM_OFFSET_FORWARD
    )

    -- Target in front of Lara
    local targetPos = TEN.Vec3(
        laraPos.x + fwd.x * TARGET_OFFSET_FORWARD,
        laraPos.y + TARGET_OFFSET_UP,
        laraPos.z + fwd.z * TARGET_OFFSET_FORWARD
    )

    State.cameraMesh:SetPosition(camPos)
    State.cameraTarget:SetPosition(targetPos)

    -- Store entry positions
    State.entryCamPos = camPos
    State.entryTargetPos = targetPos

    -- Update snapshot
    if State.snapshot then
        State.snapshot.camPos = camPos
        State.snapshot.targetPos = targetPos
    end
end

local function AttachCamera()
    if State.cameraMesh and State.cameraTarget then
        State.cameraMesh:AttachObjCamera(CAMERA_MESH_INDEX, State.cameraTarget, TARGET_MESH_INDEX)
    end
end

local function DetachCamera()
    pcall(TEN.View.ResetObjCamera)
end

-------------------------------------------------------------------------------
-- Entry / Exit
-------------------------------------------------------------------------------

function EnterPhotoMode()
    if State.active then return end

    -- Capture snapshot
    State.snapshot = CaptureSnapshot()
    if not State.snapshot then return end

    -- Initialize camera objects
    if not InitCameraObjects() then return end

    -- Place camera
    PlaceCameraInitial()

    -- Initialize state
    State.active = true
    State.controlMode = CTRL_CAMERA
    State.moveSpeed = DEFAULT_MOVE_SPEED
    State.lookSpeed = DEFAULT_LOOK_SPEED
    State.collisionOn = true
    State.fov = State.snapshot.fov
    State.roll = 0
    State.animIndex = State.snapshot.laraAnim
    State.animFrame = State.snapshot.laraFrame
    State.lightEnabled = DEFAULT_LIGHT_ENABLED
    State.lightSource = LSRC_MANUAL
    State.lightRadius = DEFAULT_LIGHT_RADIUS
    State.lightShadows = DEFAULT_LIGHT_SHADOWS
    State.lightColorIndex = 1
    State.filterIndex = 1
    State.filterStrength = 1.0
    State.tintIndex = 1
    State.hideUI = false
    State.categoryIndex = 1
    State.optionIndex = 1
    State.uiDirty = true
    State.swappedMeshes = {}
    State.outfitIndex = 1
    State.weaponIndex = 1
    State.entryFov = State.snapshot.fov
    State.entryRoll = 0

    -- Store entry light state
    State.entryLight = {
        enabled = State.lightEnabled,
        source = State.lightSource,
        pos = TEN.Vec3(State.cameraMesh:GetPosition().x,
                       State.cameraMesh:GetPosition().y,
                       State.cameraMesh:GetPosition().z),
        radius = State.lightRadius,
        shadows = State.lightShadows,
        colorIndex = State.lightColorIndex,
    }
    State.lightPos = TEN.Vec3(State.entryLight.pos.x,
                              State.entryLight.pos.y,
                              State.entryLight.pos.z)

    -- Build menu
    Menu = BuildMenu()

    -- Freeze the game
    TEN.Flow.SetFreezeMode(TEN.Flow.FreezeMode.SPECTATOR)

    -- Attach camera
    AttachCamera()

    -- Clear inputs
    TEN.Input.ClearAllKeys()

    TEN.Util.PrintLog("PhotoMode: Entered.", TEN.Util.LogLevel.INFO)
end

function ExitPhotoMode()
    if not State.active then return end

    -- Restore snapshot
    RestoreSnapshot()

    -- Detach camera
    DetachCamera()

    -- Stop light (emit with radius 0 to ensure no lingering emission)
    pcall(function()
        TEN.Effects.EmitLight(State.lightPos, TEN.Color(0, 0, 0), 0, false, PHOTO_MODE_LIGHT)
    end)

    -- Hide all UI strings
    HideAllStrings()

    -- Unfreeze
    TEN.Flow.SetFreezeMode(TEN.Flow.FreezeMode.NONE)

    -- Clear state
    State.active = false
    State.snapshot = nil
    State.entryHoldCount = 0

    -- Clear inputs
    TEN.Input.ClearAllKeys()

    TEN.Util.PrintLog("PhotoMode: Exited.", TEN.Util.LogLevel.INFO)
end

-------------------------------------------------------------------------------
-- Reset Functions
-------------------------------------------------------------------------------

function ResetCamera()
    if State.entryCamPos and State.cameraMesh then
        State.cameraMesh:SetPosition(State.entryCamPos)
    end
    if State.entryTargetPos and State.cameraTarget then
        State.cameraTarget:SetPosition(State.entryTargetPos)
    end
    State.uiDirty = true
end

function ResetLens()
    State.fov = State.entryFov
    TEN.View.SetFOV(State.fov)
    State.roll = State.entryRoll
    State.uiDirty = true
end

function ResetPose()
    if not State.snapshot then return end

    pcall(function()
        Lara:SetAnim(State.snapshot.laraAnim, State.snapshot.laraAnimSlot)
    end)
    pcall(function()
        Lara:SetFrame(State.snapshot.laraFrame)
    end)

    State.animIndex = State.snapshot.laraAnim
    State.animFrame = State.snapshot.laraFrame
    State.uiDirty = true
end

function ResetFilters()
    State.filterIndex = 1
    State.filterStrength = 1.0
    State.tintIndex = 1
    TEN.View.SetPostProcessMode(FILTER_PRESETS[1].mode)
    TEN.View.SetPostProcessStrength(1.0)
    TEN.View.SetPostProcessTint(TINT_PRESETS[1].color)
    State.uiDirty = true
end

function ResetLight()
    if State.entryLight then
        State.lightEnabled = State.entryLight.enabled
        State.lightSource = State.entryLight.source
        State.lightPos = TEN.Vec3(State.entryLight.pos.x,
                                  State.entryLight.pos.y,
                                  State.entryLight.pos.z)
        State.lightRadius = State.entryLight.radius
        State.lightShadows = State.entryLight.shadows
        State.lightColorIndex = State.entryLight.colorIndex
    end
    State.uiDirty = true
end

function PlaceLightAtCamera()
    if State.cameraMesh then
        local cp = State.cameraMesh:GetPosition()
        State.lightPos = TEN.Vec3(cp.x, cp.y, cp.z)
        State.lightSource = LSRC_MANUAL
    end
    State.uiDirty = true
end

function PlaceLightAtLara()

    local lp = Lara:GetPosition()
    State.lightPos = TEN.Vec3(lp.x, lp.y - 256, lp.z)
    State.lightSource = LSRC_MANUAL
    State.uiDirty = true
end

function ResetAppearance()
    for _, meshIdx in ipairs(State.swappedMeshes) do
        pcall(function()
            Lara:UnswapSkinnedMesh(meshIdx)
        end)
    end
    State.swappedMeshes = {}
    State.outfitIndex = 1
    State.weaponIndex = 1
    State.uiDirty = true
end

function ApplyOutfit(index)
    -- First reset existing outfit swaps
    for _, meshIdx in ipairs(State.swappedMeshes) do
        pcall(function()
            Lara:UnswapSkinnedMesh(meshIdx)
        end)
    end
    State.swappedMeshes = {}

    State.outfitIndex = index
    local preset = OUTFIT_PRESETS[index]
    if preset and preset.objID then
        -- SwapSkinnedMesh swaps the entire skin to the given object slot
        pcall(function()
            Lara:SwapSkinnedMesh(preset.objID)
        end)
    end
    State.uiDirty = true
end

function ApplyWeapon(index)

    State.weaponIndex = index
    local preset = WEAPON_PRESETS[index]
    if not preset then return end

    -- Weapon presets affect specific mesh indices
    -- This is a simplified approach; the exact implementation depends on the level setup
    State.uiDirty = true
end

-------------------------------------------------------------------------------
-- Pose Functions
-------------------------------------------------------------------------------

function SetPoseAnim(index)
    State.animIndex = index
    pcall(function()
        Lara:SetAnim(index)
    end)
    State.uiDirty = true
end

function SetPoseFrame(frame)
    State.animFrame = frame
    pcall(function()
        Lara:SetFrame(frame)
    end)
    State.uiDirty = true
end

-------------------------------------------------------------------------------
-- Camera Movement (Control Mode = Camera)
-------------------------------------------------------------------------------

local function UpdateCameraControls()
    if not State.cameraMesh or not State.cameraTarget then return end

    local camPos = State.cameraMesh:GetPosition()
    local targetPos = State.cameraTarget:GetPosition()

    local dir = GetCameraDirection()
    local speed = State.moveSpeed
    local lookSpeed = State.lookSpeed

    -- Right vector from camera direction (horizontal only)
    local rightX = dir.z
    local rightZ = -dir.x
    local rLen = math.sqrt(rightX * rightX + rightZ * rightZ)
    if rLen > 0.001 then
        rightX = rightX / rLen
        rightZ = rightZ / rLen
    end

    local newCamPos = TEN.Vec3(camPos.x, camPos.y, camPos.z)
    local newTargetPos = TEN.Vec3(targetPos.x, targetPos.y, targetPos.z)

    -- Dolly (forward/back): move both camera and target along view direction
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.FORWARD) then
        newCamPos = Vec3Add(newCamPos, Vec3Scale(dir, speed))
        newTargetPos = Vec3Add(newTargetPos, Vec3Scale(dir, speed))
    end
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.BACK) then
        newCamPos = Vec3Add(newCamPos, Vec3Scale(dir, -speed))
        newTargetPos = Vec3Add(newTargetPos, Vec3Scale(dir, -speed))
    end

    -- Mouse scroll dolly (zoom in/out)
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.MOUSE_SCROLL_UP) then
        newCamPos = Vec3Add(newCamPos, Vec3Scale(dir, speed * 2))
        newTargetPos = Vec3Add(newTargetPos, Vec3Scale(dir, speed * 2))
    end
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.MOUSE_SCROLL_DOWN) then
        newCamPos = Vec3Add(newCamPos, Vec3Scale(dir, -speed * 2))
        newTargetPos = Vec3Add(newTargetPos, Vec3Scale(dir, -speed * 2))
    end

    -- Orbit: rotate target around camera (left/right via keyboard)
    local orbitAngle = 0
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.LEFT) then
        orbitAngle = orbitAngle - lookSpeed
    end
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.RIGHT) then
        orbitAngle = orbitAngle + lookSpeed
    end

    -- Mouse right-click drag orbit (via LOOK action held + Left/Right)
    -- Controller analog stick orbit via LOOK hold
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.LOOK) then
        -- When Look is held, Left/Right provide additional orbit speed
        if TEN.Input.IsKeyHeld(TEN.Input.ActionID.LEFT) then
            orbitAngle = orbitAngle - lookSpeed * 0.5
        end
        if TEN.Input.IsKeyHeld(TEN.Input.ActionID.RIGHT) then
            orbitAngle = orbitAngle + lookSpeed * 0.5
        end
    end

    -- Apply orbit rotation
    if math.abs(orbitAngle) > 0.001 then
        local dx = targetPos.x - camPos.x
        local dz = targetPos.z - camPos.z
        local angle = math.rad(orbitAngle)
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)
        newTargetPos = TEN.Vec3(
            camPos.x + dx * cosA - dz * sinA,
            newTargetPos.y,
            camPos.z + dx * sinA + dz * cosA
        )
    end

    -- Vertical adjust: move target up/down
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.JUMP) then
        newTargetPos = TEN.Vec3(newTargetPos.x, newTargetPos.y - speed, newTargetPos.z)
    end
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.CROUCH) then
        newTargetPos = TEN.Vec3(newTargetPos.x, newTargetPos.y + speed, newTargetPos.z)
    end

    -- Strafe (step left/right)
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.STEP_LEFT) then
        local offset = TEN.Vec3(-rightX * speed, 0, -rightZ * speed)
        newCamPos = Vec3Add(newCamPos, offset)
        newTargetPos = Vec3Add(newTargetPos, offset)
    end
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.STEP_RIGHT) then
        local offset = TEN.Vec3(rightX * speed, 0, rightZ * speed)
        newCamPos = Vec3Add(newCamPos, offset)
        newTargetPos = Vec3Add(newTargetPos, offset)
    end

    -- Apply with collision check
    SafeMove(State.cameraMesh, newCamPos)
    SafeMove(State.cameraTarget, newTargetPos)
end

-------------------------------------------------------------------------------
-- Player Movement (Control Mode = Player)
-------------------------------------------------------------------------------

local function UpdatePlayerControls()

    local laraPos = Lara:GetPosition()
    local laraRot = Lara:GetRotation()
    local fwd = ForwardFromYaw(laraRot.y)
    local right = RightFromYaw(laraRot.y)
    local speed = PLAYER_MOVE_SPEED

    local newPos = TEN.Vec3(laraPos.x, laraPos.y, laraPos.z)

    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.FORWARD) then
        newPos = Vec3Add(newPos, Vec3Scale(fwd, speed))
    end
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.BACK) then
        newPos = Vec3Add(newPos, Vec3Scale(fwd, -speed))
    end
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.LEFT) then
        -- Rotate Lara left
        local newRot = TEN.Rotation(laraRot.x, laraRot.y - 2, laraRot.z)
        Lara:SetRotation(newRot)
    end
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.RIGHT) then
        -- Rotate Lara right
        local newRot = TEN.Rotation(laraRot.x, laraRot.y + 2, laraRot.z)
        Lara:SetRotation(newRot)
    end
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.JUMP) then
        newPos = TEN.Vec3(newPos.x, newPos.y - speed, newPos.z)
    end
    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.CROUCH) then
        newPos = TEN.Vec3(newPos.x, newPos.y + speed, newPos.z)
    end

    Lara:SetPosition(newPos)
end

-------------------------------------------------------------------------------
-- Light Emission
-------------------------------------------------------------------------------

local function UpdateLightEmission()
    if not State.lightEnabled then return end

    -- Determine light position based on source mode
    local lightPos = State.lightPos

    if State.lightSource == LSRC_FOLLOW_CAMERA and State.cameraMesh then
        lightPos = State.cameraMesh:GetPosition()
    elseif State.lightSource == LSRC_FOLLOW_LARA then
        local lp = Lara:GetPosition()
        lightPos = TEN.Vec3(lp.x, lp.y - 256, lp.z)
    end

    local lightColor = COLOR_PRESETS[State.lightColorIndex].color

    pcall(function()
        TEN.Effects.EmitLight(lightPos, lightColor, State.lightRadius, State.lightShadows, PHOTO_MODE_LIGHT)
    end)
end

-------------------------------------------------------------------------------
-- UI: DisplayString Management
-------------------------------------------------------------------------------

local function HideAllStrings()
    for _, ds in pairs(State.displayStrings) do
        pcall(function()
            TEN.Strings.HideString(ds)
        end)
    end
    State.displayStrings = {}
end

local function ShowUIString(key, text, x, y, color, scale)
    -- Create or update a display string
    local px, py = TEN.Util.PercentToScreen(x, y)
    local pos = TEN.Vec2(px, py)
    local flags = { TEN.Strings.DisplayStringOption.SHADOW }

    local ds = TEN.Strings.DisplayString(text, pos, scale or UI_SCALE, color or UI_COLOR_NORMAL, false, flags)
    TEN.Strings.ShowString(ds)

    State.displayStrings[key] = ds
end

local function RenderUI()
    if State.hideUI then
        HideAllStrings()
        State.uiDirty = false
        return
    end

    -- Only rebuild UI when state changes (not every frame)
    if not State.uiDirty then return end
    State.uiDirty = false

    -- Clear previous strings
    HideAllStrings()

    if not Menu then return end

    local y = UI_TOP_Y

    -- Title
    ShowUIString("title", "-- PHOTO MODE --", UI_LEFT_X, y, UI_COLOR_TITLE, UI_SCALE)
    y = y + UI_LINE_HEIGHT

    -- Control mode display
    ShowUIString("ctrl", "Control: " .. CTRL_NAMES[State.controlMode], UI_LEFT_X, y, UI_COLOR_DIMMED, UI_SCALE * 0.8)
    y = y + UI_LINE_HEIGHT * 0.8

    -- Separator
    y = y + UI_LINE_HEIGHT * 0.3

    -- Category tabs
    local catLine = ""
    for i, cat in ipairs(Menu) do
        if i == State.categoryIndex then
            catLine = catLine .. "[" .. cat.name .. "]  "
        else
            catLine = catLine .. cat.name .. "  "
        end
    end
    ShowUIString("categories", catLine, UI_LEFT_X, y, UI_COLOR_CATEGORY, UI_SCALE * 0.8)
    y = y + UI_LINE_HEIGHT

    -- Separator line
    ShowUIString("sep", "---", UI_LEFT_X, y, UI_COLOR_DIMMED, UI_SCALE * 0.6)
    y = y + UI_LINE_HEIGHT * 0.5

    -- Options for current category
    local currentCat = Menu[State.categoryIndex]
    if not currentCat then return end

    for i, opt in ipairs(currentCat.options) do
        local isSelected = (i == State.optionIndex)
        local color = isSelected and UI_COLOR_HIGHLIGHT or UI_COLOR_NORMAL
        local prefix = isSelected and "> " or "  "

        local valueStr = ""
        if opt.type == OPT_SLIDER then
            local val = opt.get()
            if opt.format then
                valueStr = "  < " .. opt.format(val) .. " >"
            else
                valueStr = "  < " .. tostring(math.floor(val)) .. " >"
            end
        elseif opt.type == OPT_SELECTOR then
            local idx = opt.get()
            local name = opt.items[idx] or "?"
            valueStr = "  < " .. name .. " >"
        elseif opt.type == OPT_TOGGLE then
            local val = opt.get()
            valueStr = "  [" .. (val and "ON" or "OFF") .. "]"
        elseif opt.type == OPT_BUTTON then
            valueStr = "  [Press]"
        elseif opt.type == OPT_DISPLAY then
            valueStr = "  " .. (opt.get() or "")
        end

        ShowUIString("opt_" .. i, prefix .. opt.label .. valueStr, UI_LEFT_X, y, color, UI_SCALE)
        y = y + UI_LINE_HEIGHT
    end

    -- Help text at bottom
    y = y + UI_LINE_HEIGHT * 0.5
    ShowUIString("help", "Up/Down=Navigate  Left/Right=Adjust  Action=Confirm  Look=Move Mode  Inventory=Exit",
        UI_LEFT_X, y, UI_COLOR_DIMMED, UI_SCALE * 0.65)
end

-------------------------------------------------------------------------------
-- Menu Navigation & Input
-------------------------------------------------------------------------------

local function HandleMenuInput()
    if not Menu then return end
    local currentCat = Menu[State.categoryIndex]
    if not currentCat then return end

    -- Navigate categories with Step Left / Step Right
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.STEP_LEFT) then
        State.categoryIndex = State.categoryIndex - 1
        if State.categoryIndex < 1 then State.categoryIndex = #Menu end
        State.optionIndex = 1
        State.uiDirty = true
        return
    end
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.STEP_RIGHT) then
        State.categoryIndex = State.categoryIndex + 1
        if State.categoryIndex > #Menu then State.categoryIndex = 1 end
        State.optionIndex = 1
        State.uiDirty = true
        return
    end

    -- Navigate options with Arrow Up / Arrow Down
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.ARROW_UP) then
        State.optionIndex = State.optionIndex - 1
        if State.optionIndex < 1 then State.optionIndex = #currentCat.options end
        State.uiDirty = true
    end
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.ARROW_DOWN) then
        State.optionIndex = State.optionIndex + 1
        if State.optionIndex > #currentCat.options then State.optionIndex = 1 end
        State.uiDirty = true
    end

    local opt = currentCat.options[State.optionIndex]
    if not opt then return end

    -- Adjust values with Arrow Left / Arrow Right
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.ARROW_LEFT) or
       TEN.Input.IsKeyPulsed(TEN.Input.ActionID.ARROW_LEFT, 0.15, 0.4) then
        if opt.type == OPT_SLIDER then
            local val = opt.get() - opt.step
            val = Clamp(val, opt.min, opt.max)
            val = Round(val, 2)
            opt.set(val)
            State.uiDirty = true
        elseif opt.type == OPT_SELECTOR then
            local val = opt.get() - 1
            if val < 1 then val = #opt.items end
            opt.set(val)
            State.uiDirty = true
        end
    end
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.ARROW_RIGHT) or
       TEN.Input.IsKeyPulsed(TEN.Input.ActionID.ARROW_RIGHT, 0.15, 0.4) then
        if opt.type == OPT_SLIDER then
            local val = opt.get() + opt.step
            val = Clamp(val, opt.min, opt.max)
            val = Round(val, 2)
            opt.set(val)
            State.uiDirty = true
        elseif opt.type == OPT_SELECTOR then
            local val = opt.get() + 1
            if val > #opt.items then val = 1 end
            opt.set(val)
            State.uiDirty = true
        end
    end

    -- Confirm with Action
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.ACTION) then
        if opt.type == OPT_BUTTON and opt.action then
            opt.action()
            State.uiDirty = true
        elseif opt.type == OPT_TOGGLE then
            opt.set(not opt.get())
            State.uiDirty = true
        end
    end
end

-------------------------------------------------------------------------------
-- Main Loop Callback (entry detection)
-------------------------------------------------------------------------------

LevelFuncs.Engine.PhotoMode.OnLoop = function()
    if State.active then return end

    -- Detect entry chord: Walk + Inventory held together for ENTRY_HOLD_FRAMES
    local walkHeld = TEN.Input.IsKeyHeld(TEN.Input.ActionID.WALK)
    local invHeld = TEN.Input.IsKeyHeld(TEN.Input.ActionID.INVENTORY)

    if walkHeld or invHeld then
        State.entryHoldCount = State.entryHoldCount + 1
        if State.entryHoldCount >= ENTRY_HOLD_FRAMES then
            State.entryHoldCount = 0
            TEN.Input.ClearAllKeys()
            EnterPhotoMode()
        end
    else
        State.entryHoldCount = 0
    end
end

-------------------------------------------------------------------------------
-- Freeze Callback (Photo Mode active logic)
-------------------------------------------------------------------------------

LevelFuncs.Engine.PhotoMode.OnFreeze = function()
    if not State.active then return end

    -- Consume/clear gameplay inputs so normal gameplay actions do not fire
    --TEN.Input.ClearAllKeys()

    -- Toggle UI visibility with LOOK key (always available)
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.LOOK) then
        State.hideUI = not State.hideUI
        State.uiDirty = true
    end

    -- Exit with Inventory key (always available)
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.INVENTORY) then
        ExitPhotoMode()
        return
    end

    if State.hideUI then
        -- UI hidden: process movement controls only (no menu fighting)
        if State.controlMode == CTRL_CAMERA then
            UpdateCameraControls()
        elseif State.controlMode == CTRL_PLAYER then
            UpdatePlayerControls()
        end
    else
        -- UI visible: process menu input only (no movement fighting)
        HandleMenuInput()
    end

    -- If exited during menu handling, stop
    if not State.active then return end

    -- Attach camera each frame to maintain view
    AttachCamera()

    -- Emit light
    UpdateLightEmission()

    -- Render UI
    RenderUI()
end

-------------------------------------------------------------------------------
-- Register Callbacks
-------------------------------------------------------------------------------

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POSTLOOP, LevelFuncs.Engine.PhotoMode.OnLoop)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.PhotoMode.OnFreeze)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Check if Photo Mode is currently active.
-- @treturn bool True if Photo Mode is active.
PhotoMode.IsActive = function()
    return State.active
end

--- Manually enter Photo Mode (alternative to chord input).
PhotoMode.Enter = function()
    EnterPhotoMode()
end

--- Manually exit Photo Mode.
PhotoMode.Exit = function()
    ExitPhotoMode()
end

return PhotoMode
