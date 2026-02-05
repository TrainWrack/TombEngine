
--External Modules
local AmmoItem = require("Engine.RingInventory.AmmoItem")
local Animation = require("Engine.RingInventory.Animation")
local Combine = require("Engine.RingInventory.Combine")
local Examine =  require("Engine.RingInventory.Examine")
local Interpolate = require("Engine.RingInventory.Interpolate")
local RingInventory = require("Engine.RingInventory.Inventory")
local InventoryData= require("Engine.RingInventory.InventoryData")
local ItemLight = require("Engine.RingInventory.ItemLight")
local ItemMenu = require("Engine.RingInventory.ItemMenu")
local ItemSpin= require("Engine.RingInventory.ItemSpin")
local Menu = require("Engine.RingInventory.Menu")
local PickupData = require("Engine.RingInventory.PickupData")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")
local Statistics = require("Engine.RingInventory.Statistics")
local Text = require("Engine.RingInventory.Text")
local UseItem = require("Engine.RingInventory.UseItem")
local Utilities = require("Engine.RingInventory.Utilities")
local WeaponMode =  require("Engine.RingInventory.WeaponMode")
local Save = require("Engine.RingInventory.Save")

--Pointers to tables
local CONSTANTS = require("Engine.RingInventory.Constants")

local InventoryStates = {}

InventoryStates.MODE = 
{
    INVENTORY = 1,
    RING_OPENING = 2,
    RING_CLOSING = 3,
	RING_CHANGE = 4,
    RING_ROTATE = 5,
    STATISTICS_OPEN = 6,
	STATISTICS = 7,
    STATISTICS_CLOSE = 8,
    EXAMINE_OPEN = 9,
	EXAMINE = 10,
	EXAMINE_RESET = 11,
    EXAMINE_CLOSE = 12,
    ITEM_USE = 13,
    ITEM_SELECT = 14,
    ITEM_DESELECT = 15,
    ITEM_SELECTED = 16,
    COMBINE = 17,
    COMBINE_SETUP = 18,
    COMBINE_CLOSE = 19,
    COMBINE_RING_OPENING = 20,
    COMBINE_SUCCESS = 21,
	COMBINE_COMPLETE = 22,
	SEPARATE = 23,
    SEPARATE_COMPLETE = 24,
    AMMO_SELECT_SETUP = 25,
    AMMO_SELECT_OPEN = 26,
    AMMO_SELECT = 27,
    AMMO_SELECT_CLOSE = 28,
    SAVE_SETUP = 29,
    SAVE_MENU = 30,
    SAVE_CLOSE = 31,
    WEAPON_MODE_SETUP = 32,
    WEAPON_MODE = 33,
    WEAPON_MODE_CLOSE = 34,
	INVENTORY_EXIT = 35,
	INVENTORY_OPENING = 36
}

local inventoryMode = InventoryStates.MODE.INVENTORY_OPENING
local previousMode = nil
local performAction = false

function InventoryStates.GetActionCheck()

    return performAction

end

function InventoryStates.SetActionCheck(check)

    performAction = check

end

function InventoryStates.SetMode(mode)

    previousMode = inventoryMode
    inventoryMode = mode
    return true

end

function InventoryStates.GetMode()
    return inventoryMode
end

function InventoryStates.GetPreviousMode()
    return previousMode
end

function InventoryStates.IsMode(mode)

    return inventoryMode == mode
    
end

