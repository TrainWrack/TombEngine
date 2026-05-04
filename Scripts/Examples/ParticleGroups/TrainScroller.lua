-- TrainScroller.lua
-- Recreates the classic scrolling train environment using the ParticleGroup system
-- with mesh particles. Three groups are maintained:
--   1. Front row  - architecture meshes along Z=47168 (facing forward)
--   2. Back row   - architecture meshes along Z=58304 (facing backward, rotated 180°)
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

-- NO_ITEM sentinel.
local NO_ITEM = -1

-- Obstacle map: {objID, zOffset} pairs.
-- ROCK0=40, ROCK2=42, ROCK3=43 (adjust ObjID values to match your project).
-- local ROCK0 = TEN.Objects.ObjID.ROCK0
-- local ROCK2 = TEN.Objects.ObjID.ROCK2
-- local ROCK3 = TEN.Objects.ObjID.ROCK3

-- local TRAIN_MAP2 = {
--     {ROCK2,  4096}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0, -3072}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0,  4096}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0, -3072}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0,  4096}, {NO_ITEM, 0},
--     {ROCK3, -3072}, {NO_ITEM, 0},
--     {ROCK0, -3072}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0,  4096}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0,  4096},
--     {ROCK3, -2048}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK2,  4096}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0, -3072}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0,  4096}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0, -3072}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0,  4096}, {NO_ITEM, 0},
--     {ROCK3, -3072}, {NO_ITEM, 0},
--     {ROCK0, -3072}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0,  4096}, {NO_ITEM, 0}, {NO_ITEM, 0},
--     {ROCK0,  4096},
--     {ROCK3, -2048}, {NO_ITEM, 0}, {NO_ITEM, 0}, {NO_ITEM, 0}
-- }

-- ============================================================
-- Constants (matching original world-space values)
-- ============================================================

local TILE_SIZE    = 6144   -- Width of one architecture tile
local VISIBLE_TILES = 8     -- How many tiles are drawn at once (+ 1 lookahead)
local Z_FRONT      = 47168  -- Z position of the front scenery row
local Z_BACK       = 58304  -- Z position of the back scenery row
local Z_OBSTACLES  = 52224  -- Z base for obstacle objects
local Y_LEVEL      = 256    -- World Y for all train objects
local SCROLL_SPEED = 32     -- Equivalent to gfUVRotate << 5; tune to taste

-- ============================================================
-- State
-- ============================================================

local groupFront    = nil
local groupBack     = nil
local groupObstacle = nil
local trainmappos   = 0

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
    groupFront = TEN.Effects.CreateParticleGroup(TEN.Objects.ObjID.ANIMATING12, VISIBLE_TILES + 1)
    if groupFront then
        groupFront:SetPosition(Vec3(0, Y_LEVEL, Z_FRONT))
        groupFront:SetEmissionRate(0)
        groupFront:SetLifetime(99999)
        groupFront:EmitBurst(VISIBLE_TILES + 1)
        groupFront:Start()
    end

    -- Back row: same count, different Z, rotated 180° around Y.
    groupBack = TEN.Effects.CreateParticleGroup(TEN.Objects.ObjID.ANIMATING12, VISIBLE_TILES + 1)
    if groupBack then
        groupBack:SetPosition(Vec3(0, Y_LEVEL, Z_BACK))
        groupBack:SetEmissionRate(0)
        groupBack:SetLifetime(99999)
        groupBack:EmitBurst(VISIBLE_TILES + 1)
        groupBack:Start()
    end

    -- Obstacle row: one slot per potential obstacle in the visible window.
    -- groupObstacle = TEN.Effects.CreateParticleGroup(TEN.Objects.ObjID.ROCK0, VISIBLE_TILES + 1)
    -- if groupObstacle then
    --     groupObstacle:SetPosition(Vec3(0, Y_LEVEL, Z_OBSTACLES))
    --     groupObstacle:SetEmissionRate(0)
    --     groupObstacle:SetLifetime(99999)
    --     groupObstacle:EmitBurst(VISIBLE_TILES + 1)
    --     groupObstacle:Start()
    -- end

    trainmappos = 0
end

