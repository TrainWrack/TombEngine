-- TrainScroller.lua
-- Recreates the classic scrolling train environment using the ParticleGroup system
-- with mesh particles. Three groups are maintained:
--   1. Front row  - architecture meshes along Z=47168 (facing forward)
--   2. Back row   - architecture meshes along Z=58304 (facing backward, rotated 180Â°)
--   3. Obstacles  - rock/debris objects at scripted Z offsets between the rows
--
-- The map arrays and scrolling math are a direct port of the original C code.
-- trainmappos advances each frame driven by a speed scalar (equivalent to gfUVRotate).
--
-- Usage: require this file from your level script, then:
--   TrainScroller.Create(laraItem)   -- call once on level start
--   TrainScroller.Update(laraItem)   -- call every frame from LevelFuncs.OnLoop
--   TrainScroller.Stop()             -- call on level end / cleanup

local TrainScroller = {}

-- ============================================================
-- Map data (direct port from C)
-- ============================================================

-- Architecture tile sequence for both rows.
-- Values are ObjID indices: 36=ARCHITECTURE6, 37=ARCHITECTURE7,
-- 38=ARCHITECTURE8, 39=ARCHITECTURE9
local TRAIN_MAP = {
    36, 36, 36, 37, 38, 39, 36, 37, 38, 38, 38, 39, 37,
    38, 39, 36, 36, 36, 36, 36, 37, 39, 36, 36, 37, 38,
    38, 39, 36, 36, 37, 39, 36, 36, 36, 37, 38, 39, 36,
    37, 38, 38, 38, 39, 37, 38, 39, 36, 36, 36, 36, 36,
    37, 39, 36, 36, 37, 38, 38, 39, 36, 36, 37, 39, 38,
    37, 36, 39, 37, 36, 36, 36, 39, 38, 38, 38, 38, 37,
    36, 39, 38, 38, 37, 39, 38, 38, 38, 38, 38, 38, 37,
    36, 36, 36, 39, 38, 38, 37, 36, 39, 37, 36, 36, 36,
    39, 38, 38, 38, 38, 37, 36, 39, 38, 38, 37, 39, 38,
    38, 38, 38, 38, 38, 37, 36, 36, 36, 39, 38
}

-- ============================================================
-- Constants (matching original world-space values)
-- ============================================================

local TILE_SIZE    = 6144   -- Width of one architecture tile
local VISIBLE_TILES = 10     -- How many tiles are drawn at once (+ 1 lookahead)
local Z_FRONT      = 47168  -- Z position of the front scenery row
local Z_BACK       = 58304  -- Z position of the back scenery row
local Z_OBSTACLES  = 52224  -- Z base for obstacle objects
local Y_LEVEL      = 256    -- World Y for all train objects
local SCROLL_SPEED = 256     -- Equivalent to gfUVRotate << 5; tune to taste

-- Obstacle configuration
local OBSTACLE_POSITIONS    = {Z_OBSTACLES - 2048,       -- lane A (near front row)
                                Z_OBSTACLES + 2048}      -- lane B (near back row)
local OBSTACLE_INTERVAL_MIN = 256   -- minimum frames between obstacle spawns
local OBSTACLE_INTERVAL_MAX = 512   -- maximum frames between obstacle spawns
local MAX_OBSTACLE_SLOTS    = 6     -- maximum simultaneous obstacles
local OBSTACLE_MESHCOUNT = 5
-- ============================================================
-- State
-- ============================================================

local groupFront    = nil
local groupBack     = nil
local groupObstacle = nil
local trainmappos   = 0
local prevTileDiv   = 0
local frontSlots    = {}  -- ring buffer: {worldX, meshVal, teleport}
local backSlots     = {}
local frontMapIdx   = 0   -- next map index for the tile entering from the left
local backMapIdx    = 0
local frontRightIdx = 1   -- which array slot is currently the rightmost
local backRightIdx  = 1
local rowsInitialized = false
local obstaclePool      = {}
local obstacleTimer     = 0
local obstacleMeshCount = 1

-- ============================================================
-- Helpers
-- ============================================================

