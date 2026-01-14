local Examine = {}

local EXAMINE_DEFAULT_SCALE = 1
local EXAMINE_MIN_SCALE = 0.3
local EXAMINE_MAX_SCALE = 1.6
local EXAMINE_TEXT_POS = Vec2(50, 80)

local examineRotation = Rotation(0, 0, 0)
local examineScaler = EXAMINE_DEFAULT_SCALE
local examineScalerOld = EXAMINE_DEFAULT_SCALE
local examineShowString = false

function Examine.Item(item)
    examineScaler = math.max(EXAMINE_MIN_SCALE, math.min(EXAMINE_MAX_SCALE, examineScaler))
    
    local objectName = Util.GetObjectIDString(item)
    local stringKey = objectName:lower().."_text"
    local localizedString = Flow.IsStringPresent(stringKey) and Flow.GetString(stringKey) or nil
    
    local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(item))
    displayItem:SetRotation(examineRotation)
    displayItem:SetScale(Vec3(examineScaler))
    
    if localizedString and examineShowString then
        local entryText = TEN.Strings.DisplayString(
            localizedString,
            Utilities.PercentPos(EXAMINE_TEXT_POS.x, EXAMINE_TEXT_POS.y),
            1,
            COLOR_MAP.NORMAL_FONT,
            true,
            {Strings.DisplayStringOption.VERTICAL_CENTER, Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER}
        )
        Strings.ShowString(entryText, 1 / 30)
    end
end


return Examine