local Settings = require("Engine.RingInventory.Settings")
local Interpolate = require("Engine.RingInventory.Interpolate")

local ItemSpin = {}

ItemSpin.ROTATION_SPEED = 5
ItemSpin.ALIGNMENT_SPEED = Settings.ANIMATION.ITEM_ANIM_TIME

ItemSpin.rings = {}
ItemSpin.itemStates = {}  -- { [objectID] = { startAngle, angleDiff, lastTarget } }

--- Initialize spinning for a ring
function ItemSpin.Initialize(ring)
    if not ring then return end

    local ringName = ring:GetType()

    if not ItemSpin.rings[ringName] then
        ItemSpin.rings[ringName] = {
            enabled = true,
            selectedItemEnabled = true,
            ring = ring
        }
    else
        ItemSpin.rings[ringName].enabled = true
        ItemSpin.rings[ringName].selectedItemEnabled = true
    end
end

local function CalculateRingAngle(itemIndex, itemCount, ringAngle)
    return (360 / itemCount) * (itemIndex - 1) + ringAngle
end

--- Start spinning for a ring
function ItemSpin.StartSpin(ring)
    if not ring then return end
    ItemSpin.Initialize(ring)
    local ringName = ring:GetType()
    ItemSpin.rings[ringName].enabled = true
end

--- Stop spinning for a ring
function ItemSpin.StopSpin(ring)
    if not ring then return end
    local ringName = ring:GetType()
    if ItemSpin.rings[ringName] then
        ItemSpin.rings[ringName].enabled = false
    end
end

--- Start spinning the selected item
function ItemSpin.StartSelectedItemSpin(ring)
    if not ring then return end
    local ringName = ring:GetType()
    if ItemSpin.rings[ringName] then
        ItemSpin.rings[ringName].selectedItemEnabled = true
    end
end

--- Stop spinning the selected item
function ItemSpin.StopSelectedItemSpin(ring)
    if not ring then return end
    local ringName = ring:GetType()
    if ItemSpin.rings[ringName] then
        ItemSpin.rings[ringName].selectedItemEnabled = false
    end
end

--- Update all spinning items - call once per frame
function ItemSpin.Update()
    for _, ringState in pairs(ItemSpin.rings) do
        if ringState.enabled then
            ItemSpin.UpdateRing(ringState)
        end
    end
end

--- Update spinning for a single ring
function ItemSpin.UpdateRing(ringState)
    local ring = ringState.ring
    if not ring then return end

    local items = ring:GetItems()
    if not items or #items == 0 then return end

    local selectedItem = ring:GetSelectedItem()
    local ringAngle = ring:GetTargetAngle()
    local itemCount = #items

    for i = 1, itemCount do
        local item = items[i]
        if item and item.objectID then
            local displayItem = item:GetDisplayItem()
            if displayItem then
                local currentRotation = displayItem:GetRotation()
                local id = item:GetObjectID()
                local spinKey = "Spin"..id

                if selectedItem and item == selectedItem then
                    -- Clear state and interpolation so next deselection starts fresh
                    ItemSpin.itemStates[id] = nil
                    Interpolate.Clear(spinKey)

                    -- Selected item spins continuously
                    if ringState.selectedItemEnabled then
                        local newY = (currentRotation.y + ItemSpin.ROTATION_SPEED) % 360
                        displayItem:SetRotation(Rotation(currentRotation.x, newY, currentRotation.z))
                    end
                else
                    local targetAngle = CalculateRingAngle(i, itemCount, ringAngle)

                    -- Initialize state on first frame
                    if not ItemSpin.itemStates[id] then
                        local angleDiff = (targetAngle - currentRotation.y) % 360
                        if angleDiff > 180 then angleDiff = angleDiff - 360 end
                        ItemSpin.itemStates[id] = {
                            startAngle = currentRotation.y,
                            angleDiff = angleDiff,
                            lastTarget = targetAngle
                        }
                    end

                    local state = ItemSpin.itemStates[id]

                    -- If target changed (ring rotated), restart from current position
                    if math.abs(targetAngle - state.lastTarget) > 0.1 then
                        local angleDiff = (targetAngle - currentRotation.y) % 360
                        if angleDiff > 180 then angleDiff = angleDiff - 360 end
                        state.startAngle = currentRotation.y
                        state.angleDiff = angleDiff
                        state.lastTarget = targetAngle
                        Interpolate.Clear(spinKey)
                    end

                    -- Use Interpolate for progress tracking and easing
                    local result = Interpolate.Calculate(spinKey, 0, 1, ItemSpin.ALIGNMENT_SPEED, Interpolate.Easing.Smoothstep)

                    local newAngle = state.startAngle + state.angleDiff * result.output
                    displayItem:SetRotation(Rotation(currentRotation.x, newAngle, currentRotation.z))
                end
            end
        end
    end
end

--- Check if a ring is currently spinning
function ItemSpin.IsSpinning(ring)
    if not ring then return false end
    local ringName = ring:GetType()
    local ringState = ItemSpin.rings[ringName]
    return ringState and ringState.enabled
end

--- Reset all spinning state
function ItemSpin.Reset()
    ItemSpin.rings = {}
    ItemSpin.itemStates = {}
end

return ItemSpin