-- Lua arrays are 1-based; wrap a 0-based C index into a 1-based Lua index.
local function mapAt(tbl, idx0)
    return tbl[(idx0 % #tbl) + 1]
end

-- Return the ObjID enum for an architecture tile value (36-39).
local function archObjID(val)
    if     val == 36 then return 0
    elseif val == 37 then return 1
    elseif val == 38 then return 2
    elseif val == 39 then return 3
    end
    return 0
end

-- ============================================================
-- Public API
-- ============================================================

--- Initialise the three particle groups.
-- @tparam Item laraItem  The Lara item (used for position reference).
function TrainScroller.Create()
    -- Front row: 9 mesh-particle slots (8 visible + 1 lookahead).
    groupFront = TEN.Effects.CreateParticleGroup(TEN.Objects.ObjID.ANIMATING2, VISIBLE_TILES + 1)
    if groupFront then
        groupFront:SetPosition(Vec3(0, Y_LEVEL, Z_FRONT))
        groupFront:SetEmissionRate(0)
        groupFront:SetLifetime(20)
        groupFront:EmitBurst(VISIBLE_TILES + 1)
        groupFront:Start()
    end

    -- Back row: same count, different Z, rotated 180Â° around Y.
    groupBack = TEN.Effects.CreateParticleGroup(TEN.Objects.ObjID.ANIMATING2, VISIBLE_TILES + 1)
    if groupBack then
        groupBack:SetPosition(Vec3(0, Y_LEVEL, Z_BACK))
        groupBack:SetEmissionRate(0)
        groupBack:SetLifetime(20)
        groupBack:EmitBurst(VISIBLE_TILES + 1)
        groupBack:Start()
    end

    -- Discover how many meshes ANIMATING1 has at runtime.
    obstacleMeshCount = OBSTACLE_MESHCOUNT

    -- Obstacle row: pool of MAX_OBSTACLE_SLOTS mesh particles (ANIMATING1).
    obstaclePool = {}
    for i = 1, MAX_OBSTACLE_SLOTS do
        obstaclePool[i] = {active = false, x = 0, z = Z_OBSTACLES, meshIdx = 0}
    end
    obstacleTimer = OBSTACLE_INTERVAL_MIN

    groupObstacle = TEN.Effects.CreateParticleGroup(TEN.Objects.ObjID.ANIMATING1, MAX_OBSTACLE_SLOTS)
    if groupObstacle then
        groupObstacle:SetPosition(Vec3(0, Y_LEVEL, Z_OBSTACLES))
        groupObstacle:SetEmissionRate(0)
        groupObstacle:SetLifetime(99999)
        groupObstacle:EmitBurst(MAX_OBSTACLE_SLOTS)
        groupObstacle:Start()
    end

    frontSlots      = {}
    backSlots       = {}
    frontMapIdx     = 0
    backMapIdx      = 0
    frontRightIdx   = VISIBLE_TILES + 1
    backRightIdx    = VISIBLE_TILES + 1
    rowsInitialized = false
    trainmappos     = 0
    prevTileDiv     = 0
end

--- Update the train scroll. Call from LevelFuncs.OnLoop every frame.
-- @tparam Item laraItem  The Lara item.
function TrainScroller.Update(laraItem)
    if not laraItem then return end

    local laraX    = laraItem:GetPosition().x
    local laraSnap = laraX - (laraX % TILE_SIZE)

    -- Advance scroll; detect tile-boundary step.
    local curTileDiv = trainmappos // TILE_SIZE
    trainmappos = (trainmappos + SCROLL_SPEED) % 0x60000
    local tileStep = (trainmappos // TILE_SIZE) ~= curTileDiv

    local tilePhase = trainmappos % TILE_SIZE - (TILE_SIZE * 4)

    -- --------------------------------------------------------
    -- Initialise ring buffers on first call.
    -- --------------------------------------------------------
    if not rowsInitialized then
        local fBase = 96 - (((trainmappos // TILE_SIZE) - (laraX // TILE_SIZE)) & 0x1F)
        local bBase = 32 - (((trainmappos // TILE_SIZE) - (laraX // TILE_SIZE) + 8) & 0x1F)
        for i = 0, VISIBLE_TILES do
            frontSlots[i + 1] = {
                worldX   = laraSnap + tilePhase + i * TILE_SIZE,
                meshVal  = mapAt(TRAIN_MAP, fBase + i),
                teleport = false,
            }
            backSlots[i + 1] = {
                worldX   = laraSnap + tilePhase + i * TILE_SIZE,
                meshVal  = mapAt(TRAIN_MAP, bBase + i),
                teleport = false,
            }
        end
        frontMapIdx   = fBase - 1
        backMapIdx    = bBase - 1
        frontRightIdx = VISIBLE_TILES + 1
        backRightIdx  = VISIBLE_TILES + 1
        rowsInitialized = true
    end

    -- --------------------------------------------------------
    -- Advance every slot continuously; only the recycled slot teleports.
    -- --------------------------------------------------------
    local RING_SIZE = VISIBLE_TILES + 1

    for i = 1, RING_SIZE do
        frontSlots[i].worldX   = frontSlots[i].worldX + SCROLL_SPEED
        frontSlots[i].teleport = false
        backSlots[i].worldX    = backSlots[i].worldX  + SCROLL_SPEED
        backSlots[i].teleport  = false
    end

    -- On each tile step, the current rightmost slot wraps to the leftmost position.
    if tileStep then
        local sf = frontSlots[frontRightIdx]
        sf.worldX   = sf.worldX - RING_SIZE * TILE_SIZE
        sf.meshVal  = mapAt(TRAIN_MAP, frontMapIdx)
        frontMapIdx = frontMapIdx - 1
        sf.teleport = true
        frontRightIdx = frontRightIdx - 1
        if frontRightIdx < 1 then frontRightIdx = RING_SIZE end

        local sb = backSlots[backRightIdx]
        sb.worldX   = sb.worldX - RING_SIZE * TILE_SIZE
        sb.meshVal  = mapAt(TRAIN_MAP, backMapIdx)
        backMapIdx  = backMapIdx - 1
        sb.teleport = true
        backRightIdx = backRightIdx - 1
        if backRightIdx < 1 then backRightIdx = RING_SIZE end
    end

    -- --------------------------------------------------------
    -- Front row particles
    -- --------------------------------------------------------
    if groupFront and groupFront.active then
        groupFront:ForEachParticle(function(index, particle)
            local s = frontSlots[index + 1]
            return {
                subIndex = archObjID(s.meshVal),
                position    = Vec3(s.worldX, Y_LEVEL, Z_FRONT),
                orientation = Vec3(0, 0, 0),
                size        = 1,
                age         = 1,
                teleport    = s.teleport,
            }
        end)
    end

    -- --------------------------------------------------------
    -- Back row particles
    -- --------------------------------------------------------
    if groupBack and groupBack.active then
        groupBack:ForEachParticle(function(index, particle)
            local s = backSlots[index + 1]
            return {
                subIndex = archObjID(s.meshVal),
                position    = Vec3(s.worldX, Y_LEVEL, Z_BACK),
                orientation = Vec3(0, 180, 0),
                size        = 1,
                age         = 1,
                teleport    = s.teleport,
            }
        end)
    end

    -- --------------------------------------------------------
    -- Obstacles: random mesh, random interval, two lane positions
    -- --------------------------------------------------------
    obstacleTimer = obstacleTimer - 1
    if obstacleTimer <= 0 then
        for i = 1, MAX_OBSTACLE_SLOTS do
            if not obstaclePool[i].active then
                obstaclePool[i].active  = true
                obstaclePool[i].x       = laraSnap + tilePhase - VISIBLE_TILES * TILE_SIZE
                obstaclePool[i].z       = OBSTACLE_POSITIONS[math.random(#OBSTACLE_POSITIONS)]
                obstaclePool[i].meshIdx = math.random(0, obstacleMeshCount - 1)
                break
            end
        end
        obstacleTimer = OBSTACLE_INTERVAL_MIN
                      + math.random(OBSTACLE_INTERVAL_MAX - OBSTACLE_INTERVAL_MIN)
    end

    -- Scroll active obstacles; cull those that have passed behind Lara.
    for i = 1, MAX_OBSTACLE_SLOTS do
        local slot = obstaclePool[i]
        if slot.active then
            slot.x = slot.x + SCROLL_SPEED
            if slot.x > laraSnap + 2 * TILE_SIZE then
                slot.active = false
            end
        end
    end

    if groupObstacle and groupObstacle.active then
        groupObstacle:ForEachParticle(function(index, particle)
            local slot = obstaclePool[index + 1]
            if slot and slot.active then
                return {
                    subIndex = slot.meshIdx,
                    position    = Vec3(slot.x, Y_LEVEL, slot.z),
                    orientation = Vec3(0, 0, 0),
                    size        = 1,
                }
            else
                return {
                    position = Vec3(0, -100000, Z_OBSTACLES),
                    size     = 0,
                }
            end
        end)
    end
end

--- Stop and clean up all train groups.
function TrainScroller.Stop()
    if groupFront    and groupFront.active    then groupFront:Stop()    end
    if groupBack     and groupBack.active     then groupBack:Stop()     end
    if groupObstacle and groupObstacle.active then groupObstacle:Stop() end
    groupFront    = nil
    groupBack     = nil
    groupObstacle = nil
    frontSlots      = {}
    backSlots       = {}
    frontMapIdx     = 0
    backMapIdx      = 0
    frontRightIdx   = 1
    backRightIdx    = 1
    rowsInitialized = false
    trainmappos     = 0
    prevTileDiv     = 0
    obstaclePool    = {}
    obstacleTimer     = 0
    obstacleMeshCount = 1
end

return TrainScroller
