-- SpiralMotion.lua
-- Demonstrates a spiral/helix particle effect using the ParticleGroup system.
-- Particles are emitted from a central point and their positions are overridden
-- each frame to follow a spiraling path upward.
--
-- Usage: require this file from your level script and call
-- SpiralMotion.Create(position) to spawn the effect.

local SpiralMotion = {}

local group = nil
local time = 0

--- Create a spiral particle effect at the given world position.
-- @tparam Vec3 origin World position for the base of the spiral.
-- @tparam[opt=Objects.ObjID.DEFAULT_SPRITES] Objects.ObjID spriteID Sprite sequence to use.
function SpiralMotion.Create(origin, spriteID)
    spriteID = spriteID or TEN.Objects.ObjID.DEFAULT_SPRITES

    group = TEN.Effects.CreateParticleGroup(spriteID, 200)
    if not group then return end

    group:SetPosition(origin)
    group:SetEmissionRate(40)
    group:SetLifetimeRange(2.0, 3.0)
    group:SetInitialSizeRange(3, 6)
    group:SetInitialColor(Color(255, 160, 50))
    group:SetInitialColorRange(Color(255, 100, 20), Color(255, 200, 80))
    group:SetBlendMode(TEN.Effects.BlendID.ADDITIVE)

    -- Minimal initial velocity; the spiral motion is applied in the update.
    group:SetInitialVelocity(Vec3(0, 0, 0))
    group:SetInitialVelocityRandom(Vec3(5, 5, 5))

    group:Start()
    time = 0
end

--- Update the spiral effect. Call this from LevelFuncs.OnLoop.
-- Drives each particle along a helical path based on its age.
function SpiralMotion.Update()
    if not group or not group.active then return end

    time = time + 1 / 30

    local basePos = group:GetPosition()
    local radius = 80       -- Spiral radius
    local riseSpeed = -60    -- Upward speed (negative Y = up)
    local angularSpeed = 4.0 -- Radians per second

    group:ForEachParticle(function(index, particle)
        local age = particle.age

        -- Compute spiral position relative to base.
        local angle = angularSpeed * age + (particle.id * 0.5) -- Offset by particle ID for spread
        local r = radius * (1.0 - particle.ageNormalized * 0.3) -- Spiral tightens slightly over time
        local x = basePos.x + r * math.cos(angle)
        local z = basePos.z + r * math.sin(angle)
        local y = basePos.y + riseSpeed * age

        -- Shrink and fade over lifetime.
        local fade = 1.0 - particle.ageNormalized
        local newSize = 6 * fade

        return {
            position = Vec3(x, y, z),
            size = newSize
        }
    end)
end

--- Stop and clean up the spiral effect.
function SpiralMotion.Stop()
    if group and group.active then
        group:Stop()
    end
    group = nil
end

return SpiralMotion
