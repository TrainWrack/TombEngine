-- SinusoidalWave.lua
-- Demonstrates a sinusoidal wave effect using the ParticleGroup system.
-- Particles are emitted in a line and their Y positions are driven by a sine function,
-- creating a flowing wave pattern.
--
-- Usage: require this file from your level script and call
-- SinusoidalWave.Create(position) to spawn the effect.

local SinusoidalWave = {}

local group = nil
local time = 0

--- Create a sinusoidal wave particle effect at the given world position.
-- @tparam Vec3 origin World position for the center of the wave.
-- @tparam[opt=Objects.ObjID.DEFAULT_SPRITES] Objects.ObjID spriteID Sprite sequence to use.
function SinusoidalWave.Create(origin, spriteID)
    spriteID = spriteID or TEN.Objects.ObjID.DEFAULT_SPRITES

    group = TEN.Effects.CreateParticleGroup(spriteID, 128)
    if not group then return end

    -- Configure particles: small, bright, additive blending.
    group:SetPosition(origin)
    group:SetEmissionRate(60)
    group:SetLifetimeRange(1.5, 2.5)
    group:SetInitialSizeRange(4, 8)
    group:SetInitialColor(Color(100, 180, 255))
    group:SetBlendMode(TEN.Effects.BlendID.ADDITIVE)

    -- Particles spread horizontally with slight upward drift.
    group:SetInitialVelocity(Vec3(80, -5, 0))
    group:SetInitialVelocityRandom(Vec3(20, 5, 10))

    group:Start()
    time = 0
end

--- Update the wave effect. Call this from LevelFuncs.OnLoop.
-- Applies a sine wave displacement to each particle based on its age and a global timer.
function SinusoidalWave.Update()
    if not group or not group.active then return end

    time = time + 1 / 30 -- Advance timer (~30 FPS)

    local amplitude = 64  -- Height of the wave
    local frequency = 3.0 -- Wave oscillation speed

    group:ForEachParticle(function(index, particle)
        local pos = particle.position
        local age = particle.age

        -- Sine wave: offset Y based on particle age and global time.
        local waveOffset = amplitude * math.sin(frequency * age + time * 2.0)
        pos.y = pos.y + waveOffset * (1 / 30) -- Apply as incremental offset per frame

        -- Fade out near end of life.
        local fade = 1.0 - particle.ageNormalized
        local newSize = (4 + 4 * fade)

        return { position = pos, size = newSize }
    end)
end

--- Stop and clean up the wave effect.
function SinusoidalWave.Stop()
    if group and group.active then
        group:Stop()
    end
    group = nil
end

return SinusoidalWave
