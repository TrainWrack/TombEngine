--- Internal file used by the RingInventory module.
-- @module RingInventory.Input
-- @local

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

--External Modules
local Examine =  require("Engine.RingInventory.Examine")
local ItemMenu = require("Engine.RingInventory.ItemMenu")
local InventoryData= require("Engine.RingInventory.InventoryData")
local InventoryStates = require("Engine.RingInventory.InventoryStates")
local Interpolate = require("Engine.RingInventory.Interpolate")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")

--Pointers to tables
local INVENTORY_MODE = InventoryStates.MODE
local RING = Ring.TYPE
local SOUND_MAP = Settings.SoundMap

local timer = 0
local continuousSpinQueued = false

local Inputs = {}

local function GetHeldHorizontalDirection()
    local isLeftHeld = TEN.Input.IsKeyHeld(TEN.Input.ActionID.LEFT)
    local isRightHeld = TEN.Input.IsKeyHeld(TEN.Input.ActionID.RIGHT)

    if isLeftHeld and not isRightHeld then
        return -1
    end

    if isRightHeld and not isLeftHeld then
        return 1
    end

    return 0
end

local function GuiIsPulsed(actionID)
    local DELAY = 0.25
    local INITIAL_DELAY = 0.5
    
    if (TEN.Input.GetActionTimeActive(actionID) >= timer) then
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

local function DoLeftKey(ring)
    InventoryStates.StartRingNavigation(ring, -1)
    TEN.Sound.PlaySound(SOUND_MAP.menuRotate)

end

local function DoRightKey(ring)
    InventoryStates.StartRingNavigation(ring, 1)
    TEN.Sound.PlaySound(SOUND_MAP.menuRotate)

end

function Inputs.Update(mode, timeInMenu)
    
    timer = timeInMenu

    local selectedRing = InventoryData.GetSelectedRing()
    local selectedRingType = InventoryData.GetSelectedRingType()
    local selectedItem  = selectedRing:GetSelectedItem()

    if mode == INVENTORY_MODE.RING_ROTATE then
        local heldDirection = GetHeldHorizontalDirection()
        local rotationProgress = Interpolate.GetProgress("RingRotateAngle")

        if heldDirection ~= 0 and rotationProgress >= 0.75 and not continuousSpinQueued then
            if heldDirection < 0 then
                DoLeftKey(selectedRing)
            else
                DoRightKey(selectedRing)
            end
            continuousSpinQueued = true
        elseif GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            DoLeftKey(selectedRing)
        elseif GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            DoRightKey(selectedRing)
        end

        if Interpolate.GetProgress("RingRotateAngle") < 0.75 or heldDirection == 0 then
            continuousSpinQueued = false
        end

        return
    end

    continuousSpinQueued = false

    if mode == INVENTORY_MODE.INVENTORY then
        if GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            DoLeftKey(selectedRing)
        elseif GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            DoRightKey(selectedRing)
        elseif GuiIsPulsed(TEN.Input.ActionID.FORWARD) and selectedRingType < RING.COMBINE then
            local targetRing = math.max(RING.PUZZLE, selectedRingType - 1)
            if targetRing ~= selectedRingType and not InventoryData.GetRing(targetRing):IsEmpty() then
                InventoryStates.StartRingChange(targetRing, -1)
                TEN.Sound.PlaySound(SOUND_MAP.menuRotate)
            end
        elseif GuiIsPulsed(TEN.Input.ActionID.BACK) and selectedRingType < RING.COMBINE then
            --add check for the options ring here to skip it if it empty
            local targetRing = math.min(RING.OPTIONS, selectedRingType + 1)
            if targetRing ~= selectedRingType and not InventoryData.GetRing(targetRing):IsEmpty() then
                InventoryStates.StartRingChange(targetRing, 1)
                TEN.Sound.PlaySound(SOUND_MAP.menuRotate)
            end
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) or GuiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
            if ItemMenu.IsSingleItemAction(selectedItem) then
                ItemMenu.ParseAction(selectedItem:GetMenuActions())
            else
                InventoryStates.SetMode(INVENTORY_MODE.ITEM_SELECT)
            end
        elseif (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) and LevelVars.Engine.RingInventory.InventoryOpenFreeze then
            TEN.Sound.PlaySound(SOUND_MAP.inventoryClose)
            InventoryStates.SetMode(INVENTORY_MODE.RING_CLOSING)
        end
    elseif mode == INVENTORY_MODE.COMBINE then
        if GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            DoLeftKey(selectedRing)
        elseif GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            DoRightKey(selectedRing)
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) or GuiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
            InventoryStates.SetActionCheck(true)
        elseif (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            InventoryStates.SetMode(INVENTORY_MODE.COMBINE_CLOSE)
        end
    elseif mode == INVENTORY_MODE.STATISTICS then
        if GuiIsPulsed(TEN.Input.ActionID.ACTION) or GuiIsPulsed(TEN.Input.ActionID.SELECT) then
            if Settings.Statistics.gameStats then
                TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
                InventoryStates.SetActionCheck(true)
            end
        elseif GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
            InventoryStates.SetMode(INVENTORY_MODE.STATISTICS_CLOSE)
        end
    elseif mode == INVENTORY_MODE.WEAPON_MODE then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
            InventoryStates.SetMode(INVENTORY_MODE.WEAPON_MODE_CLOSE)
        end
    elseif mode == INVENTORY_MODE.SAVE_MENU then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
            InventoryStates.SetMode(INVENTORY_MODE.SAVE_CLOSE)
        end
    elseif mode == INVENTORY_MODE.ITEM_SELECTED then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
            InventoryStates.SetMode(INVENTORY_MODE.ITEM_DESELECT)
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT then
        if GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            DoLeftKey(selectedRing)
        elseif GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            DoRightKey(selectedRing)
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) or GuiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
            InventoryStates.SetActionCheck(true)
        elseif (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.inventoryClose)
            InventoryStates.SetMode(INVENTORY_MODE.AMMO_SELECT_CLOSE)
        end
    elseif mode == INVENTORY_MODE.EXAMINE then     
        if TEN.Input.IsKeyHeld(TEN.Input.ActionID.FORWARD) then
            Examine.ModifyRotation(1, 0, 0)
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.BACK) then
            Examine.ModifyRotation(-1, 0, 0)
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.LEFT) then
            Examine.ModifyRotation(0, 1, 0)
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.RIGHT) then
            Examine.ModifyRotation(0, -1, 0)
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.SPRINT) then
            Examine.ModifyScale(1)
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.CROUCH) then
            Examine.ModifyScale(-1)
        elseif GuiIsPulsed(TEN.Input.ActionID.JUMP) then
            TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
            InventoryStates.SetActionCheck(true)
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) then
            Examine.ToggleText()
            TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
        elseif GuiIsPulsed(TEN.Input.ActionID.INVENTORY) then
            TEN.Sound.PlaySound(SOUND_MAP.menuChoose)
            InventoryStates.SetMode(INVENTORY_MODE.EXAMINE_CLOSE)
        end
    end
end

return Inputs