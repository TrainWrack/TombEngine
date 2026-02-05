-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

--External Modules
local Animation = require("Engine.RingInventory.Animation")
local Examine =  require("Engine.RingInventory.Examine")
local ItemMenu = require("Engine.RingInventory.ItemMenu")
local RingInventory = require("Engine.RingInventory.Inventory")
local InventoryData= require("Engine.RingInventory.InventoryData")
local InventoryStates = require("Engine.RingInventory.InventoryStates")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")

--Pointers to tables
local INVENTORY_MODE = InventoryStates.MODE
local RING = Ring.TYPE
local SOUND_MAP = Settings.SOUND_MAP

local Inputs = {}

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

    local ringInventory = InventoryData.Get("RingInventory")
    local selectedRing = ringInventory:GetSelectedRing()

    selectedRing:SelectPrevious()
    selectedRing:CalculateRotation(-1)

    InventoryStates.SetMode(INVENTORY_MODE.RING_ROTATE)
    TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
end

local function DoRightKey()
    local ringInventory = InventoryData.Get("RingInventory")
    local selectedRing = ringInventory:GetSelectedRing()

    selectedRing:SelectNext()
    selectedRing:CalculateRotation(1)

    InventoryStates.SetMode(INVENTORY_MODE.RING_ROTATE)
    TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
end

function Inputs.Update()
    
    local ringInventory = InventoryData.Get("RingInventory")
    local selectedRing = ringInventory:GetSelectedRingType()
    local previousRing = ringInventory:GetPreviousRingType()
    local selectedRingData = ringInventory:GetSelectedRing()
    local selectedItem  = selectedRingData:GetSelectedItem()
    local mode = InventoryStates.GetMode()

    if mode == INVENTORY_MODE.INVENTORY then
        if GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            DoLeftKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            DoRightKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.FORWARD) and selectedRing < RING.COMBINE then
            ringInventory:SwitchToRing(math.max(RING.PUZZLE, selectedRing - 1))
            if selectedRing ~= previousRing then
                InventoryStates.SetMode(INVENTORY_MODE.RING_CHANGE)
                selectedRingData:OffsetPosition(1)
                TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
            end
        elseif GuiIsPulsed(TEN.Input.ActionID.BACK) and selectedRing < RING.COMBINE then
            ringInventory:SwitchToRing(math.min(RING.OPTIONS, selectedRing + 1))
            if selectedRing ~= previousRing then
                selectedRingData:OffsetPosition(-1)
                InventoryStates.SetMode(INVENTORY_MODE.RING_CHANGE)
                TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
            end
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) or GuiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            Animation.EnableSaveItemData()
            if ItemMenu.IsSingleFlagSet(selectedItem) then
                ItemMenu.ParseMenuAction(selectedItem)
            else
                InventoryStates.SetMode(INVENTORY_MODE.ITEM_SELECT)
            end
        elseif (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) and LevelVars.Engine.RingInventory.InventoryOpenFreeze then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            InventoryStates.SetMode(INVENTORY_MODE.RING_CLOSING)
        end
    elseif mode == INVENTORY_MODE.COMBINE then
        if GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            DoLeftKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            DoRightKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) or GuiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            InventoryStates.SetActionCheck(true)
        elseif (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            InventoryStates.SetMode(INVENTORY_MODE.COMBINE_CLOSE)
        end
    elseif mode == INVENTORY_MODE.STATISTICS then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            InventoryStates.SetMode(INVENTORY_MODE.STATISTICS_CLOSE)
        end
    elseif mode == INVENTORY_MODE.WEAPON_MODE then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            InventoryStates.SetMode(INVENTORY_MODE.WEAPON_MODE_CLOSE)
        end
    elseif mode == INVENTORY_MODE.SAVE_MENU then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            InventoryStates.SetMode(INVENTORY_MODE.SAVE_CLOSE)
        end
    elseif mode == INVENTORY_MODE.ITEM_SELECTED then
        if (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            InventoryStates.SetMode(INVENTORY_MODE.ITEM_DESELECT)
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT then
        if GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            DoLeftKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            DoRightKey()
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) or GuiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            InventoryStates.SetActionCheck(true)
        elseif (GuiIsPulsed(TEN.Input.ActionID.INVENTORY) or GuiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
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
        elseif GuiIsPulsed(TEN.Input.ActionID.ACTION) then
            Examine.ToggleText()
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
        elseif GuiIsPulsed(TEN.Input.ActionID.INVENTORY) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            InventoryStates.SetMode(INVENTORY_MODE.EXAMINE_RESET)
        end
    end
end

return Inputs