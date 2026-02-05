-- ============================================================================
-- AmmoItem - Handles selected Ammo item
-- ============================================================================

--External Modules
local InventoryData = require("Engine.RingInventory.InventoryData")
local ItemLight = require("Engine.RingInventory.ItemLight")
local ItemSpin= require("Engine.RingInventory.ItemSpin")
local PickupData = require("Engine.RingInventory.PickupData")
local Settings = require("Engine.RingInventory.Settings")
local Text = require("Engine.RingInventory.Text")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP

--Begin Class
local AmmoItem = {}

--Constants
local AMMO_LOCATION = Vec3(0, 300, 512)

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
    
    local base  = PickupData.GetProperties(objectID)
    local data = InventoryData.BuildItem(base)
    
    return data

end

function AmmoItem.Show(weaponItem, textOnly)

    local item = GetChosenAmmo(weaponItem)
    if item then

        if not textOnly then
            local displayItem = TEN.View.DisplayItem("ChosenAmmo", item:GetObjectID(), AMMO_LOCATION, item:GetRotation(), Vec3(item:GetScale()), item:GetMeshBits())
            displayItem:SetColor(COLOR_MAP.ITEM_HIDDEN)

            ItemLight.FadeIn("ChosenAmmo", COLOR_MAP.ITEM_SELECTED)
            Text.SetItemSubLabel(item)
            ItemSpin.RotateItem("ChosenAmmo")

        end
    end
end

function AmmoItem.Hide()

    ItemLight.FadeOut("ChosenAmmo", COLOR_MAP.ITEM_HIDDEN)
    Text.Hide("ITEM_LABEL_SECONDARY")
    ItemSpin.StopItem()

end

return AmmoItem