--Pointers to tables
local PICKUP_DATA = require("Engine.CustomInventory.PickupData")
local TYPE = PICKUP_DATA.TYPE
local RING = PICKUP_DATA.RING
local RING_CENTER = PICKUP_DATA.RING_CENTER
local INVENTORY_MODE = PICKUP_DATA.INVENTORY_MODE
local SOUND_MAP = Settings.SOUND_MAP
local COLOR_MAP = Settings.COLOR_MAP
local ANIMATION = Settings.ANIMATION

--Structure for inventory
local inventory = {}

inventory.ring = {}
inventory.slice = {}
inventory.selectedRing = RING.MAIN
inventory.previousRing = nil
inventory.selectedItem = {}
inventory.ringPosition = {}
inventory.chosenItem = nil
inventory.openAtItem = nil
inventory.gameflowOverrides = nil

local function ConstructObjectList(ringType, selectedWeapon)
    local items = PICKUP_DATA.CONSTANTS
    
    if ringType == RING.AMMO or ringType == RING.COMBINE then
        ClearInventory(ringType, true)
    else
        ClearInventory()
    end
    
    for _, itemRow in ipairs(items) do
        local itemData = PICKUP_DATA.ConvertRowData(itemRow)
        local data = BuildInventoryItem(itemData)
        data.rotation = Utilities.CopyRotation(data.rotation)
        
        if data.type == TYPE.AMMO and ringType ~= RING.AMMO then
            local weaponPresent = TEN.Inventory.GetItemCount(PICKUP_DATA.AMMO_SET[data.objectID].weapon)
            if weaponPresent ~= 0 then
                goto continue
            end
        end
        
        if data.type == TYPE.WEAPON then
            if Lara:GetLaserSight(PICKUP_DATA.WEAPON_SET[data.objectID].slot) then
                data.meshBits = PICKUP_DATA.WEAPON_LASERSIGHT_DATA[data.objectID].MESHBITS
                data.name = PICKUP_DATA.WEAPON_LASERSIGHT_DATA[data.objectID].NAME
                data.menuActions = PICKUP_DATA.WEAPON_LASERSIGHT_DATA[data.objectID].FLAGS
            end
        end
        
        local ammoRing = false
        local shouldInsert = false
        
        if ringType == RING.COMBINE then
            if data.combine == true then
                data.ringName = RING.COMBINE
                
                if combineItem1 == data.objectID then
                    goto continue
                end
                
                if data.type == TYPE.WEAPON and Lara:GetLaserSight(PICKUP_DATA.WEAPON_SET[data.objectID].slot) then
                    goto continue
                end
                
                shouldInsert = (data.count ~= 0)
            else
                goto continue
            end
        elseif ringType == RING.AMMO then
            if data.type == TYPE.AMMO and PICKUP_DATA.WEAPON_AMMO_LOOKUP[selectedWeapon] and Utilities.Contains(PICKUP_DATA.WEAPON_AMMO_LOOKUP[selectedWeapon], data.objectID) then
                data.ringName = RING.AMMO
                ammoRing = true
                shouldInsert = true
            else
                goto continue
            end
        else
            shouldInsert = (data.count ~= 0)
        end
        
        if (data.objectID == TEN.Objects.ObjID.LASERSIGHT_ITEM) then
            if Lara:GetLaserSight(TEN.Objects.WeaponType.CROSSBOW) or 
               Lara:GetLaserSight(TEN.Objects.WeaponType.REVOLVER) or 
               Lara:GetLaserSight(TEN.Objects.WeaponType.HK) then
                shouldInsert = false
            end
        end
        
        inventory.ring[data.ringName] = inventory.ring[data.ringName] or {}
        
        if debug then
            print("Item: "..Util.GetObjectIDString(data.objectID))
            print("shouldInsert: "..tostring(shouldInsert))
            print("ammoRing: "..tostring(ammoRing))
        end
        
        if shouldInsert or ammoRing then
            table.insert(inventory.ring[data.ringName], data)
            local inventoryItem = TEN.View.DisplayItem(
                tostring(data.objectID),
                data.objectID,
                RING_CENTER[data.ringName],
                data.rotation,
                Vec3(data.scale),
                data.meshBits
            )
            inventoryItem:SetColor(COLOR_MAP.ITEM_COLOR)
        end
        
        ::continue::
    end
    
    if ringType then
        local ringItems = inventory.ring[ringType] or {}
        local count = #ringItems
        inventory.selectedItem[ringType] = 1
        inventory.slice[ringType] = (count > 0) and (360 / count) or 0
        inventory.ringPosition[ringType] = RING_CENTER[ringType]
    else
        for index, ringItems in pairs(inventory.ring) do
            local count = #ringItems
            inventory.selectedItem[index] = 1
            inventory.slice[index] = (count > 0) and (360 / count) or 0
            inventory.ringPosition[index] = RING_CENTER[index]
        end
    end
end

