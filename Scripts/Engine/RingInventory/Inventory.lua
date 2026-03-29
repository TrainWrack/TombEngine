-----
-- This module enables classic ring inventory in TEN levels. 
-- Example usage:
--
--	local RingInventory = require("Engine.RingInventory.Inventory")
--
-- Global ring inventory settings.
-- Settings is composed of several sub-tables, and each section of the Settings documentation corresponds to one of these sub-tables.
-- These configuration groups are located in *Settings.lua* script file inside RingInventory folder.
--
-- It is possible to change settings on a per-level basis via @{RingInventory.GetSettings} and @{RingInventory.SetSettings} functions, but keep in mind that
-- _Settings.lua is reread every time the level is reloaded_. Therefore, you need to implement custom settings management in your level script
-- if you want to override global settings.
-- @luautil RingInventory

--External Modules
local Constants = require("Engine.RingInventory.Constants")
local InventoryData = require("Engine.RingInventory.InventoryData")
local InventoryStates
local ItemSpin = require("Engine.RingInventory.ItemSpin")
local RingLight = require("Engine.RingInventory.RingLight")
local Save = require("Engine.RingInventory.Save")
local Settings = require("Engine.RingInventory.Settings")
local Strings = require("Engine.RingInventory.Strings")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointers to tables
local COLOR_MAP = Settings.ColorMap

--Local Variables
local inventoryDelay = 0

local inventorySetup = true
local inventoryOpen = false
local inventoryRunning = false

LevelFuncs.Engine.RingInventory = LevelFuncs.Engine.RingInventory or {}

-- ============================================================================
-- MAIN FUNCTIONS
-- ============================================================================
LevelFuncs.Engine.RingInventory.UpdateInventory = function()
    if not inventoryRunning then
        return
    end

    if not InventoryStates then
        InventoryStates = require("Engine.RingInventory.InventoryStates")
    end

    RingLight.Update()
    ItemSpin.Update()
    InventoryStates.Update()

end

LevelFuncs.Engine.RingInventory.RunInventory = function()
    if not InventoryStates then
        InventoryStates = require("Engine.RingInventory.InventoryStates")
    end

    if inventorySetup then
        LevelVars.Engine.RingInventory = {}
        inventoryOpen = false
        InventoryStates.SetInventoryClosed(false)
        inventoryRunning = false
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.itemSelected)
        local settings = TEN.Flow.GetSettings()
        settings.Gameplay.enableInventory = false
        TEN.Flow.SetSettings(settings)
        
        inventorySetup = false
    end
    
    local playerHp = Lara:GetHP() > 0
    local isNotUsingBinoculars = TEN.View.GetCameraType() ~= CameraType.BINOCULARS
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.INVENTORY) or TEN.Inventory.GetFocusedItem() ~= Constants.NO_VALUE) and 
       not inventoryOpen and 
       playerHp and 
       isNotUsingBinoculars then
        inventoryOpen = true
        InventoryData.SetOpenAtItem(TEN.Inventory.GetFocusedItem())
        inventoryDelay = 0
    end
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.SAVE) or TEN.Inventory.GetFocusedItem() ~= Constants.NO_VALUE) and 
       not inventoryOpen and 
       playerHp and 
       isNotUsingBinoculars then
        inventoryOpen = true
        Save.SetQuickSaveStatus(true)
        Save.SetSaveMenu()
        inventoryDelay = 0
    end
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.LOAD) or TEN.Inventory.GetFocusedItem() ~= Constants.NO_VALUE) and 
       not inventoryOpen and 
       isNotUsingBinoculars then
        inventoryOpen = true
        Save.SetQuickSaveStatus(true)
        Save.SetLoadMenu()
        inventoryDelay = 0
    end
    
    if inventoryOpen == true then
        local requiredDelay = 2
        if Save.IsQuickSaveEnabled() then
            requiredDelay = 1
        end

        inventoryDelay = inventoryDelay + 1
        TEN.View.SetPostProcessMode(View.PostProcessMode.MONOCHROME)
        TEN.View.SetPostProcessStrength(COLOR_MAP.background.a / Constants.ALPHA_MAX)
        TEN.View.SetPostProcessTint(COLOR_MAP.background)
        if inventoryDelay >= requiredDelay then
            TEN.View.DisplayItem.SetCameraPosition(Constants.CAMERA_START)
            TEN.View.DisplayItem.SetTargetPosition(Constants.TARGET_START)
            TEN.View.DisplayItem.SetFOV(80)
            TEN.View.DisplayItem.SetAmbientLight(COLOR_MAP.inventoryAmbient)
            inventoryRunning = true
            inventoryOpen = false
            Flow.SetFreezeMode(Flow.FreezeMode.FULL)
        end
    end
    
    if InventoryStates.GetInventoryClosed() then
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.itemSelected)
        InventoryStates.SetInventoryClosed(false)
        inventoryRunning = false
    end
end

local InventoryModule = {}

---Get settings tables for RingInventory.
-- @function RingInventory.GetSettings
-- @treturn Settings Current settings table
InventoryModule.GetSettings = function()
    return Utilities.CopyTable(Settings)
end

---Set settings tables for RingInventory.
-- @function RingInventory.SetSettings
-- @tparam Settings newSettings Required settings table
InventoryModule.SetSettings = function(newSettings)
    for section, values in pairs(newSettings) do
        if Settings[section] ~= nil then
            for setting, value in pairs(values) do
                if Settings[section][setting] ~= nil then
                    Settings[section][setting] = value
                end
            end
        end
    end
end

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_FREEZE, LevelFuncs.Engine.RingInventory.UpdateInventory)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_LOOP, LevelFuncs.Engine.RingInventory.RunInventory)

return InventoryModule