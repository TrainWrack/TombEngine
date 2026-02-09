
-- ============================================================================
-- Ring Class - Manage Rings and items stored in them
-- ============================================================================

--External Modules
local Utilities = require("Engine.RingInventory.Utilities")

--Pointer to tables

-- Ring Class - represents a single ring in the inventory
local Ring = {}
Ring.__index = Ring

-- Class Constants
local RING_POSITION_OFFSET = 1000
Ring.RING_RADIUS = (View.GetAspectRatio() > 1.7) and -512 or -450

Ring.TYPE =
{
	PUZZLE = 1,
    MAIN = 2,
	OPTIONS = 3,
	COMBINE = 4,
	AMMO = 5
}

-- Default center positions for different ring types
Ring.CENTERS = {
    [Ring.TYPE.PUZZLE] = Vec3(0, -800, 1024),
    [Ring.TYPE.MAIN] = Vec3(0, 200, 1024),
    [Ring.TYPE.OPTIONS] = Vec3(0, 1200, 1024),
    [Ring.TYPE.COMBINE] = Vec3(0, 300, 1024),
    [Ring.TYPE.AMMO] = Vec3(0, 300, 1024)
}

-- Constructor
function Ring.Create(ringType, centerPosition, inventory)
    local self = setmetatable({}, Ring)
    
    -- Instance variables
    self.type = ringType
    self.items = {}
    self.selectedItemIndex = 1
    self.position = centerPosition or Vec3(0, 0, 0)
    self.previousPosition = centerPosition or Vec3(0, 0, 0)
    self.slice = 0
    self.inventory = inventory  -- Reference to parent inventory
    
    self.currentAngle = 0
    self.previousAngle = 0
    self.targetAngle = 0
    
    return self
end

-- Static method: Get ring by type from inventory
function Ring.GetRingByType(ringType)
    if Ring.inventory then
        return Ring.inventory:GetRing(ringType)
    end
    return nil
end

-- Recalculate slice based on item count
function Ring:RecalculateSlice()
    if #self.items > 0 then
        self.slice = 360 / #self.items
    else
        self.slice = 0
    end
end

-- Add item to this ring
function Ring:AddItem(item)

    table.insert(self.items, item)
    self:RecalculateSlice()
end

