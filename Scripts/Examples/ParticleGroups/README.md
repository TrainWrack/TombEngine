# ParticleGroup Examples

Sample Lua scripts demonstrating the **ParticleGroup** system in TombEngine.
Each example creates a different visual effect using particles driven entirely from Lua.

## How to Use

1. Copy the desired script(s) into your level's `Scripts/` directory.
2. In your level script, `require` the module and call its functions:

```lua
-- In your level script (e.g., Scripts/Levels/MyLevel.lua)
local SinusoidalWave = require("Examples/ParticleGroups/SinusoidalWave")
local SpiralMotion   = require("Examples/ParticleGroups/SpiralMotion")
local FlockingBoids  = require("Examples/ParticleGroups/FlockingBoids")
local FallingLeaves  = require("Examples/ParticleGroups/FallingLeaves")

LevelFuncs.OnStart = function()
    -- Create effects at specific world positions.
    SinusoidalWave.Create(Vec3(10000, -512, 20000))
    SpiralMotion.Create(Vec3(15000, -256, 25000))
    FlockingBoids.Create(Vec3(20000, -1024, 30000))
    FallingLeaves.Create(Vec3(12000, -2048, 18000))
end

LevelFuncs.OnLoop = function()
    SinusoidalWave.Update()
    SpiralMotion.Update()
    FlockingBoids.Update()
    FallingLeaves.Update()
end

LevelFuncs.OnEnd = function()
    SinusoidalWave.Stop()
    SpiralMotion.Stop()
    FlockingBoids.Stop()
    FallingLeaves.Stop()
end
```

## Examples

### 1. Sinusoidal Wave (`SinusoidalWave.lua`)
Particles stream horizontally while their Y position oscillates in a sine wave pattern.
Creates a flowing, ribbon-like wave effect ideal for magical energy or water currents.

**Key techniques:**
- `ForEachParticle` to override position each frame
- Sine function driven by particle age + global timer
- Size fading based on `ageNormalized`

### 2. Spiral Motion (`SpiralMotion.lua`)
Particles rise upward in a helical spiral from a central point.
Useful for magical portals, energy columns, or fire tornado effects.

**Key techniques:**
- `ForEachParticle` with trigonometric position override
- Particle ID used as angle offset for even distribution
- Spiral radius tightens over particle lifetime

### 3. Flocking Boids (`FlockingBoids.lua`)
Particles behave as a flock using the classic Boids algorithm with three rules:
- **Separation** — avoid crowding nearby neighbors
- **Alignment** — steer toward average heading of neighbors
- **Cohesion** — steer toward center of nearby neighbors

Includes boundary containment to keep the flock near the origin.

**Key techniques:**
- Two-pass approach: collect all positions, then compute steering
- `ForEachParticle` for data collection
- `SetParticle` for applying velocity changes
- Long lifetime with burst spawn (no continuous emission)

### 4. Falling Leaves (`FallingLeaves.lua`)
Particles simulate leaves drifting downward with realistic swaying motion.
Includes random wind gusts and gentle tumbling rotation.

**Key techniques:**
- Per-particle phase offset using `particle.id` for varied sway
- Wind gust simulation with periodic random changes
- Velocity damping to simulate air resistance
- Color range for autumn leaf variation

## API Reference

Each module exposes three functions:

| Function | Description |
|----------|-------------|
| `Module.Create(origin, spriteID)` | Spawn the effect at a world position. `spriteID` is optional. |
| `Module.Update()` | Call every frame from `LevelFuncs.OnLoop`. |
| `Module.Stop()` | Stop the effect and clean up. |
