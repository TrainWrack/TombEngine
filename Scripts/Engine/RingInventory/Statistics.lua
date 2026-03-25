--- Internal file used by the RingInventory module.
-- @module RingInventory.Statistics
-- @local

-- ============================================================================
-- Statistics - Handles statistics function and data for ring inventory
-- ============================================================================

--External Modules
local Settings = require("Engine.RingInventory.Settings")
local Text = require("Engine.RingInventory.Text")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP

--Class Start
local Stats = {}

local statisticsType = false

local LEVEL_HEADER_POS = Vec2(50, 33.3)
local HEADER_TEXT_POS = Vec2(22.4, 41.7)
local STATS_TEXT_POS = Vec2(65, 41.7)
local STATS_TEXT_SCALE = 1

local LEVEL_HEADER_TEXT = 
{
name = "LEVEL_HEADER_TEXT",                 
text = "",               
position = LEVEL_HEADER_POS,                   
scale = STATS_TEXT_SCALE,                             
color = COLOR_MAP.HEADER_FONT,        
visible = false,                           
flags = 
{
    Strings.DisplayStringOption.CENTER,
    Strings.DisplayStringOption.SHADOW
},
translate = false,
}

local HEADER_TEXT = 
{
name = "HEADER_TEXT",                 
text = "",               
position = HEADER_TEXT_POS,                   
scale = STATS_TEXT_SCALE,                             
color = COLOR_MAP.NORMAL_FONT,        
visible = false,                           
flags = 
{
    Strings.DisplayStringOption.SHADOW
},
translate = false,
}

local STATS_TEXT = 
{
name = "STATS_TEXT",                 
text = "",               
position = STATS_TEXT_POS,                   
scale = STATS_TEXT_SCALE,                             
color = COLOR_MAP.NORMAL_FONT,        
visible = false,                           
flags = 
{
    Strings.DisplayStringOption.SHADOW
},
translate = false,
}

local GetStatistics = function(type)

    local secretCount = type and Flow.GetTotalSecretCount() or TEN.Flow.GetCurrentLevel().secrets
    local levelStats = Flow.GetStatistics(type)
    local statistics = tostring(levelStats.timeTaken):sub(1, -4) .. "\n" ..
        tostring(levelStats.secrets) .. " / " .. tostring(secretCount) .. "\n" ..
        tostring(levelStats.pickups) .. "\n" ..
        tostring(levelStats.kills) .. "\n" ..
        tostring(levelStats.ammoUsed) .. "\n" ..
        tostring(levelStats.healthPacksUsed) .. "\n" ..
        string.format("%.1f", levelStats.distanceTraveled / 420) .. " m"

    return statistics

end

local GetLabels = function(type)

    local secretsText = type and Flow.GetString("total_secrets_found") or Flow.GetString("level_secrets_found")

    local headings = 
        Flow.GetString("time_taken").."\n"..
        secretsText.."\n"..
        Flow.GetString("pickups").."\n"..
        Flow.GetString("kills").."\n"..
        Flow.GetString("ammo_used").."\n"..
        Flow.GetString("used_medipacks").."\n"..
        Flow.GetString("distance_travelled")

    return headings

end

function Stats.SetupStats()

    Text.Create(LEVEL_HEADER_TEXT)
    Text.Create(HEADER_TEXT) 
    Text.Create(STATS_TEXT)
    Text.AddToGroup("STATISTICS", "LEVEL_HEADER_TEXT")
    Text.AddToGroup("STATISTICS", "HEADER_TEXT")
    Text.AddToGroup("STATISTICS", "STATS_TEXT")

    local level = Flow.GetCurrentLevel()
    local levelHeader = Flow.GetString(level.nameKey)
    
    local headings = GetLabels(statisticsType)
    local statistics = GetStatistics(statisticsType)
    
    Text.SetText("LEVEL_HEADER_TEXT", levelHeader, false)
    Text.SetText("HEADER_TEXT", headings, false)
    Text.SetText("STATS_TEXT", statistics, false)

end

function Stats.Show()
    Text.ShowGroup("STATISTICS")
end

function Stats.Hide()
    Text.HideGroup("STATISTICS")
end

function Stats.UpdateStatistics(type)

    if type then
        Text.SetText("LEVEL_HEADER_TEXT", Flow.GetString("game_title"), true)
    else
        local level = Flow.GetCurrentLevel()
        Text.SetText("LEVEL_HEADER_TEXT", Flow.GetString(level.nameKey), true)
    end

    local statistics = GetStatistics(type)
    local headings = GetLabels(type)
    Text.SetText("HEADER_TEXT", headings, true)
    Text.SetText("STATS_TEXT", statistics, true)
end

function Stats.ToggleType()
    statisticsType = not statisticsType
    Stats.UpdateStatistics(statisticsType)
end

function Stats.GetType()
    return statisticsType
end

function Stats.UpdateIngameTime()
    
    if Settings.STATISTICS.PROGRESS_TIME then
        Flow.GetStatistics(true).timeTaken = Flow.GetStatistics(true).timeTaken + 1
        Flow.GetStatistics(false).timeTaken = Flow.GetStatistics(false).timeTaken + 1
    end

end

return Stats