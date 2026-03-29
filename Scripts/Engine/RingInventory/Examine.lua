--- Internal file used by the RingInventory module.
-- @module RingInventory.Examine
-- @local

-- ============================================================================
-- Examine - Handles examine functions and data for ring inventory
-- ============================================================================
--External Modules
local Interpolate = require("Engine.RingInventory.Interpolate")
local Settings = require("Engine.RingInventory.Settings")
local Text = require("Engine.RingInventory.Text")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointer to tables
local COLOR_MAP = Settings.ColorMap

--Examine functions
local Examine = {}

local EXAMINE_POSITION = Vec3(0, 100, 0)
local EXAMINE_DEFAULT_SCALE = 1
local EXAMINE_MIN_SCALE = 0.3
local EXAMINE_MAX_SCALE = 1.6
local EXAMINE_TEXT_POS = Vec2(50, 80)
local ROTATION_MULTIPLIER = 2
local ZOOM_MULTIPLIER = 0.15
local ROTATION_SMOOTHING = 0.35
local ROTATION_SNAP_THRESHOLD = 0.05

local function NormalizeAngle(angle)
    angle = angle % 360
    if angle < 0 then
        angle = angle + 360
    end
    return angle
end

local function GetShortestAngleDelta(current, target)
    local delta = (target - current + 180) % 360 - 180
    if delta < -180 then
        delta = delta + 360
    end
    return delta
end

local function NormalizeRotation(rotation)
    return Rotation(
        NormalizeAngle(rotation.x),
        NormalizeAngle(rotation.y),
        NormalizeAngle(rotation.z)
    )
end

local function StepRotationAxis(current, target)
    local normalizedCurrent = NormalizeAngle(current)
    local normalizedTarget = NormalizeAngle(target)
    local delta = GetShortestAngleDelta(normalizedCurrent, normalizedTarget)

    if math.abs(delta) <= ROTATION_SNAP_THRESHOLD then
        return normalizedTarget
    end

    local step = delta * Interpolate.Easing.Softstep(ROTATION_SMOOTHING)
    return NormalizeAngle(normalizedCurrent + step)
end

local EXAMINE_TEXT = 
    {
        name = "EXAMINE_TEXT",                 
        text = "",               
        position = EXAMINE_TEXT_POS,                   
        scale = 1,                             
        color = COLOR_MAP.plainText,        
        visible = false,                           
        flags = 
        {
            Strings.DisplayStringOption.VERTICAL_CENTER,
            Strings.DisplayStringOption.CENTER,
            Strings.DisplayStringOption.SHADOW
        },
        translate = false,
    }

local EXAMINE_CONTROLS = 
    {
        name = "EXAMINE_CONTROLS",                 
        text = "",               
        position = Vec2(3, 80),              
        scale = 0.7,                          
        color = COLOR_MAP.plainText,    
        visible = false,                     
        flags = 
        {
            Strings.DisplayStringOption.SHADOW
        },
        translate = false,
    }

local examineRotation = Rotation(0, 0, 0)
local examineTargetRotation = Rotation(0, 0, 0)
local examineScaler = EXAMINE_DEFAULT_SCALE
local examineShowString = false
local alpha  = 0
local targetAlpha = 0

Examine.item = nil

local function ExamineLabel(showText)

    local string = ""

    if showText then
        string = string..Input.GetActionBinding(ActionID.ACTION)..": "..Flow.GetString("toggle_text")
    end

    string = string.."\n"..
            
            Input.GetActionBinding(ActionID.JUMP)..": "..Flow.GetString("reset").."\n"..
            Input.GetActionBinding(ActionID.SPRINT)..": "..Flow.GetString("zoom_in").."\n"..
            Input.GetActionBinding(ActionID.CROUCH)..": "..Flow.GetString("zoom_out")
            
    return string

end

