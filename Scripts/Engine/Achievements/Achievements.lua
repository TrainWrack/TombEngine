--- Achievement system entry point.
-- Loads achievement definitions from a setup file, persists unlock state across
-- levels via GameVars, and exposes a simple API for game scripts.
--
-- Popup notifications (POSTLOOP) and the list viewer (PREFREEZE) are registered
-- automatically when ImportAchievements() is called.
--
-- Quick-start (add to LevelFuncs.OnStart in every level that uses achievements):
--
--   local Achievements = require("Engine.Achievements.Achievements")
--   Achievements.ImportAchievements("AchievementSetup")
--
-- Unlock an achievement at runtime:
--   Achievements.Unlock("treasure_hunter")
--
-- Open the full list (e.g. from a key bind or trigger):
--   Achievements.ShowAchievementList()
--
-- @module Engine.Achievements.Achievements

local Settings = require("Engine.Achievements.Settings")
local Block    = require("Engine.Achievements.Block")   -- referenced by sub-modules
local Popup    = require("Engine.Achievements.Popup")
local List     = require("Engine.Achievements.List")

LevelFuncs.Engine.Achievements = LevelFuncs.Engine.Achievements or {}

-- Persist unlock state across levels and save/loads.
GameVars.Engine.Achievements = GameVars.Engine.Achievements or { unlocked = {} }

local Achievements = {}

-- Module-level definition tables (runtime only; not persisted).
local Defs   = {}   -- ordered array of definition tables
local DefMap = {}   -- id string -> definition table

-- Guard: prevents duplicate AddCallback registrations within one Lua session.
local _callbacksRegistered = false

-- ============================================================================
-- LevelFuncs callbacks
-- Must live in LevelFuncs so that AddCallback / RemoveCallback can reference
-- them by value after a level reload.
-- ============================================================================

LevelFuncs.Engine.Achievements.OnLoop = function()
    Popup.Tick()
    Popup.Draw()
end

LevelFuncs.Engine.Achievements.OnFreeze = function()
    List.Tick()
    List.Draw()
end

-- ============================================================================
-- Internal helpers
-- ============================================================================

local function PlaySound(soundId)
    if soundId and soundId > 0 then
        TEN.Sound.PlaySound(soundId)
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Load achievement definitions from an external file and start the system.
-- Can be called from LevelFuncs.OnStart and LevelFuncs.OnLoad; duplicate
-- registrations are guarded internally.
-- @tparam string fileName  Name of the Lua file (without extension) in the
--                          script folder (e.g. "AchievementSetup").
function Achievements.ImportAchievements(fileName)
    if type(fileName) ~= "string" then
        TEN.Util.PrintLog("Achievements.ImportAchievements: 'fileName' must be a string.",
                          TEN.Util.LogLevel.WARNING)
        return
    end

    local ok, data = pcall(require, fileName)
    if not ok or type(data) ~= "table" then
        TEN.Util.PrintLog("Achievements.ImportAchievements: could not load '" .. fileName .. "'.",
                          TEN.Util.LogLevel.WARNING)
        return
    end

    Defs   = {}
    DefMap = {}

    for i, entry in ipairs(data) do
        if type(entry.id) ~= "string" then
            TEN.Util.PrintLog("Achievements: entry " .. i .. " missing string 'id'. Skipped.",
                              TEN.Util.LogLevel.WARNING)
        elseif type(entry.title) ~= "string" then
            TEN.Util.PrintLog("Achievements: entry '" .. entry.id .. "' missing string 'title'. Skipped.",
                              TEN.Util.LogLevel.WARNING)
        elseif type(entry.description) ~= "string" then
            TEN.Util.PrintLog("Achievements: entry '" .. entry.id .. "' missing string 'description'. Skipped.",
                              TEN.Util.LogLevel.WARNING)
        elseif type(entry.spriteId) ~= "number" then
            TEN.Util.PrintLog("Achievements: entry '" .. entry.id .. "' missing number 'spriteId'. Skipped.",
                              TEN.Util.LogLevel.WARNING)
        else
            local def = {
                id          = entry.id,
                title       = entry.title,
                description = entry.description,
                spriteId    = entry.spriteId,
                hidden      = entry.hidden == true,
            }
            Defs[#Defs + 1] = def
            DefMap[entry.id] = def
        end
    end

    -- Ensure GameVars structure is valid (e.g. after ClearAll or first run).
    GameVars.Engine.Achievements         = GameVars.Engine.Achievements         or {}
    GameVars.Engine.Achievements.unlocked = GameVars.Engine.Achievements.unlocked or {}

    -- Inject runtime tables into sub-modules.
    Popup.Init(DefMap)
    List.Init(Defs)

    Achievements.Status(true)

    TEN.Util.PrintLog("Achievements: loaded " .. #Defs .. " definition(s) from '" .. fileName .. "'.",
                      TEN.Util.LogLevel.INFO)
end

--- Enable or disable the achievement callbacks.
-- ImportAchievements() calls this automatically with value = true.
-- @tparam bool value  True to activate, false to deactivate.
function Achievements.Status(value)
    if value then
        if not _callbacksRegistered then
            TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POSTLOOP,
                                  LevelFuncs.Engine.Achievements.OnLoop)
            TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE,
                                  LevelFuncs.Engine.Achievements.OnFreeze)
            _callbacksRegistered = true
        end
    else
        TEN.Logic.RemoveCallback(TEN.Logic.CallbackPoint.POSTLOOP,
                                 LevelFuncs.Engine.Achievements.OnLoop)
        TEN.Logic.RemoveCallback(TEN.Logic.CallbackPoint.PREFREEZE,
                                 LevelFuncs.Engine.Achievements.OnFreeze)
        _callbacksRegistered = false
    end
