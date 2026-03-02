--External Modules
local InventoryData = require("Engine.RingInventory.InventoryData")

local ItemSpin = {}

ItemSpin.ROTATION_SPEED = 5
ItemSpin.ALIGNMENT_SPEED = 0.125
ItemSpin.ROTATION_THRESHOLD = 0.5

-- Track spinning per ring: { ringName = { enabled, rotationOffset } }
ItemSpin.rings = {}

-- Additional item for manual rotation
ItemSpin.additionalItem = nil

--- Initialize spinning for a ring
-- @param ringName: The ring type/name to spin items for
-- @param rotationOffset: Optional rotation offset for ring positioning
function ItemSpin.Initialize(ringName, rotationOffset)
    if not ringName then return end
    
    if not ItemSpin.rings[ringName] then
        ItemSpin.rings[ringName] = {
            enabled = true,
            selectedItemEnabled = true,
            rotationOffset = rotationOffset or 0
        }
    else
        ItemSpin.rings[ringName].rotationOffset = rotationOffset or 0
    end
end

local function CalculateRingAngle(itemIndex, itemCount, rotationOffset)
    return (360 / itemCount) * (itemIndex - 1) + rotationOffset
end

--- Set rotation offset for a ring
function ItemSpin.SetRotationOffset(ringName, offset)
    if not ringName then return end
    
    if ItemSpin.rings[ringName] then
        ItemSpin.rings[ringName].rotationOffset = offset
    end
end

--- Start spinning the selected item in a ring
function ItemSpin.StartSpin(ringName)
    if not ringName then return end
    ItemSpin.Initialize(ringName)
    ItemSpin.rings[ringName].enabled = true
end

--- Stop spinning for a ring
function ItemSpin.StopSpin(ringName)
    if not ringName then return end
    
    if ItemSpin.rings[ringName] then
        ItemSpin.rings[ringName].enabled = false
    end
end

function ItemSpin.StartSelectedItemSpin(ringName)
    if not ringName then return end
    
    if ItemSpin.rings[ringName] then
        ItemSpin.rings[ringName].selectedItemEnabled = true
    end
end

--- Stop spinning for a ring
function ItemSpin.StopSelectedItemSpin(ringName)
    if not ringName then return end
    
    if ItemSpin.rings[ringName] then
        ItemSpin.rings[ringName].selectedItemEnabled = false
    end
end

--- Rotate an additional item (independent of rings)
function ItemSpin.RotateItem(item)
    ItemSpin.additionalItem = item
end

--- Stop rotating the additional item
function ItemSpin.StopItem()
    ItemSpin.additionalItem = nil
end

--- Update all spinning items
function ItemSpin.Update()
    -- Update additional item (manual rotation)
    if ItemSpin.additionalItem then 
        local displayItem = ItemSpin.additionalItem:GetDisplayItem()
        if displayItem then
            local currentRotation = displayItem:GetRotation()
            local newY = (currentRotation.y + ItemSpin.ROTATION_SPEED) % 360
            displayItem:SetRotation(Rotation(currentRotation.x, newY, currentRotation.z))
        end
    end

    -- Update all rings
    for ringName, ringState in pairs(ItemSpin.rings) do
        if ringState.enabled then
            ItemSpin.UpdateRing(ringName, ringState)
        end
    end
end

--- Update spinning for a specific ring
function ItemSpin.UpdateRing(ringName, ringState)
    local ring = InventoryData.GetRing(ringName)
    if not ring then return end
    
    local items = ring:GetItems()
    if not items or #items == 0 then return end
    
    local selectedItem = ring:GetSelectedItem()
    local itemCount = #items
    
    for i = 1, itemCount do
        local item = items[i]
        if item and item.objectID then
            local displayItem = item:GetDisplayItem()
            
            if displayItem then
                local targetAngle = CalculateRingAngle(i, itemCount, ringState.rotationOffset)
                local currentRotation = displayItem:GetRotation()
                
                -- Rotate selected item, align others to their target positions
                if selectedItem and item == selectedItem then
                    -- Selected item spins continuously
                    if ringState.selectedItemEnabled then
                    local newY = (currentRotation.y + ItemSpin.ROTATION_SPEED) % 360
                    displayItem:SetRotation(Rotation(currentRotation.x, newY, currentRotation.z))
                    end
                else
                    -- Non-selected items align to their target angle
                    local currentAngle = currentRotation.y
                    local angleDiff = (targetAngle - currentAngle) % 360
                    if angleDiff > 180 then
                        angleDiff = angleDiff - 360
                    end
                    local newAngle = (currentAngle + angleDiff * ItemSpin.ALIGNMENT_SPEED) % 360
                    displayItem:SetRotation(Rotation(currentRotation.x, newAngle, currentRotation.z))
                end
            end
        end
    end
end

--- Get the currently spinning selected item for a ring
function ItemSpin.GetCurrentItem(ringName)
    if not ringName then return nil end
    
    local ring = InventoryData.GetRing(ringName)
    if ring then
        return ring:GetSelectedItem()
    end
    return nil
end

--- Check if a ring is currently spinning
function ItemSpin.IsSpinning(ringName)
    if not ringName then return false end
    
    local ringState = ItemSpin.rings[ringName]
    return ringState and ringState.enabled
end

--- Reset all spinning state
function ItemSpin.Reset()
    ItemSpin.rings = {}
    ItemSpin.additionalItem = nil
end

return ItemSpin
