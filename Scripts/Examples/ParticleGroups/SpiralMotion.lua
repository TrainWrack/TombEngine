-- SpiralMotion.lua
-- Demonstrates a spiral/helix particle effect using the ParticleGroup system.
-- Particles are emitted from a central point and their positions are overridden
-- each frame to follow a spiraling path upward.
--
-- Works with both sprite sequences and mesh objects. When a mesh object is used
-- (e.g., BATS_EMITTER), the sprite index selects the mesh frame, enabling animation.
-- The size field controls the sprite billboard scale for sprite groups, and the
-- uniform mesh scale for mesh groups.
--
-- Usage: require this file from your level script and call
-- SpiralMotion.Create(position) to spawn the effect.

local SpiralMotion = {}

-- Sprite animation settings.
local ANIM_FRAMES    = 4   -- Number of animation frames in the sequence.
local ANIM_FPS       = 12  -- Frame rate of the sprite animation.

local group = nil
local time = 0

--- Create a spiral particle effect at the given world position.
-- @tparam Vec3 origin World position for the base of the spiral.
-- @tparam[opt=Objects.ObjID.DEFAULT_SPRITES] Objects.ObjID objectID Object slot to use.
-- @tparam[opt=0] float damage HP damage per second dealt to Lara on contact (0 = disabled).
function SpiralMotion.Create(origin, objectID, damage)
    objectID = objectID or TEN.Objects.ObjID.DEFAULT_SPRITES
    damage   = damage or 0

    group = TEN.Effects.CreateParticleGroup(objectID, 200)
    if not group.active then return end

    -- Randomize the spawn position slightly for variety.
    local offset = math.random(-512, 512)
    local newOrigin = (math.random(0, 1) == 0)
        and Vec3(origin.x + offset, origin.y, origin.z)
        or  Vec3(origin.x, origin.y, origin.z + offset)

    group:SetPosition(newOrigin)
    group:SetEmissionRate(10)
    group:SetLifetimeRange(2.0, 3.0)
    group:SetInitialSizeRange(4, 8)
    group:SetInitialColor(Color(255, 160, 50))
    group:SetInitialColorRange(Color(255, 100, 20), Color(255, 200, 80))
    group:SetBlendMode(TEN.Effects.BlendID.ADDITIVE)
    group:SetInitialVelocity(Vec3(0, 0, 0))
    group:SetInitialVelocityRandom(Vec3(5, 5, 5))

    if damage > 0 then
        group:SetDamage(damage)
    end

    group:Start()
    time = 0
end

--- Update the spiral effect. Call this from LevelFuncs.OnLoop.
-- Drives each particle along a helical path based on its age.
function SpiralMotion.Update()
    if not group or not group.active then return end

    time = time + 1 / 30

    local basePos      = group:GetPosition()
    local radius       = 1024      -- Spiral radius in world units.
    local riseSpeed    = -1024     -- Upward speed (negative Y = up in TombEngine).
    local angularSpeed = 1.0       -- Radians per second.

    group:ForEachParticle(function(index, particle)
        local age = particle.age

        -- Compute helical position relative to the emitter.
        local angle = angularSpeed * age + (particle.id * 0.5)
        local r = radius * (1.0 - particle.ageNormalized * 0.3)
        local x = basePos.x + r * math.cos(angle)
        local z = basePos.z + r * math.sin(angle)
        local y = basePos.y + riseSpeed * age

        -- Shrink and fade over lifetime.
        local fade    = 1.0 - particle.ageNormalized
        local newSize = 128 * fade

        -- Cycle through sprite/mesh frames for animation.
        local frame       = math.floor(age * ANIM_FPS) % ANIM_FRAMES
        local spriteIndex = (frame + particle.id) % ANIM_FRAMES

        return {
            position    = Vec3(x, y, z),
            size        = newSize,
            spriteIndex = spriteIndex,
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
