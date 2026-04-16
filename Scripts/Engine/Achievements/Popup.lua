--- Popup notification system for achievements.
-- Maintains a FIFO queue of achievement IDs and animates each one as a block
-- that slides up from below the screen, holds, then slides back down.
-- The popup automatically pauses when the achievement list viewer is open
-- (because POSTLOOP callbacks do not fire during FULL freeze mode).
-- @module Engine.Achievements.Popup
-- @local

local Settings = require("Engine.Achievements.Settings")
local Block    = require("Engine.Achievements.Block")

local Popup = {}

-- ============================================================================
-- State
-- ============================================================================

-- Injected via Popup.Init() after definitions are loaded.
local DefMap = nil

local Queue      = {}      -- FIFO queue of achievement IDs
local state      = "IDLE"  -- "IDLE" | "SLIDING_IN" | "HOLDING" | "SLIDING_OUT"
local currentDef = nil     -- definition table for the currently displayed popup
local posY       = 0       -- current Y position in screen percent
local alpha      = 0       -- current alpha 0-255 (float, floored on draw)
local holdTimer  = 0       -- elapsed hold time in seconds

local STATE_IDLE        = "IDLE"
local STATE_SLIDING_IN  = "SLIDING_IN"
local STATE_HOLDING     = "HOLDING"
local STATE_SLIDING_OUT = "SLIDING_OUT"

-- ============================================================================
-- Internal
-- ============================================================================

local function PlaySound(soundId)
    if soundId and soundId > 0 then
        TEN.Sound.PlaySound(soundId)
    end
end

local function Lerp(current, target, speed)
    return current + (target - current) * speed
end

local function StartNext()
    if #Queue == 0 then
        state      = STATE_IDLE
        currentDef = nil
        return
    end

    local id  = table.remove(Queue, 1)
    local def = DefMap and DefMap[id] or nil

    if not def then
        -- Unknown ID; skip silently and try the next entry.
        StartNext()
        return
    end

    currentDef = def
    posY       = Settings.Popup.startPosY
    alpha      = 0
    holdTimer  = 0
    state      = STATE_SLIDING_IN

    PlaySound(Settings.Popup.sound)
end

-- ============================================================================
-- Public
-- ============================================================================

--- Inject definition tables. Called by Achievements.lua after loading the setup file.
-- @tparam table defMap  id-to-definition map  { [id] = def }
function Popup.Init(defMap)
    DefMap = defMap
end

--- Add an achievement ID to the display queue.
-- If the popup is currently idle the new entry starts immediately.
-- @tparam string id  Achievement ID as defined in the setup file.
function Popup.Enqueue(id)
    Queue[#Queue + 1] = id
    if state == STATE_IDLE then
        StartNext()
    end
end

--- Update popup animation. Intended for the POSTLOOP callback.
-- Automatically does nothing when the FULL freeze list is open because
-- POSTLOOP callbacks do not fire during freeze mode.
function Popup.Tick()
    if state == STATE_IDLE then return end

    local P = Settings.Popup

    if state == STATE_SLIDING_IN then
        posY  = Lerp(posY,  P.targetPosY, P.slideSpeed)
        alpha = Lerp(alpha, 255,           P.alphaSpeed)

        if math.abs(posY - P.targetPosY) < 0.15 then
            posY  = P.targetPosY
            alpha = 255
            state = STATE_HOLDING
        end

    elseif state == STATE_HOLDING then
        holdTimer = holdTimer + 1 / 30
        if holdTimer >= P.holdTime then
            state = STATE_SLIDING_OUT
        end

    elseif state == STATE_SLIDING_OUT then
        posY  = Lerp(posY,  P.startPosY, P.slideSpeed)
        alpha = Lerp(alpha, 0,            P.alphaSpeed)

        if math.abs(posY - P.startPosY) < 0.5 then
            posY  = P.startPosY
            alpha = 0
            StartNext()   -- advances queue (or goes IDLE)
        end
    end
end

--- Draw the current popup block. Intended for the POSTLOOP callback.
function Popup.Draw()
    if state == STATE_IDLE then return end
    if not currentDef then return end

    local isUnlocked = GameVars.Engine.Achievements.unlocked[currentDef.id] == true
    Block.Draw(currentDef, isUnlocked, Settings.Popup.posX, posY, math.floor(alpha))
end

--- Returns true while a popup is visible or entries are waiting in the queue.
-- @treturn bool
function Popup.IsActive()
    return state ~= STATE_IDLE or #Queue > 0
end

--- Discard all queued and in-progress popups (e.g. after ClearAll).
function Popup.ClearQueue()
    Queue      = {}
    state      = STATE_IDLE
    currentDef = nil
    alpha      = 0
    posY       = Settings.Popup.startPosY
end

return Popup
