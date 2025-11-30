local Statistics = {}

local Settings = require("Engine.CustomInventory.Settings")
local COLOR_MAP = Settings.COLOR_MAP

function Statistics.ShowLevelStats(gameStats)
   
    local levelStats = Flow.GetStatistics(gameStats)
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

return Statistics