--- Update the train scroll. Call from LevelFuncs.OnLoop every frame.
-- @tparam Item laraItem  The Lara item.
function TrainScroller.Update(laraItem)
    if not laraItem then return end

    local laraX = laraItem:GetPosition().x

    -- Detect tile-boundary wrap BEFORE advancing (used for teleport suppression below).
    local prevTileDiv = trainmappos // TILE_SIZE

    -- Advance scroll position (mirrors: trainmappos += gfUVRotate << 5, mod 0x60000)
    trainmappos = (trainmappos + SCROLL_SPEED) % 0x60000

    -- A tile boundary was crossed this frame; particles must teleport to avoid
    -- the interpolator animating the ~TILE_SIZE position reset.
    local wrapOccurred = (trainmappos // TILE_SIZE) ~= prevTileDiv

    -- Snap Lara's X to tile grid
    local laraSnap = laraX - (laraX % TILE_SIZE)

    -- X offset within the current tile (mirrors: trainmappos%6144 - 24576 in C)
    local tilePhase = trainmappos % TILE_SIZE - (TILE_SIZE * 4)

    -- --------------------------------------------------------
    -- Front row  (C: obj = &TRAIN_MAP[96 - ((pos/TILE - laraX/TILE) & 0x1F)])
    -- --------------------------------------------------------
    if groupFront and groupFront.active then
        local baseIdx = 96 - (((trainmappos // TILE_SIZE) - (laraX // TILE_SIZE)) & 0x1F)

        groupFront:ForEachParticle(function(index, particle)
            local worldX = laraSnap + tilePhase + index * TILE_SIZE
            local objVal = mapAt(TRAIN_MAP, baseIdx + index)

            return {
                spriteIndex = archObjID(objVal),
                position    = Vec3(worldX, Y_LEVEL, Z_FRONT),
                orientation = Vec3(0, 0, 0),
                size        = 1,
                teleport    = wrapOccurred,
            }
        end)
    end

    -- --------------------------------------------------------
    -- Back row  (C: obj = &TRAIN_MAP[32 - ((pos/TILE - laraX/TILE + 8) & 0x1F)])
    --            rotated 180° around Y (phd_RotY(32760) ≈ 180°).
    --
    -- The C code passes -x as the LOCAL offset to phd_PutPolygons_train, but
    -- after the 180° Y rotation the local X axis = world -X, so the world
    -- displacement is -(-x) = +x — identical to the front row.  Do NOT negate.
    -- --------------------------------------------------------
    if groupBack and groupBack.active then
        local baseIdx = 32 - (((trainmappos // TILE_SIZE) - (laraX // TILE_SIZE) + 8) & 0x1F)

        groupBack:ForEachParticle(function(index, particle)
            local worldX = laraSnap + tilePhase + index * TILE_SIZE
            local objVal = mapAt(TRAIN_MAP, baseIdx + index)

            return {
                spriteIndex = archObjID(objVal),
                position    = Vec3(worldX, Y_LEVEL, Z_BACK),
                orientation = Vec3(0, 180, 0),
                size        = 1,
                teleport    = wrapOccurred,
            }
        end)
    end

    -- --------------------------------------------------------
    -- Obstacles  (C: p = &TRAIN_MAP2[32 - ((pos/TILE - laraX/TILE + 8) & 0x1F)])
    -- --------------------------------------------------------
    -- if groupObstacle and groupObstacle.active then
    --     local baseIdx = 32 - (((trainmappos // TILE_SIZE) - (laraX // TILE_SIZE) + 8) & 0x1F)

    --     groupObstacle:ForEachParticle(function(slot, particle)
    --         local entry = mapAt(TRAIN_MAP2, baseIdx + slot)
    --         local objType = entry[1]
    --         local zOff    = entry[2]

    --         if objType == NO_ITEM then
    --             -- Park invisible slots far off-screen.
    --             return {
    --                 meshID   = TEN.Objects.ObjID.ROCK0,
    --                 position = Vec3(laraX, -100000, Z_OBSTACLES),
    --                 size     = 0,
    --             }
    --         end

    --         local worldX = laraSnap + tilePhase + slot * TILE_SIZE
    --         if slot == VISIBLE_TILES then
    --             worldX = laraSnap + tilePhase + VISIBLE_TILES * TILE_SIZE
    --         end

    --         return {
    --             meshID   = objType,
    --             position = Vec3(worldX, Y_LEVEL, zOff + Z_OBSTACLES),
    --             size     = 1,
    --         }
    --     end)
    -- end
end

--- Stop and clean up all train groups.
function TrainScroller.Stop()
    if groupFront    and groupFront.active    then groupFront:Stop()    end
    if groupBack     and groupBack.active     then groupBack:Stop()     end
    if groupObstacle and groupObstacle.active then groupObstacle:Stop() end
    groupFront    = nil
    groupBack     = nil
    groupObstacle = nil
    trainmappos   = 0
end

return TrainScroller
