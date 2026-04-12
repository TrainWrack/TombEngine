--- Camera management for the PhotoMode module.
-- Handles creation of null-mesh camera objects, initial placement,
-- attaching/detaching the object camera, and camera movement.
-- @module Engine.PhotoMode.Camera
-- @local

local Settings = require("Engine.PhotoMode.Settings")
local States   = require("Engine.PhotoMode.States")

local Camera = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function ForwardFromYaw(yawDeg)
    local rad = math.rad(yawDeg)
    return TEN.Vec3(math.sin(rad), 0, math.cos(rad))
end

local function RightFromYaw(yawDeg)
    local rad = math.rad(yawDeg + 90)
    return TEN.Vec3(math.sin(rad), 0, math.cos(rad))
end

local function Vec3Add(a, b)
    return TEN.Vec3(a.x + b.x, a.y + b.y, a.z + b.z)
end

local function Vec3Scale(v, s)
    return TEN.Vec3(v.x * s, v.y * s, v.z * s)
end

local function IsInsideSolid(pos)
    local ok, probe = pcall(TEN.Collision.Probe, pos)
    if not ok then return false end
    return probe:IsInsideSolidGeometry()
end

local function SafeMove(moveable, newPos, collisionOn)
    if collisionOn then
        if IsInsideSolid(newPos) then return false end
    end
    moveable:SetPosition(newPos)
    return true
end

-- ============================================================================
-- Create / Destroy
-- ============================================================================

local function GetOrCreate(name)
    local exists = TEN.Objects.IsNameInUse(name)
    if exists then return TEN.Objects.GetMoveableByName(name), false end

    local pos  = Lara:GetPosition()
    local rot  = TEN.Rotation(0, 0, 0)
    local room = Lara:GetRoomNumber()

    local ok, mov = pcall(TEN.Objects.Moveable,
        TEN.Objects.ObjID.CAMERA_TARGET, name, pos, rot, room)
    if ok and mov then
        mov:Enable()
        return mov, true
    end
    return nil, false
end

function Camera.Init()
    local state = States.Get()

    local camMesh, _   = GetOrCreate(Settings.Camera.meshName)
    local camTarget, _ = GetOrCreate(Settings.Camera.targetName)

    state.cameraMesh   = camMesh
    state.cameraTarget = camTarget

    if not camMesh or not camTarget then
        TEN.Util.PrintLog("PhotoMode: Failed to create camera objects.", TEN.Util.LogLevel.ERROR)
        return false
    end

    return true
end

function Camera.PlaceInitial()
    local state = States.Get()
    if not state.cameraMesh or not state.cameraTarget then return end

    local laraPos = Lara:GetPosition()
    local laraRot = Lara:GetRotation()
    local fwd     = ForwardFromYaw(laraRot.y)

    local cfg = Settings.Camera

    local camPos = TEN.Vec3(
        laraPos.x + fwd.x * cfg.offsetForward,
        laraPos.y + cfg.offsetUp,
        laraPos.z + fwd.z * cfg.offsetForward
    )

    local targetPos = TEN.Vec3(
        laraPos.x + fwd.x * cfg.targetForward,
        laraPos.y + cfg.targetUp,
        laraPos.z + fwd.z * cfg.targetForward
    )

    state.cameraMesh:SetPosition(camPos)
    state.cameraTarget:SetPosition(targetPos)

    state.entryCamPos    = camPos
    state.entryTargetPos = targetPos

    if state.snapshot then
        state.snapshot.camPos    = camPos
        state.snapshot.targetPos = targetPos
    end
end

function Camera.Attach()
    local state = States.Get()
    if state.cameraMesh and state.cameraTarget then
        state.cameraMesh:AttachObjCamera(
            Settings.Camera.meshIndex,
            state.cameraTarget,
            Settings.Camera.targetIndex
        )
    end
end

function Camera.Detach()
    pcall(TEN.View.ResetObjCamera)
end

function Camera.Reset()
    local state = States.Get()
    if state.entryCamPos and state.cameraMesh then
        state.cameraMesh:SetPosition(state.entryCamPos)
    end
    if state.entryTargetPos and state.cameraTarget then
        state.cameraTarget:SetPosition(state.entryTargetPos)
    end
end

-- ============================================================================
-- Direction helpers (public for Input module)
-- ============================================================================

function Camera.GetDirection()
    local state = States.Get()
    if not state.cameraMesh or not state.cameraTarget then
        return TEN.Vec3(0, 0, 1)
    end
    local cp = state.cameraMesh:GetPosition()
    local tp = state.cameraTarget:GetPosition()
    local dx = tp.x - cp.x
    local dy = tp.y - cp.y
    local dz = tp.z - cp.z
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 1 then return TEN.Vec3(0, 0, 1) end
    return TEN.Vec3(dx / len, dy / len, dz / len)
end

function Camera.GetRightVector()
    local dir = Camera.GetDirection()
    local rx = dir.z
    local rz = -dir.x
    local rLen = math.sqrt(rx * rx + rz * rz)
    if rLen > 0.001 then
        rx = rx / rLen
        rz = rz / rLen
    end
    return TEN.Vec3(rx, 0, rz)
end

-- ============================================================================
-- Movement (called from Input module)
-- ============================================================================

function Camera.MoveForward(speed)
    local state = States.Get()
    local dir = Camera.GetDirection()
    local newCam = Vec3Add(state.cameraMesh:GetPosition(), Vec3Scale(dir, speed))
    local newTgt = Vec3Add(state.cameraTarget:GetPosition(), Vec3Scale(dir, speed))
    SafeMove(state.cameraMesh, newCam, state.collisionOn)
    SafeMove(state.cameraTarget, newTgt, state.collisionOn)
end

function Camera.MoveBack(speed)
    Camera.MoveForward(-speed)
end

function Camera.Strafe(speed)
    local state = States.Get()
    local right = Camera.GetRightVector()
    local offset = Vec3Scale(right, speed)
    local newCam = Vec3Add(state.cameraMesh:GetPosition(), offset)
    local newTgt = Vec3Add(state.cameraTarget:GetPosition(), offset)
    SafeMove(state.cameraMesh, newCam, state.collisionOn)
    SafeMove(state.cameraTarget, newTgt, state.collisionOn)
end

function Camera.OrbitHorizontal(angle)
    local state = States.Get()
    local camPos = state.cameraMesh:GetPosition()
    local targetPos = state.cameraTarget:GetPosition()
    local dx = targetPos.x - camPos.x
    local dz = targetPos.z - camPos.z
    local rad = math.rad(angle)
    local cosA = math.cos(rad)
    local sinA = math.sin(rad)
    local newTarget = TEN.Vec3(
        camPos.x + dx * cosA - dz * sinA,
        targetPos.y,
        camPos.z + dx * sinA + dz * cosA
    )
    SafeMove(state.cameraTarget, newTarget, state.collisionOn)
end

function Camera.AdjustTargetVertical(speed)
    local state = States.Get()
    local tp = state.cameraTarget:GetPosition()
    local newTarget = TEN.Vec3(tp.x, tp.y + speed, tp.z)
    SafeMove(state.cameraTarget, newTarget, state.collisionOn)
end

return Camera
