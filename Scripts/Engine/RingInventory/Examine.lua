-- ============================================================================
-- Examine - Handles examine functions and data for ring inventory
-- ============================================================================
--External Modules
local Settings = require("Engine.RingInventory.Settings")
local Text = require("Engine.RingInventory.Text")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointer to tables
local COLOR_MAP = Settings.COLOR_MAP

--Examine functions
local Examine = {}

local EXAMINE_DEFAULT_SCALE = 1
local EXAMINE_MIN_SCALE = 0.3
local EXAMINE_MAX_SCALE = 1.6
local EXAMINE_TEXT_POS = Vec2(50, 80)
local ROTATION_MULTIPLIER = 2
local ZOOM_MULTIPLIER = 0.3

local EXAMINE_TEXT = 
{
name = "EXAMINE_TEXT",                 
text = "",               
position = EXAMINE_TEXT_POS,                   
scale = 1,                             
color = COLOR_MAP.NORMAL_FONT,        
visible = false,                           
flags = 
{
    Strings.DisplayStringOption.VERTICAL_CENTER,
    Strings.DisplayStringOption.CENTER,
    Strings.DisplayStringOption.SHADOW
},
translate = false,
}
    
Text.Create(EXAMINE_TEXT) --Create Examine Text Channel

local examineRotation = Rotation(0, 0, 0)
local examineScaler = EXAMINE_DEFAULT_SCALE
local examinePreviousScale = EXAMINE_DEFAULT_SCALE
local examineShowString = false

function Examine.Item(itemData)

    local item = itemData.objectID
    examineScaler = math.max(EXAMINE_MIN_SCALE, math.min(EXAMINE_MAX_SCALE, examineScaler))
    local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(item))
    displayItem:SetRotation(examineRotation)
    displayItem:SetScale(Vec3(examineScaler))
    
end

function Examine.SetupText(itemData)

    local item = itemData.objectID

    examineShowString = false
    local objectName = Util.GetObjectIDString(item)
    local stringKey = objectName:lower().."_text"
    local localizedString = Flow.IsStringPresent(stringKey) and Flow.GetString(stringKey) or nil

    if localizedString then
        Text.SetText("EXAMINE_TEXT", localizedString, false)
    end

end

function Examine.ToggleText()

    examineShowString = not examineShowString
    
    if examineShowString then
        Text.Show("EXAMINE_TEXT")
    else
        Text.Hide("EXAMINE_TEXT")
    end

end

function Examine.ModifyRotation(dirX, dirY, dirZ)

    examineRotation.x = examineRotation.x + dirX * ROTATION_MULTIPLIER
    examineRotation.y = examineRotation.y + dirY * ROTATION_MULTIPLIER
    examineRotation.z = examineRotation.z + dirZ * ROTATION_MULTIPLIER

end

function Examine.ModifyScale(dir)

    examineScaler = examineScaler + dir * ZOOM_MULTIPLIER

end

function Examine.GetRotation()

    return examineRotation
    
end

function Examine.SetRotation(rotation)

    examineRotation = Utilities.CopyRotation(rotation)
    
end

function Examine.GetScale()

    return examineScaler

end

function Examine.GetPreviousScale()

    return examinePreviousScale

end

function Examine.SetScale(scaleValue)

    examinePreviousScale = scaleValue
    examineScaler = scaleValue
    
end

function Examine.ResetExamine()

    examineRotation = Rotation(0, 0, 0)
    examineScaler = EXAMINE_DEFAULT_SCALE

end

return Examine