--RING INVENTORY BY TRAINWRECK

local CustomInventory = {}
local debug = false

--External Modules
local Animation = require("Engine.RingInventory.Animation")
local Menu = require("Engine.CustomMenu")
local Interpolate = require("Engine.InterpolateModule")
local InventoryStates = require("Engine.RingInventory.InventoryStates")
local Save = require("Engine.RingInventory.Save")
local Settings = require("Engine.RingInventory.Settings")
local States = require("Engine.RingInventory.States")
local Statistics = require("Engine.RingInventory.Statistics")
local Strings = require("Engine.RingInventory.Statistics")
local Text = require("Engine.RingInventory.Text")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointers to tables
local PICKUP_DATA = require("Engine.RingInventory.PickupData")
local TYPE = PICKUP_DATA.TYPE
local RING = PICKUP_DATA.RING
local INVENTORY_MODE = PICKUP_DATA.INVENTORY_MODE
local SOUND_MAP = Settings.SOUND_MAP
local COLOR_MAP = Settings.COLOR_MAP
local ANIMATION = Settings.ANIMATION

--Constants
local NO_VALUE = -1
local CAMERA_START = Vec3(0, -2500, 200)
local CAMERA_END = Vec3(0, -36, -1151)
local TARGET_START = Vec3(0, 0, 1000)
local TARGET_END = Vec3(0, 110, 0)


local ITEM_START = Vec3(0, 200, 512)
local ITEM_END = Vec3(0, 0, 400)


--Variables
local useBinoculars = false

--Structure for inventory

local inventorySetup = true
local timeInMenu = 0
local inventoryDelay = 0
local menuAlpha = 0


LevelFuncs.Engine.RingInventory = {}

-- ============================================================================
-- MAIN DRAW AND USE FUNCTIONS
-- ============================================================================
local function ExitInventory()
    LevelVars.Engine.RingInventory.InventoryOpenFreeze = false
    ClearInventory(nil, true)
    TEN.Inventory.SetEnterInventory(NO_VALUE)
    Interpolate.ClearAll()
    Menu.DeleteAll()
    Flow.SetFreezeMode(Flow.FreezeMode.NONE)
    inventoryMode = INVENTORY_MODE.INVENTORY_OPENING
    selectedRing = RING.MAIN
    TEN.View.DisplayItem.ResetCamera()
    timeInMenu = 0
    saveList = false
    combineItem1 = nil
    LevelVars.Engine.RingInventory.InventoryClosed = true
end

local function UpdateInventory()
    if not LevelVars.Engine.RingInventory.InventoryRunning then
        return
    end
    
    timeInMenu = timeInMenu + 1
    DrawBackground(menuAlpha)
    DrawInventoryHeader(inventoryHeader, menuAlpha)
    Text.Update()
    Text.DrawAll()
    
    if LevelVars.Engine.RingInventory.InventoryOpen then
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        currentRingAngle = 0
        targetRingAngle = 0
        TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_OPEN)
        ConstructObjectList()
        LevelVars.Engine.RingInventory.InventoryOpen = false
        OpenInventoryAtItem(inventoryOpenItem, true)
    else
        Input(inventoryMode)
        DrawInventory(inventoryMode)
        DrawInventoryHeader(inventorySubHeader, menuAlpha)
        DrawInventorySprites(selectedRing, menuAlpha)
        SetRotationInventoryItems()
    end
end

local function RunInventory()
    if inventorySetup then
        LevelVars.Engine.RingInventory = {}
        LevelVars.Engine.RingInventory.InventoryOpen = false
        LevelVars.Engine.RingInventory.InventoryOpenFreeze = false
        LevelVars.Engine.RingInventory.InventoryClosed = false
        LevelVars.Engine.RingInventory.InventoryRunning = false
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.ITEM_COLOR_VISIBLE)
        
        local settings = TEN.Flow.GetSettings()
        settings.Gameplay.enableInventory = false
        TEN.Flow.SetSettings(settings)

        Text.Setup()
        
        inventorySetup = false
    end
    
    if useBinoculars then
        TEN.View.UseBinoculars()
        useBinoculars = false
    end
    
    local playerHp = Lara:GetHP() > 0
    local isNotUsingBinoculars = TEN.View.GetCameraType() ~= CameraType.BINOCULARS
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.INVENTORY) or TEN.Inventory.GetEnterInventory() ~= NO_VALUE) and 
       not LevelVars.Engine.RingInventory.InventoryOpen and 
       playerHp and 
       isNotUsingBinoculars then
        LevelVars.Engine.RingInventory.InventoryOpen = true
        inventoryOpenItem = TEN.Inventory.GetEnterInventory()
        inventoryDelay = 0
    end
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.SAVE) or TEN.Inventory.GetEnterInventory() ~= NO_VALUE) and 
       not LevelVars.Engine.RingInventory.InventoryOpen and 
       playerHp and 
       isNotUsingBinoculars then
        LevelVars.Engine.RingInventory.InventoryOpen = true
        inventoryOpenItem = TEN.Objects.ObjID.PC_SAVE_INV_ITEM
        inventoryDelay = 0
    end
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.LOAD) or TEN.Inventory.GetEnterInventory() ~= NO_VALUE) and 
       not LevelVars.Engine.RingInventory.InventoryOpen and 
       isNotUsingBinoculars then
        LevelVars.Engine.RingInventory.InventoryOpen = true
        inventoryOpenItem = TEN.Objects.ObjID.PC_LOAD_INV_ITEM
        inventoryDelay = 0
    end
    
    if LevelVars.Engine.RingInventory.InventoryOpen == true then
        inventoryDelay = inventoryDelay + 1
        TEN.View.SetPostProcessMode(View.PostProcessMode.MONOCHROME)
        TEN.View.SetPostProcessStrength(COLOR_MAP.BACKGROUND.a / ALPHA_MAX)
        TEN.View.SetPostProcessTint(COLOR_MAP.BACKGROUND)
        if inventoryDelay >= 2 then
            TEN.View.DisplayItem.SetCameraPosition(CAMERA_START)
            TEN.View.DisplayItem.SetTargetPosition(TARGET_START)
            TEN.View.DisplayItem.SetFOV(80)
            TEN.View.DisplayItem.SetAmbientLight(COLOR_MAP.INVENTORY_AMBIENT)
            LevelVars.Engine.RingInventory.InventoryRunning = true
            Flow.SetFreezeMode(Flow.FreezeMode.FULL)
        end
    end
    
    if LevelVars.Engine.RingInventory.InventoryClosed then
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.ITEM_COLOR_VISIBLE)
        LevelVars.Engine.RingInventory.InventoryClosed = false
        LevelVars.Engine.RingInventory.InventoryRunning = false
    end
end

function CustomInventory.GetTimeInMenu()

    return timeInMenu

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