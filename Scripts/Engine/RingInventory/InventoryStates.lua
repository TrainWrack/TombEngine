
--External Modules
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
local PickupData = require("Engine.RingInventory.PickupData")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")
local Statistics = require("Engine.RingInventory.Statistics")
local Save = require("Engine.RingInventory.Save")
local Sprites = require("Engine.RingInventory.Sprites")
local Text = require("Engine.RingInventory.Text")
local WeaponMode =  require("Engine.RingInventory.WeaponMode")

--Pointers to tables
local ANIM_SETTINGS = Settings.ANIMATION
local COLOR_MAP = Settings.COLOR_MAP
local SOUND_MAP = Settings.SOUND_MAP

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

local function UpdateActionLabel(itemSelected, override)

    local string = nil

    if  itemSelected and ItemMenu.IsSingleItemAction(itemSelected) then
        local itemActions = itemSelected:GetMenuActions()
        for _, entry in ipairs(PickupData.ItemActionFlags) do
            if ItemMenu.HasItemAction(itemActions, entry.bit) then
                string = Flow.GetString(entry.string)
                break
            end
        end
    elseif override then
        string = Flow.GetString(override)
    else
        string = Flow.GetString("actions_select")
    end

    local actionString = Input.GetActionBinding(ActionID.SELECT)..": "..string

    Text.SetText("CONTROLS_SELECT", actionString, true)

end

local function UpdateBackLabel(label)
    
    local backstring

    if label then
        backstring = label
    else
        backstring = "close"
    end

    local string = Input.GetActionBinding(ActionID.DESELECT)..": "..Flow.GetString(backstring)
    Text.SetText("CONTROLS_BACK", string, true)
end

local function ExamineLabel(showText)

    local string = ""

    if showText then
        string = string..Input.GetActionBinding(ActionID.ACTION)..": "..Flow.GetString("toggle_text")
    end

    string = string.." "..
            Input.GetActionBinding(ActionID.JUMP)..": "..Flow.GetString("reset").."\n"..
            Input.GetActionBinding(ActionID.SPRINT)..": "..Flow.GetString("zoom_in").." "..
            Input.GetActionBinding(ActionID.CROUCH)..": "..Flow.GetString("zoom_out")
            
    return string

end


local function ShowSelectedAmmoName(weaponItem)

    if not weaponItem or weaponItem:GetType() ~= PickupData.TYPE.WEAPON then
        Text.Hide("ITEM_LABEL_SECONDARY")
        return
    end

    local itemObjectID = weaponItem:GetObjectID()

    if not itemObjectID then
        Text.Hide("ITEM_LABEL_SECONDARY")
        return
    end

    local weaponSlot = PickupData.WEAPON_SET[itemObjectID].slot

    local ammoType = Lara:GetAmmoType(weaponSlot)
    
    if not ammoType then
        Text.Hide("ITEM_LABEL_SECONDARY")
        return
    end
    
    local objectID = PickupData.AMMO_TYPE_TO_OBJECT[ammoType]
    
    if not objectID then return end
    
    local base  = PickupData.GetProperties(objectID)
    local data = InventoryData.BuildItem(base)
 
    Text.SetItemSubLabel(data)

end

local function CreateAmmoRing(item)

    if PickupData.WEAPON_SET[item:GetObjectID()] then
        local ammoRing = InventoryData.SetupSecondaryRing(Ring.TYPE.AMMO, InventoryData.GetChosenItem(), true)
        ammoRing:Color(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_SELECTED)
        ItemSpin.StartSpin(ammoRing)
        Text.SetItemLabel(ammoRing:GetSelectedItem())
    end

end

local function ShowAmmoRing(item)

    if PickupData.WEAPON_SET[item:GetObjectID()] then
        local ammoRing = InventoryData.GetRing(Ring.TYPE.AMMO)
        ammoRing:Color(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_SELECTED)
        ItemSpin.StartSpin(ammoRing)
        Text.SetItemLabel(ammoRing:GetSelectedItem())
    end

end

local function HideAmmoRing(item)

    if PickupData.WEAPON_SET[item:GetObjectID()] then
        local ammoRing = InventoryData.GetRing(Ring.TYPE.AMMO)
        ammoRing:Color(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_HIDDEN)
        ItemSpin.StopSelectedItemSpin(ammoRing)
    end

end