local function OpenInventoryAtItem(itemID, repositionRings)
    if itemID == NO_VALUE then
        return
    end
    
    local ringIndex, itemIndex = FindItemInInventory(itemID)
    
    if not (ringIndex and itemIndex) then
        return
    end
    
    inventory.selectedItem[ringIndex] = itemIndex
    local slice = inventory.slice[ringIndex]
    local angle = -slice * (itemIndex - 1)
    currentRingAngle = angle
    targetRingAngle = angle
    
    if repositionRings then
        local ringPosition = RING_CENTER[RING.MAIN]
        selectedRing = ringIndex
        
        for index in pairs(inventory.ring) do
            local offset = (index - selectedRing) * RING_POSITION_OFFSET
            inventory.ringPosition[index] = Vec3(ringPosition.x, ringPosition.y + offset, ringPosition.z)
            TranslateRing(index, inventory.ringPosition[index], RING_RADIUS, angle)
        end
    end
    
    if itemID == TEN.Objects.ObjID.PC_SAVE_INV_ITEM or itemID == TEN.Objects.ObjID.PC_LOAD_INV_ITEM then
        if itemID == TEN.Objects.ObjID.PC_SAVE_INV_ITEM then
            saveList = true
        end
        saveSelected = true
    end
end

local function SetupSecondaryRing(ringName, item)
    previousRing = selectedRing
    combineItem1 = item or GetSelectedItem(selectedRing).objectID
    targetRingAngle = 0
    currentRingAngle = 0
    ConstructObjectList(ringName, combineItem1)
    selectedRing = ringName
    inventory.ringPosition[ringName] = RING_CENTER[ringName]
    
    if ringName == RING.AMMO then
        local weaponSlot = PICKUP_DATA.WEAPON_SET[combineItem1].slot
        local ammoType = Lara:GetAmmoType(weaponSlot)
        local objectID = PICKUP_DATA.AMMO_TYPE_TO_OBJECT[ammoType]
        OpenInventoryAtItem(objectID, false)
    end
end



local function FindItemInInventory(targetID)
    for ringIndex, ring in pairs(inventory.ring) do
        for itemIndex, itemEntry in ipairs(ring) do
            if itemEntry.objectID == targetID then
                return ringIndex, itemIndex
            end
        end
    end
    return nil, nil
end

local function GetInventoryItem(itemID)
    local ringIndex, itemIndex = FindItemInInventory(itemID)
    if not ringIndex or not itemIndex then
        return nil
    end
    return inventory.ring[ringIndex][itemIndex]
end

local function ReadGameflow()
    local overrides = {}
    for _, itemID in ipairs(TEN.Flow.GetCurrentLevel().objects) do
        if itemID.objectID then
            local id = TEN.Inventory.ConvertInventoryItemToObject(itemID.objectID)
            overrides[id] = { 
                item = id,
                yOffset = itemID.yOffset,
                scale = itemID.scale,
                rotation = itemID.rotation,
                menuActions = itemID.action,
                name = itemID.nameKey,
                meshBits = itemID.meshBits,
                orientation = itemID.axis
            }
        end
    end
    return overrides
end

local function BuildInventoryItem(data)
    gameflowOverrides = ReadGameflow() or {}
    data.count = TEN.Inventory.GetItemCount(data.objectID)
    
    local override = gameflowOverrides[data.objectID] or {}
    
    if override.yOffset ~= nil then data.yOffset = override.yOffset end
    if override.scale ~= nil then data.scale = override.scale end
    if override.rotation ~= nil then data.rotation = override.rotation end
    if override.menuActions ~= nil then data.menuActions = override.menuActions end
    if override.name ~= nil then data.name = override.name end
    if override.meshBits ~= nil then data.meshBits = override.meshBits end
    if override.orientation ~= nil then data.orientation = override.orientation end
    if override.type ~= nil then data.type = override.type end
    if override.combine ~= nil then data.combine = override.combine end
    
    return data
end

local function GetSelectedItem(ring)
    return inventory.ring[ring][inventory.selectedItem[ring]]
end

local function GetSelectedRing(ring)
    return inventory.ring[ring][inventory.selectedItem[ring]]
end



local function ClearInventory(ringName, clearDrawItems)
    if ringName then
        local ring = inventory.ring[ringName]
        
        if clearDrawItems and ring then
            for _, itemData in ipairs(ring) do
                local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(itemData.objectID))
                displayItem:Remove()
            end
        end
        
        inventory.ring[ringName] = {}
        inventory.slice[ringName] = nil
        inventory.selectedItem[ringName] = nil
        inventory.ringPosition[ringName] = nil
    else
        if clearDrawItems then
            TEN.View.DisplayItem.ClearAllItems()
        end
        
        inventory = {ring = {}, slice = {}, selectedItem = {}, ringPosition = {}}
    end
end

local function GetCombineItemsCount(selectedItem)
    local itemCount = 0
    local items = PICKUP_DATA.CONSTANTS
    
    for _, itemRow in ipairs(items) do
        local itemData = PICKUP_DATA.ConvertRowData(itemRow)
        local data = BuildInventoryItem(itemData)
        local shouldInsert = false
        
        if data.combine == true then
            if selectedItem == data.objectID then
                goto continue
            end
            
            if data.type == TYPE.WEAPON and Lara:GetLaserSight(PICKUP_DATA.WEAPON_SET[data.objectID].slot) then
                goto continue
            end
            
            shouldInsert = (data.count ~= 0)
        else
            goto continue
        end
        
        if shouldInsert then
            itemCount = itemCount + 1
        end
        
        ::continue::
    end
    return itemCount
end