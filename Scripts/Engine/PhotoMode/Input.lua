--- Generic input handling for the PhotoMode module.
-- Based on the current control mode (Camera / Player / Light),
-- the same directional inputs move different things.
-- @module Engine.PhotoMode.Input
-- @local

local Camera   = require("Engine.PhotoMode.Camera")
local Settings = require("Engine.PhotoMode.Settings")
local States   = require("Engine.PhotoMode.States")

local ActionID = TEN.Input.ActionID
local Input = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function ForwardFromYaw(yawDeg)
    local rad = math.rad(yawDeg)
    return TEN.Vec3(math.sin(rad), 0, math.cos(rad))
end

local function Vec3Add(a, b)
    return TEN.Vec3(a.x + b.x, a.y + b.y, a.z + b.z)
end

local function Vec3Scale(v, s)
    return TEN.Vec3(v.x * s, v.y * s, v.z * s)
end

-- ============================================================================
-- Camera Controls
-- ============================================================================

local function UpdateCameraInput()
    local state = States.Get()
    local speed = state.moveSpeed
    local lookSpeed = state.lookSpeed

    -- Dolly forward / back
    if TEN.Input.IsKeyHeld(ActionID.FORWARD) then
        Camera.MoveForward(speed)
    end
    if TEN.Input.IsKeyHeld(ActionID.BACK) then
        Camera.MoveBack(speed)
    end

    -- Mouse scroll dolly
    if TEN.Input.IsKeyHit(ActionID.MOUSE_SCROLL_UP) then
        Camera.MoveForward(speed * 2)
    end
    if TEN.Input.IsKeyHit(ActionID.MOUSE_SCROLL_DOWN) then
        Camera.MoveBack(speed * 2)
    end

    -- Orbit horizontal
    local orbitAngle = 0
    if TEN.Input.IsKeyHeld(ActionID.LEFT) then
        orbitAngle = orbitAngle - lookSpeed
    end
    if TEN.Input.IsKeyHeld(ActionID.RIGHT) then
        orbitAngle = orbitAngle + lookSpeed
    end
    if math.abs(orbitAngle) > 0.001 then
        Camera.OrbitHorizontal(orbitAngle)
    end

    -- Vertical target adjust
    if TEN.Input.IsKeyHeld(ActionID.JUMP) then
        Camera.AdjustTargetVertical(-speed)
    end
    if TEN.Input.IsKeyHeld(ActionID.CROUCH) then
        Camera.AdjustTargetVertical(speed)
    end

    -- Strafe (step left / right consumed by header nav when menu is visible,
    -- so strafe only works when UI is hidden)
    if TEN.Input.IsKeyHeld(ActionID.STEP_LEFT) then
        Camera.Strafe(-speed)
    end
    if TEN.Input.IsKeyHeld(ActionID.STEP_RIGHT) then
        Camera.Strafe(speed)
    end
end

-- ============================================================================
-- Player Controls
-- ============================================================================

local function UpdatePlayerInput()
    local cfg   = Settings.Player
    local speed = cfg.moveSpeed
    local rotSpeed = cfg.rotateSpeed

    local laraPos = Lara:GetPosition()
    local laraRot = Lara:GetRotation()
    local fwd     = ForwardFromYaw(laraRot.y)

    local newPos = TEN.Vec3(laraPos.x, laraPos.y, laraPos.z)

    if TEN.Input.IsKeyHeld(ActionID.FORWARD) then
        newPos = Vec3Add(newPos, Vec3Scale(fwd, speed))
    end
    if TEN.Input.IsKeyHeld(ActionID.BACK) then
        newPos = Vec3Add(newPos, Vec3Scale(fwd, -speed))
    end
    if TEN.Input.IsKeyHeld(ActionID.LEFT) then
        Lara:SetRotation(TEN.Rotation(laraRot.x, laraRot.y - rotSpeed, laraRot.z))
    end
    if TEN.Input.IsKeyHeld(ActionID.RIGHT) then
        Lara:SetRotation(TEN.Rotation(laraRot.x, laraRot.y + rotSpeed, laraRot.z))
    end
    if TEN.Input.IsKeyHeld(ActionID.JUMP) then
        newPos = TEN.Vec3(newPos.x, newPos.y - speed, newPos.z)
    end
    if TEN.Input.IsKeyHeld(ActionID.CROUCH) then
        newPos = TEN.Vec3(newPos.x, newPos.y + speed, newPos.z)
    end

    Lara:SetPosition(newPos)
end

-- ============================================================================
-- Light Controls (manual placement mode)
-- ============================================================================

local function UpdateLightInput()
    local state = States.Get()
    local speed = Settings.Camera.defaultMoveSpeed

    local lightPos = state.lightPos

    -- Move light with directional keys (XZ plane based on camera direction)
    local dir   = Camera.GetDirection()
    local right = Camera.GetRightVector()

    if TEN.Input.IsKeyHeld(ActionID.FORWARD) then
        lightPos = Vec3Add(lightPos, Vec3Scale(TEN.Vec3(dir.x, 0, dir.z), speed))
    end
    if TEN.Input.IsKeyHeld(ActionID.BACK) then
        lightPos = Vec3Add(lightPos, Vec3Scale(TEN.Vec3(dir.x, 0, dir.z), -speed))
    end
    if TEN.Input.IsKeyHeld(ActionID.LEFT) then
        lightPos = Vec3Add(lightPos, Vec3Scale(right, -speed))
    end
    if TEN.Input.IsKeyHeld(ActionID.RIGHT) then
        lightPos = Vec3Add(lightPos, Vec3Scale(right, speed))
    end
    if TEN.Input.IsKeyHeld(ActionID.JUMP) then
        lightPos = TEN.Vec3(lightPos.x, lightPos.y - speed, lightPos.z)
    end
    if TEN.Input.IsKeyHeld(ActionID.CROUCH) then
        lightPos = TEN.Vec3(lightPos.x, lightPos.y + speed, lightPos.z)
    end

    state.lightPos = lightPos
end

-- ============================================================================
-- Public: Dispatch based on current mode
-- ============================================================================

function Input.Update()
    local mode = States.GetMode()

    if mode == States.Mode.CAMERA then
        UpdateCameraInput()
    elseif mode == States.Mode.PLAYER then
        UpdatePlayerInput()
    elseif mode == States.Mode.LIGHT then
        UpdateLightInput()
    end
end

return Input
