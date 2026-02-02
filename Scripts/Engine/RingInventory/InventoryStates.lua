
--External Modules
local Animate = require("Engine.RingInventory.Animation")
local Examine =  require("Engine.RingInventory.Examine")
local Interpolate = require("Engine.RingInventory.Interpolate")
local RingInventory = require("Engine.RingInventory.Inventory")
local InventoryData= require("Engine.RingInventory.InventoryData")
local PICKUP_DATA = require("Engine.RingInventory.PickupData")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointers to tables
local CONSTANTS = require("Engine.RingInventory.Constants")
local INVENTORY_MODE = PICKUP_DATA.INVENTORY_MODE
local COLOR_MAP = Settings.COLOR_MAP

local InventoryStates = {}

function InventoryStates.SetState(mode)
    local selectedItem = GetSelectedItem(selectedRing)
    
    if mode == INVENTORY_MODE.INVENTORY then
        RotateItem(tostring(selectedItem.objectID))
        ShowChosenAmmo(selectedItem.objectID, true)
        DrawItemLabel(selectedItem, true)
    elseif mode == INVENTORY_MODE.RING_OPENING then
        if AnimateInventory(mode) then
            if saveSelected then
                itemStoreRotations = true
                inventoryMode = INVENTORY_MODE.SAVE_SETUP
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end
        end
    elseif mode == INVENTORY_MODE.RING_CLOSING then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY_EXIT
        end
    elseif mode == INVENTORY_MODE.RING_ROTATE then
        if AnimateInventory(mode) then
            currentRingAngle = targetRingAngle
            if previousMode then
                inventoryMode = previousMode
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end
        end
    elseif mode == INVENTORY_MODE.RING_CHANGE then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
            for index, _ in ipairs(inventory.selectedItem) do
                inventory.selectedItem[index] = 1
            end
            currentRingAngle = 0
            targetRingAngle = 0
        end
    elseif mode == INVENTORY_MODE.EXAMINE_OPEN then
        SaveItemData(selectedItem)
        DeleteChosenAmmo()
        SetInventoryHeader("examine", true)
        if combineItem1 or AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.EXAMINE
        end
    elseif mode == INVENTORY_MODE.EXAMINE then
        ExamineItem(selectedItem.objectID)
    elseif mode == INVENTORY_MODE.EXAMINE_RESET then
        if AnimateInventory(mode) then
            examineScaler = examineScalerOld
            inventoryMode = INVENTORY_MODE.EXAMINE_CLOSE
        end
    elseif mode == INVENTORY_MODE.EXAMINE_CLOSE then
        SetInventoryHeader("actions_inventory", true)
        if combineItem1 or AnimateInventory(mode) then
            inventoryMode = combineItem1 and INVENTORY_MODE.ITEM_SELECTED or INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.ITEM_SELECT then
        SaveItemData(selectedItem)
        if AnimateInventory(mode) then
            previousRingAngle = currentRingAngle
            combineItem1 = selectedItem.objectID
            SetInventoryHeader(selectedItem.name, true)
            CreateItemMenu(selectedItem.objectID)
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED
        end
    elseif mode == INVENTORY_MODE.ITEM_SELECTED then
        ShowItemMenu()
        ShowChosenAmmo(combineItem1)
    elseif mode == INVENTORY_MODE.ITEM_DESELECT then
        DeleteChosenAmmo(true)
        SetInventoryHeader("actions_inventory", true)
        if AnimateInventory(mode) then
            combineItem1 = nil
            currentRingAngle = previousRingAngle
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.STATISTICS_OPEN then
        DeleteChosenAmmo()
        SaveItemData(selectedItem)
        CreateStatisticsMenu()
        SetInventoryHeader("actions_inventory", false)
        if combineItem1 or AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.STATISTICS
        end
    elseif mode == INVENTORY_MODE.STATISTICS then
        RunStatisticsMenu()
        Statistics.ShowLevelStats(statisticsType)
    elseif mode == INVENTORY_MODE.STATISTICS_CLOSE then
        if combineItem1 or AnimateInventory(mode) then
            SetInventoryHeader("actions_inventory", true)
            inventoryMode = combineItem1 and INVENTORY_MODE.ITEM_SELECTED or INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.SAVE_SETUP then
        DeleteChosenAmmo()
        SaveItemData(selectedItem)
        if combineItem1 or AnimateInventory(mode) then
            CreateSaveMenu(saveList)
            SetInventoryHeader("actions_inventory", false)
            inventoryMode = INVENTORY_MODE.SAVE_MENU
        end
    elseif mode == INVENTORY_MODE.SAVE_MENU then
        RunSaveMenu()
    elseif mode == INVENTORY_MODE.SAVE_CLOSE then
        if combineItem1 then
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED
        elseif AnimateInventory(mode) then
            SetInventoryHeader("actions_inventory", true)
            if saveSelected then
                saveSelected = false
                inventoryMode = INVENTORY_MODE.RING_CLOSING
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end
        end
    elseif mode == INVENTORY_MODE.COMBINE_SETUP then
        DeleteChosenAmmo()
        SaveItemData(selectedItem)
        if combineItem1 or AnimateInventory(mode) then
            SetupSecondaryRing(RING.COMBINE)
            SetInventoryHeader(selectedItem.name, true)
            SetInventorySubHeader("combine_with", true)
            inventoryMode = INVENTORY_MODE.COMBINE_RING_OPENING
        end
    elseif mode == INVENTORY_MODE.COMBINE_RING_OPENING then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.COMBINE
        end
    elseif mode == INVENTORY_MODE.COMBINE then
        RotateItem(tostring(selectedItem.objectID))
        DrawItemLabel(selectedItem, true)
        
        if performCombine then
            combineItem2 = GetSelectedItem(RING.COMBINE).objectID
            if CombineItems(combineItem1, combineItem2) then
                TEN.Sound.PlaySound(SOUND_MAP.MENU_COMBINE)
                inventoryMode = INVENTORY_MODE.COMBINE_SUCCESS
            else
                TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                performCombine = false
            end
        end
    elseif mode == INVENTORY_MODE.COMBINE_SUCCESS then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.COMBINE_CLOSE
        end
    elseif mode == INVENTORY_MODE.COMBINE_CLOSE then
        if AnimateInventory(mode) then
            SetInventorySubHeader("combine_with", false)
            SetInventoryHeader("actions_inventory", true)
            inventoryOpenItem = combineResult and combineResult or combineItem1
            combineItem1 = nil
            combineItem2 = nil
            combineResult = nil
            performCombine = false
            inventoryMode = INVENTORY_MODE.COMBINE_COMPLETE
            LevelVars.Engine.RingInventory.InventoryOpen = true
        end
    elseif mode == INVENTORY_MODE.COMBINE_COMPLETE then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.ITEM_USE then
        SaveItemData(selectedItem)
        DeleteChosenAmmo()
        SetInventoryHeader("actions_inventory", true)
        if AnimateInventory(mode) then
            UseItem(selectedItem.objectID)
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT_SETUP then
        SaveItemData(selectedItem)
        DeleteChosenAmmo()
        SetupSecondaryRing(RING.AMMO, combineItem1)
        inventoryMode = INVENTORY_MODE.AMMO_SELECT_OPEN
    elseif mode == INVENTORY_MODE.AMMO_SELECT_OPEN then
        if AnimateInventory(mode) then
            SetInventorySubHeader("choose_ammo", true)
            inventoryMode = INVENTORY_MODE.AMMO_SELECT
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT then
        RotateItem(tostring(selectedItem.objectID))
        DrawItemLabel(selectedItem, false)
        if performCombine then
            local ammo = PICKUP_DATA.AMMO_SET[selectedItem.objectID]
            Lara:SetAmmoType(ammo.slot)
            inventoryMode = INVENTORY_MODE.AMMO_SELECT_CLOSE
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT_CLOSE then
        if AnimateInventory(mode) then
            performCombine = false
            selectedRing = previousRing
            SetInventorySubHeader("choose_ammo", false)
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED
        end
    elseif mode == INVENTORY_MODE.SEPARATE then
        DeleteChosenAmmo()
        if AnimateInventory(mode) then
            SeparateItems(selectedItem.objectID)
            inventoryOpenItem = combineItem1
            combineItem1 = nil
            LevelVars.Engine.RingInventory.InventoryOpen = true
            inventoryMode = INVENTORY_MODE.SEPARATE_COMPLETE
        end
    elseif mode == INVENTORY_MODE.SEPARATE_COMPLETE then
        SetInventoryHeader("actions_inventory", true)
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.WEAPON_MODE_SETUP then
        CreateWeaponModeMenu(combineItem1)
        SetInventorySubHeader("choose_ammo", true)
        inventoryMode = INVENTORY_MODE.WEAPON_MODE
    elseif mode == INVENTORY_MODE.WEAPON_MODE then
        RunWeaponModeMenu()
    elseif mode == INVENTORY_MODE.WEAPON_MODE_CLOSE then
        SetInventorySubHeader("choose_ammo", false)
        inventoryMode = INVENTORY_MODE.ITEM_SELECTED
    elseif mode == INVENTORY_MODE.INVENTORY_OPENING then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.RING_OPENING
        end
    elseif mode == INVENTORY_MODE.INVENTORY_EXIT then
        if AnimateInventory(mode) then
            ExitInventory()
        end
    end
end

return InventoryStates