-- Remove item by object ID
function Ring:RemoveItem(objectID)
    for i, item in ipairs(self.items) do
        if item.objectID == objectID then
            table.remove(self.items, i)
            -- Adjust selected index if needed
            if self.selectedItemIndex > #self.items then
                self.selectedItemIndex = math.max(1, #self.items)
            end
            self:RecalculateSlice()
            return true
        end
    end
    return false
end

-- Clear all items
function Ring:Clear()
    self.items = {}
    self.selectedItemIndex = 1
end

-- Get item by object ID
function Ring:GetItem(objectID)
    for _, item in ipairs(self.items) do
        if item.objectID == objectID then
            return item
        end
    end
    return nil
end

-- Get all items
function Ring:GetItems()
    return self.items
end

-- Get item count
function Ring:GetItemCount()
    return #self.items
end

-- Get selected item
function Ring:GetSelectedItem()
    if #self.items == 0 then return nil end
    return self.items[self.selectedItemIndex]
end

-- Set selected item by index
function Ring:SetSelectedItemIndex(index)
    if index >= 1 and index <= #self.items then
        self.selectedItemIndex = index
        return true
    end
    return false
end

-- Set selected item by object ID
function Ring:SetSelectedItemByID(objectID)
    for i, item in ipairs(self.items) do
        if item.objectID == objectID then
            self.selectedItemIndex = i
            return true
        end
    end
    return false
end

-- Get selected item index
function Ring:GetSelectedItemIndex()
    return self.selectedItemIndex
end

-- Navigate to next item
function Ring:SelectNext()
    if #self.items == 0 then return end
    self.selectedItemIndex = (self.selectedItemIndex % #self.items) + 1
end

-- Navigate to previous item
function Ring:SelectPrevious()
    if #self.items == 0 then return end
    self.selectedItemIndex = self.selectedItemIndex - 1
    if self.selectedItemIndex < 1 then
        self.selectedItemIndex = #self.items
    end
end

-- Set visibility for all items in this ring
function Ring:SetVisibility(visible)
    for i = 1, #self.items do
        local currentItem = self.items[i].objectID
        local inventoryItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        if inventoryItem then
            inventoryItem:SetVisible(visible)
        end
    end
end

-- Translate items in a circle
function Ring:Translate(center, radius, rotationOffset, alpha)
    alpha = alpha or 1.0
    center = center or self.position
    radius = radius or Ring.RING_RADIUS
    rotationOffset = rotationOffset or 0
    
    local itemCount = #self.items
    if itemCount == 0 then return end
    
    local ItemSpin  = require("Engine.RingInventory.ItemSpin")
    ItemSpin.Initialize(self.type, rotationOffset)

    for i = 1, itemCount do
        local currentItem = self.items[i].objectID
        local currentDisplayItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        if currentDisplayItem then
            local angleDeg = (360 / itemCount) * (i - 1) + rotationOffset
            local position = center:Translate(Rotation(0, angleDeg, 0), radius)
            currentDisplayItem:SetPosition(Utilities.OffsetY(position, self.items[i].yOffset))
        end
    end
end

-- Fade items (except optionally the selected one)
function Ring:Fade(fadeValue, omitItem)
    
    for i = 1, #self.items do
        local currentItem = self.items[i].objectID
        
        if omitItem and omitItem:GetObjectID() == currentItem then
            goto continue
        end
        
        local currentDisplayItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        if currentDisplayItem then
            local itemColor = currentDisplayItem:GetColor()
            currentDisplayItem:SetColor(Utilities.ColorCombine(itemColor, fadeValue))
        end
        
        ::continue::
    end
end

-- Color items (except optionally the selected one)
function Ring:Color(color, omitItem)
    
    for i = 1, #self.items do
        local currentItem = self.items[i].objectID
        
        if omitItem and omitItem.objectID == currentItem then
            goto continue
        end
        
        local currentDisplayItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        if currentDisplayItem then
            local itemColor = currentDisplayItem:GetColor()
            currentDisplayItem:SetColor(Utilities.ColorCombine(color, itemColor.a))
        end
        
        ::continue::
    end
end

-- Set ring position
function Ring:SetPosition(position)
    self.previousPosition = self.position 
    self.position = position
end

function Ring:OffsetPosition(direction)

    self.previousPosition = self.position 
    self.position = Vec3(self.previousPosition.x, self.previousPosition.y + direction * RING_POSITION_OFFSET, self.previousPosition.z)

end

-- Get ring position
function Ring:GetPosition()
    return self.position
end

-- Get ring position
function Ring:GetPreviousPosition()
    return self.previousPosition
end

-- Get ring type
function Ring:GetType()
    return self.type
end

-- Get another ring by type from the same inventory
function Ring:GetRingByType(ringType)
    if self.inventory then
        return self.inventory:GetRing(ringType)
    end
    return nil
end

-- Set slice value
function Ring:SetSlice(slice)
    self.slice = slice
end

-- Get slice value
function Ring:GetSlice()
    return self.slice
end

-- Get current angle
function Ring:GetCurrentAngle()
    return self.currentAngle
end

-- Set current angle
function Ring:SetCurrentAngle(angle)
    self.currentAngle = angle
end

-- Get previous angle
function Ring:GetPreviousAngle()
    return self.previousAngle
end

-- Get target angle
function Ring:GetTargetAngle()
    return self.targetAngle
end

-- Set target angle
function Ring:SetTargetAngle(angle)
    self.previousAngle = self.targetAngle
    self.targetAngle = angle
end

-- Calculate rotation angle
function Ring:CalculateRotation(direction)
    
    self.previousAngle = self.currentAngle
    self.targetAngle = self.currentAngle + direction * self.slice

end

-- Set all angles at once
function Ring:SetAngles(current, previous, target)
    if current ~= nil then self.currentAngle = current end
    if previous ~= nil then self.previousAngle = previous end
    if target ~= nil then self.targetAngle = target end
end

-- Get all angles at once
function Ring:GetAngles()
    return {
        current = self.currentAngle,
        previous = self.previousAngle,
        target = self.targetAngle
    }
end

-- Interpolate current angle towards target
function Ring:InterpolateAngle(alpha)
    alpha = alpha or 0.1
    self.previousAngle = self.currentAngle
    self.currentAngle = self.currentAngle + (self.targetAngle - self.currentAngle) * alpha
    return self.currentAngle
end

-- Check if angle has reached target
function Ring:IsAtTargetAngle(threshold)
    threshold = threshold or 0.1
    return math.abs(self.targetAngle - self.currentAngle) < threshold
end

-- Reset all angles to zero
function Ring:ResetAngles()
    self.currentAngle = 0
    self.previousAngle = 0
    self.targetAngle = 0
end

-- Check if ring is empty
function Ring:IsEmpty()
    return #self.items == 0
end

-- Find item index by object ID
function Ring:FindItemIndex(objectID)
    for i, item in ipairs(self.items) do
        if item.objectID == objectID then
            return i
        end
    end
    return nil
end

return Ring