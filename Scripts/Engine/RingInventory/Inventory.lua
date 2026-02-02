--RING INVENTORY BY TRAINWRECK

local CustomInventory = {}
local debug = false

--External Modules
local Animation = require("Engine.RingInventory.Animation")
local Menu = require("Engine.CustomMenu")
local Interpolate = require("Engine.InterpolateModule")
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
local RING_CENTER = PICKUP_DATA.RING_CENTER
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
local AMMO_LOCATION = Vec3(0, 300, 512)

local PROGRESS_COMPLETE = 1

local ALPHA_MAX = 255
local ALPHA_MIN = 0

--Variables
local useBinoculars = false
local itemStoreRotations = false
local itemRotation = Rotation(0, 0, 0)
local itemRotationOld = Rotation(0, 0, 0)

local ammoAdded = true



--Structure for inventory

local inventorySetup = true
local timeInMenu = 0
local inventoryDelay = 0
local inventoryMode = INVENTORY_MODE.INVENTORY_OPENING
local previousMode = nil
local menuAlpha = 0

CustomInventory.INVENTORY_MODE = 
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
	INVENTORY_OPENING = 36
}

LevelFuncs.Engine.RingInventory = {}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================



local function IsSingleFlagSet(flags)
    return flags ~= 0 and (flags & (flags - 1)) == 0
end






-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

local function RotateItem(itemName)
    local currentDisplayItem = TEN.View.DisplayItem.GetItemByName(itemName)
    local itemRotations = currentDisplayItem:GetRotation()
    local itemColor = currentDisplayItem:GetColor()
    local targetColor = Animation.Interpolate.Lerp(itemColor, COLOR_MAP.ITEM_COLOR_VISIBLE, ITEM_SPINBACK_ALPHA)
    currentDisplayItem:SetRotation(Rotation(itemRotations.x, (itemRotations.y + ANIMATION.ROTATION_SPEED) % 360, itemRotations.z))
    currentDisplayItem:SetColor(targetColor)
end

local function ShowChosenAmmo(item, textOnly)
    local inventoryItem = GetInventoryItem(item)
    if not inventoryItem or inventoryItem.type ~= TYPE.WEAPON then
        Text.Hide("ITEM_LABEL_SECONDARY")
        return
    end
    
    local slot = PICKUP_DATA.WEAPON_SET[item].slot
    local ammoType = Lara:GetAmmoType(slot)
    if not ammoType then return end
    
    local objectID = PICKUP_DATA.AMMO_TYPE_TO_OBJECT[ammoType]
    if not objectID then return end
    
    local row = PICKUP_DATA.GetRow(objectID)
    local base = PICKUP_DATA.ConvertRowData(row)
    
    if ammoAdded and not textOnly then
        local data = BuildInventoryItem(base)
        data.rotation = Utilities.CopyRotation(data.rotation)
        
        local ammoItem = TEN.View.DisplayItem(
            "ChosenAmmo",
            data.objectID,
            AMMO_LOCATION,
            data.rotation,
            Vec3(data.scale),
            data.meshBits
        )
        
        ammoItem:SetColor(COLOR_MAP.ITEM_COLOR_VISIBLE)
        ammoAdded = false
    end
    
    local data = BuildInventoryItem(base)
    local label = Text.CreateItemLabel(data)
    Text.SetText("ITEM_LABEL_SECONDARY", label, true)
    --DrawItemLabel(data, false)
    
    if not textOnly then
        RotateItem("ChosenAmmo")
    end
end

local function DeleteChosenAmmo(itemOnly)
    TEN.View.DisplayItem.RemoveItem("ChosenAmmo")
    ammoAdded = true

    if not itemOnly then
        
        Text.Hide("ITEM_LABEL_SECONDARY")
    
    end
end




local function SaveItemData(selectedItem)
    if itemStoreRotations then
        local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(selectedItem.objectID))
        itemRotationOld = displayItem:GetRotation()
        itemRotation = selectedItem.rotation
        examineRotation = Utilities.CopyRotation(selectedItem.rotation)
        examineScalerOld = selectedItem.scale
        examineScaler = selectedItem.scale
        itemStoreRotations = false
    end
end

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

function CustomInventory.SetMode(mode)

    previousMode = inventoryMode
    inventoryMode = mode

end

function CustomInventory.GetMode()

    return inventoryMode
    
end

function CustomInventory.IsMode(mode)

    return inventoryMode == mode
    
end

function CustomInventory.UseBinoculars()

    useBinoculars = true

end

function CustomInventory.GetTimeInMenu()

    return timeInMenu

end

-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.RingInventory)
-- ============================================================================

LevelFuncs.Engine.RingInventory.UpdateInventory = UpdateInventory
LevelFuncs.Engine.RingInventory.RunInventory = RunInventory

-- ============================================================================
-- CALLBACKS
-- ============================================================================

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.RingInventory.UpdateInventory)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.RingInventory.RunInventory)

return CustomInventory