function InventoryStates.Update()

    timeInMenu = timeInMenu + 1

    if not Inputs then
        Inputs = require("Engine.RingInventory.Input")
    end

    if not ItemMenu then
        ItemMenu = require("Engine.RingInventory.ItemMenu")
    end

    local selectedRing = InventoryData.GetSelectedRing()
    local selectedItem = selectedRing:GetSelectedItem()
    
    if inventoryMode == InventoryStates.MODE.INVENTORY then

    elseif inventoryMode == InventoryStates.MODE.INVENTORY_OPENING then
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        Text.Setup()
        Sprites.ShowBackground()
        Sprites.ShowArrows()
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
        Sprites.Clear()
        TEN.Inventory.SetFocusedItem(Constants.NO_VALUE)
        Interpolate.ClearAll()
        ItemSpin.Reset()
        Menu.DeleteAll()
        InventoryStates.SetMode(InventoryStates.MODE.INVENTORY_OPENING)
        InventoryData.SwitchToRingType(Ring.TYPE.MAIN)
        TEN.View.DisplayItem.ResetCamera()
        Text.DestroyAll()
        timeInMenu = 0
        InventoryData.SetChosenItem()
        InventoryStates.SetInventoryClosed(true)
        InventoryData.ClearAll()
        Flow.SetFreezeMode(Flow.FreezeMode.NONE)       
    elseif inventoryMode == InventoryStates.MODE.RING_OPENING then
        if onEnter then
            selectedRing:Color(COLOR_MAP.ITEM_DESELECTED, COLOR_MAP.ITEM_SELECTED)
            ItemSpin.StartSpin(selectedRing)
            onEnter = false
        end
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            local selectedRing = InventoryData.GetSelectedRing()
            local selectedItem = selectedRing:GetSelectedItem()
            Text.SetItemLabel(selectedItem)
            Text.SetText("HEADER", "actions_inventory", true)
            UpdateActionLabel(selectedItem)
            UpdateBackLabel()
            ShowSelectedAmmoName(selectedItem)
            onEnter = true
            InventoryData.ColorAll(COLOR_MAP.ITEM_DESELECTED, COLOR_MAP.ITEM_SELECTED, true)
            InventoryStates.SetMode(InventoryStates.MODE.INVENTORY)
        end
    elseif inventoryMode == InventoryStates.MODE.RING_CLOSING then
        if onEnter then
            Text.Hide("ITEM_LABEL_PRIMARY")
            Text.Hide("ITEM_LABEL_SECONDARY")
            Text.Hide("HEADER")
            Text.Hide("SUB_HEADER")
            Text.Hide("CONTROLS_SELECT")
            Text.Hide("CONTROLS_BACK")
            InventoryData.ColorAll(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_HIDDEN)
            Sprites.HideBackground()
            Sprites.HideArrows()
            InventoryData.SetVisibility(false, true)
            onEnter = false
        end
        if ANIM_SETTINGS.SKIP_RING_CLOSE or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            InventoryStates.SetMode(InventoryStates.MODE.INVENTORY_EXIT)
        end
    elseif inventoryMode == InventoryStates.MODE.RING_ROTATE then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            selectedRing:SetCurrentAngle(selectedRing:GetTargetAngle())
            Text.SetItemLabel(selectedItem)
            UpdateActionLabel(selectedItem)
            ShowSelectedAmmoName(selectedItem)
            if previousMode then
                inventoryMode = previousMode
            else
                InventoryStates.SetMode(InventoryStates.MODE.INVENTORY)
            end
        end
    elseif inventoryMode == InventoryStates.MODE.RING_CHANGE then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            ItemSpin.StartSpin(selectedRing)
            Text.SetItemLabel(selectedItem)
            UpdateActionLabel(selectedItem)
            ShowSelectedAmmoName(selectedItem)
            InventoryStates.SetMode(InventoryStates.MODE.INVENTORY)
        end
    elseif inventoryMode == InventoryStates.MODE.EXAMINE_OPEN then

            Animation.SaveItemData(selectedItem)
            ItemMenu.Hide()
            Text.SetText("HEADER", "examine", true)
            Text.Hide("ITEM_LABEL_SECONDARY")
            Text.Hide("ITEM_LABEL_PRIMARY")
            selectedRing:Color(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_HIDDEN)
            Examine.Show(selectedItem)
            Text.SetText("CONTROLS_SELECT", ExamineLabel(Examine.TextStatus()), true)
            UpdateBackLabel("back")
            Sprites.HideArrows()
            HideAmmoRing(selectedItem)
            InventoryStates.SetMode(InventoryStates.MODE.EXAMINE)

    elseif inventoryMode == InventoryStates.MODE.EXAMINE then

        if InventoryStates.GetActionCheck() then
            Examine.ResetExamine(selectedItem)
            InventoryStates.SetActionCheck(false)
        end

    elseif inventoryMode == InventoryStates.MODE.EXAMINE_CLOSE then
        
        local isItemChosen = InventoryData.IsItemChosen()
        Examine.Hide()
        if isItemChosen then
            ItemMenu.Show()
            Text.SetText("HEADER", selectedItem:GetName(), true)
            ShowAmmoRing(selectedItem)
            selectedRing:Color(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_SELECTED)
            UpdateActionLabel()
            UpdateBackLabel("actions_deselect")
            InventoryStates.SetMode(InventoryStates.MODE.ITEM_SELECTED)
        else
            Text.SetText("HEADER", "actions_inventory", true)
            Text.SetItemLabel(selectedItem)
            UpdateActionLabel(selectedItem)
            UpdateBackLabel()
            Sprites.ShowArrows()
            selectedRing:Color(COLOR_MAP.ITEM_DESELECTED, COLOR_MAP.ITEM_SELECTED)
            InventoryStates.SetMode(InventoryStates.MODE.INVENTORY)
        end

    elseif inventoryMode == InventoryStates.MODE.ITEM_SELECT then
        if onEnter then
            ItemSpin.StopSelectedItemSpin(selectedRing)
            Animation.SaveItemData(selectedItem)
            InventoryData.SetChosenItem(selectedItem)
            selectedRing:Color(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_SELECTED)
            Text.SetText("HEADER", selectedItem:GetName(), true)
            Text.Hide("ITEM_LABEL_SECONDARY")
            Text.Hide("ITEM_LABEL_PRIMARY")
            UpdateActionLabel()
            UpdateBackLabel("actions_deselect")
            ItemMenu.Create(selectedItem)
            ItemMenu.Show()
            Sprites.HideArrows()
            CreateAmmoRing(selectedItem)
            onEnter = false
        end
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            InventoryStates.SetMode(InventoryStates.MODE.ITEM_SELECTED)
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_SELECTED then
        
    elseif inventoryMode == InventoryStates.MODE.ITEM_DESELECT then
        if onEnter then
            Text.SetText("HEADER", "actions_inventory", true)
            ItemMenu.Hide()
            Text.SetItemLabel(selectedItem)
            UpdateActionLabel(selectedItem)
            UpdateBackLabel()
            selectedRing:Color(COLOR_MAP.ITEM_DESELECTED, COLOR_MAP.ITEM_SELECTED)
            ShowSelectedAmmoName(selectedItem)
            local ammoRing = InventoryData.GetRing(Ring.TYPE.AMMO)
            ItemSpin.StopSpin(ammoRing)
            ammoRing:Color(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_HIDDEN)
            Sprites.ShowArrows()
            onEnter = false
        end
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            InventoryData.SetChosenItem(nil)
            ItemSpin.StartSelectedItemSpin(selectedRing)
            onEnter = true
            InventoryStates.SetMode(InventoryStates.MODE.INVENTORY)
        end
    elseif inventoryMode == InventoryStates.MODE.ITEM_USE then
        if onEnter then
            Text.Hide("ITEM_LABEL_PRIMARY")
            Text.Hide("ITEM_LABEL_SECONDARY")
            Text.Hide("HEADER")
            Text.Hide("SUB_HEADER")
            InventoryData.ColorAll(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_HIDDEN, true)
            onEnter = false
        end
        if ANIM_SETTINGS.SKIP_RING_CLOSE or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            TEN.Inventory.UseItem(selectedItem.objectID)
            InventoryStates.SetMode(InventoryStates.MODE.RING_CLOSING)
        end
    elseif inventoryMode == InventoryStates.MODE.STATISTICS_OPEN then
        if onEnter then
            Text.Hide("ITEM_LABEL_PRIMARY")
            Animation.SaveItemData(selectedItem)
            Statistics.SetupStats()
            Text.SetText("HEADER", "statistics", true)
            UpdateBackLabel("back")
            ItemSpin.StopSelectedItemSpin(selectedRing)
            Statistics.Show()
            Sprites.HideArrows()
            selectedRing:Color(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_SELECTED)
            if InventoryData.IsItemChosen() then
                ItemMenu.Hide()
                HideAmmoRing(selectedItem)
            end

            if Settings.STATISTICS.GAME_STATS then
                UpdateActionLabel(nil, "game_statistics")
            else
                Text.Hide("CONTROLS_SELECT")
            end
            onEnter = false
        end
        if InventoryData.IsItemChosen() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            inventoryMode = InventoryStates.MODE.STATISTICS
        end
    elseif inventoryMode == InventoryStates.MODE.STATISTICS then
        
        if InventoryStates.GetActionCheck() then
            Statistics.ToggleType()
            if Statistics.GetType() then
                UpdateActionLabel(nil, "level_statistics")
            else
                UpdateActionLabel(nil, "game_statistics")
            end
            InventoryStates.SetActionCheck(false)
        end
    elseif inventoryMode == InventoryStates.MODE.STATISTICS_CLOSE then
        
        local isItemChosen = InventoryData.IsItemChosen()
        
        if onEnter then
            Statistics.Hide()

            if not isItemChosen then
                selectedRing:Color(COLOR_MAP.ITEM_DESELECTED, COLOR_MAP.ITEM_SELECTED)
                Text.SetText("HEADER", "actions_inventory", true)
                Sprites.ShowArrows()
                UpdateActionLabel(selectedItem)
                UpdateBackLabel()
                ItemSpin.StartSelectedItemSpin(selectedRing)
            end

            onEnter = false
        end

        if isItemChosen or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            if isItemChosen then
                ItemMenu.Show()
                UpdateActionLabel()
                Text.SetText("HEADER", selectedItem:GetName(), true)
                ShowAmmoRing(selectedItem)
                InventoryStates.SetMode(InventoryStates.MODE.ITEM_SELECTED)
            else
                InventoryStates.SetMode(InventoryStates.MODE.INVENTORY)
            end
        end 
    elseif inventoryMode == InventoryStates.MODE.SAVE_SETUP then
        if onEnter then
            if Save.IsLoadMenu() then
                Text.SetText("HEADER", "load_game", true)
            else
                Text.SetText("HEADER", "save_game", true)
            end
            ItemMenu.Hide()
            Text.Hide("ITEM_LABEL_PRIMARY")
            Text.Hide("ITEM_LABEL_SECONDARY")
            Text.Hide("CONTROLS_SELECT")
            Text.Hide("CONTROLS_BACK")
            Animation.SaveItemData(selectedItem)
            ItemSpin.StopSelectedItemSpin(selectedRing)
            Sprites.HideArrows()
            if InventoryData.IsItemChosen() then
                ItemMenu.Hide()
                HideAmmoRing(selectedItem)
            end

            Save.CreateSaveMenu()
            Save.Show()

            onEnter = false
        end

        if Save.IsQuickSaveEnabled() or InventoryData.IsItemChosen() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            inventoryMode = InventoryStates.MODE.SAVE_MENU
        end
    elseif inventoryMode == InventoryStates.MODE.SAVE_MENU then
        
    elseif inventoryMode == InventoryStates.MODE.SAVE_CLOSE then
        if onEnter then
            Save.Hide()

            if not InventoryData.IsItemChosen() then
                UpdateActionLabel()
                UpdateBackLabel()
                Text.SetText("HEADER", "actions_inventory", true)
                Sprites.ShowArrows()
            end

            onEnter = false
        end

        if InventoryData.IsItemChosen() then
            ItemMenu.Show()
            ShowAmmoRing(selectedItem)
            Text.SetText("HEADER", selectedItem:GetName(), true)
            UpdateActionLabel()
            UpdateBackLabel()
            onEnter = true
            inventoryMode = InventoryStates.MODE.ITEM_SELECTED
        elseif Save.IsQuickSaveEnabled() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            if Save.IsSaveSelected() or Save.IsQuickSaveEnabled() then
                Save.ClearSaveSelected()
                Save.SetQuickSaveStatus(false)
                onEnter = true
                inventoryMode = InventoryStates.MODE.INVENTORY_EXIT
            else
                
                ItemSpin.StartSelectedItemSpin(selectedRing)
                onEnter = true
                inventoryMode = InventoryStates.MODE.INVENTORY
            end
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_SETUP then
        if onEnter then
            ItemMenu.Hide()
            Animation.SaveItemData(selectedItem)
            ItemSpin.StopSelectedItemSpin(selectedRing)
            selectedRing:Color(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_SELECTED)
            Sprites.HideArrows()
            onEnter = false
        end
        if InventoryData.IsItemChosen() or Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            onEnter = true
            InventoryData.SetChosenItem(selectedItem)
            HideAmmoRing(selectedItem)
            local combineRing = InventoryData.SetupSecondaryRing(Ring.TYPE.COMBINE)
            combineRing:Color(COLOR_MAP.ITEM_DESELECTED, COLOR_MAP.ITEM_SELECTED)
            Text.SetText("HEADER", selectedItem.name, true)
            Text.SetText("SUB_HEADER", "combine_with", true)
            inventoryMode = InventoryStates.MODE.COMBINE_RING_OPENING
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE_RING_OPENING then
        if Animation.Inventory(inventoryMode, selectedRing, selectedItem) then
            Text.SetItemLabel(selectedItem)
            UpdateActionLabel(selectedItem)
            inventoryMode = InventoryStates.MODE.COMBINE
        end
    elseif inventoryMode == InventoryStates.MODE.COMBINE then

        if InventoryStates.GetActionCheck() then
        
            if Combine.CombineItems(InventoryData.GetChosenItem(), selectedItem) then
                TEN.Sound.PlaySound(SOUND_MAP.MENU_COMBINE)
                Animation.SaveItemData(selectedItem)
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
        Text.Hide("SUB_HEADER")
        Text.SetText("HEADER", "actions_inventory", true)
        ItemMenu.Hide()
        InventoryData.SetOpenAtItem(Combine.GetResults() and Combine.GetResults() or InventoryData.GetChosenItem():GetObjectID())
        InventoryData.SetChosenItem()
        Combine.ClearResults()
        InventoryStates.SetActionCheck(false)
        InventoryData.ColorAll(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_HIDDEN)
        inventoryMode = InventoryStates.MODE.INVENTORY_OPENING
    elseif inventoryMode == InventoryStates.MODE.SEPARATE then
            Combine.SeparateItems(selectedItem)
            ItemMenu.Hide()
            Text.SetText("HEADER", "actions_inventory", true)
            InventoryData.SetOpenAtItem(Combine.GetResults())
            InventoryData.SetChosenItem(nil)
            inventoryMode = InventoryStates.MODE.INVENTORY_OPENING
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_OPEN then
            Animation.SaveItemData(selectedItem)
            local ammoRing = InventoryData.GetRing(Ring.TYPE.AMMO)
            ammoRing:Color(COLOR_MAP.ITEM_DESELECTED, COLOR_MAP.ITEM_SELECTED)
            InventoryData.SwitchToRingType(Ring.TYPE.AMMO)
            ItemMenu.Hide()
            UpdateActionLabel(ammoRing:GetSelectedItem())
            UpdateBackLabel("back")
            Text.SetText("SUB_HEADER", "choose_ammo", true)
            inventoryMode = InventoryStates.MODE.AMMO_SELECT
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT then
        if InventoryStates.GetActionCheck() then
            local ammo = PickupData.AMMO_SET[selectedItem.objectID]
            Lara:SetAmmoType(ammo.slot)
            inventoryMode = InventoryStates.MODE.AMMO_SELECT_CLOSE
        end
    elseif inventoryMode == InventoryStates.MODE.AMMO_SELECT_CLOSE then
            InventoryStates.SetActionCheck(false)
            InventoryData.ReturnToPreviousRing()
            InventoryData.GetRing(Ring.TYPE.AMMO):Color(COLOR_MAP.ITEM_HIDDEN, COLOR_MAP.ITEM_SELECTED)
            Text.Hide("SUB_HEADER")
            UpdateActionLabel()
            UpdateBackLabel("actions_deselect")
            ItemMenu.Show()
            Text.SetItemLabel(selectedItem)
            inventoryMode = InventoryStates.MODE.ITEM_SELECTED
    elseif inventoryMode == InventoryStates.MODE.WEAPON_MODE_SETUP then
        WeaponMode.CreateWeaponModeMenu(selectedItem)
        WeaponMode.Show()
        ItemMenu.Hide()
        UpdateBackLabel("back")
        inventoryMode = InventoryStates.MODE.WEAPON_MODE
    elseif inventoryMode == InventoryStates.MODE.WEAPON_MODE then
        
    elseif inventoryMode == InventoryStates.MODE.WEAPON_MODE_CLOSE then
        WeaponMode.Hide()
        UpdateBackLabel("actions_deselect")
        ItemMenu.Show()
        inventoryMode = InventoryStates.MODE.ITEM_SELECTED
    end

    Statistics.UpdateIngameTime()
    
    Examine.Update()
    Examine.Draw()
    Menu.UpdateActiveMenus()
    Menu.DrawActiveMenus()
    InventoryData.SetItemRotations(timeInMenu)
    Inputs.Update(inventoryMode, timeInMenu)
    InventoryData.DrawAllRings()
    Text.Update()
    Text.DrawAll()
    Sprites.Update(selectedRing)
    Sprites.Draw()
    
end

return InventoryStates