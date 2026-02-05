-- ============================================================================
-- MENU FUNCTIONS
-- ============================================================================
--External Modules
local Menu = require("Engine.RingInventory.Menu")
local PickupData = require("Engine.RingInventory.PickupData")
local Save = require("Engine.RingInventory.Save")
local InventoryData = require("Engine.RingInventory.InventoryData")
local InventoryStates= require("Engine.RingInventory.InventoryStates")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP
local INVENTORY_MODE = InventoryStates.MODE


local ItemMenu = {}

local function HasItemAction(packedFlags, flag)
    return (packedFlags & flag) ~= 0
end

local function HasChooseAmmo(menuActions)
    for _, flag in ipairs(PickupData.CHOOSE_AMMO_FLAGS) do
        if HasItemAction(menuActions, flag) then
            return true
        end
    end
    return false
end

function ItemMenu.IsSingleItemAction(item)
    
    local flags = item:GetMenuActions()

    return flags ~= 0 and (flags & (flags - 1)) == 0

end

function ItemMenu.ParseAction(item)

    local menuActions = item:GetMenuActions()

    if HasItemAction(menuActions, ItemAction.USE) or HasItemAction(menuActions, ItemAction.EQUIP) then
        InventoryStates.SetMode(INVENTORY_MODE.ITEM_USE)
    elseif HasItemAction(menuActions, ItemAction.EXAMINE) then
        InventoryStates.SetMode(INVENTORY_MODE.EXAMINE_OPEN)
    elseif HasItemAction(menuActions, ItemAction.COMBINE) then
        InventoryStates.SetMode(INVENTORY_MODE.COMBINE_SETUP)
    elseif HasItemAction(menuActions, ItemAction.STATISTICS) then
        InventoryStates.SetMode(INVENTORY_MODE.STATISTICS_OPEN)
    elseif HasItemAction(menuActions, ItemAction.SAVE) then
        Save.SetSaveMenu()
        InventoryStates.SetMode(INVENTORY_MODE.SAVE_SETUP)
    elseif HasItemAction(menuActions, ItemAction.LOAD) then
        Save.SetLoadMenu()
        InventoryStates.SetMode(INVENTORY_MODE.SAVE_SETUP)
    elseif HasItemAction(menuActions, ItemAction.SEPARATE) then
        InventoryStates.SetMode(INVENTORY_MODE.SEPARATE)
    elseif HasItemAction(menuActions, ItemAction.CHOOSE_AMMO_HK) then
        InventoryStates.SetMode(INVENTORY_MODE.WEAPON_MODE_SETUP)
    elseif HasChooseAmmo(menuActions) then
        InventoryStates.SetMode(INVENTORY_MODE.AMMO_SELECT_SETUP)
    end
end

function ItemMenu.DoItemAction()
    local menu = LevelVars.Engine.Menus["menuActions"]
    if not menu then return end
    
    local selectedItem = menu.items[menu.currentItem]
    if selectedItem and selectedItem.actionBit then
        ItemMenu.ParseAction(selectedItem.actionBit)
    end
end

function ItemMenu.Create(item)
    local menuActions = {}
    local itemData = InventoryData.GetInventoryItem(item)
    
    if not itemData then
        return
    end
    
    local itemMenuActions = itemData:GetMenuActions()

    for _, entry in ipairs(PickupData.ItemActionFlags) do
        if HasItemAction(itemMenuActions, entry.bit) then
            local allowInsert = true
            
            if entry.bit == ItemAction.COMBINE then
                local itemCount = InventoryData.GetCombineItemsCount(itemData:GetObjectID())
                allowInsert = (itemCount ~= 0)
            end
            
            if allowInsert then
                table.insert(menuActions, {
                    itemName = entry.string,
                    actionBit = entry.bit,
                    options = nil,
                    currentOption = 1
                })
            end
        end
    end
    
    local itemMenu = Menu.Create("menuActions", nil, menuActions, "Engine.RingInventory.DoItemAction", nil, Menu.Type.ITEMS_ONLY)
    
    itemMenu:SetItemsPosition(Vec2(50, 35))
    itemMenu:SetVisibility(true)
    itemMenu:SetLineSpacing(5.3)
    itemMenu:SetItemsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    itemMenu:SetItemsTranslate(true)
    itemMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, 1.5, nil, true)
    itemMenu:SetTitlePosition(Vec2(50, 4))
end

function ItemMenu.Show()
    Menu.AddActive("menuActions")
end

function ItemMenu.Hide()
    Menu.RemoveActive("menuActions")
end

-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.RingInventory)
-- ============================================================================
LevelFuncs.Engine.RingInventory.DoItemAction = ItemMenu.DoItemAction

return ItemMenu