-- ============================================================================
-- ItemLighting Module - Handles item color/lighting animations
-- ============================================================================

--External Modules
local Animation = require("Engine.CustomInventory.Animation")

--Begin Class
local ItemLighting = {}

--Constants
local FADE_SPEED = 0.1  -- Color interpolation speed
local COLOR_VISIBLE = Color(255, 255, 255, 255)  -- Bright/highlighted
local COLOR_NORMAL = Color(255, 255, 255, 100)   -- Normal/dimmed

-- State tracking
ItemLighting.currentItem = nil
ItemLighting.items = {}  -- Store item data: { originalColor, targetColor, isFadingIn, isFadingOut }

--- Start lighting up an item (fade to visible)
function ItemLighting.FadeIn(itemID)
    local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(itemID))
    if not displayItem then return end
    
    -- Stop previous item if exists
    if ItemLighting.currentItem and ItemLighting.currentItem ~= itemID then
        ItemLighting.FadeOut(ItemLighting.currentItem)
    end
    
    -- Initialize item data if not exists
    if not ItemLighting.items[itemID] then
        ItemLighting.items[itemID] = {
            originalColor = displayItem:GetColor(),
            targetColor = ItemLighting.COLOR_VISIBLE,
            isFadingIn = false,
            isFadingOut = false
        }
    end
    
    -- Start fading in
    ItemLighting.items[itemID].isFadingIn = true
    ItemLighting.items[itemID].isFadingOut = false
    ItemLighting.items[itemID].targetColor = ItemLighting.COLOR_VISIBLE
    ItemLighting.currentItem = itemID
end

--- Start fading out an item (fade to original color)
function ItemLighting.FadeOut(itemID)
    if not ItemLighting.items[itemID] then return end
    
    local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(itemID))
    if not displayItem then
        ItemLighting.items[itemID] = nil
        return
    end
    
    -- Start fading out
    ItemLighting.items[itemID].isFadingIn = false
    ItemLighting.items[itemID].isFadingOut = true
    ItemLighting.items[itemID].targetColor = ItemLighting.items[itemID].originalColor
end

--- Update all fading items
function ItemLighting.Update()
    for itemID, data in pairs(ItemLighting.items) do
        local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(itemID))
        
        if not displayItem then
            -- Clean up if item no longer exists
            ItemLighting.items[itemID] = nil
            if ItemLighting.currentItem == itemID then
                ItemLighting.currentItem = nil
            end
        else
            -- Handle fading in or out
            if data.isFadingIn or data.isFadingOut then
                local currentColor = displayItem:GetColor()
                local targetColor = Animation.Interpolate.Lerp(currentColor, data.targetColor, FADE_SPEED)
                displayItem:SetColor(targetColor)
                
                -- Check if fade is complete (simple threshold check)
                local threshold = 2
                if math.abs(targetColor.r - currentColor.r) < threshold and
                   math.abs(targetColor.g - currentColor.g) < threshold and
                   math.abs(targetColor.b - currentColor.b) < threshold and
                   math.abs(targetColor.a - currentColor.a) < threshold then
                    -- Snap to exact target
                    displayItem:SetColor(data.targetColor)
                    
                    -- Clean up if fading out is complete
                    if data.isFadingOut then
                        ItemLighting.items[itemID] = nil
                        if ItemLighting.currentItem == itemID then
                            ItemLighting.currentItem = nil
                        end
                    else
                        -- Just mark as complete if fading in
                        data.isFadingIn = false
                    end
                end
            end
        end
    end
end

--- Get current lit item
function ItemLighting.GetCurrentItem()
    return ItemLighting.currentItem
end

--- Check if an item is fading in
function ItemLighting.IsFadingIn(itemID)
    return ItemLighting.items[itemID] and ItemLighting.items[itemID].isFadingIn
end

--- Check if an item is fading out
function ItemLighting.IsFadingOut(itemID)
    return ItemLighting.items[itemID] and ItemLighting.items[itemID].isFadingOut
end

--- Clean up all items and reset module
function ItemLighting.Reset()
    ItemLighting.currentItem = nil
    ItemLighting.items = {}
end

return ItemLighting