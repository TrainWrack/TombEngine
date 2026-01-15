-- ============================================================================
-- Combine - Handles combine functions and data for ring inventory
-- ============================================================================

--Pointers to tables
local PICKUP_DATA = require("Engine.CustomInventory.PickupData")
local TYPE = PICKUP_DATA.TYPE

--Combine functions
local Combine = {}

--Variables
Combine.performCombine = false
Combine.result = nil

function Combine.PerformWaterskinCombine(flag)
    local smallRaw = Lara:GetWaterSkinStatus(false)
    local bigRaw = Lara:GetWaterSkinStatus(true)
    
    local smallLiters = (smallRaw > 0) and (smallRaw - 1) or 0
    local bigLiters = (bigRaw > 0) and (bigRaw - 1) or 0
    
    local smallCapacity = 3 - smallLiters
    local bigCapacity = 5 - bigLiters
    
    if flag then
        if bigRaw > 1 and smallCapacity > 0 then
            local transfer = math.min(bigLiters, smallCapacity)
            smallLiters = smallLiters + transfer
            bigLiters = bigLiters - transfer
            
            Lara:SetWaterSkinStatus(smallLiters + 1, false)
            Lara:SetWaterSkinStatus(bigLiters + 1, true)
            
            Combine.result = (smallLiters + 1) + (TEN.Objects.ObjID.WATERSKIN1_EMPTY - 1)
            return true
        end
    else
        if smallRaw > 1 and bigCapacity > 0 then
            local transfer = math.min(smallLiters, bigCapacity)
            bigLiters = bigLiters + transfer
            smallLiters = smallLiters - transfer
            
            Lara:SetWaterSkinStatus(smallLiters + 1, false)
            Lara:SetWaterSkinStatus(bigLiters + 1, true)
            
            Combine.result = (bigLiters + 1) + (TEN.Objects.ObjID.WATERSKIN2_EMPTY - 1)
            return true
        end
    end
    
    return false
end

function Combine.CombineItems(data1, data2)
    
    local item1 = data1.objectID
    local item2 = data2.objectID
    
    if data1.type == TYPE.WATERSKIN and data2.type == TYPE.WATERSKIN then
        if (item1 >= TEN.Objects.ObjID.WATERSKIN1_EMPTY and
            item1 <= TEN.Objects.ObjID.WATERSKIN1_3 and
            item2 >= TEN.Objects.ObjID.WATERSKIN2_EMPTY and
            item2 <= TEN.Objects.ObjID.WATERSKIN2_5) then
            if (Combine.PerformWaterskinCombine(false)) then
                return true
            end
        elseif(item2 >= TEN.Objects.ObjID.WATERSKIN1_EMPTY and
            item2 <= TEN.Objects.ObjID.WATERSKIN1_3 and
            item1 >= TEN.Objects.ObjID.WATERSKIN2_EMPTY and
            item1 <= TEN.Objects.ObjID.WATERSKIN2_5) then
            if (Combine.PerformWaterskinCombine(true)) then
                return true
            end
        end
    end
    
    for _, combo in ipairs(PICKUP_DATA.combineTable) do
        local a, b, result = combo[1], combo[2], combo[3]
        
        if (item1 == a and item2 == b) or (item1 == b and item2 == a) then
            local count1 = TEN.Inventory.GetItemCount(item1)
            local count2 = TEN.Inventory.GetItemCount(item2)
            
            if count1 == 0 or count2 == 0 then
                return false
            end
            
            if PICKUP_DATA.WEAPON_LASERSIGHT_DATA[result] and
               PICKUP_DATA.WEAPON_SET[result] and
               PICKUP_DATA.WEAPON_SET[result].slot then
                Lara:SetLaserSight(PICKUP_DATA.WEAPON_SET[result].slot, true)
            end
            
            TEN.Inventory.TakeItem(item1, 1)
            TEN.Inventory.TakeItem(item2, 1)
            TEN.Inventory.GiveItem(result, 1)
            
            Combine.result = result
            return true
        end
    end
    
    return false
end

function Combine.SeparateItems(item3)
    for _, combo in ipairs(PICKUP_DATA.combineTable) do
        local a, b, result = combo[1], combo[2], combo[3]
        
        if item3 == result then
            local count = TEN.Inventory.GetItemCount(item3)
            
            if count == 0 then
                return false
            end
            
            if PICKUP_DATA.WEAPON_LASERSIGHT_DATA[result] and
               PICKUP_DATA.WEAPON_SET[result] and
               PICKUP_DATA.WEAPON_SET[result].slot then
                Lara:SetLaserSight(PICKUP_DATA.WEAPON_SET[result].slot, false)
            end
            
            TEN.Inventory.TakeItem(item3, 1)
            TEN.Inventory.GiveItem(a, 1)
            TEN.Inventory.GiveItem(b, 1)
            
            Combine.result = a
            return true
        end
    end
    
    return false
end

return Combine