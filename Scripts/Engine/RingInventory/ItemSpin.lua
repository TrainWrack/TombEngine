--External Modules
local InventoryData = require("Engine.RingInventory.InventoryData")

local ItemSpin = {}

ItemSpin.ROTATION_SPEED = 5
ItemSpin.ALIGNMENT_SPEED = 0.125
ItemSpin.ROTATION_THRESHOLD = 0.5

local enabled = true

ItemSpin.currentItem = nil
ItemSpin.ringName = nil
ItemSpin.rotationOffset = 0
ItemSpin.additionalItem = nil

function ItemSpin.Initialize(ringName, rotationOffset)
    ItemSpin.ringName = ringName
    ItemSpin.rotationOffset = rotationOffset or 0
end

local function CalculateRingAngle(itemIndex, itemCount, rotationOffset)
    return (360 / itemCount) * (itemIndex - 1) + rotationOffset
end

function ItemSpin.SetRotationOffset(offset)
    if ItemSpin.currentItem then
        ItemSpin.currentItem = nil
    end
    ItemSpin.rotationOffset = offset
end

function ItemSpin.StartSpin(item)
    ItemSpin.currentItem = item
    enabled = true
end

function ItemSpin.StopSpin()
    ItemSpin.currentItem = nil
    enabled = false
end

function ItemSpin.RotateItem(item)
    ItemSpin.additionalItem = item
end

function ItemSpin.StopItem()
    ItemSpin.additionalItem = nil
end

function ItemSpin.Update()

    if ItemSpin.additionalItem then 
        local displayItem = ItemSpin.additionalItem:GetDisplayItem()
        if displayItem then
            local currentRotation = displayItem:GetRotation()
            local newY = (currentRotation.y + ItemSpin.ROTATION_SPEED) % 360
            displayItem:SetRotation(Rotation(currentRotation.x, newY, currentRotation.z))
        end
    end

    if not enabled then
        return
    end

    if not ItemSpin.ringName then return end
    
    local ring = InventoryData.GetRing(ItemSpin.ringName)
    if not ring then return end
    
    local items = ring:GetItems()
    if not items then return end
    
    local itemCount = #items
    if itemCount == 0 then return end
    
    for i = 1, itemCount do
        local item = items[i]
        if item and item.objectID then

            local displayItem = item:GetDisplayItem()
            
            if displayItem then
                local targetAngle = CalculateRingAngle(i, itemCount, ItemSpin.rotationOffset)
                local currentRotation = displayItem:GetRotation()
                
                if item == ItemSpin.currentItem then
                    local newY = (currentRotation.y + ItemSpin.ROTATION_SPEED) % 360
                    displayItem:SetRotation(Rotation(currentRotation.x, newY, currentRotation.z))
                else
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

function ItemSpin.GetCurrentItem()
    return ItemSpin.currentItem
end

function ItemSpin.IsSpinning(item)
    return ItemSpin.currentItem == item
end

function ItemSpin.Reset()
    ItemSpin.currentItem = nil
    ItemSpin.ringName = nil
    ItemSpin.rotationOffset = 0
    enabled = true
end

return ItemSpin