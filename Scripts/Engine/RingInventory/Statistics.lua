-- ============================================================================
-- Statistics - Handles statistics function and data for ring inventory
-- ============================================================================

--External Modules
local Menu = require("Engine.RingInventory.Menu")
local Settings = require("Engine.RingInventory.Settings")
local Text = require("Engine.RingInventory.Text")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP

--Variables
local oneTimeCheck = true
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

Text.Create(LEVEL_HEADER_TEXT)
Text.Create(HEADER_TEXT) 
Text.Create(STATS_TEXT)
Text.AddToGroup("STATISTICS", "LEVEL_HEADER_TEXT")
Text.AddToGroup("STATISTICS", "HEADER_TEXT")
Text.AddToGroup("STATISTICS", "STATS_TEXT")

local GetStatistics = function()

    local level = Flow.GetCurrentLevel()
    local levelStats = Flow.GetStatistics(statisticsType)
    local statistics = tostring(levelStats.timeTaken):sub(1, -4) .. "\n" ..
        tostring(Flow.GetSecretCount()) .. " / " .. tostring(level.secrets) .. "\n" ..
        tostring(levelStats.pickups) .. "\n" ..
        tostring(levelStats.kills) .. "\n" ..
        tostring(levelStats.ammoUsed) .. "\n" ..
        tostring(levelStats.healthPacksUsed) .. "\n" ..
        string.format("%.1f", levelStats.distanceTraveled / 420) .. " m"

    return statistics

end

function Stats.SetupStats()

    local level = Flow.GetCurrentLevel()
    local levelHeader = Flow.GetString(level.nameKey)
    local headings = 
        Flow.GetString("time_taken").."\n"..
        Flow.GetString("total_secrets_found").."\n"..
        Flow.GetString("pickups").."\n"..
        Flow.GetString("kills").."\n"..
        Flow.GetString("ammo_used").."\n"..
        Flow.GetString("used_medipacks").."\n"..
        Flow.GetString("distance_travelled")
    
    local statistics = GetStatistics()
    
    Text.SetText("LEVEL_HEADER_TEXT", levelHeader, false)
    Text.SetText("HEADER_TEXT", headings, false)
    Text.SetText("STATS_TEXT", statistics, false)

end

function Stats.Show()

    Text.ShowGroup("STATISTICS")
    Menu.AddActive("StatisticsMenu")
    oneTimeCheck = true
end

function Stats.Hide()
    
    if oneTimeCheck then
        Text.HideGroup("STATISTICS")
        Menu.RemoveActive("StatisticsMenu")
        oneTimeCheck = false
    end

end

function Stats.UpdateStatistics()

    local statistics = GetStatistics()
    Text.SetText("STATS_TEXT", statistics, true)

end

function Stats.ToggleType()
    statisticsType = not statisticsType
    Stats.UpdateStatistics()
end

function Stats.CreateStatisticsMenu()
    local statItems = {}
    local items = {"statistics_level", "statistics_game"}
    
    if items then
        for _, itemData in ipairs(items) do
            local text = "< " .. Flow.GetString(itemData) .. " >"
            table.insert(statItems, text)
        end
    end
    
    local table = {
        {
            itemName = "Blank",
            options = statItems,
            currentOption = 1
        }
    }
    
    local statisticsMenu = Menu.Create("StatisticsMenu", nil, table, nil, nil, Menu.Type.OPTIONS_ONLY)
    
    statisticsMenu:SetOptionsPosition(Vec2(50, 24.7))
    statisticsMenu:SetLineSpacing(5.3)
    statisticsMenu:SetOptionsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    statisticsMenu:SetOnOptionChangeFunction("Blank", "Engine.RingInventory.ChangeStatistics")
    statisticsMenu:SetWrapAroundOptions(true)
    statisticsMenu:EnableInputs(true)
end

local function CalculateCompassAngle(timeCount)
    local needleOrient = Rotation(0, -Lara:GetRotation().y, 0)
    local wibble = math.sin((timeCount % 0x40) / 0x3F * (2 * math.pi))
    needleOrient.y = needleOrient.y + wibble
    return needleOrient
end

local function CalculateStopWatchRotation()
    local angles = {}
    local levelTime = Flow.GetStatistics(statisticsType).timeTaken
    angles.hour_hand_angle = Rotation(0, 0, -(levelTime.h / 12) * 360)
    angles.minute_hand_angle = Rotation(0, 0, -(levelTime.m / 60) * 360)
    angles.second_hand_angle = Rotation(0, 0, -(levelTime.s / 60) * 360)
    return angles
end

function Stats.SetItemRotations(timeCount)

    local angles = CalculateStopWatchRotation()
    local stopwatch = TEN.View.DisplayItem.GetItemByName(tostring(TEN.Objects.ObjID.STOPWATCH_ITEM))
    if stopwatch then
        stopwatch:SetJointRotation(4, angles.hour_hand_angle)
        stopwatch:SetJointRotation(5, angles.minute_hand_angle)
        stopwatch:SetJointRotation(6, angles.second_hand_angle)
    end

    local compass = TEN.View.DisplayItem.GetItemByName(tostring(TEN.Objects.ObjID.COMPASS_ITEM))
    if compass then
        compass:SetJointRotation(1, CalculateCompassAngle(timeCount))
    end
end

-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.CustomInventory)
-- ============================================================================
LevelFuncs.Engine.RingInventory = LevelFuncs.Engine.RingInventory or {}
LevelFuncs.Engine.RingInventory.ChangeStatistics = Stats.ToggleType

return Stats