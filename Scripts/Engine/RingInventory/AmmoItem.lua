-- ============================================================================
-- AmmoItem - Handles selected Ammo item
-- ============================================================================

--External Modules
local Animation = require("Engine.RingInventory.Animation")
local InventoryData = require("Engine.RingInventory.InventoryData")
local PickupData = require("Engine.RingInventory.PickupData")
local Settings = require("Engine.RingInventory.Settings")
local Text = require("Engine.RingInventory.Text")



--Begin Class
local AmmoItem = {}

--Constants
local FADE_SPEED = 0.1  -- Color interpolation speed
local COLOR_VISIBLE = Color(255, 255, 255, 255)  -- Bright/highlighted
local COLOR_HIDDEN = Color(255, 255, 255, 0)   -- Normal/dimmed
local AMMO_LOCATION = Vec3(0, 300, 512)

local RingInventory = InventoryData.Get("RingInventory")

local function GetChosenAmmo(weaponItem)

    local itemObjectID = weaponItem:GetObjectID()
    local weaponSlot = PickupData.WEAPON_SET[itemObjectID].slot
    if not itemObjectID then
        return
    end

    local ammoType = Lara:GetAmmoType(weaponSlot)
    if not ammoType then
        return
    end
    
    local objectID = PickupData.AMMO_TYPE_TO_OBJECT[ammoType]
    if not objectID then return end
    
    local item = RingInventory:FindItem(objectID)
    
    return item

end

-- State tracking
AmmoItem.currentItem = nil
AmmoItem.item = nil  -- Store item data: { originalColor, targetColor, isFadingIn, isFadingOut }

--- Start showing up an item (fade to visible)
function AmmoItem.FadeIn(weaponItem)

    local data = GetChosenAmmo(weaponItem)

    if not data then
        return
    end

    local itemID = data:GetObjectID()
    local displayItem = itemID and TEN.View.DisplayItem("ChosenAmmo", itemID, AMMO_LOCATION, data:GetRotation(), Vec3(data:GetScale()), data:GetMeshBits())
    displayItem:SetColor(COLOR_HIDDEN)

    -- Initialize item data if not exists
    if not AmmoItem.item then

        AmmoItem.item = {
            originalColor = displayItem:GetColor(),
            targetColor = COLOR_VISIBLE,
            isFadingIn = false,
            isFadingOut = false,
        }

    end
    
    -- Start fading in
    AmmoItem.item.isFadingIn = true
    AmmoItem.item.isFadingOut = false
    AmmoItem.item.targetColor = COLOR_VISIBLE
    AmmoItem.currentItem = itemID

end

--- Start fading out an item (fade to original color)
function AmmoItem.FadeOut()
    if not AmmoItem.item then return end
    
    local displayItem = TEN.View.DisplayItem.GetItemByName("ChosenAmmo")
    
    if not displayItem then
        AmmoItem.item = nil
        return
    end
    
    -- Start fading out
    AmmoItem.item.isFadingIn = false
    AmmoItem.item.isFadingOut = true
    AmmoItem.item.targetColor = AmmoItem.item.originalColor
end

--- Update all fading items
function AmmoItem.Update()
   
    local displayItem = TEN.View.DisplayItem.GetItemByName("ChosenAmmo")
    
    if not displayItem then
        -- Clean up if item no longer exists
        AmmoItem.item = nil
        AmmoItem.currentItem = nil
    else
        -- Handle fading in or out
        if AmmoItem.item.isFadingIn or AmmoItem.item.isFadingOut then
            local currentColor = displayItem:GetColor()
            local targetColor = Animation.Interpolate.Lerp(currentColor, AmmoItem.item.targetColor, FADE_SPEED)
            displayItem:SetColor(targetColor)
            
            -- Check if fade is complete (simple threshold check)
            local threshold = 2
            if math.abs(targetColor.r - currentColor.r) < threshold and
                math.abs(targetColor.g - currentColor.g) < threshold and
                math.abs(targetColor.b - currentColor.b) < threshold and
                math.abs(targetColor.a - currentColor.a) < threshold then
                -- Snap to exact target
                displayItem:SetColor(AmmoItem.item.targetColor)
                
                -- Clean up if fading out is complete
                if AmmoItem.item.isFadingOut then
                    AmmoItem.item = nil
                    AmmoItem.currentItem = nil
                else
                    -- Just mark as complete if fading in
                    AmmoItem.item.isFadingIn = false
                end
            end
        end


        --Rotate selected ammo
        if AmmoItem.item then
            local itemRotations = displayItem:GetRotation()
            displayItem:SetRotation(Rotation(itemRotations.x, (itemRotations.y + Settings.ANIMATION.ROTATION_SPEED) % 360, itemRotations.z))
        end

    end

end

--- Get current lit item
function AmmoItem.GetCurrentItem()
    return AmmoItem.currentItem
end

--- Check if an item is fading in
function AmmoItem.IsFadingIn()
    return AmmoItem.item and AmmoItem.item.isFadingIn
end

--- Check if an item is fading out
function AmmoItem.IsFadingOut()
    return AmmoItem.item and AmmoItem.item.isFadingOut
end

--- Clean up all items and reset module
function AmmoItem.Reset()
    AmmoItem.currentItem = nil
    AmmoItem.item = nil
end

return AmmoItem