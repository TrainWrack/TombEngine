-- ============================================================================
-- WeaponMode - Handles weapon mode functions and data for ring inventory
-- ============================================================================

--External Modules
local Menu = require("Engine.RingInventory.Menu")
local Settings = require("Engine.RingInventory.Settings")

--Pointers to tables
local PICKUP_DATA = require("Engine.RingInventory.PickupData")
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
    local weaponModeMenu = Menu.Create("WeaponModeMenu", nil, weaponModes, "Engine.RingInventory.ChangeWeaponMode", nil, Menu.Type.ITEMS_ONLY)
    
    weaponModeMenu:SetItemsPosition(Vec2(50, 35))
    weaponModeMenu:SetVisibility(true)
    weaponModeMenu:SetLineSpacing(5.3)
    weaponModeMenu:SetItemsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    weaponModeMenu:SetItemsTranslate(true)
    weaponModeMenu:setCurrentItem(modeIndex)
    weaponModeMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, nil, nil, true)
end

function WeaponMode.RunWeaponModeMenu()

    local weaponModeMenu = Menu.Get("WeaponModeMenu")
    weaponModeMenu:Draw()

end


-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.RingInventory)
-- ============================================================================
LevelFuncs.Engine.RingInventory = LevelFuncs.Engine.RingInventory or {}
LevelFuncs.Engine.RingInventory.ChangeWeaponMode = WeaponMode.ChangeWeaponMode

return WeaponMode