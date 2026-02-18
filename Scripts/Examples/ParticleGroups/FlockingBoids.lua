-- FlockingBoids.lua
-- Demonstrates flocking behavior (Boids algorithm) using the ParticleGroup system.
-- Particles behave as boids with three classic rules:
--   1. Separation - avoid crowding nearby boids
--   2. Alignment  - steer toward average heading of nearby boids
--   3. Cohesion   - steer toward average position of nearby boids
--
-- Usage: require this file from your level script and call
-- FlockingBoids.Create(position) to spawn the flock.

local FlockingBoids = {}

local group = nil
local time = 0

-- Tuning parameters.
local SEPARATION_RADIUS = 50
local ALIGNMENT_RADIUS  = 120
local COHESION_RADIUS   = 150
local SEPARATION_WEIGHT = 2.0
local ALIGNMENT_WEIGHT  = 1.0
local COHESION_WEIGHT   = 1.0
local MAX_SPEED         = 80
local BOUND_RADIUS      = 400 -- Keep boids within this distance of origin

--- Create a flocking boid effect at the given world position.
-- @tparam Vec3 origin World center for the flock.
-- @tparam[opt=Objects.ObjID.DEFAULT_SPRITES] Objects.ObjID spriteID Sprite sequence to use.
function FlockingBoids.Create(origin, spriteID)
    spriteID = spriteID or TEN.Objects.ObjID.DEFAULT_SPRITES

    group = TEN.Effects.CreateParticleGroup(spriteID, 64)
    if not group then return end

    group:SetPosition(origin)
    group:SetEmissionRate(0)      -- No auto-emission; we burst-spawn the flock.
    group:SetLifetime(9999)       -- Boids live indefinitely.
    group:SetInitialSizeRange(4, 6)
    group:SetInitialColor(Color(220, 220, 255))
    group:SetBlendMode(TEN.Effects.BlendID.ADDITIVE)

    -- Give initial random velocities.
    group:SetInitialVelocity(Vec3(0, 0, 0))
    group:SetInitialVelocityRandom(Vec3(40, 20, 40))

    -- Spawn the flock as a burst.
    group:EmitBurst(30)
    group:Start()
    time = 0
end

--- Update the flock. Call this from LevelFuncs.OnLoop.
-- Implements simplified Boids separation, alignment, and cohesion.
function FlockingBoids.Update()
    if not group or not group.active then return end

    time = time + 1 / 30
    local dt = 1 / 30
    local origin = group:GetPosition()

    -- First pass: collect all active particle positions and velocities.
    local boids = {}
    group:ForEachParticle(function(index, particle)
        boids[#boids + 1] = {
            index    = index,
            position = particle.position,
            velocity = particle.velocity,
        }
    end)

    -- Second pass: compute steering forces and apply.
    for i, boid in ipairs(boids) do
        local sepX, sepY, sepZ = 0, 0, 0
        local aliX, aliY, aliZ = 0, 0, 0
        local cohX, cohY, cohZ = 0, 0, 0
        local sepCount, aliCount, cohCount = 0, 0, 0

        for j, other in ipairs(boids) do
            if i ~= j then
                local dx = boid.position.x - other.position.x
                local dy = boid.position.y - other.position.y
                local dz = boid.position.z - other.position.z
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

                if dist > 0 then
                    -- Separation: push away from close neighbors.
                    if dist < SEPARATION_RADIUS then
                        local factor = 1.0 / dist
                        sepX = sepX + dx * factor
                        sepY = sepY + dy * factor
                        sepZ = sepZ + dz * factor
                        sepCount = sepCount + 1
                    end

                    -- Alignment: match velocity of nearby neighbors.
                    if dist < ALIGNMENT_RADIUS then
                        aliX = aliX + other.velocity.x
                        aliY = aliY + other.velocity.y
                        aliZ = aliZ + other.velocity.z
                        aliCount = aliCount + 1
                    end

                    -- Cohesion: steer toward center of nearby neighbors.
                    if dist < COHESION_RADIUS then
                        cohX = cohX + other.position.x
                        cohY = cohY + other.position.y
                        cohZ = cohZ + other.position.z
                        cohCount = cohCount + 1
                    end
                end
            end
        end

        -- Average and weight the forces.
        local steerX, steerY, steerZ = 0, 0, 0

        if sepCount > 0 then
            steerX = steerX + (sepX / sepCount) * SEPARATION_WEIGHT
            steerY = steerY + (sepY / sepCount) * SEPARATION_WEIGHT
            steerZ = steerZ + (sepZ / sepCount) * SEPARATION_WEIGHT
        end

        if aliCount > 0 then
            local avgVx = aliX / aliCount
            local avgVy = aliY / aliCount
            local avgVz = aliZ / aliCount
            steerX = steerX + (avgVx - boid.velocity.x) * ALIGNMENT_WEIGHT
            steerY = steerY + (avgVy - boid.velocity.y) * ALIGNMENT_WEIGHT
            steerZ = steerZ + (avgVz - boid.velocity.z) * ALIGNMENT_WEIGHT
        end

        if cohCount > 0 then
            local centerX = cohX / cohCount
            local centerY = cohY / cohCount
            local centerZ = cohZ / cohCount
            steerX = steerX + (centerX - boid.position.x) * COHESION_WEIGHT
            steerY = steerY + (centerY - boid.position.y) * COHESION_WEIGHT
            steerZ = steerZ + (centerZ - boid.position.z) * COHESION_WEIGHT
        end

        -- Boundary force: push boids back toward origin if too far.
        local toOriginX = origin.x - boid.position.x
        local toOriginY = origin.y - boid.position.y
        local toOriginZ = origin.z - boid.position.z
        local distToOrigin = math.sqrt(toOriginX * toOriginX + toOriginY * toOriginY + toOriginZ * toOriginZ)

        if distToOrigin > BOUND_RADIUS then
            local boundForce = (distToOrigin - BOUND_RADIUS) * 0.05
            steerX = steerX + toOriginX / distToOrigin * boundForce
            steerY = steerY + toOriginY / distToOrigin * boundForce
            steerZ = steerZ + toOriginZ / distToOrigin * boundForce
        end

        -- Apply steering to velocity.
        local newVx = boid.velocity.x + steerX * dt
        local newVy = boid.velocity.y + steerY * dt
        local newVz = boid.velocity.z + steerZ * dt

        -- Clamp speed.
        local speed = math.sqrt(newVx * newVx + newVy * newVy + newVz * newVz)
        if speed > MAX_SPEED then
            local scale = MAX_SPEED / speed
            newVx = newVx * scale
            newVy = newVy * scale
            newVz = newVz * scale
        end

        group:SetParticle(boid.index, {
            velocity = Vec3(newVx, newVy, newVz)
        })
    end
end

--- Stop and clean up the flock.
function FlockingBoids.Stop()
    if group and group.active then
        group:Stop()
    end
    group = nil
end

return FlockingBoids
