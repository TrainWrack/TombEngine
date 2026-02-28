--RING INVENTORY BY TRAINWRECK

--External Modules
local Constants = require("Engine.RingInventory.Constants")
local InventoryData = require("Engine.RingInventory.InventoryData")
local InventoryStates
local Settings = require("Engine.RingInventory.Settings")
local Strings = require("Engine.RingInventory.Strings")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP

--Local Variables
local inventoryDelay = 0

local inventorySetup = true
local inventoryOpen = false
local inventoryRunning = false

LevelFuncs.Engine.RingInventory = {}

-- ============================================================================
-- MAIN FUNCTIONS
-- ============================================================================
local function UpdateInventory()
    if not inventoryRunning then
        return
    end

    if not InventoryStates then
        InventoryStates = require("Engine.RingInventory.InventoryStates")
    end

    InventoryStates.Update()

end

local function RunInventory()

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
        TEN.View.SetPostProcessTint(COLOR_MAP.ITEM_SELECTED)
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
        local Save = require("Engine.RingInventory.Save")
        Save.SetQuickSaveStatus(true)
        Save.SetSaveMenu()
        InventoryData.SetOpenAtItem(TEN.Objects.ObjID.PC_SAVE_INV_ITEM)
        inventoryDelay = 0
    end
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.LOAD) or TEN.Inventory.GetFocusedItem() ~= Constants.NO_VALUE) and 
       not inventoryOpen and 
       isNotUsingBinoculars then
        inventoryOpen = true
        local Save = require("Engine.RingInventory.Save")
        Save.SetQuickSaveStatus(true)
        Save.SetLoadMenu()
        InventoryData.SetOpenAtItem(TEN.Objects.ObjID.PC_LOAD_INV_ITEM)
        inventoryDelay = 0
    end
    
    if inventoryOpen == true then
        inventoryDelay = inventoryDelay + 1
        TEN.View.SetPostProcessMode(View.PostProcessMode.MONOCHROME)
        TEN.View.SetPostProcessStrength(COLOR_MAP.BACKGROUND.a / Constants.ALPHA_MAX)
        TEN.View.SetPostProcessTint(COLOR_MAP.BACKGROUND)
        if inventoryDelay >= 2 then
            TEN.View.DisplayItem.SetCameraPosition(Constants.CAMERA_START)
            TEN.View.DisplayItem.SetTargetPosition(Constants.TARGET_START)
            TEN.View.DisplayItem.SetFOV(80)
            TEN.View.DisplayItem.SetAmbientLight(COLOR_MAP.INVENTORY_AMBIENT)
            inventoryRunning = true
            inventoryOpen = false
            Flow.SetFreezeMode(Flow.FreezeMode.FULL)
        end
    end
    
    if InventoryStates.GetInventoryClosed() then
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.ITEM_SELECTED)
        InventoryStates.SetInventoryClosed(false)
        inventoryRunning = false
    end
end


-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.RingInventory)
-- ============================================================================
LevelFuncs.Engine.RingInventory = LevelFuncs.Engine.RingInventory or {}
LevelFuncs.Engine.RingInventory.UpdateInventory = UpdateInventory
LevelFuncs.Engine.RingInventory.RunInventory = RunInventory

-- ============================================================================
-- CALLBACKS
-- ============================================================================
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_FREEZE, LevelFuncs.Engine.RingInventory.UpdateInventory)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_LOOP, LevelFuncs.Engine.RingInventory.RunInventory)