-- FallingLeaves.lua
-- Demonstrates a falling leaves effect using the ParticleGroup system.
-- Particles simulate leaves drifting downward with:
--   - Gentle swaying (horizontal sine oscillation)
--   - Slow tumbling rotation
--   - Random gusts of wind
--   - Size and color variation for visual richness
--   - Optional poison effect (e.g., toxic leaves from a poisonous plant)
--
-- Usage: require this file from your level script and call
-- FallingLeaves.Create(position) to spawn the effect.

local FallingLeaves = {}

local group = nil
local time = 0

-- Wind simulation state.
local windX = 0
local windZ = 0
local gustTimer = 0

--- Create a falling leaves effect at the given world position.
-- Leaves will emit from a horizontal area above the given position.
-- @tparam Vec3 origin World position (top of the area where leaves appear).
-- @tparam[opt=Objects.ObjID.DEFAULT_SPRITES] Objects.ObjID spriteID Sprite sequence to use.
-- @tparam[opt=0] int poison Poison units per second added to Lara on contact (0 = disabled).
function FallingLeaves.Create(origin, spriteID, poison)
    spriteID = spriteID or TEN.Objects.ObjID.DEFAULT_SPRITES
    poison   = poison or 0

    group = TEN.Effects.CreateParticleGroup(spriteID, 100)
    if not group then return end

    group:SetPosition(origin)
    group:SetEmissionRate(8) -- Gentle, sparse emission.
    group:SetLifetimeRange(4.0, 7.0)
    group:SetInitialSizeRange(6, 14)

    -- Earthy autumn colors.
    group:SetInitialColorRange(Color(180, 140, 40), Color(220, 80, 20))

    group:SetBlendMode(TEN.Effects.BlendID.ALPHA_BLEND)

    -- Leaves drift downward slowly with some horizontal spread (positive Y = down).
    group:SetInitialVelocity(Vec3(0, 15, 0))
    group:SetInitialVelocityRandom(Vec3(40, 5, 40))
    group:SetInitialAcceleration(Vec3(0, 3, 0))         -- Light gravity pull

    -- Gentle tumbling.
    group:SetInitialRotation(0)
    group:SetInitialRotationVelocity(45) -- Degrees per second

    if poison > 0 then
        group:SetPoison(poison)
    end

    group:Start()
    time = 0
    windX = 0
    windZ = 0
    gustTimer = 0
end

--- Update the leaves effect. Call this from LevelFuncs.OnLoop.
-- Adds swaying motion, wind gusts, and size changes over lifetime.
function FallingLeaves.Update()
    if not group or not group.active then return end

    local dt = 1 / 30
    time = time + dt

    -- Simulate wind gusts: periodically change wind direction.
    gustTimer = gustTimer + dt
    if gustTimer > 2.0 then
        gustTimer = 0
        windX = (math.random() - 0.5) * 30
        windZ = (math.random() - 0.5) * 30
    end

    -- Smoothly interpolate wind toward target (simple exponential decay).
    local swayAmplitude     = 25
    local swayFrequency     = 1.5
    local swayResponsiveness = 5    -- How quickly particles react to sway/wind
    local horizontalDamping  = 0.95 -- Air resistance on horizontal velocity
    local verticalDamping    = 0.98 -- Air resistance on vertical velocity
    local gravityPull        = 3    -- Gentle downward pull each frame

    group:ForEachParticle(function(index, particle)
        local pos = particle.position
        local vel = particle.velocity
        local age = particle.age

        -- Horizontal swaying: sine-based oscillation unique to each particle.
        local phase = (particle.id % 10) * 0.6 -- Unique phase offset per particle
        local swayX = swayAmplitude * math.sin(swayFrequency * age + phase)
        local swayZ = swayAmplitude * math.cos(swayFrequency * age + phase * 0.7)

        -- Apply sway and wind as velocity adjustments.
        local newVx = vel.x * horizontalDamping + (swayX + windX) * dt * swayResponsiveness
        local newVz = vel.z * horizontalDamping + (swayZ + windZ) * dt * swayResponsiveness

        -- Leaves slow their fall slightly as they sway (air resistance).
        local newVy = vel.y * verticalDamping + gravityPull * dt

        -- Shrink slightly near end of life (curling up).
        local lifeFade = 1.0 - particle.ageNormalized * 0.4
        local newSize = particle.size * lifeFade

        return {
            velocity = Vec3(newVx, newVy, newVz),
            size = math.max(2, newSize)
        }
    end)
end

--- Stop and clean up the leaves effect.
function FallingLeaves.Stop()
    if group and group.active then
        group:Stop()
    end
    group = nil
end

return FallingLeaves
