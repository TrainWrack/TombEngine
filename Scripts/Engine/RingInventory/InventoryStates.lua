
--External Modules
local AmmoItem = require("Engine.RingInventory.AmmoItem")
local Animation = require("Engine.RingInventory.Animation")
local Combine = require("Engine.RingInventory.Combine")
local Constants = require("Engine.RingInventory.Constants")
local Examine =  require("Engine.RingInventory.Examine")
local Menu = require("Engine.RingInventory.Menu")
local InventoryData= require("Engine.RingInventory.InventoryData")
local Interpolate = require("Engine.RingInventory.Interpolate")
local ItemMenu
local Inputs
local ItemSpin = require("Engine.RingInventory.ItemSpin")
local ItemLight = require("Engine.RingInventory.ItemLight")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")
local Statistics = require("Engine.RingInventory.Statistics")
local Save = require("Engine.RingInventory.Save")
local Text = require("Engine.RingInventory.Text")
local WeaponMode =  require("Engine.RingInventory.WeaponMode")

--Pointers to tables
ANIM_SETTINGS = Settings.ANIMATION
COLOR_MAP = Settings.COLOR_MAP
SOUND_MAP = Settings.SOUND_MAP


--Variables
local inventoryClosed = false

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
	INVENTORY_OPENING = 36,
    STATISTICS_SETUP = 37
}

local inventoryMode = InventoryStates.MODE.INVENTORY_OPENING
local previousMode = nil
local performAction = false
local onEnter = true
local timeInMenu = 0

function InventoryStates.GetActionCheck()

    return performAction

end

function InventoryStates.SetActionCheck(check)

    performAction = check

end

function InventoryStates.SetInventoryClosed(status)

    inventoryClosed = status

end

function InventoryStates.GetInventoryClosed()

    return inventoryClosed

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

function InventoryStates.UpdateItem(selectedItem)
    
    AmmoItem.Show(selectedItem, true)
    Text.SetItemLabel(selectedItem)
    ItemLight.FadeIn(selectedItem, COLOR_MAP.ITEM_SELECTED)
    ItemSpin.StartSpin(selectedItem)

end

