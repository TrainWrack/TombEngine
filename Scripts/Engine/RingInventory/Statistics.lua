--External Modules
local Menu = require("Engine.CustomMenu")
local Settings = require("Engine.CustomInventory.Settings")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP

local Statistics = {}

Statistics.type = false

function Statistics.ShowLevelStats()
   
    local levelStats = Flow.GetStatistics(Statistics.type)
    local level = Flow.GetCurrentLevel()
   
    local levelNameX, levelNameY = TEN.Util.PercentToScreen(50, 33.3)
    local headingsX, headingsY = TEN.Util.PercentToScreen(22.4, 41.7)
    local dataX, dataY = TEN.Util.PercentToScreen(65, 41.7)
    local textScale = 1

 	local headings = DisplayString("Time Taken\nSecrets\nPickups\nKills\nAmmo Used\nMedi packs used\nDistance Travelled", Vec2(headingsX, headingsY), textScale, COLOR_MAP.NORMAL_FONT, false)
	local levelName = DisplayString(tostring(Flow.GetString(level.nameKey)), Vec2(levelNameX, levelNameY), textScale, COLOR_MAP.HEADER_FONT, false)

    local stats = DisplayString(
        tostring(levelStats.timeTaken):sub(1, -4) .. "\n" ..
        tostring(Flow.GetSecretCount()) .. " / " .. tostring(level.secrets) .. "\n" ..
        tostring(levelStats.pickups) .. "\n" ..
        tostring(levelStats.kills) .. "\n" ..
        tostring(levelStats.ammoUsed) .. "\n" ..
        tostring(levelStats.healthPacksUsed) .. "\n" ..
        string.format("%.1f", levelStats.distanceTraveled / 420) .. " m",
        Vec2(dataX, dataY),
        textScale,
        COLOR_MAP.NORMAL_FONT,
        false
    )

    levelName:SetFlags({ TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW })
    headings:SetFlags({ TEN.Strings.DisplayStringOption.SHADOW })
    stats:SetFlags({ TEN.Strings.DisplayStringOption.SHADOW })

    TEN.Strings.ShowString(levelName, 1 / 30)
    TEN.Strings.ShowString(headings, 1 / 30)
    TEN.Strings.ShowString(stats, 1 / 30)

end

function Statistics.ChangeStatistics()
    Statistics.type = not Statistics.type
end

function Statistics.CreateStatisticsMenu()
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
    
    local statisticsMenu = Menu.Create("SatisticsMenu", "statistics", table, nil, nil, Menu.Type.OPTIONS_ONLY)
    
    statisticsMenu:SetOptionsPosition(Vec2(50, 24.7))
    statisticsMenu:SetVisibility(true)
    statisticsMenu:SetLineSpacing(5.3)
    statisticsMenu:SetOptionsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    statisticsMenu:SetOnOptionChangeFunction("Blank", "Engine.CustomInventory.ChangeStatistics")
    statisticsMenu:SetWrapAroundOptions(true)
    statisticsMenu:EnableInputs(true)
    statisticsMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, nil, nil, true)
    statisticsMenu:SetTitlePosition(Vec2(50, 4))
end

function Statistics.RunStatisticsMenu()
    local statisticsMenu = Menu.Get("SatisticsMenu")
    statisticsMenu:Draw()
end

local function CalculateCompassAngle()
    local needleOrient = Rotation(0, -Lara:GetRotation().y, 0)
    local wibble = math.sin((timeInMenu % 0x40) / 0x3F * (2 * math.pi))
    needleOrient.y = needleOrient.y + wibble
    return needleOrient
end

local function CalculateStopWatchRotation()
    local angles = {}
    local levelTime = Flow.GetStatistics(Statistics.type).timeTaken
    angles.hour_hand_angle = Rotation(0, 0, -(levelTime.h / 12) * 360)
    angles.minute_hand_angle = Rotation(0, 0, -(levelTime.m / 60) * 360)
    angles.second_hand_angle = Rotation(0, 0, -(levelTime.s / 60) * 360)
    return angles
end

function Statistics.SetItemRotations()

    local angles = CalculateStopWatchRotation()
    local stopwatch = TEN.View.DisplayItem.GetItemByName(tostring(TEN.Objects.ObjID.STOPWATCH_ITEM))
    stopwatch:SetJointRotation(4, angles.hour_hand_angle)
    stopwatch:SetJointRotation(5, angles.minute_hand_angle)
    stopwatch:SetJointRotation(6, angles.second_hand_angle)
    
    local compass = TEN.View.DisplayItem.GetItemByName(tostring(TEN.Objects.ObjID.COMPASS_ITEM))
    compass:SetJointRotation(1, CalculateCompassAngle())

end

-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.CustomInventory)
-- ============================================================================
LevelFuncs.Engine.CustomInventory = LevelFuncs.Engine.CustomInventory or {}
LevelFuncs.Engine.CustomInventory.ChangeStatistics = Statistics.ChangeStatistics

return Statistics