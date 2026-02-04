
--External Modules
local Animate = require("Engine.RingInventory.Animation")
local Combine = require("Engine.RingInventory.Combine")
local Examine =  require("Engine.RingInventory.Examine")
local Interpolate = require("Engine.RingInventory.Interpolate")
local RingInventory = require("Engine.RingInventory.Inventory")
local InventoryData= require("Engine.RingInventory.InventoryData")
local ItemMenu = require("Engine.RingInventory.ItemMenu")
local Menu = require("Engine.RingInventory.Menu")
local PickupData = require("Engine.RingInventory.PickupData")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")
local Statistics = require("Engine.RingInventory.Statistics")
local Text = require("Engine.RingInventory.Settings")
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

function InventoryStates.SetMode(inventoryMode)

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

function InventoryStates.IsMode(inventoryMode)

    return inventoryMode == inventoryMode
    
end

function InventoryStates.Update()

    local selectedRing = InventoryData.Get("RingInventory"):GetSelectedRing()
    local selectedItem = selectedRing:GetSelectedItem()
    
    if inventoryMode == InventoryStates.MODE.INVENTORY then
        RotateItem(tostring(selectedItem.objectID))
        ShowChosenAmmo(selectedItem.objectID, true)
        DrawItemLabel(selectedItem, true)
    elseif inventoryMode == InventoryStates.MODE.RING_OPENING then
        if Animate.Inventory(inventoryMode) then
            if saveSelected then
                itemStoreRotations = true
                inventoryMode = InventoryStates.MODE.SAVE_SETUP
            else
                inventoryMode = InventoryStates.MODE.INVENTORY
            end
        end
    elseif inventoryMode == InventoryStates.MODE.RING_CLOSING then
        if Animate.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.INVENTORY_EXIT
        end
    elseif inventoryMode == InventoryStates.MODE.RING_ROTATE then
        if Animate.Inventory(inventoryMode) then
            currentRingAngle = targetRingAngle
            if previousMode then
                inventoryMode = previousMode
            else
                inventoryMode = InventoryStates.MODE.INVENTORY
            end
        end
    elseif inventoryMode == InventoryStates.MODE.RING_CHANGE then
        if Animate.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.INVENTORY
            for index, _ in ipairs(inventory.selectedItem) do
                inventory.selectedItem[index] = 1
            end
            currentRingAngle = 0
            targetRingAngle = 0
        end
    elseif inventoryMode == InventoryStates.MODE.EXAMINE_OPEN then
        SaveItemData(selectedItem)
        DeleteChosenAmmo()
        Text.SetText("HEADER", "examine", true)
        if combineItem1 or Animate.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.EXAMINE
        end
    elseif inventoryMode == InventoryStates.MODE.EXAMINE then
        ExamineItem(selectedItem.objectID)
    elseif inventoryMode == InventoryStates.MODE.EXAMINE_RESET then
        if Animate.Inventory(inventoryMode) then
            examineScaler = examineScalerOld
            inventoryMode = InventoryStates.MODE.EXAMINE_CLOSE
        end
    elseif inventoryMode == InventoryStates.MODE.EXAMINE_CLOSE then
        Text.SetText("HEADER", "actions_inventory", true)
        if combineItem1 or Animate.Inventory(inventoryMode) then
            inventoryMode = combineItem1 and InventoryStates.MODE.ITEM_SELECTED or InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_SELECT then
        SaveItemData(selectedItem)
        if Animate.Inventory(inventoryMode) then
            previousRingAngle = currentRingAngle
            combineItem1 = selectedItem.objectID
            SetInventoryHeader(selectedItem.name, true)
            CreateItemMenu(selectedItem.objectID)
            inventoryMode = InventoryStates.MODE.ITEM_SELECTED
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_SELECTED then
        ShowItemMenu()
        ShowChosenAmmo(combineItem1)
    elseif inventoryMode == InventoryStates.MODE.ITEM_DESELECT then
        DeleteChosenAmmo(true)
        Text.SetText("HEADER", "actions_inventory", true)
        if Animate.Inventory(inventoryMode) then
            combineItem1 = nil
            currentRingAngle = previousRingAngle
            inventoryMode = InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.STATISTICS_OPEN then
        DeleteChosenAmmo()
        SaveItemData(selectedItem)
        Statistics.CreateStatisticsMenu()
        Text.SetText("HEADER", "statistics", true)
        if combineItem1 or Animate.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.STATISTICS
        end
    elseif inventoryMode == InventoryStates.MODE.STATISTICS then
        Statistics.Show()
    elseif inventoryMode == InventoryStates.MODE.STATISTICS_CLOSE then
        Statistics.Hide()
        if combineItem1 or Animate.Inventory(inventoryMode) then
            Text.SetText("HEADER", "actions_inventory", true)
            inventoryMode = combineItem1 and InventoryStates.MODE.ITEM_SELECTED or InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.SAVE_SETUP then
        DeleteChosenAmmo()
        SaveItemData(selectedItem)
        if combineItem1 or Animate.Inventory(inventoryMode) then
            CreateSaveMenu(saveList)
            Text.SetText("HEADER", "actions_inventory", false)
            inventoryMode = InventoryStates.MODE.SAVE_MENU
        end
    elseif inventoryMode == InventoryStates.MODE.SAVE_MENU then
        RunSaveMenu()
    elseif inventoryMode == InventoryStates.MODE.SAVE_CLOSE then
        if combineItem1 then
            inventoryMode = InventoryStates.MODE.ITEM_SELECTED
        elseif Animate.Inventory(inventoryMode) then
            Text.SetText("HEADER", "actions_inventory", true)
            if saveSelected then
                saveSelected = false
                inventoryMode = InventoryStates.MODE.RING_CLOSING
            else
                inventoryMode = InventoryStates.MODE.INVENTORY
            end
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_SETUP then
        DeleteChosenAmmo()
        SaveItemData(selectedItem)
        if combineItem1 or Animate.Inventory(inventoryMode) then
            SetupSecondaryRing(RING.COMBINE)
            Text.SetText("HEADER", selectedItem.name, true)
            Text.SetText("SUB_HEADER", "combine_with", true)
            inventoryMode = InventoryStates.MODE.COMBINE_RING_OPENING
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_RING_OPENING then
        if Animate.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.COMBINE
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE then
        RotateItem(tostring(selectedItem.objectID))
        DrawItemLabel(selectedItem, true)
        
        if performCombine then
            combineItem2 = GetSelectedItem(RING.COMBINE).objectID
            if CombineItems(combineItem1, combineItem2) then
                TEN.Sound.PlaySound(SOUND_MAP.MENU_COMBINE)
                inventoryMode = InventoryStates.MODE.COMBINE_SUCCESS
            else
                TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                performCombine = false
            end
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_SUCCESS then
        if Animate.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.COMBINE_CLOSE
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_CLOSE then
        if Animate.Inventory(inventoryMode) then
            Text.SetText("SUB_HEADER", "combine_with", false)
            Text.SetText("HEADER", "actions_inventory", true)
            inventoryOpenItem = combineResult and combineResult or combineItem1
            combineItem1 = nil
            combineItem2 = nil
            combineResult = nil
            performCombine = false
            inventoryMode = InventoryStates.MODE.COMBINE_COMPLETE
            LevelVars.Engine.RingInventory.InventoryOpen = true
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_COMPLETE then
        if Animate.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_USE then
        SaveItemData(selectedItem)
        DeleteChosenAmmo()
        Text.SetText("HEADER", "actions_inventory", true)
        if Animate.Inventory(inventoryMode) then
            UseItem(selectedItem.objectID)
        end
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_SETUP then
        SaveItemData(selectedItem)
        DeleteChosenAmmo()
        SetupSecondaryRing(RING.AMMO, combineItem1)
        inventoryMode = InventoryStates.MODE.AMMO_SELECT_OPEN
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_OPEN then
        if Animate.Inventory(inventoryMode) then
            Text.SetText("SUB_HEADER", "choose_ammo", true)
            inventoryMode = InventoryStates.MODE.AMMO_SELECT
        end
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT then
        RotateItem(tostring(selectedItem.objectID))
        DrawItemLabel(selectedItem, false)
        if performCombine then
            local ammo = PICKUP_DATA.AMMO_SET[selectedItem.objectID]
            Lara:SetAmmoType(ammo.slot)
            inventoryMode = InventoryStates.MODE.AMMO_SELECT_CLOSE
        end
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_CLOSE then
        if Animate.Inventory(inventoryMode) then
            performCombine = false
            selectedRing = previousRing
            Text.SetText("SUB_HEADER", "choose_ammo", false)
            inventoryMode = InventoryStates.MODE.ITEM_SELECTED
        end
    elseif inventoryMode == InventoryStates.MODE.SEPARATE then
        DeleteChosenAmmo()
        if Animate.Inventory(inventoryMode) then
            SeparateItems(selectedItem.objectID)
            inventoryOpenItem = combineItem1
            RingInventory:SetChosenItem(nil)
            LevelVars.Engine.RingInventory.InventoryOpen = true
            inventoryMode = InventoryStates.MODE.SEPARATE_COMPLETE
        end
    elseif inventoryMode == InventoryStates.MODE.SEPARATE_COMPLETE then
        Text.SetText("HEADER", "actions_inventory", true)
        if Animate.Inventory(inventoryMode) then
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
        if Animate.Inventory(inventoryMode) then
            inventoryMode = InventoryStates.MODE.RING_OPENING
        end
    elseif inventoryMode == InventoryStates.MODE.INVENTORY_EXIT then
        if Animate.Inventory(inventoryMode) then
            LevelFuncs.Engine.RingInventory.ExitInventory()
        end
    end
end

return InventoryStates