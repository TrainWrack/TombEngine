local Statistics = {}

local Settings = require("Engine.CustomInventory.Settings")
local COLOR_MAP = Settings.COLOR_MAP

-- Function to display level statistics on the screen
function Statistics.ShowLevelStats(gameStats)
    -- Retrieve current level statistics and configuration
    local levelStats = Flow.GetStatistics(gameStats)
    local level = Flow.GetCurrentLevel()

    -- Define screen positions for various UI elements using percentages
    local levelNameX, levelNameY = PercentToScreen(50, 33.3)   -- Position of the level name
    local headingsX, headingsY = PercentToScreen(22.4, 41.7)     -- Position of the headings
    local dataX, dataY = PercentToScreen(65, 41.7)           -- Position of the statistics data
    --local controlX, controlY = PercentToScreen(50, 90)       -- Position of the control instructions
    
    -- Set color and text scale for all UI elements
    local textScale = 1                                      -- Default text scale

    -- Create and display text for the UI.
 	local headings = DisplayString("Time Taken\nSecrets\nPickups\nKills\nAmmo Used\nMedi packs used\nDistance Travelled", Vec2(headingsX, headingsY), textScale, COLOR_MAP.NORMAL_FONT, false)
	local levelName = DisplayString(tostring(Flow.GetString(level.nameKey)), Vec2(levelNameX, levelNameY), textScale, COLOR_MAP.HEADER_FONT, false)
	--local control = DisplayString("Press ACTION to continue", Vec2(controlX, controlY), textScale / 2, textColor, false)


    -- Create and display statistics values
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
        false  -- Disable translations
    )

    -- Apply text effects (e.g., centering, shadow, blink)
    levelName:SetFlags({ TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW })
    headings:SetFlags({ TEN.Strings.DisplayStringOption.SHADOW })
    stats:SetFlags({ TEN.Strings.DisplayStringOption.SHADOW })
    --control:SetFlags({ TEN.Strings.DisplayStringOption.SHADOW, TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.BLINK })

    -- Display all UI elements on the screen
    ShowString(levelName, 1 / 30)
    ShowString(headings, 1 / 30)
    ShowString(stats, 1 / 30)
    --ShowString(control, 1 / 30)

    -- Draw a background graphic for the stats screen
	
    -- local bg = DisplaySprite(ObjID.BAR_BORDER_GRAPHICS, 1, Vec2(50, 48), 0, Vec2(60, 60), Color(20, 157, 0, 128))
    -- bg:Draw(0, View.AlignMode.CENTER, View.ScaleMode.STRETCH, Effects.BlendID.ADDITIVE)
end

function Statistics.LevelStats()

    TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE,LevelFuncs.EndLevelStats)
    -- Make game greyscale
    TEN.View.SetPostProcessMode(PostProcessMode.MONOCHROME)
    TEN.View.SetPostProcessStrength(1.0)
    Flow.SetFreezeMode(Flow.FreezeMode.FULL)


end


function Statistics.EndLevelStats()
    -- Move to next level or next Lara Start Pos when ACTION is pressed
    
    if TEN.Input.KeyIsHit(ActionID.ACTION) then 
        
        TEN.Logic.RemoveCallback(TEN.Logic.CallbackPoint.PREFREEZE,LevelFuncs.EndLevelStats)
        Flow.SetFreezeMode(Flow.FreezeMode.None)
        EndLevel() --Add number of level here as an argument.
        return

    end
    LevelFuncs.ShowLevelStats()

end

return Statistics