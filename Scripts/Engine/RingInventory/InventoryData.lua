--Pointers to tables
local PICKUP_DATA = require("Engine.RingInventory.PickupData")
local InventoryItem = require("Engine.RingInventory.InventoryItem")
local TYPE = PICKUP_DATA.TYPE
local RING = PICKUP_DATA.RING
local RING_CENTER = PICKUP_DATA.RING_CENTER
local INVENTORY_MODE = PICKUP_DATA.INVENTORY_MODE
local SOUND_MAP = Settings.SOUND_MAP
local COLOR_MAP = Settings.COLOR_MAP
local ANIMATION = Settings.ANIMATION

--External Modules
local Constants = require("Engine.RingInventory.Constants")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP
local RING_CENTER = Ring.CENTERS
local RING_TYPE = Ring.TYPE

-- Inventory Class - wrapper for managing rings by type
local Inventory = {}
Inventory.__index = Inventory

-- Constructor
function Inventory.Create()
    local self = setmetatable({}, Inventory)
    
    -- Main storage: [ringType] = Ring instance
    self.rings = {}
    
    -- Tracking
    self.selectedRingType = RING.MAIN
    self.previousRingType = nil
    self.combineItem1 = nil
    
    -- Gameflow overrides cache
    self.gameflowOverrides = nil
    
    -- Ring rotation tracking
    self.currentRingAngle = 0
    self.targetRingAngle = 0
    
    -- Save/load UI state
    self.saveList = false
    self.saveSelected = false
    
    return self
end

-- Get or create a ring by type
function Inventory:GetRing(ringType)
    if not self.rings[ringType] then
        local center = RING_CENTER[ringType]
        self.rings[ringType] = Ring.new(ringType, center, self)  -- Pass self as inventory reference
    end
    return self.rings[ringType]
end

-- Add an existing Ring instance to the inventory
function Inventory:AddRing(ring)
    if not ring then
        return false
    end
    
    -- Set the ring's inventory reference to this inventory
    ring.inventory = self
    
    -- Store the ring
    self.rings[ring.type] = ring
    
    return true
end

-- Check if a ring exists
function Inventory:HasRing(ringType)
    return self.rings[ringType] ~= nil
end

-- Get all rings
function Inventory:GetAllRings()
    return self.rings
end

-- Get currently selected ring
function Inventory:GetSelectedRing()
    return self:GetRing(self.selectedRingType)
end

-- Get selected ring type
function Inventory:GetSelectedRingType()
    return self.selectedRingType
end

-- Get previous ring type
function Inventory:GetPreviousRingType()
    return self.previousRingType
end

-- Switch to a different ring
function Inventory:SwitchToRing(ringType)
    if not RING_TYPE[ringType] then
        return false
    end
    
    self.previousRingType = self.selectedRingType
    self.selectedRingType = ringType
    return true
end

-- Return to previous ring
function Inventory:ReturnToPreviousRing()
    if self.previousRingType then
        local temp = self.selectedRingType
        self.selectedRingType = self.previousRingType
        self.previousRingType = temp
        return true
    end
    return false
end

-- Setup secondary ring (combine, ammo, etc.)
function Inventory:SetupSecondaryRing(ringType, item)
    self.previousRingType = self.selectedRingType
    
    local currentRing = self:GetSelectedRing()
    self.combineItem1 = item or (currentRing and currentRing:GetSelectedItem().objectID)
    
    -- Get or create the new ring
    local newRing = self:GetRing(ringType)
    
    -- You can implement ConstructObjectList here if needed
    -- self:ConstructObjectList(ringType, self.combineItem1)
    
    self.selectedRingType = ringType
    
    -- Special handling for ammo ring
    if ringType == RING.AMMO then
        local weaponSlot = PICKUP_DATA.WEAPON_SET[self.combineItem1].slot
        local ammoType = Lara:GetAmmoType(weaponSlot)
        local objectID = PICKUP_DATA.AMMO_TYPE_TO_OBJECT[ammoType]
        newRing:SetSelectedItemByID(objectID)
    end
    
    return newRing
end

