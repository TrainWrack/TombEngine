
local SpinBack = {}

SpinBack.items = {}  -- Track rotations for spinback

SpinBack.SPEED = .125

function SpinBack.Start(itemID, rotation)
    local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(itemID))
    if displayItem then
        SpinBack.items[itemID] = {
            current = displayItem:GetRotation(),
            target = rotation,
            isActive = true
        }
    end
end

function SpinBack.Update()
    for itemID, spinback in pairs(SpinBack.items) do
        if spinback.isActive then
            local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(itemID))
            if displayItem then
                local current = spinback.current
                local target = spinback.target
                
                -- Smooth interpolation
                local newX = current.x + (target.x - current.x) * SpinBack.SPEED
                local newY = current.y + (target.y - current.y) * SpinBack.SPEED
                local newZ = current.z + (target.z - current.z) * SpinBack.SPEED
                
                spinback.current = Rotation(newX, newY, newZ)
                displayItem:SetRotation(spinback.current)
                
                -- Check if close enough to target
                local threshold = 0.5
                if math.abs(target.x - newX) < threshold and
                   math.abs(target.y - newY) < threshold and
                   math.abs(target.z - newZ) < threshold then
                    displayItem:SetRotation(target)
                    spinback.isActive = false
                end
            else
                spinback.isActive = false
            end
        end
    end
end

return SpinBack