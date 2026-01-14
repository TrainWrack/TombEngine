--Code for weapon mode menu and setting

--External Modules
local Menu = require("Engine.CustomMenu")
local Settings = require("Engine.CustomInventory.Settings")

--Pointers to tables
local PICKUP_DATA = require("Engine.CustomInventory.PickupData")
local COLOR_MAP = Settings.COLOR_MAP

local WeaponMode = {}

function WeaponMode.ChangeWeaponMode()
    local index = Menu.Get("WeaponModeMenu"):getCurrentItemIndex()
    Lara:SetWeaponMode(index)
end

function WeaponMode.CreateWeaponModeMenu(itemData)
    
    local weaponModes = {}
    
    for _, entry in ipairs(PICKUP_DATA.WEAPON_MODE_LOOKUP) do
        if entry.weapon == itemData.objectID then
            table.insert(weaponModes, {
                itemName = entry.string,
                actionBit = entry.bit,
                options = nil,
                currentOption = 1
            })
        end
    end
    
    local modeIndex = Lara:GetWeaponMode()
    local itemMenu = Menu.Create("WeaponModeMenu", nil, weaponModes, "Engine.CustomInventory.ChangeWeaponMode", nil, Menu.Type.ITEMS_ONLY)
    
    itemMenu:SetItemsPosition(Vec2(50, 35))
    itemMenu:SetVisibility(true)
    itemMenu:SetLineSpacing(5.3)
    itemMenu:SetItemsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    itemMenu:SetItemsTranslate(true)
    itemMenu:setCurrentItem(modeIndex)
    itemMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, nil, nil, true)
end

function WeaponMode.RunWeaponModeMenu()
    local weaponModeMenu = Menu.Get("WeaponModeMenu")
    weaponModeMenu:Draw()
end


-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.CustomInventory)
-- ============================================================================
LevelFuncs.Engine.CustomInventory = LevelFuncs.Engine.CustomInventory or {}
LevelFuncs.Engine.CustomInventory.ChangeWeaponMode = WeaponMode.ChangeWeaponMode

return WeaponMode