-- Find item across all rings
function Inventory:FindItem(objectID)
    for ringType, ring in pairs(self.rings) do
        local item = ring:GetItem(objectID)
        if item then
            return item, ringType, ring
        end
    end
    return nil, nil, nil
end

-- Remove a ring
function Inventory:RemoveRing(ringType)
    if self.rings[ringType] then
        self.rings[ringType] = nil
        
        -- If we removed the selected ring, switch to main
        if self.selectedRingType == ringType then
            self.selectedRingType = RING.MAIN
        end
        return true
    end
    return false
end

-- Clear all rings
function Inventory:ClearAll()
    for _, ring in pairs(self.rings) do
        ring:Clear()
    end
end

-- Fade all rings
function Inventory:FadeAll(visible, omitSelectedRing)
    local fadeValue = visible and CONSTANTS.ALPHA_MAX or CONSTANTS.ALPHA_MIN
    
    for ringType, ring in pairs(self.rings) do
        if not (omitSelectedRing and ringType == self.selectedRingType) then
            ring:Fade(fadeValue, false)
            ring:SetVisibility(visible)
        end
    end
end

-- Set visibility for all rings
function Inventory:SetAllVisibility(visible, omitSelectedRing)
    for ringType, ring in pairs(self.rings) do
        if not (omitSelectedRing and ringType == self.selectedRingType) then
            ring:SetVisibility(visible)
        end
    end
end

-- Color all rings
function Inventory:ColorAll(color, omitSelectedRing, alpha)
    for ringType, ring in pairs(self.rings) do
        if not (omitSelectedRing and ringType == self.selectedRingType) then
            ring:Color(color, false, alpha)
        end
    end
end

-- Iterator for all rings
function Inventory:IterateRings()
    return pairs(self.rings)
end

-- Read gameflow overrides for items
function Inventory:ReadGameflow()
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

-- Build item with gameflow overrides
function Inventory:BuildItem(data)
    self.gameflowOverrides = self.gameflowOverrides or self:ReadGameflow()
    data.count = TEN.Inventory.GetItemCount(data.objectID)
    
    local override = self.gameflowOverrides[data.objectID] or {}
    
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

-- Construct rings with items from game data
function Inventory:Construct(ringType, selectedWeapon)
    local items = PICKUP_DATA.CONSTANTS
    
    if ringType == RING.AMMO or ringType == RING.COMBINE then
        self:Clear(ringType, true)
    else
        self:Clear(nil, true)
    end
    
    for _, itemRow in ipairs(items) do
        local itemData = PICKUP_DATA.ConvertRowData(itemRow)
        local data = self:BuildItem(itemData)
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
                
                if self.combineItem1 == data.objectID then
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
        
        if shouldInsert or ammoRing then
            -- Get or create the ring for this item
            local ring = self:GetRing(data.ringName)
            
            -- Add item to ring
            ring:AddItem(data)
            
            -- Create display item
            local inventoryItem = TEN.View.DisplayItem(
                tostring(data.objectID),
                data.objectID,
                Inventory.DEFAULT_CENTERS[data.ringName],
                data.rotation,
                Vec3(data.scale),
                data.meshBits
            )
            inventoryItem:SetColor(COLOR_MAP.ITEM_COLOR)
        end
        
        ::continue::
    end
    
    -- Initialize ring positions
    if ringType then
        local ring = self:GetRing(ringType)
        ring:SetPosition(Inventory.DEFAULT_CENTERS[ringType])
    else
        for ringType, ring in pairs(self.rings) do
            ring:SetPosition(Inventory.DEFAULT_CENTERS[ringType])
        end
    end
end

