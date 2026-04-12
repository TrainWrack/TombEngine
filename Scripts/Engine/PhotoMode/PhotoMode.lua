--- PhotoMode entry point.
-- Orchestrates all sub-modules: Camera, States, Input, Menu, Frames.
-- Uses the RingInventory-style Menu with header tabs to provide a polished UI.
--
-- To use in a level script:
--
--    local PhotoMode = require("Engine.PhotoMode.PhotoMode")
--
-- Entry is triggered by holding Walk + Inventory for N frames.
-- While active the game is frozen (SPECTATOR mode) and the object camera is used.
--
-- @module Engine.PhotoMode.PhotoMode
-- @local

local Camera   = require("Engine.PhotoMode.Camera")
local Frames   = require("Engine.PhotoMode.Frames")
local Input    = require("Engine.PhotoMode.Input")
local Menu     = require("Engine.PhotoMode.Menu")
local Settings = require("Engine.PhotoMode.Settings")
local States   = require("Engine.PhotoMode.States")

LevelFuncs.Engine.PhotoMode = LevelFuncs.Engine.PhotoMode or {}

local PhotoMode = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function Clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function Round(val, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(val * mult + 0.5) / mult
end

-- ============================================================================
-- Option name builders (for selector-type options)
-- ============================================================================

local function BuildNames(list, key)
    local t = {}
    for _, v in ipairs(list) do t[#t + 1] = v[key or "name"] end
    return t
end

local CTRL_MODE_NAMES  = States.ModeNames
local LIGHT_SRC_NAMES  = Settings.Light.sourceNames
local FILTER_NAMES     = BuildNames(Settings.Filters.presets)
local TINT_NAMES       = BuildNames(Settings.Filters.tints)
local COLOR_NAMES      = BuildNames(Settings.Light.colorPresets)
local OUTFIT_NAMES     = BuildNames(Settings.Outfits)
local WEAPON_NAMES     = BuildNames(Settings.Weapons)
local FRAME_NAMES      = BuildNames(Settings.Frames.presets)

-- ============================================================================
-- LevelFuncs callbacks for menu option changes
-- ============================================================================

-- We register thin callback stubs in LevelFuncs so Menu can call them by name.

LevelFuncs.Engine.PhotoMode.OnAccept = function()
    -- Accept on the currently selected item: for items-only menus this is a no-op
end

LevelFuncs.Engine.PhotoMode.OnExit = function()
    PhotoMode.Exit()
end

-- ============================================================================
-- Apply Functions (setters triggered by option changes)
-- ============================================================================

local function ApplyFOV(state)
    TEN.View.SetFOV(state.fov)
end

local function ApplyRoll(state)
    TEN.View.SetRoll(state.roll)
end

local function ApplyFilter(state)
    local preset = Settings.Filters.presets[state.filterIndex]
    if preset then
        TEN.View.SetPostProcessMode(preset.mode)
    end
end

local function ApplyFilterStrength(state)
    TEN.View.SetPostProcessStrength(state.filterStrength)
end

local function ApplyTint(state)
    local preset = Settings.Filters.tints[state.tintIndex]
    if preset then
        TEN.View.SetPostProcessTint(preset.color)
    end
end

local function ApplyOutfit(state)
    -- Reset existing swaps
    for _, meshIdx in ipairs(state.swappedMeshes) do
        pcall(function() Lara:UnswapSkinnedMesh(meshIdx) end)
    end
    state.swappedMeshes = {}

    local preset = Settings.Outfits[state.outfitIndex]
    if preset and preset.objID then
        pcall(function() Lara:SwapSkinnedMesh(preset.objID) end)
    end
end

local function ApplyPoseAnim(state)
    pcall(function() Lara:SetAnim(state.animIndex) end)
end

local function ApplyPoseFrame(state)
    pcall(function() Lara:SetFrame(state.animFrame) end)
end

-- ============================================================================
-- Reset Functions
-- ============================================================================

local function ResetCamera()
    Camera.Reset()
end

local function ResetLens()
    local state = States.Get()
    state.fov  = state.entryFov
    state.roll = state.entryRoll
    ApplyFOV(state)
    ApplyRoll(state)
end

local function ResetPose()
    local state = States.Get()
    if not state.snapshot then return end
    pcall(function() Lara:SetAnim(state.snapshot.laraAnim, state.snapshot.laraAnimSlot) end)
    pcall(function() Lara:SetFrame(state.snapshot.laraFrame) end)
    state.animIndex = state.snapshot.laraAnim
    state.animFrame = state.snapshot.laraFrame
end

local function ResetFilters()
    local state = States.Get()
    state.filterIndex    = 1
    state.filterStrength = 1.0
    state.tintIndex      = 1
    ApplyFilter(state)
    ApplyFilterStrength(state)
    ApplyTint(state)
end

local function ResetLight()
    local state = States.Get()
    if state.entryLight then
        state.lightEnabled    = state.entryLight.enabled
        state.lightSource     = state.entryLight.source
        state.lightPos        = TEN.Vec3(state.entryLight.pos.x, state.entryLight.pos.y, state.entryLight.pos.z)
        state.lightRadius     = state.entryLight.radius
        state.lightShadows    = state.entryLight.shadows
        state.lightColorIndex = state.entryLight.colorIndex
    end
end

local function ResetAppearance()
    local state = States.Get()
    for _, meshIdx in ipairs(state.swappedMeshes) do
        pcall(function() Lara:UnswapSkinnedMesh(meshIdx) end)
    end
    state.swappedMeshes = {}
    state.outfitIndex = 1
    state.weaponIndex = 1
end

local function PlaceLightAtCamera()
    local state = States.Get()
    if state.cameraMesh then
        local cp = state.cameraMesh:GetPosition()
        state.lightPos = TEN.Vec3(cp.x, cp.y, cp.z)
        state.lightSource = States.LightSource.MANUAL
    end
end

local function PlaceLightAtLara()
    local state = States.Get()
    local lp = Lara:GetPosition()
    state.lightPos = TEN.Vec3(lp.x, lp.y - 256, lp.z)
    state.lightSource = States.LightSource.MANUAL
end

-- ============================================================================
-- Menu Construction
-- ============================================================================

-- Each header maps to one menu. Menu items use ITEMS_AND_OPTIONS type so
-- left/right changes values while forward/back navigates items.

local MENU_CAMERA  = "pm_camera"
local MENU_LENS    = "pm_lens"
local MENU_POSE    = "pm_pose"
local MENU_LIGHT   = "pm_light"
local MENU_FILTERS = "pm_filters"
local MENU_OUTFIT  = "pm_outfit"
local MENU_FRAMES  = "pm_frames"
local MENU_UI      = "pm_ui"

local function NumberRange(min, max, step, format)
    local opts = {}
    local val = min
    while val <= max + step * 0.01 do
        if format then
            opts[#opts + 1] = format(val)
        else
            opts[#opts + 1] = tostring(math.floor(val))
        end
        val = val + step
    end
    return opts
end

local function BoolOptions()
    return { "OFF", "ON" }
end

local function BoolToIndex(v)
    return v and 2 or 1
end

local function IndexToBool(i)
    return i == 2
end

local function ValueToOptionIndex(value, min, step)
    return math.floor((value - min) / step + 0.5) + 1
end

local function OptionIndexToValue(index, min, step)
    return min + (index - 1) * step
end

local function BuildAllMenus()
    local state = States.Get()
    local cfg   = Settings

    Menu.DeleteAll()

    -- ================================================================
    -- CAMERA menu
    -- ================================================================
    local cameraItems = {
        { itemName = "Mode",       options = CTRL_MODE_NAMES, currentOption = state.controlMode },
        { itemName = "Move Speed", options = NumberRange(cfg.Camera.minMoveSpeed, cfg.Camera.maxMoveSpeed, cfg.Camera.moveSpeedStep),
          currentOption = ValueToOptionIndex(state.moveSpeed, cfg.Camera.minMoveSpeed, cfg.Camera.moveSpeedStep) },
        { itemName = "Look Speed", options = NumberRange(cfg.Camera.minLookSpeed, cfg.Camera.maxLookSpeed, cfg.Camera.lookSpeedStep,
              function(v) return string.format("%.1f", v) end),
          currentOption = ValueToOptionIndex(state.lookSpeed, cfg.Camera.minLookSpeed, cfg.Camera.lookSpeedStep) },
        { itemName = "Collision",  options = BoolOptions(), currentOption = BoolToIndex(state.collisionOn) },
        { itemName = "Reset Camera", options = { "[Press]" }, currentOption = 1 },
    }
    local camMenu = Menu.Create(MENU_CAMERA, "", cameraItems,
        "Engine.PhotoMode.OnAccept", "Engine.PhotoMode.OnExit", Menu.Type.ITEMS_AND_OPTIONS)
    camMenu:SetItemsPosition(Vec2(15, 25))
    camMenu:SetOptionsPosition(Vec2(55, 25))
    camMenu:SetTitle("", nil, 0)
    camMenu:SetOnItemChangeFunction("Engine.PhotoMode.OnCameraItemChange")

    -- Option change callbacks
    LevelFuncs.Engine.PhotoMode.OnCameraItemChange = function()
        local m = Menu.Get(MENU_CAMERA)
        if not m then return end
        -- Sync state from options
        state.controlMode = m:GetOptionIndexForItem(1)
        state.moveSpeed   = OptionIndexToValue(m:GetOptionIndexForItem(2), cfg.Camera.minMoveSpeed, cfg.Camera.moveSpeedStep)
        state.lookSpeed   = OptionIndexToValue(m:GetOptionIndexForItem(3), cfg.Camera.minLookSpeed, cfg.Camera.lookSpeedStep)
        state.collisionOn = IndexToBool(m:GetOptionIndexForItem(4))
    end

    -- Per-item option change
    for i, item in ipairs(cameraItems) do
        item.onOptionChange = "Engine.PhotoMode.OnCameraOptionChange"
    end
    LevelFuncs.Engine.PhotoMode.OnCameraOptionChange = function()
        local m = Menu.Get(MENU_CAMERA)
        if not m then return end
        local idx = m:GetCurrentItemIndex()
        if idx == 1 then state.controlMode = m:GetCurrentOptionIndex()
        elseif idx == 2 then state.moveSpeed = OptionIndexToValue(m:GetCurrentOptionIndex(), cfg.Camera.minMoveSpeed, cfg.Camera.moveSpeedStep)
        elseif idx == 3 then state.lookSpeed = OptionIndexToValue(m:GetCurrentOptionIndex(), cfg.Camera.minLookSpeed, cfg.Camera.lookSpeedStep)
        elseif idx == 4 then state.collisionOn = IndexToBool(m:GetCurrentOptionIndex())
        elseif idx == 5 then ResetCamera()
        end
    end

    -- ================================================================
    -- LENS menu
    -- ================================================================
    local lensItems = {
        { itemName = "FOV",  options = NumberRange(cfg.Lens.minFOV, cfg.Lens.maxFOV, cfg.Lens.fovStep),
          currentOption = ValueToOptionIndex(state.fov, cfg.Lens.minFOV, cfg.Lens.fovStep) },
        { itemName = "Roll", options = NumberRange(cfg.Lens.minRoll, cfg.Lens.maxRoll, cfg.Lens.rollStep),
          currentOption = ValueToOptionIndex(state.roll, cfg.Lens.minRoll, cfg.Lens.rollStep) },
        { itemName = "Reset Lens", options = { "[Press]" }, currentOption = 1 },
    }
    local lensMenu = Menu.Create(MENU_LENS, "", lensItems,
        "Engine.PhotoMode.OnAccept", "Engine.PhotoMode.OnExit", Menu.Type.ITEMS_AND_OPTIONS)
    lensMenu:SetItemsPosition(Vec2(15, 25))
    lensMenu:SetOptionsPosition(Vec2(55, 25))
    lensMenu:SetTitle("", nil, 0)

    for _, item in ipairs(lensItems) do
        item.onOptionChange = "Engine.PhotoMode.OnLensOptionChange"
    end
    LevelFuncs.Engine.PhotoMode.OnLensOptionChange = function()
        local m = Menu.Get(MENU_LENS)
        if not m then return end
        local idx = m:GetCurrentItemIndex()
        if idx == 1 then
            state.fov = OptionIndexToValue(m:GetCurrentOptionIndex(), cfg.Lens.minFOV, cfg.Lens.fovStep)
            ApplyFOV(state)
        elseif idx == 2 then
            state.roll = OptionIndexToValue(m:GetCurrentOptionIndex(), cfg.Lens.minRoll, cfg.Lens.rollStep)
            ApplyRoll(state)
        elseif idx == 3 then
            ResetLens()
            -- Update menu option indices to reflect reset
            m:SetOptionIndexForItem(1, ValueToOptionIndex(state.fov, cfg.Lens.minFOV, cfg.Lens.fovStep))
            m:SetOptionIndexForItem(2, ValueToOptionIndex(state.roll, cfg.Lens.minRoll, cfg.Lens.rollStep))
        end
    end

    -- ================================================================
    -- POSE menu
    -- ================================================================
    local poseItems = {
        { itemName = "Anim Index", options = NumberRange(0, 999, 1),
          currentOption = state.animIndex + 1 },
        { itemName = "Frame",      options = NumberRange(0, 999, 1),
          currentOption = state.animFrame + 1 },
        { itemName = "Reset Pose", options = { "[Press]" }, currentOption = 1 },
    }
    local poseMenu = Menu.Create(MENU_POSE, "", poseItems,
        "Engine.PhotoMode.OnAccept", "Engine.PhotoMode.OnExit", Menu.Type.ITEMS_AND_OPTIONS)
    poseMenu:SetItemsPosition(Vec2(15, 25))
    poseMenu:SetOptionsPosition(Vec2(55, 25))
    poseMenu:SetTitle("", nil, 0)

    for _, item in ipairs(poseItems) do
        item.onOptionChange = "Engine.PhotoMode.OnPoseOptionChange"
    end
    LevelFuncs.Engine.PhotoMode.OnPoseOptionChange = function()
        local m = Menu.Get(MENU_POSE)
        if not m then return end
        local idx = m:GetCurrentItemIndex()
        if idx == 1 then
            state.animIndex = m:GetCurrentOptionIndex() - 1
            ApplyPoseAnim(state)
        elseif idx == 2 then
            state.animFrame = m:GetCurrentOptionIndex() - 1
            ApplyPoseFrame(state)
        elseif idx == 3 then
            ResetPose()
            m:SetOptionIndexForItem(1, state.animIndex + 1)
            m:SetOptionIndexForItem(2, state.animFrame + 1)
        end
    end

    -- ================================================================
    -- LIGHT menu
    -- ================================================================
    local lightItems = {
        { itemName = "Enabled",        options = BoolOptions(), currentOption = BoolToIndex(state.lightEnabled) },
        { itemName = "Source",          options = LIGHT_SRC_NAMES, currentOption = state.lightSource },
        { itemName = "Radius",         options = NumberRange(cfg.Light.minRadius, cfg.Light.maxRadius, cfg.Light.radiusStep),
          currentOption = ValueToOptionIndex(state.lightRadius, cfg.Light.minRadius, cfg.Light.radiusStep) },
        { itemName = "Shadows",        options = BoolOptions(), currentOption = BoolToIndex(state.lightShadows) },
        { itemName = "Color",          options = COLOR_NAMES, currentOption = state.lightColorIndex },
        { itemName = "Place at Camera", options = { "[Press]" }, currentOption = 1 },
        { itemName = "Place at Lara",   options = { "[Press]" }, currentOption = 1 },
        { itemName = "Reset Light",     options = { "[Press]" }, currentOption = 1 },
    }
    local lightMenu = Menu.Create(MENU_LIGHT, "", lightItems,
        "Engine.PhotoMode.OnAccept", "Engine.PhotoMode.OnExit", Menu.Type.ITEMS_AND_OPTIONS)
    lightMenu:SetItemsPosition(Vec2(15, 25))
    lightMenu:SetOptionsPosition(Vec2(55, 25))
    lightMenu:SetTitle("", nil, 0)

    for _, item in ipairs(lightItems) do
        item.onOptionChange = "Engine.PhotoMode.OnLightOptionChange"
    end
    LevelFuncs.Engine.PhotoMode.OnLightOptionChange = function()
        local m = Menu.Get(MENU_LIGHT)
        if not m then return end
        local idx = m:GetCurrentItemIndex()
        if idx == 1 then state.lightEnabled = IndexToBool(m:GetCurrentOptionIndex())
        elseif idx == 2 then state.lightSource = m:GetCurrentOptionIndex()
        elseif idx == 3 then state.lightRadius = OptionIndexToValue(m:GetCurrentOptionIndex(), cfg.Light.minRadius, cfg.Light.radiusStep)
        elseif idx == 4 then state.lightShadows = IndexToBool(m:GetCurrentOptionIndex())
        elseif idx == 5 then state.lightColorIndex = m:GetCurrentOptionIndex()
        elseif idx == 6 then PlaceLightAtCamera()
        elseif idx == 7 then PlaceLightAtLara()
        elseif idx == 8 then ResetLight()
        end
    end

    -- ================================================================
    -- FILTERS menu
    -- ================================================================
    local filterItems = {
        { itemName = "Preset",   options = FILTER_NAMES, currentOption = state.filterIndex },
        { itemName = "Strength", options = NumberRange(0, 1.0, 0.05, function(v) return string.format("%.2f", v) end),
          currentOption = ValueToOptionIndex(state.filterStrength, 0, 0.05) },
        { itemName = "Tint",     options = TINT_NAMES, currentOption = state.tintIndex },
        { itemName = "Reset Filters", options = { "[Press]" }, currentOption = 1 },
    }
    local filterMenu = Menu.Create(MENU_FILTERS, "", filterItems,
        "Engine.PhotoMode.OnAccept", "Engine.PhotoMode.OnExit", Menu.Type.ITEMS_AND_OPTIONS)
    filterMenu:SetItemsPosition(Vec2(15, 25))
    filterMenu:SetOptionsPosition(Vec2(55, 25))
    filterMenu:SetTitle("", nil, 0)

    for _, item in ipairs(filterItems) do
        item.onOptionChange = "Engine.PhotoMode.OnFilterOptionChange"
    end
    LevelFuncs.Engine.PhotoMode.OnFilterOptionChange = function()
        local m = Menu.Get(MENU_FILTERS)
        if not m then return end
        local idx = m:GetCurrentItemIndex()
        if idx == 1 then
            state.filterIndex = m:GetCurrentOptionIndex()
            ApplyFilter(state)
        elseif idx == 2 then
            state.filterStrength = OptionIndexToValue(m:GetCurrentOptionIndex(), 0, 0.05)
            ApplyFilterStrength(state)
        elseif idx == 3 then
            state.tintIndex = m:GetCurrentOptionIndex()
            ApplyTint(state)
        elseif idx == 4 then
            ResetFilters()
            m:SetOptionIndexForItem(1, state.filterIndex)
            m:SetOptionIndexForItem(2, ValueToOptionIndex(state.filterStrength, 0, 0.05))
            m:SetOptionIndexForItem(3, state.tintIndex)
        end
    end

    -- ================================================================
    -- OUTFIT menu
    -- ================================================================
    local outfitItems = {
        { itemName = "Outfit",  options = OUTFIT_NAMES, currentOption = state.outfitIndex },
        { itemName = "Weapons", options = WEAPON_NAMES, currentOption = state.weaponIndex },
        { itemName = "Reset",   options = { "[Press]" }, currentOption = 1 },
    }
    local outfitMenu = Menu.Create(MENU_OUTFIT, "", outfitItems,
        "Engine.PhotoMode.OnAccept", "Engine.PhotoMode.OnExit", Menu.Type.ITEMS_AND_OPTIONS)
    outfitMenu:SetItemsPosition(Vec2(15, 25))
    outfitMenu:SetOptionsPosition(Vec2(55, 25))
    outfitMenu:SetTitle("", nil, 0)

    for _, item in ipairs(outfitItems) do
        item.onOptionChange = "Engine.PhotoMode.OnOutfitOptionChange"
    end
    LevelFuncs.Engine.PhotoMode.OnOutfitOptionChange = function()
        local m = Menu.Get(MENU_OUTFIT)
        if not m then return end
        local idx = m:GetCurrentItemIndex()
        if idx == 1 then
            state.outfitIndex = m:GetCurrentOptionIndex()
            ApplyOutfit(state)
        elseif idx == 2 then
            state.weaponIndex = m:GetCurrentOptionIndex()
        elseif idx == 3 then
            ResetAppearance()
            m:SetOptionIndexForItem(1, state.outfitIndex)
            m:SetOptionIndexForItem(2, state.weaponIndex)
        end
    end

    -- ================================================================
    -- FRAMES menu
    -- ================================================================
    local framesItems = {
        { itemName = "Frame", options = FRAME_NAMES, currentOption = state.frameIndex },
    }
    local framesMenu = Menu.Create(MENU_FRAMES, "", framesItems,
        "Engine.PhotoMode.OnAccept", "Engine.PhotoMode.OnExit", Menu.Type.ITEMS_AND_OPTIONS)
    framesMenu:SetItemsPosition(Vec2(15, 25))
    framesMenu:SetOptionsPosition(Vec2(55, 25))
    framesMenu:SetTitle("", nil, 0)

    for _, item in ipairs(framesItems) do
        item.onOptionChange = "Engine.PhotoMode.OnFrameOptionChange"
    end
    LevelFuncs.Engine.PhotoMode.OnFrameOptionChange = function()
        local m = Menu.Get(MENU_FRAMES)
        if not m then return end
        state.frameIndex = m:GetCurrentOptionIndex()
    end

    -- ================================================================
    -- UI menu
    -- ================================================================
    local uiItems = {
        { itemName = "Hide UI",          options = BoolOptions(), currentOption = BoolToIndex(state.hideUI) },
        { itemName = "Exit Photo Mode",  options = { "[Press]" }, currentOption = 1 },
    }
    local uiMenu = Menu.Create(MENU_UI, "", uiItems,
        "Engine.PhotoMode.OnAccept", "Engine.PhotoMode.OnExit", Menu.Type.ITEMS_AND_OPTIONS)
    uiMenu:SetItemsPosition(Vec2(15, 25))
    uiMenu:SetOptionsPosition(Vec2(55, 25))
    uiMenu:SetTitle("", nil, 0)

    for _, item in ipairs(uiItems) do
        item.onOptionChange = "Engine.PhotoMode.OnUIOptionChange"
    end
    LevelFuncs.Engine.PhotoMode.OnUIOptionChange = function()
        local m = Menu.Get(MENU_UI)
        if not m then return end
        local idx = m:GetCurrentItemIndex()
        if idx == 1 then
            state.hideUI = IndexToBool(m:GetCurrentOptionIndex())
        elseif idx == 2 then
            PhotoMode.Exit()
        end
    end

    -- ================================================================
    -- Set up headers (STEP_LEFT / STEP_RIGHT to navigate)
    -- ================================================================
    Menu.SetHeaders({
        { name = "Camera",  menuName = MENU_CAMERA },
        { name = "Lens",    menuName = MENU_LENS },
        { name = "Pose",    menuName = MENU_POSE },
        { name = "Light",   menuName = MENU_LIGHT },
        { name = "Filters", menuName = MENU_FILTERS },
        { name = "Outfit",  menuName = MENU_OUTFIT },
        { name = "Frames",  menuName = MENU_FRAMES },
        { name = "UI",      menuName = MENU_UI },
    })

    -- Activate the first header's menu
    Menu.SetActiveHeader(1)
end

-- ============================================================================
-- Light Emission (every frame while active)
-- ============================================================================

local function UpdateLightEmission()
    local state = States.Get()
    if not state.lightEnabled then return end

    local lightPos = state.lightPos

    if state.lightSource == States.LightSource.FOLLOW_CAMERA and state.cameraMesh then
        lightPos = state.cameraMesh:GetPosition()
    elseif state.lightSource == States.LightSource.FOLLOW_LARA then
        local lp = Lara:GetPosition()
        lightPos = TEN.Vec3(lp.x, lp.y - 256, lp.z)
    end

    local lightColor = Settings.Light.colorPresets[state.lightColorIndex].color

    pcall(function()
        TEN.Effects.EmitLight(lightPos, lightColor, state.lightRadius, state.lightShadows, Settings.Light.lightName)
    end)
end

-- ============================================================================
-- Entry / Exit
-- ============================================================================

function PhotoMode.Enter()
    if States.IsActive() then return end

    -- Capture snapshot
    local snap = States.CaptureSnapshot()
    if not snap then return end

    -- Create camera objects
    if not Camera.Init() then return end

    -- Place camera relative to Lara
    Camera.PlaceInitial()

    -- Reset state to defaults
    States.ResetToEntry()
    States.SetActive(true)

    local state = States.Get()
    state.entryFov  = snap.fov
    state.entryRoll = 0
    state.animIndex = snap.laraAnim
    state.animFrame = snap.laraFrame

    -- Store entry light state
    local camPos = state.cameraMesh:GetPosition()
    state.entryLight = {
        enabled    = state.lightEnabled,
        source     = state.lightSource,
        pos        = TEN.Vec3(camPos.x, camPos.y, camPos.z),
        radius     = state.lightRadius,
        shadows    = state.lightShadows,
        colorIndex = state.lightColorIndex,
    }
    state.lightPos = TEN.Vec3(camPos.x, camPos.y, camPos.z)

    -- Build menus
    BuildAllMenus()

    -- Freeze the game
    TEN.Flow.SetFreezeMode(TEN.Flow.FreezeMode.SPECTATOR)

    -- Attach object camera
    Camera.Attach()

    TEN.Input.ClearAllKeys()
    TEN.Util.PrintLog("PhotoMode: Entered.", TEN.Util.LogLevel.INFO)
end

function PhotoMode.Exit()
    if not States.IsActive() then return end

    -- Restore snapshot
    States.RestoreSnapshot()

    -- Detach camera
    Camera.Detach()

    -- Stop light
    pcall(function()
        local state = States.Get()
        TEN.Effects.EmitLight(state.lightPos, TEN.Color(0, 0, 0), 0, false, Settings.Light.lightName)
    end)

    -- Clean up menus
    Menu.DeleteAll()

    -- Clear frames
    Frames.Clear()

    -- Unfreeze
    TEN.Flow.SetFreezeMode(TEN.Flow.FreezeMode.NONE)

    States.SetActive(false)
    States.Get().snapshot = nil
    States.Get().entryHoldCount = 0

    TEN.Input.ClearAllKeys()
    TEN.Util.PrintLog("PhotoMode: Exited.", TEN.Util.LogLevel.INFO)
end

function PhotoMode.IsActive()
    return States.IsActive()
end

-- ============================================================================
-- Header drawing position
-- ============================================================================

local HEADER_POS   = TEN.Vec2(50, 15)
local HEADER_SCALE = 1.0

-- ============================================================================
-- Callbacks
-- ============================================================================

LevelFuncs.Engine.PhotoMode.OnLoop = function()
    if States.IsActive() then return end

    local state = States.Get()
    local walkHeld = TEN.Input.IsKeyHeld(TEN.Input.ActionID.WALK)
    local invHeld  = TEN.Input.IsKeyHeld(TEN.Input.ActionID.INVENTORY)

    if walkHeld or invHeld then
        state.entryHoldCount = state.entryHoldCount + 1
        if state.entryHoldCount >= Settings.Entry.holdFrames then
            state.entryHoldCount = 0
            TEN.Input.ClearAllKeys()
            PhotoMode.Enter()
        end
    else
        state.entryHoldCount = 0
    end
end

LevelFuncs.Engine.PhotoMode.OnFreeze = function()
    if not States.IsActive() then return end

    local state = States.Get()

    -- Toggle UI with LOOK key
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.LOOK) then
        state.hideUI = not state.hideUI
    end

    -- Exit with Inventory key (always available)
    if TEN.Input.IsKeyHit(TEN.Input.ActionID.INVENTORY) then
        PhotoMode.Exit()
        return
    end

    if state.hideUI then
        -- UI hidden: movement controls only
        Input.Update()
    else
        -- UI visible: menu handles input (includes header nav via STEP_LEFT/RIGHT)
        Menu.UpdateActiveMenus()
    end

    if not States.IsActive() then return end

    -- Attach camera every frame
    Camera.Attach()

    -- Emit light
    UpdateLightEmission()

    -- Update and draw frames
    Frames.Update()
    Frames.Draw()

    -- Draw UI (menus + headers) unless hidden
    if not state.hideUI then
        -- Draw header bar
        local headerAlpha = 255
        -- Use the alpha from the active menu for consistency
        local activeMenuName = Menu.GetActiveHeaderMenu()
        if activeMenuName then
            local m = Menu.Get(activeMenuName)
            if m and m.IsVisible and not m:IsVisible() then
                headerAlpha = 0
            end
        end
        Menu.DrawHeaders(HEADER_POS, HEADER_SCALE, headerAlpha)
        Menu.DrawActiveMenus()

        -- Draw mode indicator at top
        local modeText = "Mode: " .. States.GetModeName()
        local modePos  = TEN.Util.PercentToScreen(TEN.Vec2(50, 10))
        local modeStr  = TEN.Strings.DisplayString(
            modeText, modePos, 0.9,
            Settings.ColorMap.dimmed, false,
            { Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER }
        )
        TEN.Strings.ShowString(modeStr, 1 / 30)

        -- Draw control hint at bottom
        local helpText = "StepL/R=Tab  Up/Down=Select  Left/Right=Adjust  Look=Hide UI  Inventory=Exit"
        local helpPos  = TEN.Util.PercentToScreen(TEN.Vec2(50, 92))
        local helpStr  = TEN.Strings.DisplayString(
            helpText, helpPos, 0.65,
            Settings.ColorMap.dimmed, false,
            { Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER }
        )
        TEN.Strings.ShowString(helpStr, 1 / 30)
    end
end

-- ============================================================================
-- Register Callbacks
-- ============================================================================

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POSTLOOP,  LevelFuncs.Engine.PhotoMode.OnLoop)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.PhotoMode.OnFreeze)

return PhotoMode