function InventoryStates.Update()

    local selectedRing = InventoryData.Get("RingInventory"):GetSelectedRing()
    local selectedItem = selectedRing:GetSelectedItem()
    
    if inventoryMode == InventoryStates.MODE.INVENTORY then
        ItemSpin.StartSpin(selectedItem.objectID)
        AmmoItem.Show(selectedItem, true)
        Text.SetItemLabel(selectedItem)
    elseif inventoryMode == InventoryStates.MODE.RING_OPENING then
        if Animation.Inventory(inventoryMode) then
            if saveSelected then
                Animation.EnableSaveItemData()
                inventoryMode = InventoryStates.MODE.SAVE_SETUP
            else
                inventoryMode = InventoryStates.MODE.INVENTORY
            end
        end
    elseif inventoryMode == InventoryStates.MODE.RING_CLOSING then
        if Animation.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.INVENTORY_EXIT
        end
    elseif inventoryMode == InventoryStates.MODE.RING_ROTATE then
        if Animation.Inventory(inventoryMode) then
            currentRingAngle = targetRingAngle
            if previousMode then
                inventoryMode = previousMode
            else
                inventoryMode = InventoryStates.MODE.INVENTORY
            end
        end
    elseif inventoryMode == InventoryStates.MODE.RING_CHANGE then
        if Animation.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.INVENTORY
            for index, _ in ipairs(inventory.selectedItem) do
                inventory.selectedItem[index] = 1
            end
            currentRingAngle = 0
            targetRingAngle = 0
        end
    elseif inventoryMode == InventoryStates.MODE.EXAMINE_OPEN then
        Animation.SaveItemData(selectedItem)
        AmmoItem.Hide()
        Text.SetText("HEADER", "examine", true)
        if combineItem1 or Animation.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.EXAMINE
        end
    elseif inventoryMode == InventoryStates.MODE.EXAMINE then
        Examine.Item(selectedItem)
    elseif inventoryMode == InventoryStates.MODE.EXAMINE_RESET then
        if Animation.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.EXAMINE_CLOSE
        end
    elseif inventoryMode == InventoryStates.MODE.EXAMINE_CLOSE then
        Text.SetText("HEADER", "actions_inventory", true)
        if combineItem1 or Animation.Inventory(inventoryMode) then
            inventoryMode = combineItem1 and InventoryStates.MODE.ITEM_SELECTED or InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_SELECT then
        Animation.SaveItemData(selectedItem)
        if Animation.Inventory(inventoryMode) then
            previousRingAngle = currentRingAngle
            combineItem1 = selectedItem.objectID
            SetInventoryHeader(selectedItem.name, true)
            CreateItemMenu(selectedItem.objectID)
            inventoryMode = InventoryStates.MODE.ITEM_SELECTED
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_SELECTED then
        ShowItemMenu()
        AmmoItem.Show(combineItem1, false)
    elseif inventoryMode == InventoryStates.MODE.ITEM_DESELECT then
        AmmoItem.Hide()
        Text.SetText("HEADER", "actions_inventory", true)
        if Animation.Inventory(inventoryMode) then
            combineItem1 = nil
            currentRingAngle = previousRingAngle
            inventoryMode = InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.STATISTICS_OPEN then
        AmmoItem.Hide()
        Animation.SaveItemData(selectedItem)
        Statistics.CreateStatisticsMenu()
        Text.SetText("HEADER", "statistics", true)
        if combineItem1 or Animation.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.STATISTICS
        end
    elseif inventoryMode == InventoryStates.MODE.STATISTICS then
        Statistics.Show()
    elseif inventoryMode == InventoryStates.MODE.STATISTICS_CLOSE then
        Statistics.Hide()
        if combineItem1 or Animation.Inventory(inventoryMode) then
            Text.SetText("HEADER", "actions_inventory", true)
            inventoryMode = combineItem1 and InventoryStates.MODE.ITEM_SELECTED or InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.SAVE_SETUP then
        AmmoItem.Hide()
        Animation.SaveItemData(selectedItem)
        if combineItem1 or Animation.Inventory(inventoryMode) then
            CreateSaveMenu(saveList)
            Text.SetText("HEADER", "actions_inventory", false)
            inventoryMode = InventoryStates.MODE.SAVE_MENU
        end
    elseif inventoryMode == InventoryStates.MODE.SAVE_MENU then
        RunSaveMenu()
    elseif inventoryMode == InventoryStates.MODE.SAVE_CLOSE then
        if combineItem1 then
            inventoryMode = InventoryStates.MODE.ITEM_SELECTED
        elseif Animation.Inventory(inventoryMode) then
            Text.SetText("HEADER", "actions_inventory", true)
            if saveSelected then
                saveSelected = false
                inventoryMode = InventoryStates.MODE.RING_CLOSING
            else
                inventoryMode = InventoryStates.MODE.INVENTORY
            end
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_SETUP then
        AmmoItem.Hide()
        Animation.SaveItemData(selectedItem)
        if combineItem1 or Animation.Inventory(inventoryMode) then
            SetupSecondaryRing(RING.COMBINE)
            Text.SetText("HEADER", selectedItem.name, true)
            Text.SetText("SUB_HEADER", "combine_with", true)
            inventoryMode = InventoryStates.MODE.COMBINE_RING_OPENING
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_RING_OPENING then
        if Animation.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.COMBINE
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE then
        RotateItem(tostring(selectedItem.objectID))
        DrawItemLabel(selectedItem, true)
        
        if InventoryStates.GetActionCheck() then
            combineItem2 = GetSelectedItem(RING.COMBINE).objectID
            if CombineItems(combineItem1, combineItem2) then
                TEN.Sound.PlaySound(SOUND_MAP.MENU_COMBINE)
                inventoryMode = InventoryStates.MODE.COMBINE_SUCCESS
            else
                TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                InventoryStates.SetActionCheck(false)
            end
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_SUCCESS then
        if Animation.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.COMBINE_CLOSE
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_CLOSE then
        if Animation.Inventory(inventoryMode) then
            Text.Hide("SUB_HEADER")
            Text.SetText("HEADER", "actions_inventory", true)
            inventoryOpenItem = combineResult and combineResult or combineItem1
            combineItem1 = nil
            combineItem2 = nil
            combineResult = nil
            InventoryStates.SetActionCheck(false)
            inventoryMode = InventoryStates.MODE.COMBINE_COMPLETE
            LevelVars.Engine.RingInventory.InventoryOpen = true
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_COMPLETE then
        if Animation.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_USE then
        Animation.SaveItemData(selectedItem)
        AmmoItem.Hide()
        Text.SetText("HEADER", "actions_inventory", true)
        if Animation.Inventory(inventoryMode) then
            UseItem(selectedItem.objectID)
        end
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_SETUP then
        Animation.SaveItemData(selectedItem)
        AmmoItem.Hide()
        SetupSecondaryRing(RING.AMMO, combineItem1)
        inventoryMode = InventoryStates.MODE.AMMO_SELECT_OPEN
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_OPEN then
        if Animation.Inventory(inventoryMode) then
            Text.SetText("SUB_HEADER", "choose_ammo", true)
            inventoryMode = InventoryStates.MODE.AMMO_SELECT
        end
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT then
        RotateItem(tostring(selectedItem.objectID))
        DrawItemLabel(selectedItem, false)
        if InventoryStates.GetActionCheck() then
            local ammo = PICKUP_DATA.AMMO_SET[selectedItem.objectID]
            Lara:SetAmmoType(ammo.slot)
            inventoryMode = InventoryStates.MODE.AMMO_SELECT_CLOSE
        end
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_CLOSE then
        if Animation.Inventory(inventoryMode) then
            InventoryStates.SetActionCheck(false)
            selectedRing = previousRing
            Text.Hide("SUB_HEADER")
            inventoryMode = InventoryStates.MODE.ITEM_SELECTED
        end
    elseif inventoryMode == InventoryStates.MODE.SEPARATE then
        AmmoItem.Hide()
        if Animation.Inventory(inventoryMode) then
            Combine.SeparateItems(selectedItem)
            inventoryOpenItem = combineItem1
            RingInventory:SetChosenItem(nil)
            LevelVars.Engine.RingInventory.InventoryOpen = true
            inventoryMode = InventoryStates.MODE.SEPARATE_COMPLETE
        end
    elseif inventoryMode == InventoryStates.MODE.SEPARATE_COMPLETE then
        Text.SetText("HEADER", "actions_inventory", true)
        if Animation.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.WEAPON_MODE_SETUP then
        Text.SetText("SUB_HEADER", "choose_ammo", true)
        WeaponMode.CreateWeaponModeMenu(selectedItem)
        inventoryMode = InventoryStates.MODE.WEAPON_MODE
    elseif inventoryMode == InventoryStates.MODE.WEAPON_MODE then
        WeaponMode.Show()
    elseif inventoryMode == InventoryStates.MODE.WEAPON_MODE_CLOSE then
        WeaponMode.Hide()
        Text.SetText("SUB_HEADER", "choose_ammo", false)
        inventoryMode = InventoryStates.MODE.ITEM_SELECTED
    elseif inventoryMode == InventoryStates.MODE.INVENTORY_OPENING then
        if Animation.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.RING_OPENING
        end
    elseif inventoryMode == InventoryStates.MODE.INVENTORY_EXIT then
        if Animation.Inventory(inventoryMode) then
            LevelFuncs.Engine.RingInventory.ExitInventory()
        end
    end
end

return InventoryStates