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
local Save = require("Engine.RingInventory.Save")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP
local RING_CENTER = Ring.CENTERS
local RING_TYPE = Ring.TYPE

-- Inventory Class - wrapper for managing rings by type
local InventoryData = {}
InventoryData.__index = InventoryData
InventoryData._registry = {}

--Variables
local gameflowOverrides = nil

-- Constructor
function InventoryData.Create(name)
    local self = setmetatable({}, InventoryData)
    
    -- Main storage: [ringType] = Ring instance
    self.rings = {}
    
    -- Tracking
    self.selectedRingType = RING.MAIN
    self.previousRingType = nil
    self.chosenItem = nil
    self.openAtItem = nil
    
    self.name = name

    return self
end

function InventoryData.Get(name)
    return InventoryData._registry[name]
end

-- Get or create a ring by type
function InventoryData:GetRing(ringType)
    if not self.rings[ringType] then
        local center = RING_CENTER[ringType]
        self.rings[ringType] = Ring.Create(ringType, center, self)  -- Pass self as inventory reference
    end
    return self.rings[ringType]
end

-- Add an existing Ring instance to the inventory
function InventoryData:AddRing(ring)
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
function InventoryData:HasRing(ringType)
    return self.rings[ringType] ~= nil
end

-- Get all rings
function InventoryData:GetAllRings()
    return self.rings
end

-- Get currently selected ring
function InventoryData:GetSelectedRing()
    return self:GetRing(self.selectedRingType)
end

-- Get selected ring type
function InventoryData:GetSelectedRingType()
    return self.selectedRingType
end

-- Get previous ring type
function InventoryData:GetPreviousRingType()
    return self.previousRingType
end

-- Switch to a different ring
function InventoryData:SwitchToRing(ringType)
    if not RING_TYPE[ringType] then
        return false
    end
    
    self.previousRingType = self.selectedRingType
    self.selectedRingType = ringType
    return true
end

-- Return to previous ring
function InventoryData:ReturnToPreviousRing()
    if self.previousRingType then
        local temp = self.selectedRingType
        self.selectedRingType = self.previousRingType
        self.previousRingType = temp
        return true
    end
    return false
end

-- Setup secondary ring (combine, ammo, etc.)
function InventoryData:SetupSecondaryRing(ringType, item)
    self.previousRingType = self.selectedRingType
    
    local currentRing = self:GetSelectedRing()
    self.chosenItem = item or (currentRing and currentRing:GetSelectedItem().objectID)
    
    -- Get or create the new ring
    local newRing = self:GetRing(ringType)
    
    -- You can implement ConstructObjectList here if needed
    -- self:ConstructObjectList(ringType, self.chosenItem)
    
    self.selectedRingType = ringType
    
    -- Special handling for ammo ring
    if ringType == RING.AMMO then
        local weaponSlot = PICKUP_DATA.WEAPON_SET[self.chosenItem].slot
        local ammoType = Lara:GetAmmoType(weaponSlot)
        local objectID = PICKUP_DATA.AMMO_TYPE_TO_OBJECT[ammoType]
        newRing:SetSelectedItemByID(objectID)
    end
    
    return newRing
end

-- Find item across all rings
function InventoryData:FindItem(objectID)
    for ringType, ring in pairs(self.rings) do
        local item = ring:GetItem(objectID)
        if item then
            return item, ringType, ring
        end
    end
    return nil, nil, nil
end

-- Remove a ring
function InventoryData:RemoveRing(ringType)
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
function InventoryData:ClearAll()
    for _, ring in pairs(self.rings) do
        ring:Clear()
    end
end

-- Fade all rings
function InventoryData:FadeAll(visible, omitSelectedRing)
    local fadeValue = visible and CONSTANTS.ALPHA_MAX or CONSTANTS.ALPHA_MIN
    
    for ringType, ring in pairs(self.rings) do
        if not (omitSelectedRing and ringType == self.selectedRingType) then
            ring:Fade(fadeValue)
            ring:SetVisibility(visible)
        end
    end
end

-- Set visibility for all rings
function InventoryData:SetAllVisibility(visible, omitSelectedRing)
    for ringType, ring in pairs(self.rings) do
        if not (omitSelectedRing and ringType == self.selectedRingType) then
            ring:SetVisibility(visible)
        end
    end
end

-- Color all rings
function InventoryData:ColorAll(color, omitSelectedRing)
    for ringType, ring in pairs(self.rings) do
        if not (omitSelectedRing and ringType == self.selectedRingType) then
            ring:Color(color)
        end
    end
end

-- Iterator for all rings
function InventoryData:IterateRings()
    return pairs(self.rings)
end

-- Read gameflow overrides for items
local ReadGameflow = function()
    local overrides = {}
    for _, itemID in ipairs(TEN.Flow.GetCurrentLevel().objects) do
        if itemID.objectID then
            local id = TEN.InventoryData.ConvertInventoryItemToObject(itemID.objectID)
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
function InventoryData.BuildItem(data)
    gameflowOverrides = gameflowOverrides or ReadGameflow()
    data.count = TEN.InventoryData.GetItemCount(data.objectID)
    
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

    --add metatable for inventoryItem methods
    InventoryItem.New(data)
    
    return data
end

-- Construct rings with items from game data
function InventoryData:Construct(ringType, selectedWeapon)
    
    local items = PICKUP_DATA.CONSTANTS
    
    if ringType == RING.AMMO or ringType == RING.COMBINE then
        self:Clear(ringType, true)
    else
        self:Clear(nil, true)
    end
    
    for _, itemRow in ipairs(items) do
        local itemData = PICKUP_DATA.ConvertRowData(itemRow)
        itemData.rotation = Utilities.CopyRotation(itemData.rotation)
        local data = InventoryData.BuildItem(itemData)
        
        if data.type == TYPE.AMMO and ringType ~= RING.AMMO then
            local weaponPresent = TEN.InventoryData.GetItemCount(PICKUP_DATA.AMMO_SET[data.objectID].weapon)
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
                
                if self.chosenItem == data.objectID then
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
                Ring.CENTERS[data.ringName],
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
        ring:SetPosition(InventoryData.DEFAULT_CENTERS[ringType])
    else
        for ringType, ring in pairs(self.rings) do
            ring:SetPosition(InventoryData.DEFAULT_CENTERS[ringType])
        end
    end
end

-- Open inventory at specific item
function InventoryData:OpenAtItem(itemID, repositionRings)
    if itemID == Constants.NO_VALUE then
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
        local ringPosition = InventoryData.DEFAULT_CENTERS[RING.MAIN]
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
function InventoryData:GetCombineItemsCount(selectedItem)
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
function InventoryData:Clear(ringType, clearDrawItems)
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
function InventoryData:GetRingCount()
    local count = 0
    for _ in pairs(self.rings) do
        count = count + 1
    end
    return count
end

--Get item selected objectID
function InventoryData:GetChosenItem()

    return self.chosenItem 

end

--Set item selected objectID
function InventoryData:SetChosenItem(objectID)

    self.chosenItem = objectID
    return true

end

--Check item selected objectID
function InventoryData:IsChosenItem(objectID)

    return self.chosenItem == objectID

end

--Get open at item objectID
function InventoryData:GetOpenAtItem()

    return self.openAtItem

end

--Set open at item objectID
function InventoryData:SetOpenAtItem(objectID)

    self.openAtItem = objectID
    return true

end

return InventoryData