end

--- Unlock an achievement.
-- Has no effect if the achievement is already unlocked or the ID is unknown.
-- Enqueues a slide-in popup notification automatically.
-- @tparam string id  Achievement ID as defined in the setup file.
function Achievements.Unlock(id)
    if not DefMap[id] then
        TEN.Util.PrintLog("Achievements.Unlock: unknown id '" .. tostring(id) .. "'.",
                          TEN.Util.LogLevel.WARNING)
        return
    end

    if GameVars.Engine.Achievements.unlocked[id] then return end

    GameVars.Engine.Achievements.unlocked[id] = true
    Popup.Enqueue(id)

    TEN.Util.PrintLog("Achievements: unlocked '" .. id .. "'.", TEN.Util.LogLevel.INFO)
end

--- Check whether a specific achievement is unlocked.
-- @tparam  string id  Achievement ID.
-- @treturn bool       True if unlocked.
function Achievements.IsUnlocked(id)
    return GameVars.Engine.Achievements.unlocked[id] == true
end

--- Returns true if every loaded achievement has been unlocked.
-- Returns false (not true) when no definitions have been loaded yet.
-- @treturn bool
function Achievements.IsAllUnlocked()
    if #Defs == 0 then return false end
    for _, def in ipairs(Defs) do
        if not GameVars.Engine.Achievements.unlocked[def.id] then
            return false
        end
    end
    return true
end

--- Returns ratio of unlocked achievements.
-- Returns false (not true) when no definitions have been loaded yet.
-- @treturn number|bool  Ratio of unlocked achievements (0.0 to 1.0) or false if no definitions.
function Achievements.GetUnlockRatio()
    if #Defs == 0 then return false end
    local unlockedCount = 0
    for _, def in ipairs(Defs) do
        if GameVars.Engine.Achievements.unlocked[def.id] then
            unlockedCount = unlockedCount + 1
        end
    end
    local total    = (#Defs > 0) and #Defs or 1
    return unlockedCount / total
end

--- Clear all unlock state and discard any pending popup notifications.
-- Unlocked achievements will appear locked again the next time the list opens.
function Achievements.ClearAll()
    GameVars.Engine.Achievements.unlocked = {}
    Popup.ClearQueue()
    TEN.Util.PrintLog("Achievements: all achievements cleared.", TEN.Util.LogLevel.INFO)
end

--- Open the full-screen achievement list (enters FULL freeze mode).
-- The list stays open until the player presses the exit action defined in
-- Settings.List.exitAction (default: Inventory key).
function Achievements.ShowAchievementList()
    List.Open()
end

return Achievements