function InventoryStates.Update()

    timeInMenu = timeInMenu + 1

    if not Inputs then
        Inputs = require("Engine.RingInventory.Input")
    end

    local selectedRing = InventoryData.GetSelectedRing()
    local selectedItem = selectedRing:GetSelectedItem()
    
    if inventoryMode == InventoryStates.MODE.INVENTORY then
            
    elseif inventoryMode == InventoryStates.MODE.RING_OPENING then
        if Save.IsQuickSaveEnabled() then
            Animation.EnableSaveItemData()
            InventoryStates.SetMode(InventoryStates.MODE.SAVE_SETUP)
        elseif Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            local selectedRing = InventoryData.GetSelectedRing()
            local selectedItem = selectedRing:GetSelectedItem()
            ItemSpin.Initialize(selectedRing:GetType())
            InventoryStates.UpdateItem(selectedItem)
            ItemLight.SetOriginalColor(selectedItem, COLOR_MAP.ITEM_DESELECTED)
            InventoryStates.SetMode(InventoryStates.MODE.INVENTORY)
        end
    elseif inventoryMode == InventoryStates.MODE.RING_CLOSING then
            if onEnter then
                Text.Hide("ITEM_LABEL_PRIMARY")
                Text.Hide("ITEM_LABEL_SECONDARY")
                Text.Hide("HEADER")
                Text.Hide("SUB_HEADER")
                onEnter = false
            end
        if  ANIM_SETTINGS.SKIP_RING_CLOSE or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            InventoryStates.SetMode(InventoryStates.MODE.INVENTORY_EXIT)
        end
    elseif inventoryMode == InventoryStates.MODE.RING_ROTATE then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            selectedRing:SetCurrentAngle(selectedRing:GetTargetAngle())
            InventoryStates.UpdateItem(selectedItem)
            if previousMode then
                inventoryMode = previousMode
            else
                InventoryStates.SetMode(InventoryStates.MODE.INVENTORY)
            end
        end
    elseif inventoryMode == InventoryStates.MODE.RING_CHANGE then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            ItemSpin.Initialize(selectedRing:GetType(), 0)
            InventoryStates.UpdateItem(selectedItem)
            InventoryStates.SetMode(InventoryStates.MODE.INVENTORY)
        end
    elseif inventoryMode == InventoryStates.MODE.EXAMINE_OPEN then
        if onEnter then
            Animation.SaveItemData(selectedItem)
            AmmoItem.Hide()
            Text.SetText("HEADER", "examine", true)
            onEnter = false
        end
        if InventoryData.IsItemChosen() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            InventoryStates.SetMode(InventoryStates.MODE.EXAMINE)
        end
    elseif inventoryMode == InventoryStates.MODE.EXAMINE then
        Examine.Item(selectedItem)
    elseif inventoryMode == InventoryStates.MODE.EXAMINE_RESET then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            InventoryStates.SetMode(InventoryStates.MODE.EXAMINE_CLOSE)
        end
    elseif inventoryMode == InventoryStates.MODE.EXAMINE_CLOSE then
        if onEnter then
            Text.SetText("HEADER", "actions_inventory", true)
            onEnter = false
        end
        if InventoryData.IsItemChosen() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            InventoryStates.SetMode(InventoryData.IsItemChosen() and InventoryStates.MODE.ITEM_SELECTED or InventoryStates.MODE.INVENTORY)
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_SELECT then
        if onEnter then
            Animation.SaveItemData(selectedItem)
            onEnter = false
        end
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            InventoryData.SetChosenItem(selectedItem)
            ItemSpin.StopSpin()
            Text.Hide("ITEM_LABEL_PRIMARY")
            Text.SetText("HEADER", selectedItem.name, true)
            ItemMenu = require("Engine.RingInventory.ItemMenu")
            ItemMenu.Create(selectedItem)
            ItemMenu.Show()
            AmmoItem.Show(InventoryData.GetChosenItem(), false)
            InventoryStates.SetMode(InventoryStates.MODE.ITEM_SELECTED)
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_SELECTED then
        
    elseif inventoryMode == InventoryStates.MODE.ITEM_DESELECT then
        if onEnter then
            AmmoItem.Hide()
            Text.SetText("HEADER", "actions_inventory", true)
            ItemMenu.Hide()
            InventoryStates.UpdateItem(selectedItem)
            onEnter = false
        end
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            InventoryData.SetChosenItem(nil)
            onEnter = true
            InventoryStates.SetMode(InventoryStates.MODE.INVENTORY)
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_USE then
        if onEnter then
            Animation.SaveItemData(selectedItem)
            AmmoItem.Hide()
            Text.SetText("HEADER", "actions_inventory", true)
            onEnter = false
        end
        if ANIM_SETTINGS.SKIP_RING_CLOSE or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            TEN.Inventory.UseItem(selectedItem.objectID)
            InventoryStates.SetMode(InventoryStates.MODE.RING_CLOSING)
            --UseItem.Item(selectedItem.objectID)
        end
    elseif inventoryMode == InventoryStates.MODE.STATISTICS_SETUP then
        AmmoItem.Hide()
        Text.Hide("ITEM_LABEL_PRIMARY")
        ItemSpin.StopSpin()
        Animation.SaveItemData(selectedItem)
        Statistics.SetupStats()
        Statistics.CreateStatisticsMenu()
        Text.SetText("HEADER", "statistics", true)
        Statistics.Show()
        inventoryMode = InventoryStates.MODE.STATISTICS_OPEN
    elseif inventoryMode == InventoryStates.MODE.STATISTICS_OPEN then
        if InventoryData.IsItemChosen() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            inventoryMode = InventoryStates.MODE.STATISTICS
        end
    elseif inventoryMode == InventoryStates.MODE.STATISTICS then
        
    elseif inventoryMode == InventoryStates.MODE.STATISTICS_CLOSE then
        if onEnter then
            Statistics.Hide()
            Text.SetText("HEADER", "actions_inventory", true)
            InventoryStates.UpdateItem(selectedItem)
            onEnter = false
        end
        if InventoryData.IsItemChosen() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            inventoryMode = InventoryData.IsItemChosen() and InventoryStates.MODE.ITEM_SELECTED or InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.SAVE_SETUP then
        if onEnter then
            AmmoItem.Hide()
            if Save.IsLoadMenu() then
                Text.SetText("HEADER", "load_game", true)
            else
                Text.SetText("HEADER", "save_game", true)
            end
            onEnter = false
        end

        Animation.SaveItemData(selectedItem)
        if Save.IsQuickSaveEnabled() or InventoryData.IsItemChosen() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            Save.CreateSaveMenu()
            Save.Show()
            onEnter = true
            inventoryMode = InventoryStates.MODE.SAVE_MENU
        end
    elseif inventoryMode == InventoryStates.MODE.SAVE_MENU then
        
    elseif inventoryMode == InventoryStates.MODE.SAVE_CLOSE then
        if InventoryData.IsItemChosen() then
            inventoryMode = InventoryStates.MODE.ITEM_SELECTED
        elseif Save.IsQuickSaveEnabled() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            if Save.IsSaveSelected() or Save.IsQuickSaveEnabled() then
                Save.ClearSaveSelected()
                Save.SetQuickSaveStatus(false)
                inventoryMode = InventoryStates.MODE.INVENTORY_EXIT
            else
                Text.SetText("HEADER", "actions_inventory", true)
                inventoryMode = InventoryStates.MODE.INVENTORY
            end
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_SETUP then
        if onEnter then
            AmmoItem.Hide()
            Animation.SaveItemData(selectedItem)
            onEnter = false
        end
        if InventoryData.IsItemChosen() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            local ring = require("Engine.RingInventory.Ring")
            InventoryData.SetupSecondaryRing(ring.TYPE.COMBINE)
            Text.SetText("HEADER", selectedItem.name, true)
            Text.SetText("SUB_HEADER", "combine_with", true)
            inventoryMode = InventoryStates.MODE.COMBINE_RING_OPENING
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_RING_OPENING then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            InventoryStates.UpdateItem(selectedItem)
            inventoryMode = InventoryStates.MODE.COMBINE
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE then

        if InventoryStates.GetActionCheck() then
        
            if Combine.CombineItems(InventoryData.GetChosenItem(), selectedItem) then
                TEN.Sound.PlaySound(SOUND_MAP.MENU_COMBINE)
                inventoryMode = InventoryStates.MODE.COMBINE_SUCCESS
            else
                TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                InventoryStates.SetActionCheck(false)
            end
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_SUCCESS then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            inventoryMode = InventoryStates.MODE.COMBINE_CLOSE
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_CLOSE then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            Text.Hide("SUB_HEADER")
            Text.SetText("HEADER", "actions_inventory", true)
            InventoryData.SetOpenAtItem(Combine.GetResults() and Combine.GetResults() or InventoryData.GetChosenItem())
            InventoryData.SetChosenItem()
            InventoryStates.SetActionCheck(false)
            inventoryMode = InventoryStates.MODE.COMBINE_COMPLETE
            LevelVars.Engine.RingInventory.InventoryOpen = true
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_COMPLETE then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            inventoryMode = InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.SEPARATE then
        if onEnter then
            AmmoItem.Hide()
            onEnter = false
        end
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            Combine.SeparateItems(selectedItem)
            InventoryData.SetOpenAtItem(Combine.GetResults())
            InventoryData.SetChosenItem(nil)
            LevelVars.Engine.RingInventory.InventoryOpen = true
            inventoryMode = InventoryStates.MODE.SEPARATE_COMPLETE
        end
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_SETUP then
        Animation.SaveItemData(selectedItem)
        AmmoItem.Hide()
        local ring = require("Engine.RingInventory.Ring")
        InventoryData.SetupSecondaryRing(ring.TYPE.AMMO, InventoryData.GetChosenItem())
        inventoryMode = InventoryStates.MODE.AMMO_SELECT_OPEN
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_OPEN then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            ItemMenu.Hide()
            Text.SetText("SUB_HEADER", "choose_ammo", true)
            InventoryStates.UpdateItem(selectedItem)
            inventoryMode = InventoryStates.MODE.AMMO_SELECT
        end
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT then
        if InventoryStates.GetActionCheck() then
            local ammo = PICKUP_DATA.AMMO_SET[selectedItem.objectID]
            Lara:SetAmmoType(ammo.slot)
            inventoryMode = InventoryStates.MODE.AMMO_SELECT_CLOSE
        end
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_CLOSE then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            InventoryStates.SetActionCheck(false)
            InventoryData.ReturnToPreviousRing()
            Text.Hide("SUB_HEADER")
            ItemMenu.Show()
            InventoryStates.UpdateItem(selectedItem)
            inventoryMode = InventoryStates.MODE.ITEM_SELECTED
        end
    elseif inventoryMode == InventoryStates.MODE.SEPARATE_COMPLETE then
        if onEnter then
            Text.SetText("HEADER", "actions_inventory", true)
            onEnter = false
        end
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            inventoryMode = InventoryStates.MODE.INVENTORY
        end
    elseif inventoryMode == InventoryStates.MODE.WEAPON_MODE_SETUP then
        Text.SetText("SUB_HEADER", "choose_ammo", true)
        WeaponMode.CreateWeaponModeMenu(selectedItem)
        WeaponMode.Show()
        ItemMenu.Hide()
        inventoryMode = InventoryStates.MODE.WEAPON_MODE
    elseif inventoryMode == InventoryStates.MODE.WEAPON_MODE then
        
    elseif inventoryMode == InventoryStates.MODE.WEAPON_MODE_CLOSE then
        WeaponMode.Hide()
        ItemMenu.Show()
        Text.Hide("SUB_HEADER")
        AmmoItem.Show(InventoryData.GetChosenItem(), false)
        inventoryMode = InventoryStates.MODE.ITEM_SELECTED
    elseif inventoryMode == InventoryStates.MODE.INVENTORY_OPENING then
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        Text.Setup()
        if Save.IsQuickSaveEnabled() then
            InventoryStates.SetMode(InventoryStates.MODE.SAVE_SETUP)
        else
            Text.SetText("HEADER", "actions_inventory", true)
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_OPEN)
            InventoryData.Construct()
            InventoryData.OpenAtItem(InventoryData.GetOpenAtItem(), true)
            inventoryMode = InventoryStates.MODE.RING_OPENING
        end
    elseif inventoryMode == InventoryStates.MODE.INVENTORY_EXIT then
        InventoryData.Reset()
        TEN.Inventory.SetFocusedItem(Constants.NO_VALUE)
        Interpolate.ClearAll()
        Menu.DeleteAll()
        InventoryStates.SetMode(InventoryStates.MODE.INVENTORY_OPENING)
        InventoryData.SwitchToRing(Ring.TYPE.MAIN)
        TEN.View.DisplayItem.ResetCamera()
        Text.DestroyAll()
        timeInMenu = 0
        InventoryData.SetChosenItem()
        InventoryStates.SetInventoryClosed(true)
        Flow.SetFreezeMode(Flow.FreezeMode.NONE)
    end

    Statistics.UpdateStatistics()
    
    Menu.UpdateActiveMenus()
    Menu.DrawActiveMenus()
    ItemLight.Update()
    ItemSpin.Update()
    InventoryData.SetItemRotations(timeInMenu)
    Inputs.Update(timeInMenu)
    InventoryData.DrawAllRings()
    Text.Update()
    Text.DrawAll()
    
end

return InventoryStates