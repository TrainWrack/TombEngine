
--External Modules
local CONSTANTS = require("Engine.RingInventory.Constants")
local CustomInventory = require("Engine.RingInventory.Inventory")
local Settings = require("Engine.RingInventory.Settings")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointers to tables
local SOUND_MAP = Settings.SOUND_MAP

local Ring = {}

Ring.TYPE = {
	PUZZLE = 1,
    MAIN = 2,
	OPTIONS = 3,
	COMBINE = 4,
	AMMO = 5
}

Ring.CENTER = {
    [PICKUP_DATA.RING.PUZZLE] = Vec3(0,-800,1024),
    [PICKUP_DATA.RING.MAIN] = Vec3(0,200,1024),
    [PICKUP_DATA.RING.OPTIONS] = Vec3(0,1200,1024),
    [PICKUP_DATA.RING.COMBINE] = Vec3(0,300,1024),
    [PICKUP_DATA.RING.AMMO] = Vec3(0,300,1024)
}

Ring.RING_POSITION_OFFSET = 1000
Ring.RING_RADIUS = (View.GetAspectRatio() > 1.7) and -512 or -450


Ring.currentRingAngle = 0
Ring.previousRingAngle = 0
Ring.targetRingAngle = 0
Ring.direction = 1

function Ring.SetVisibility(ringName, visible)
    local ring = Inventory.GetRing(ringName)
    if not ring then return end
    
    local itemCount = #ring
    for i = 1, itemCount do
        local currentItem = ring[i].objectID
        local inventoryItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        inventoryItem:SetVisible(visible)
    end
end

function Ring.Translate(ringName, center, radius, rotationOffset, alpha)
    alpha = alpha or 1.0
    local ring = Inventory.GetRing(ringName)
    if not ring then return end
    
    local itemCount = #ring
    for i = 1, itemCount do
        local currentItem = ring[i].objectID
        local currentDisplayItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        local angleDeg = (360 / itemCount) * (i - 1) + rotationOffset
        local position = center:Translate(Rotation(0, angleDeg, 0), radius)
        local itemRotations = currentDisplayItem:GetRotation()
        
        local currentAngle = itemRotations.y
        local angleDiff = (angleDeg - currentAngle) % 360
        if angleDiff > 180 then
            angleDiff = angleDiff - 360
        end
        local newAngle = (currentAngle + angleDiff * alpha) % 360
        
        currentDisplayItem:SetPosition(Utilities.OffsetY(position, ring[i].yOffset))
        currentDisplayItem:SetRotation(Rotation(itemRotations.x, newAngle, itemRotations.z))
    end
end

function Ring.Fade(ringName, fadeValue, omitSelectedItem)
    local ring = Inventory.GetRing(ringName)
    if not ring then return end
    
    local itemCount = #ring
    local selectedItem = omitSelectedItem and GetSelectedItem(selectedRing).objectID
    
    for i = 1, itemCount do
        local currentItem = ring[i].objectID
        local currentDisplayItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        if omitSelectedItem and selectedItem == currentItem then
            goto continue
        end
        
        local itemColor = currentDisplayItem:GetColor()
        currentDisplayItem:SetColor(Utilities.ColorCombine(itemColor, fadeValue))
        
        ::continue::
    end
end

function Ring.Color(ringName, color, omitSelectedItem, alpha)
    local ring = Inventory.GetRing(ringName)
    if not ring then return end
    
    local itemCount = #ring
    local selectedItem = omitSelectedItem and GetSelectedItem(selectedRing).objectID
    
    for i = 1, itemCount do
        local currentItem = ring[i].objectID
        local currentDisplayItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        if omitSelectedItem and selectedItem == currentItem then
            goto continue
        end
        
        local itemColor = currentDisplayItem:GetColor()
        local targetColor = Animation.Interpolate.Lerp(itemColor, color, alpha)
        currentDisplayItem:SetColor(Utilities.ColorCombine(targetColor, itemColor.a))
        
        ::continue::
    end
end

function Ring.FadeAll(visible, omitSelectedRing)
    local fadeValue = visible and ALPHA_MAX or ALPHA_MIN
    
    for index in pairs(inventory.ring) do
        if not (omitSelectedRing and index == selectedRing) then
            FadeRing(index, fadeValue, false)
            SetRingVisibility(index, visible)
        end
    end
end

return Ring