-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

--External Modules
local Examine =  require("Engine.RingInventory.Examine")
local Interpolate = require("Engine.RingInventory.Interpolate")
local RingInventory = require("Engine.RingInventory.Inventory")
local InventoryData= require("Engine.RingInventory.InventoryData")
local PICKUP_DATA = require("Engine.RingInventory.PickupData")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointers to tables
local CONSTANTS = require("Engine.RingInventory.Constants")
local INVENTORY_MODE = PICKUP_DATA.INVENTORY_MODE
local COLOR_MAP = Settings.COLOR_MAP
local SOUND_MAP = Settings.SOUND_MAP

local Input = {}

local function GuiIsPulsed(actionID)
    local DELAY = 0.25
    local INITIAL_DELAY = 0.5
    
    if (TEN.Input.GetActionTimeActive(actionID) >= RingInventory.GetTimeInMenu()) then
        return false
    end
    
    local oppositeAction = nil
    if actionID == TEN.Input.ActionID.FORWARD then
        oppositeAction = TEN.Input.ActionID.BACK
    elseif actionID == TEN.Input.ActionID.BACK then
        oppositeAction = TEN.Input.ActionID.FORWARD
    elseif actionID == TEN.Input.ActionID.LEFT then
        oppositeAction = TEN.Input.ActionID.RIGHT
    elseif actionID == TEN.Input.ActionID.RIGHT then
        oppositeAction = TEN.Input.ActionID.LEFT
    end
    
    local isActionLocked = false
    if oppositeAction ~= nil then
        isActionLocked = TEN.Input.IsKeyHeld(oppositeAction) == true
    end
    
    if isActionLocked then
        return false
    end
    
    return TEN.Input.IsKeyPulsed(actionID, DELAY, INITIAL_DELAY)
end

local function DoLeftKey()
    local inventoryTable = inventory.ring[selectedRing]
    inventory.selectedItem[selectedRing] = (inventory.selectedItem[selectedRing] % #inventoryTable) + 1
    targetRingAngle = currentRingAngle - inventory.slice[selectedRing]
    previousMode = inventoryMode
    inventoryMode = INVENTORY_MODE.RING_ROTATE
    TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
end

local function DoRightKey()
    local inventoryTable = inventory.ring[selectedRing]
    inventory.selectedItem[selectedRing] = ((inventory.selectedItem[selectedRing] - 2) % #inventoryTable) + 1
    targetRingAngle = currentRingAngle + inventory.slice[selectedRing]
    previousMode = inventoryMode
    inventoryMode = INVENTORY_MODE.RING_ROTATE
    TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
end

function Input.Update(mode)
    if mode == INVENTORY_MODE.INVENTORY then
        if GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            DoLeftKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            DoRightKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.FORWARD) and selectedRing < RING.COMBINE then
            previousRing = selectedRing
            selectedRing = math.max(RING.PUZZLE, selectedRing - 1)
            if selectedRing ~= previousRing then
                inventoryMode = INVENTORY_MODE.RING_CHANGE
                direction = 1
                TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
            end
        elseif GuiIsPulsed(TEN.Input.ActionID.BACK) and selectedRing < RING.COMBINE then
            previousRing = selectedRing
            selectedRing = math.min(RING.OPTIONS, selectedRing + 1)
            if selectedRing ~= previousRing then
                direction = -1
                inventoryMode = INVENTORY_MODE.RING_CHANGE
                TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
            end
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) or GuiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            itemStoreRotations = true
            local menuActions = GetSelectedItem(selectedRing).menuActions
            if IsSingleFlagSet(menuActions) then
                ParseMenuAction(menuActions)
            else
                inventoryMode = INVENTORY_MODE.ITEM_SELECT
            end
        elseif (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) and LevelVars.Engine.RingInventory.InventoryOpenFreeze then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            inventoryMode = INVENTORY_MODE.RING_CLOSING
        end
    elseif mode == INVENTORY_MODE.COMBINE then
        if GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            DoLeftKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            DoRightKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) or GuiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            performCombine = true
        elseif (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            inventoryMode = INVENTORY_MODE.COMBINE_CLOSE
        end
    elseif mode == INVENTORY_MODE.STATISTICS then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.STATISTICS_CLOSE
        end
    elseif mode == INVENTORY_MODE.WEAPON_MODE then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.WEAPON_MODE_CLOSE
        end
    elseif mode == INVENTORY_MODE.SAVE_MENU then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.SAVE_CLOSE
        end
    elseif mode == INVENTORY_MODE.ITEM_SELECTED then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.ITEM_DESELECT
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT then
        if GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            DoLeftKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            DoRightKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) or GuiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            performCombine = true
        elseif (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            RingInventory.SetMode(INVENTORY_MODE.AMMO_SELECT_CLOSE)
        end
    elseif mode == INVENTORY_MODE.EXAMINE then
        local ROTATION_MULTIPLIER = 2
        local ZOOM_MULTIPLIER = 0.3
        
        if TEN.Input.IsKeyHeld(TEN.Input.ActionID.FORWARD) then
            examineRotation.x = examineRotation.x + ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.BACK) then
            examineRotation.x = examineRotation.x - ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.LEFT) then
            examineRotation.y = examineRotation.y + ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.RIGHT) then
            examineRotation.y = examineRotation.y - ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.SPRINT) then
            examineScaler = examineScaler + ZOOM_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.CROUCH) then
            examineScaler = examineScaler - ZOOM_MULTIPLIER
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) then
            examineShowString = not examineShowString
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
        elseif GuiIsPulsed(TEN.Input.ActionID.INVENTORY) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            RingInventory.SetMode(INVENTORY_MODE.EXAMINE_RESET)
        end
    end
end

return Input