function Examine.Item(itemData)

    examineScaler = math.max(EXAMINE_MIN_SCALE, math.min(EXAMINE_MAX_SCALE, examineScaler))
    local displayItem = itemData:GetDisplayItem()
    displayItem:SetRotation(examineRotation)
    displayItem:SetScale(Vec3(examineScaler))
    displayItem:Draw()
    
end

function Examine.SetupText(itemData)

    local item = itemData:GetObjectID()

    local objectName = Objects.GetSlotName(item)
    local stringKey = objectName:lower().."_text"
    local localizedString = Flow.IsStringPresent(stringKey) and Flow.GetString(stringKey) or nil

    
    if localizedString then
        examineShowString = true
        Text.Create(EXAMINE_TEXT)
        Text.SetText("EXAMINE_TEXT", localizedString, true)
    end

    Text.Create(EXAMINE_CONTROLS)
    Text.SetText("EXAMINE_CONTROLS", ExamineLabel(examineShowString), true)

end

function Examine.ToggleText()

    examineShowString = not examineShowString
    
    if examineShowString then
        Text.Show("EXAMINE_TEXT")
    else
        Text.Hide("EXAMINE_TEXT")
    end

end

function Examine.TextStatus()
    return examineShowString
end

function Examine.ModifyRotation(dirX, dirY, dirZ)

    examineTargetRotation.x = NormalizeAngle(examineTargetRotation.x + dirX * ROTATION_MULTIPLIER)
    examineTargetRotation.y = NormalizeAngle(examineTargetRotation.y + dirY * ROTATION_MULTIPLIER)
    examineTargetRotation.z = NormalizeAngle(examineTargetRotation.z + dirZ * ROTATION_MULTIPLIER)

end

function Examine.ModifyScale(dir)

    examineScaler = examineScaler + dir * ZOOM_MULTIPLIER

end

function Examine.GetRotation()

    return NormalizeRotation(examineTargetRotation)
    
end

function Examine.SetRotation(rotation)

    examineRotation = NormalizeRotation(rotation)
    examineTargetRotation = NormalizeRotation(rotation)
    
end

function Examine.GetScale()

    return examineScaler

end


function Examine.SetScale(scaleValue)

    examineScaler = scaleValue
    
end

function Examine.ResetExamine(item)

    Examine.SetRotation(item:GetRotation())
    Examine.SetScale(item:GetScale())

end

function Examine.Show(item)

    if not item then return end 

    Examine.ResetExamine(item)
    Examine.SetupText(item)
    targetAlpha = 255
    Examine.item  = TEN.View.DisplayItem(item:GetObjectID(), EXAMINE_POSITION, examineRotation, Vec3(examineScaler), item:GetMeshBits())

end

function Examine.Draw()

    if not Examine.item  then return end

    examineScaler = math.max(EXAMINE_MIN_SCALE, math.min(EXAMINE_MAX_SCALE, examineScaler))
    local color = Examine.item :GetColor()
    Examine.item :SetRotation(examineRotation)
    Examine.item :SetScale(Vec3(examineScaler))
    Examine.item :SetColor(Utilities.ColorCombine(color, alpha))
    Examine.item :Draw()

end

function Examine.Hide()

    Text.Hide("EXAMINE_CONTROLS")
    Text.Hide("EXAMINE_TEXT")
    examineShowString = false
    targetAlpha = 0

end

function Examine.Update()

    if not Examine.item  then return end

    examineRotation = Rotation(
        StepRotationAxis(examineRotation.x, examineTargetRotation.x),
        StepRotationAxis(examineRotation.y, examineTargetRotation.y),
        StepRotationAxis(examineRotation.z, examineTargetRotation.z)
    )

    local color = Examine.item :GetColor()
    alpha = Interpolate.StepAlpha(alpha, targetAlpha, Settings.Animation.textAlphaSpeed)
    local targetColor = Utilities.ColorCombine(color, alpha)
    Examine.item :SetColor(targetColor)

    if alpha == 0 then
        Examine.item  = nil
        Text.Destroy("EXAMINE_TEXT")
        Text.Destroy("EXAMINE_CONTROLS")
    end

end

return Examine