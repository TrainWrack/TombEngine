-- ============================================================================
-- AmmoItem - Handles selected Ammo item
-- ============================================================================

--External Modules
local ItemLight = require("Engine.RingInventory.ItemLight")
local ItemSpin= require("Engine.RingInventory.ItemSpin")
local PickupData = require("Engine.RingInventory.PickupData")
local Settings = require("Engine.RingInventory.Settings")
local Text = require("Engine.RingInventory.Text")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP
local TYPE = PickupData.TYPE

--Begin Class
local AmmoItem = {}

--Constants
local AMMO_LOCATION = Vec3(0, 300, 512)

--DisplayItem Storage
AmmoItem.ammoItem = nil

local function GetChosenAmmo(weaponItem)

    if not weaponItem or weaponItem:GetType() ~= TYPE.WEAPON then
        return
    end

    local itemObjectID = weaponItem:GetObjectID()

    if not itemObjectID then
        return
    end

    local weaponSlot = PickupData.WEAPON_SET[itemObjectID].slot

    local ammoType = Lara:GetAmmoType(weaponSlot)
    
    if not ammoType then
        return
    end
    
    local objectID = PickupData.AMMO_TYPE_TO_OBJECT[ammoType]
    
    if not objectID then return end

    local InventoryData = require("Engine.RingInventory.InventoryData")
    
    local base  = PickupData.GetProperties(objectID)
    local data = InventoryData.BuildItem(base)
    local displayItem = data:CreateDisplayItem(AMMO_LOCATION)
    displayItem:SetColor(COLOR_MAP.ITEM_HIDDEN)
    return data

end
--Update this function to make sure item is drawn somewhere else, Maybe add ammoselected ring
function AmmoItem.Show(weaponItem, textOnly)

    AmmoItem.ammoItem = GetChosenAmmo(weaponItem)
    
    if AmmoItem.ammoItem then

        if not textOnly then
            ItemLight.FadeIn(AmmoItem.ammoItem, COLOR_MAP.ITEM_SELECTED)
            ItemSpin.RotateItem(AmmoItem.ammoItem)
        end

        Text.SetItemSubLabel(AmmoItem.ammoItem)
    end

    if not AmmoItem.ammoItem then
        
        Text.Hide("ITEM_LABEL_SECONDARY")

    end

end

function AmmoItem.Hide()

    if not AmmoItem.ammoItem then return end
    
    ItemLight.FadeOut(AmmoItem.ammoItem, COLOR_MAP.ITEM_HIDDEN)
    Text.Hide("ITEM_LABEL_SECONDARY")
    ItemSpin.StopItem()

end

return AmmoItem