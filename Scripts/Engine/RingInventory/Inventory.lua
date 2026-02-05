--RING INVENTORY BY TRAINWRECK

local CustomInventory = {}
local debug = false

--External Modules
local Constants = require("Engine.RingInventory.Constants")
local Inputs -- Delayed require to break circular dependency
local Menu = require("Engine.RingInventory.Menu")
local Interpolate = require("Engine.InterpolateModule")
local InventoryData = require("Engine.RingInventory.InventoryData")
local InventoryStates = require("Engine.RingInventory.InventoryStates")
local ItemLight = require("Engine.RingInventory.ItemLight")
local ItemSpin= require("Engine.RingInventory.ItemSpin")
local Settings = require("Engine.RingInventory.Settings")
local Text = require("Engine.RingInventory.Text")
local Ring      = require("Engine.RingInventory.Ring")

--Pointers to tables
local RING = Ring.TYPE
local INVENTORY_MODE = InventoryStates.MODE
local SOUND_MAP = Settings.SOUND_MAP
local COLOR_MAP = Settings.COLOR_MAP

--Variables
local useBinoculars = false
local timeInMenu = 0
local inventoryDelay = 0
local menuAlpha = 0

local inventorySetup = true
local inventorySetupFreeze = false
local inventoryOpen = false
local inventoryClosed = false
local inventoryRunning = false


LevelFuncs.Engine.RingInventory = {}

-- ============================================================================
-- MAIN FUNCTIONS
-- ============================================================================
local function ExitInventory()
    local ringInventory = InventoryData.Get("RingInventory")
    inventoryOpenFreeze = false
    ringInventory:Clear(nil, true)
    TEN.Inventory.SetEnterInventory(Constants.NO_VALUE)
    Interpolate.ClearAll()
    Menu.DeleteAll()
    Flow.SetFreezeMode(Flow.FreezeMode.NONE)
    InventoryStates.SetMode(INVENTORY_MODE.INVENTORY_OPENING)
    ringInventory:SwitchToRing(RING.MAIN)
    TEN.View.DisplayItem.ResetCamera()
    timeInMenu = 0
    saveList = false
    InventoryData:SetChosenItem()
    inventoryClosed = true
end

local function UpdateInventory()
    if not inventoryRunning then
        return
    end
    
    -- Lazy load Inputs to break circular dependency
    if not Inputs then
        Inputs = require("Engine.RingInventory.Input")
    end
    
    timeInMenu = timeInMenu + 1
   
    if inventoryOpen then
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        currentRingAngle = 0
        targetRingAngle = 0
        TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_OPEN)
        ConstructObjectList()
        inventoryOpen = false
        OpenInventoryAtItem(inventoryOpenItem, true)
    else
        Inputs.Update()
        InventoryStates.Update()
        Menu.DrawActiveMenus()
        Menu.UpdateActiveMenus()
        ItemLight.Update()
        ItemSpin.Update()
        Text.DrawAll()
        Text.Update()
        
        DrawInventory(inventoryMode)
        DrawInventoryHeader(inventorySubHeader, menuAlpha)
        DrawInventorySprites(selectedRing, menuAlpha)
    end
end

local function RunInventory()
    if inventorySetup then
        LevelVars.Engine.RingInventory = {}
        inventoryOpen = false
        inventoryClosed = false
        inventoryRunning = false
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.ITEM_COLOR_VISIBLE)
        
        local settings = TEN.Flow.GetSettings()
        settings.Gameplay.enableInventory = false
        TEN.Flow.SetSettings(settings)

        InventoryData.Create("RingInventory")
        Text.Setup()
        
        inventorySetup = false
    end

    local ringInventory = InventoryData.Get("RingInventory")
    
    if useBinoculars then
        TEN.View.UseBinoculars()
        useBinoculars = false
    end
    
    local playerHp = Lara:GetHP() > 0
    local isNotUsingBinoculars = TEN.View.GetCameraType() ~= CameraType.BINOCULARS
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.INVENTORY) or TEN.Inventory.GetEnterInventory() ~= Constants.NO_VALUE) and 
       not inventoryOpen and 
       playerHp and 
       isNotUsingBinoculars then
        inventoryOpen = true
        ringInventory:SetOpenAtItem(TEN.Inventory.GetEnterInventory())
        inventoryDelay = 0
    end
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.SAVE) or TEN.Inventory.GetEnterInventory() ~= Constants.NO_VALUE) and 
       not inventoryOpen and 
       playerHp and 
       isNotUsingBinoculars then
        inventoryOpen = true
        ringInventory:SetOpenAtItem(TEN.Objects.ObjID.PC_SAVE_INV_ITEM)
        inventoryDelay = 0
    end
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.LOAD) or TEN.Inventory.GetEnterInventory() ~= Constants.NO_VALUE) and 
       not inventoryOpen and 
       isNotUsingBinoculars then
        inventoryOpen = true
        ringInventory:SetOpenAtItem(TEN.Objects.ObjID.PC_LOAD_INV_ITEM)
        inventoryDelay = 0
    end
    
    if inventoryOpen == true then
        inventoryDelay = inventoryDelay + 1
        TEN.View.SetPostProcessMode(View.PostProcessMode.MONOCHROME)
        TEN.View.SetPostProcessStrength(COLOR_MAP.BACKGROUND.a / ALPHA_MAX)
        TEN.View.SetPostProcessTint(COLOR_MAP.BACKGROUND)
        if inventoryDelay >= 2 then
            TEN.View.DisplayItem.SetCameraPosition(Constants.CAMERA_START)
            TEN.View.DisplayItem.SetTargetPosition(Constants.TARGET_START)
            TEN.View.DisplayItem.SetFOV(80)
            TEN.View.DisplayItem.SetAmbientLight(COLOR_MAP.INVENTORY_AMBIENT)
            inventoryRunning = true
            Flow.SetFreezeMode(Flow.FreezeMode.FULL)
        end
    end
    
    if inventoryClosed then
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.ITEM_COLOR_VISIBLE)
        inventoryClosed = false
        inventoryRunning = false
    end
end

function CustomInventory.GetTimeInMenu()

    return timeInMenu

end

function CustomInventory.EnableBinoculars()

    useBinoculars = true

end

-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.RingInventory)
-- ============================================================================

LevelFuncs.Engine.RingInventory.UpdateInventory = UpdateInventory
LevelFuncs.Engine.RingInventory.RunInventory = RunInventory
LevelFuncs.Engine.RingInventory.ExitInventory = ExitInventory

-- ============================================================================
-- CALLBACKS
-- ============================================================================

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.RingInventory.UpdateInventory)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.RingInventory.RunInventory)

return CustomInventory