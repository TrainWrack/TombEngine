-- ============================================================================
-- ItemSpin Module - Handles item rotation animations for ring inventory
-- ============================================================================

--External Modules
local InventoryData = require("Engine.RingInventory.InventoryData")
local InventoryItem = require("Engine.RingInventory.InventoryItem")

local ItemSpin = {}

-- Configuration
ItemSpin.ROTATION_SPEED = 5  -- Degrees per frame for spinning item
ItemSpin.ALIGNMENT_SPEED = 0.125  -- Interpolation speed for aligning to ring angle
ItemSpin.ROTATION_THRESHOLD = 0.5  -- Threshold for considering rotation complete

-- State tracking
ItemSpin.currentItem = nil
ItemSpin.ringName = nil  -- Which ring we're managing
ItemSpin.rotationOffset = 0  -- Current ring rotation offset

--- Initialize the spin module with a ring
function ItemSpin.Initialize(ringName, rotationOffset)
    ItemSpin.ringName = ringName
    ItemSpin.rotationOffset = rotationOffset or 0
end

--- Calculate the target angle for an item in the ring
local function CalculateRingAngle(itemIndex, itemCount, rotationOffset)
    return (360 / itemCount) * (itemIndex - 1) + rotationOffset
end

--- Update ring rotation offset (called when ring translates)
function ItemSpin.SetRotationOffset(offset)
    -- If there's a currently spinning item, stop it and start return
    if ItemSpin.currentItem then
        local previousItem = ItemSpin.currentItem
        ItemSpin.currentItem = nil
        -- Item will automatically start aligning to new angle in Update()
    end
    
    ItemSpin.rotationOffset = offset
end

--- Start spinning an item
function ItemSpin.StartSpin(itemID)
    -- Stop previous item (it will auto-align in Update)
    ItemSpin.currentItem = itemID
end

--- Update all item rotations
function ItemSpin.Update()
    if not ItemSpin.ringName then return end
    
    local ring = InventoryData.GetRing(ItemSpin.ringName)
    if not ring then return end
    
    local itemCount = #ring
    
    for i = 1, itemCount do
        local currentItem = ring[i]:GetObjectID()
        local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        
        if displayItem then
            local targetAngle = CalculateRingAngle(i, itemCount, ItemSpin.rotationOffset)
            local currentRotation = displayItem:GetRotation()
            
            -- Current spinning item - continuous rotation
            if currentItem == ItemSpin.currentItem then
                local newY = (currentRotation.y + ItemSpin.ROTATION_SPEED) % 360
                displayItem:SetRotation(Rotation(currentRotation.x, newY, currentRotation.z))
            else
                -- All other items - align to ring angle
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

--- Get current spinning item
function ItemSpin.GetCurrentItem()
    return ItemSpin.currentItem
end

--- Check if an item is spinning
function ItemSpin.IsSpinning(itemID)
    return ItemSpin.currentItem == itemID
end

--- Clean up and reset module
function ItemSpin.Reset()
    ItemSpin.currentItem = nil
    ItemSpin.ringName = nil
    ItemSpin.rotationOffset = 0
end

return ItemSpin