-- Open inventory at specific item
function Inventory:OpenAtItem(itemID, repositionRings)
    if itemID == NO_VALUE then
        return
    end
    
    local item, ringType, ring = self:FindItem(itemID)
    
    if not (ringType and ring) then
        return
    end
    
    -- Set selected item
    ring:SetSelectedItemByID(itemID)
    
    local slice = ring:GetSlice()
    local itemIndex = ring:GetSelectedItemIndex()
    local angle = -slice * (itemIndex - 1)
    
    -- Store angle (you may want to make these instance variables)
    self.currentRingAngle = angle
    self.targetRingAngle = angle
    
    if repositionRings then
        local ringPosition = Inventory.DEFAULT_CENTERS[RING.MAIN]
        self.selectedRingType = ringType
        
        for rType, r in pairs(self.rings) do
            local offset = (rType - self.selectedRingType) * 1000  -- RING_POSITION_OFFSET
            local position = Vec3(ringPosition.x, ringPosition.y + offset, ringPosition.z)
            r:SetPosition(position)
            r:Translate(position, Ring.RING_RADIUS, angle)
        end
    end
    
    if itemID == TEN.Objects.ObjID.PC_SAVE_INV_ITEM or itemID == TEN.Objects.ObjID.PC_LOAD_INV_ITEM then
        -- Handle save/load UI state
        self.saveList = (itemID == TEN.Objects.ObjID.PC_SAVE_INV_ITEM)
        self.saveSelected = true
    end
end

-- Get count of combinable items (excluding selected item)
function Inventory:GetCombineItemsCount(selectedItem)
    local itemCount = 0
    local items = PICKUP_DATA.CONSTANTS
    
    for _, itemRow in ipairs(items) do
        local itemData = PICKUP_DATA.ConvertRowData(itemRow)
        local data = self:BuildItem(itemData)
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

-- Clear a specific ring or all rings
function Inventory:Clear(ringType, clearDrawItems)
    if ringType then
        local ring = self.rings[ringType]
        
        if clearDrawItems and ring then
            for _, item in ipairs(ring:GetItems()) do
                local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(item.objectID))
                if displayItem then
                    displayItem:Remove()
                end
            end
        end
        
        -- Remove the ring entirely
        self.rings[ringType] = nil
        
        -- If we cleared the selected ring, switch to main
        if self.selectedRingType == ringType then
            self.selectedRingType = RING.MAIN
        end
    else
        -- Clear all rings
        if clearDrawItems then
            TEN.View.DisplayItem.ClearAllItems()
        end
        
        self.rings = {}
        self.selectedRingType = RING.MAIN
        self.previousRingType = nil
    end
end

-- Get count of rings
function Inventory:GetRingCount()
    local count = 0
    for _ in pairs(self.rings) do
        count = count + 1
    end
    return count
end

return Inventory

--Structure for inventory
local Inventory = {}


local chosenItem = nil
local openAtItem = nil
local gameflowOverrides = nil


function Inventory.Clear(ringName, clearDrawItems)
    if ringName then
        local ring = Inventory.ring[ringName]
        
        if clearDrawItems and ring then
            for _, itemData in ipairs(ring) do
                local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(itemData:GetObjectID()))
                displayItem:Remove()
            end
        end
        
        Inventory.ring[ringName] = {}
        Inventory.slice[ringName] = nil
        Inventory.selectedItem[ringName] = nil
        Inventory.ringPosition[ringName] = nil
    else
        if clearDrawItems then
            TEN.View.DisplayItem.ClearAllItems()
        end
        
        Inventory.ring = {}
        Inventory.slice = {}
        Inventory.selectedItem = {}
        Inventory.ringPosition = {}

    end
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

function Inventory.BuildItem(data)
    Inventory.gameflowOverrides = ReadGameflow() or {}
    data.count = TEN.Inventory.GetItemCount(data.objectID)
    
    local override = Inventory.gameflowOverrides[data.objectID] or {}
    
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

function Inventory.Construct(ringType, selectedWeapon)
    local items = PICKUP_DATA.CONSTANTS
    
    if ringType == RING.AMMO or ringType == RING.COMBINE then
        Inventory.ClearInventory(ringType, true)
    else
        Inventory.ClearInventory()
    end
    
    for _, itemRow in ipairs(items) do
        local itemData = PICKUP_DATA.ConvertRowData(itemRow)
        local data = Inventory.BuildItem(itemData)
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

            if getmetatable(data) ~= InventoryItem then
                setmetatable(data, InventoryItem)
            end

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

function Inventory.OpenAtItem(itemID, repositionRings)
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

return Inventory