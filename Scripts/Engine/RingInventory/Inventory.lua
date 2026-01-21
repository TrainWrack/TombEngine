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

local function HasItemAction(packedFlags, flag)
    return (packedFlags & flag) ~= 0
end

local function HasChooseAmmo(menuActions)
    for _, flag in ipairs(PICKUP_DATA.CHOOSE_AMMO_FLAGS) do
        if HasItemAction(menuActions, flag) then
            return true
        end
    end
    return false
end

local function IsSingleFlagSet(flags)
    return flags ~= 0 and (flags & (flags - 1)) == 0
end

local function GuiIsPulsed(actionID)
    local DELAY = 0.25
    local INITIAL_DELAY = 0.5
    
    if (TEN.Input.GetActionTimeActive(actionID) >= timeInMenu) then
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
        isActionLocked = TEN.Input.IsKeyHeld(oppositeAction)
    end
    
    if isActionLocked then
        return false
    end
    
    return TEN.Input.IsKeyPulsed(actionID, DELAY, INITIAL_DELAY)
end

-- ============================================================================
-- MENU FUNCTIONS
-- ============================================================================

local function ParseMenuAction(menuActions)
    if HasItemAction(menuActions, ItemAction.USE) or HasItemAction(menuActions, ItemAction.EQUIP) then
        inventoryMode = INVENTORY_MODE.ITEM_USE
    elseif HasItemAction(menuActions, ItemAction.EXAMINE) then
        inventoryMode = INVENTORY_MODE.EXAMINE_OPEN
    elseif HasItemAction(menuActions, ItemAction.COMBINE) then
        inventoryMode = INVENTORY_MODE.COMBINE_SETUP
    elseif HasItemAction(menuActions, ItemAction.STATISTICS) then
        inventoryMode = INVENTORY_MODE.STATISTICS_OPEN
    elseif HasItemAction(menuActions, ItemAction.SAVE) then
        Save.saveList = true
        inventoryMode = INVENTORY_MODE.SAVE_SETUP
    elseif HasItemAction(menuActions, ItemAction.LOAD) then
        Save.saveList = false
        inventoryMode = INVENTORY_MODE.SAVE_SETUP
    elseif HasItemAction(menuActions, ItemAction.SEPARATE) then
        inventoryMode = INVENTORY_MODE.SEPARATE
    elseif HasItemAction(menuActions, ItemAction.CHOOSE_AMMO_HK) then
        inventoryMode = INVENTORY_MODE.WEAPON_MODE_SETUP
    elseif HasChooseAmmo(menuActions) then
        inventoryMode = INVENTORY_MODE.AMMO_SELECT_SETUP
    end
end

local function DoItemAction()
    local menu = LevelVars.Engine.Menus["menuActions"]
    if not menu then return end
    
    local selectedItem = menu.items[menu.currentItem]
    if selectedItem and selectedItem.actionBit then
        ParseMenuAction(selectedItem.actionBit)
    end
end

local function CreateItemMenu(item)
    local menuActions = {}
    local itemData = GetInventoryItem(item)
    local itemMenuActions = itemData.menuActions
    
    for _, entry in ipairs(PICKUP_DATA.ItemActionFlags) do
        if HasItemAction(itemMenuActions, entry.bit) then
            local allowInsert = true
            
            if entry.bit == ItemAction.COMBINE then
                local itemCount = GetCombineItemsCount(itemData.objectID)
                allowInsert = (itemCount ~= 0)
            end
            
            if allowInsert then
                table.insert(menuActions, {
                    itemName = entry.string,
                    actionBit = entry.bit,
                    options = nil,
                    currentOption = 1
                })
            end
        end
    end
    
    local itemMenu = Menu.Create("menuActions", nil, menuActions, "Engine.RingInventory.DoItemAction", nil, Menu.Type.ITEMS_ONLY)
    
    itemMenu:SetItemsPosition(Vec2(50, 35))
    itemMenu:SetVisibility(true)
    itemMenu:SetLineSpacing(5.3)
    itemMenu:SetItemsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    itemMenu:SetItemsTranslate(true)
    itemMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, 1.5, nil, true)
    itemMenu:SetTitlePosition(Vec2(50, 4))
end

local function ShowItemMenu()
    local itemMenu = Menu.Get("menuActions")
    itemMenu:Draw()
end

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

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

local function Input(mode)
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
            inventoryMode = INVENTORY_MODE.AMMO_SELECT_CLOSE
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
            inventoryMode = INVENTORY_MODE.EXAMINE_RESET
        end
    end
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


-- ============================================================================
-- ANIMATION FUNCTIONS
-- ============================================================================

local function ClearBatchMotionProgress(prefix, motionTable)
    for _, motion in ipairs(motionTable) do
        local id = prefix..motion.key
        Interpolate.Clear(id)
    end
end

local function PerformBatchMotion(prefix, motionTable, time, clearProgress, ringName, item, reverse)
    local interpolated = {}
    local allComplete = true
    local omitSelectedItem = item and true or false
    
    for _, motion in ipairs(motionTable) do
        local id = prefix..motion.key
        local interp = {output = motion.start, progress = PROGRESS_COMPLETE}
        
        if motion.start ~= motion.finish then
            local startVal = reverse and motion.finish or motion.start
            local endVal = reverse and motion.start or motion.finish
            interp = Interpolate.Calculate(id, motion.type, startVal, endVal, time, true)
        end
        
        interpolated[motion.key] = interp
        
        if interp.progress < PROGRESS_COMPLETE then
            allComplete = false
        end
    end
    
    if interpolated.ringCenter or interpolated.ringRadius or interpolated.ringAngle then
        local center = interpolated.ringCenter and interpolated.ringCenter.output or inventory.ringPosition[ringName]
        local radius = interpolated.ringRadius and interpolated.ringRadius.output or RING_RADIUS
        local angle = interpolated.ringAngle and interpolated.ringAngle.output or 0
        TranslateRing(ringName, center, radius, angle, ITEM_SPINBACK_ALPHA)
    end
    
    if interpolated.ringColor then
        ColorRing(ringName, interpolated.ringColor.output, omitSelectedItem, ITEM_SPINBACK_ALPHA)
    end
    
    if interpolated.ringFade then
        FadeRing(ringName, interpolated.ringFade.output, omitSelectedItem)
    end
    
    if interpolated.menuFade then
        menuAlpha = interpolated.menuFade.output
    end
    
    if interpolated.camera then
        TEN.View.DisplayItem.SetCameraPosition(interpolated.camera.output)
    end
    
    if interpolated.target then
        TEN.View.DisplayItem.SetTargetPosition(interpolated.target.output)
    end
    
    if item then
        local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(item.objectID))
        if interpolated.itemColor then
            displayItem:SetColor(interpolated.itemColor.output)
        end
        if interpolated.itemPosition then
            displayItem:SetPosition(Utilities.OffsetY(interpolated.itemPosition.output, item.yOffset))
        end
        if interpolated.itemScale then
            displayItem:SetScale(Vec3(interpolated.itemScale.output))
        end
        if interpolated.itemRotation then
            displayItem:SetRotation(interpolated.itemRotation.output)
        end
    end
    
    if allComplete then
        if clearProgress then
            ClearBatchMotionProgress(prefix, motionTable)
        end
        return true
    end
end

local function AnimateInventory(mode)
    local selectedItem = GetSelectedItem(selectedRing)
    
    local ringAnimation = {
        {key = "ringRadius", type = Interpolate.Type.LINEAR, start = 0, finish = RING_RADIUS},
        {key = "ringAngle", type = Interpolate.Type.LINEAR, start = -360, finish = currentRingAngle},
        {key = "ringCenter", type = Interpolate.Type.VEC3, start = inventory.ringPosition[selectedRing], finish = inventory.ringPosition[selectedRing]},
        {key = "ringFade", type = Interpolate.Type.LINEAR, start = ALPHA_MIN, finish = ALPHA_MAX},
        {key = "camera", type = Interpolate.Type.VEC3, start = CAMERA_START, finish = CAMERA_END},
        {key = "target", type = Interpolate.Type.VEC3, start = TARGET_START, finish = TARGET_END},
    }
    
    local useAnimation = {
        {key = "itemPosition", type = Interpolate.Type.VEC3, start = ITEM_START, finish = ITEM_END},
        {key = "itemScale", type = Interpolate.Type.LINEAR, start = examineScalerOld, finish = examineScaler},
        {key = "itemRotation", type = Interpolate.Type.ROTATION, start = itemRotationOld, finish = itemRotation},
    }
    
    local examineReset = {
        useAnimation[2],
        {key = "itemRotation", type = Interpolate.Type.ROTATION, start = itemRotation, finish = examineRotation},
    }
    
    local examineAnimation = {
        useAnimation[1],
        useAnimation[2],
        useAnimation[3],
        {key = "ringFade", type = Interpolate.Type.LINEAR, start = ALPHA_MAX, finish = ALPHA_MIN},
    }
    
    local combineRingAnimation = {
        ringAnimation[1],
        ringAnimation[2],
        ringAnimation[3],
        ringAnimation[4]
    }
    
    local combineClose = {
        {key = "ringFade", type = Interpolate.Type.LINEAR, start = ALPHA_MAX, finish = ALPHA_MIN}
    }
    
    local menuFade = {
        {key = "menuFade", type = Interpolate.Type.LINEAR, start = ALPHA_MIN, finish = ALPHA_MAX}
    }
    
    if mode == INVENTORY_MODE.INVENTORY_OPENING then
        if PerformBatchMotion("MenuFadeIn", menuFade, ANIMATION.ITEM_ANIM_TIME, false, nil, nil, false) then
            return true
        end
    elseif mode == INVENTORY_MODE.RING_OPENING then
        if PerformBatchMotion("RingOpening", ringAnimation, ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing) then
            FadeRings(true, true)
            LevelVars.Engine.RingInventory.InventoryOpenFreeze = true
            return true
        end
    elseif mode == INVENTORY_MODE.RING_CLOSING then
        FadeRings(false, true)
        if PerformBatchMotion("RingClosing", ringAnimation, ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            return true
        end
    elseif mode == INVENTORY_MODE.RING_CHANGE then
        local allMotionComplete = true
        
        for index in pairs(inventory.ring) do
            local oldPosition = inventory.ringPosition[index]
            local newPosition = Vec3(oldPosition.x, oldPosition.y + direction * RING_POSITION_OFFSET, oldPosition.z)
            local motionSet = {
                {key = "ringAngle", type = Interpolate.Type.LINEAR, start = -360, finish = 0},
                {key = "ringCenter", type = Interpolate.Type.VEC3, start = oldPosition, finish = newPosition},
                {key = "ringColor", type = Interpolate.Type.COLOR, start = COLOR_MAP.ITEM_COLOR_DESELECTED, finish = COLOR_MAP.ITEM_COLOR_DESELECTED},
            }
            
            if PerformBatchMotion("RingChange"..index, motionSet, ANIMATION.INVENTORY_ANIM_TIME, true, index) then
                inventory.ringPosition[index] = newPosition
            else
                allMotionComplete = false
            end
        end
        
        if allMotionComplete then
            return true
        end
    elseif mode == INVENTORY_MODE.RING_ROTATE then
        local motionSet = {
            {key = "ringAngle", type = Interpolate.Type.LINEAR, start = currentRingAngle, finish = targetRingAngle},
            {key = "ringColor", type = Interpolate.Type.COLOR, start = COLOR_MAP.ITEM_COLOR_DESELECTED, finish = COLOR_MAP.ITEM_COLOR_DESELECTED},
        }
        
        if PerformBatchMotion("RingRotate", motionSet, ANIMATION.ITEM_ANIM_TIME, true, selectedRing) then
            currentRingAngle = targetRingAngle
            return true
        end
    elseif mode == INVENTORY_MODE.EXAMINE_OPEN or 
           mode == INVENTORY_MODE.STATISTICS_OPEN or 
           mode == INVENTORY_MODE.SAVE_SETUP or 
           mode == INVENTORY_MODE.COMBINE_SETUP or 
           mode == INVENTORY_MODE.ITEM_SELECT or 
           mode == INVENTORY_MODE.COMBINE_SUCCESS then
        if PerformBatchMotion("ExamineOpen", examineAnimation, ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, selectedItem) then
            return true
        end
    elseif mode == INVENTORY_MODE.EXAMINE_CLOSE or 
           mode == INVENTORY_MODE.STATISTICS_CLOSE or 
           mode == INVENTORY_MODE.SAVE_CLOSE or 
           mode == INVENTORY_MODE.ITEM_DESELECT then
        if PerformBatchMotion("ExamineClose", examineAnimation, ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, selectedItem, true) then
            return true
        end
    elseif mode == INVENTORY_MODE.EXAMINE_RESET then
        if PerformBatchMotion("ExamineReset", examineReset, ANIMATION.ITEM_ANIM_TIME, true, selectedRing, selectedItem, true) then
            return true
        end
    elseif mode == INVENTORY_MODE.COMBINE_RING_OPENING or mode == INVENTORY_MODE.AMMO_SELECT_OPEN then
        if PerformBatchMotion("CombineRingOpening", combineRingAnimation, ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing) then
            return true
        end
    elseif mode == INVENTORY_MODE.COMBINE_CLOSE then
        local allMotionComplete = true
        for index in pairs(inventory.ring) do
            if not PerformBatchMotion("combineCloseSuccess"..index, combineClose, ANIMATION.INVENTORY_ANIM_TIME, true, index) then
                allMotionComplete = false
            end
        end
        if allMotionComplete then
            return true
        end
    elseif mode == INVENTORY_MODE.COMBINE_COMPLETE then
        local allMotionComplete = true
        for index in pairs(inventory.ring) do
            if not PerformBatchMotion("combineCloseSuccess"..index, combineClose, ANIMATION.INVENTORY_ANIM_TIME, true, index, nil, true) then
                allMotionComplete = false
            end
        end
        if allMotionComplete then
            return true
        end
    elseif mode == INVENTORY_MODE.ITEM_USE then
        if combineItem1 then
            if not PerformBatchMotion("ItemDeselect", useAnimation, ANIMATION.INVENTORY_ANIM_TIME, false, selectedRing, selectedItem, true) then
                return false
            end
        end
        
        FadeRings(false, true)
        
        if PerformBatchMotion("RingClosing", ringAnimation, ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            if combineItem1 then
                ClearBatchMotionProgress("ItemDeselect", useAnimation)
            end
            return true
        end
        return false
    elseif mode == INVENTORY_MODE.AMMO_SELECT_CLOSE then
        if PerformBatchMotion("AmmoRingClosing", combineRingAnimation, ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            return true
        end
    elseif mode == INVENTORY_MODE.SEPARATE then
        local allMotionComplete = true
        for index in pairs(inventory.ring) do
            if not PerformBatchMotion("combineCloseSuccess"..index, combineClose, ANIMATION.INVENTORY_ANIM_TIME, true, index) then
                allMotionComplete = false
            end
        end
        if allMotionComplete then
            return true
        end
    elseif mode == INVENTORY_MODE.SEPARATE_COMPLETE then
        local allMotionComplete = true
        for index in pairs(inventory.ring) do
            if not PerformBatchMotion("combineCloseSuccess"..index, combineClose, ANIMATION.INVENTORY_ANIM_TIME, true, index, nil, true) then
                allMotionComplete = false
            end
        end
        if allMotionComplete then
            return true
        end
    elseif mode == INVENTORY_MODE.INVENTORY_EXIT then
        if PerformBatchMotion("InventoryExit", menuFade, ANIMATION.ITEM_ANIM_TIME, false, nil, nil, true) then
            return true
        end
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



local function DrawInventory(mode)
    local selectedItem = GetSelectedItem(selectedRing)
    
    if mode == INVENTORY_MODE.INVENTORY then
        RotateItem(tostring(selectedItem.objectID))
        ShowChosenAmmo(selectedItem.objectID, true)
        DrawItemLabel(selectedItem, true)
    elseif mode == INVENTORY_MODE.RING_OPENING then
        if AnimateInventory(mode) then
            if saveSelected then
                itemStoreRotations = true
                inventoryMode = INVENTORY_MODE.SAVE_SETUP
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end
        end
    elseif mode == INVENTORY_MODE.RING_CLOSING then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY_EXIT
        end
    elseif mode == INVENTORY_MODE.RING_ROTATE then
        if AnimateInventory(mode) then
            currentRingAngle = targetRingAngle
            if previousMode then
                inventoryMode = previousMode
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end
        end
    elseif mode == INVENTORY_MODE.RING_CHANGE then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
            for index, _ in ipairs(inventory.selectedItem) do
                inventory.selectedItem[index] = 1
            end
            currentRingAngle = 0
            targetRingAngle = 0
        end
    elseif mode == INVENTORY_MODE.EXAMINE_OPEN then
        SaveItemData(selectedItem)
        DeleteChosenAmmo()
        SetInventoryHeader("examine", true)
        if combineItem1 or AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.EXAMINE
        end
    elseif mode == INVENTORY_MODE.EXAMINE then
        ExamineItem(selectedItem.objectID)
    elseif mode == INVENTORY_MODE.EXAMINE_RESET then
        if AnimateInventory(mode) then
            examineScaler = examineScalerOld
            inventoryMode = INVENTORY_MODE.EXAMINE_CLOSE
        end
    elseif mode == INVENTORY_MODE.EXAMINE_CLOSE then
        SetInventoryHeader("actions_inventory", true)
        if combineItem1 or AnimateInventory(mode) then
            inventoryMode = combineItem1 and INVENTORY_MODE.ITEM_SELECTED or INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.ITEM_SELECT then
        SaveItemData(selectedItem)
        if AnimateInventory(mode) then
            previousRingAngle = currentRingAngle
            combineItem1 = selectedItem.objectID
            SetInventoryHeader(selectedItem.name, true)
            CreateItemMenu(selectedItem.objectID)
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED
        end
    elseif mode == INVENTORY_MODE.ITEM_SELECTED then
        ShowItemMenu()
        ShowChosenAmmo(combineItem1)
    elseif mode == INVENTORY_MODE.ITEM_DESELECT then
        DeleteChosenAmmo(true)
        SetInventoryHeader("actions_inventory", true)
        if AnimateInventory(mode) then
            combineItem1 = nil
            currentRingAngle = previousRingAngle
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.STATISTICS_OPEN then
        DeleteChosenAmmo()
        SaveItemData(selectedItem)
        CreateStatisticsMenu()
        SetInventoryHeader("actions_inventory", false)
        if combineItem1 or AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.STATISTICS
        end
    elseif mode == INVENTORY_MODE.STATISTICS then
        RunStatisticsMenu()
        Statistics.ShowLevelStats(statisticsType)
    elseif mode == INVENTORY_MODE.STATISTICS_CLOSE then
        if combineItem1 or AnimateInventory(mode) then
            SetInventoryHeader("actions_inventory", true)
            inventoryMode = combineItem1 and INVENTORY_MODE.ITEM_SELECTED or INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.SAVE_SETUP then
        DeleteChosenAmmo()
        SaveItemData(selectedItem)
        if combineItem1 or AnimateInventory(mode) then
            CreateSaveMenu(saveList)
            SetInventoryHeader("actions_inventory", false)
            inventoryMode = INVENTORY_MODE.SAVE_MENU
        end
    elseif mode == INVENTORY_MODE.SAVE_MENU then
        RunSaveMenu()
    elseif mode == INVENTORY_MODE.SAVE_CLOSE then
        if combineItem1 then
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED
        elseif AnimateInventory(mode) then
            SetInventoryHeader("actions_inventory", true)
            if saveSelected then
                saveSelected = false
                inventoryMode = INVENTORY_MODE.RING_CLOSING
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end
        end
    elseif mode == INVENTORY_MODE.COMBINE_SETUP then
        DeleteChosenAmmo()
        SaveItemData(selectedItem)
        if combineItem1 or AnimateInventory(mode) then
            SetupSecondaryRing(RING.COMBINE)
            SetInventoryHeader(selectedItem.name, true)
            SetInventorySubHeader("combine_with", true)
            inventoryMode = INVENTORY_MODE.COMBINE_RING_OPENING
        end
    elseif mode == INVENTORY_MODE.COMBINE_RING_OPENING then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.COMBINE
        end
    elseif mode == INVENTORY_MODE.COMBINE then
        RotateItem(tostring(selectedItem.objectID))
        DrawItemLabel(selectedItem, true)
        
        if performCombine then
            combineItem2 = GetSelectedItem(RING.COMBINE).objectID
            if CombineItems(combineItem1, combineItem2) then
                TEN.Sound.PlaySound(SOUND_MAP.MENU_COMBINE)
                inventoryMode = INVENTORY_MODE.COMBINE_SUCCESS
            else
                TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                performCombine = false
            end
        end
    elseif mode == INVENTORY_MODE.COMBINE_SUCCESS then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.COMBINE_CLOSE
        end
    elseif mode == INVENTORY_MODE.COMBINE_CLOSE then
        if AnimateInventory(mode) then
            SetInventorySubHeader("combine_with", false)
            SetInventoryHeader("actions_inventory", true)
            inventoryOpenItem = combineResult and combineResult or combineItem1
            combineItem1 = nil
            combineItem2 = nil
            combineResult = nil
            performCombine = false
            inventoryMode = INVENTORY_MODE.COMBINE_COMPLETE
            LevelVars.Engine.RingInventory.InventoryOpen = true
        end
    elseif mode == INVENTORY_MODE.COMBINE_COMPLETE then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.ITEM_USE then
        SaveItemData(selectedItem)
        DeleteChosenAmmo()
        SetInventoryHeader("actions_inventory", true)
        if AnimateInventory(mode) then
            UseItem(selectedItem.objectID)
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT_SETUP then
        SaveItemData(selectedItem)
        DeleteChosenAmmo()
        SetupSecondaryRing(RING.AMMO, combineItem1)
        inventoryMode = INVENTORY_MODE.AMMO_SELECT_OPEN
    elseif mode == INVENTORY_MODE.AMMO_SELECT_OPEN then
        if AnimateInventory(mode) then
            SetInventorySubHeader("choose_ammo", true)
            inventoryMode = INVENTORY_MODE.AMMO_SELECT
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT then
        RotateItem(tostring(selectedItem.objectID))
        DrawItemLabel(selectedItem, false)
        if performCombine then
            local ammo = PICKUP_DATA.AMMO_SET[selectedItem.objectID]
            Lara:SetAmmoType(ammo.slot)
            inventoryMode = INVENTORY_MODE.AMMO_SELECT_CLOSE
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT_CLOSE then
        if AnimateInventory(mode) then
            performCombine = false
            selectedRing = previousRing
            SetInventorySubHeader("choose_ammo", false)
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED
        end
    elseif mode == INVENTORY_MODE.SEPARATE then
        DeleteChosenAmmo()
        if AnimateInventory(mode) then
            SeparateItems(selectedItem.objectID)
            inventoryOpenItem = combineItem1
            combineItem1 = nil
            LevelVars.Engine.RingInventory.InventoryOpen = true
            inventoryMode = INVENTORY_MODE.SEPARATE_COMPLETE
        end
    elseif mode == INVENTORY_MODE.SEPARATE_COMPLETE then
        SetInventoryHeader("actions_inventory", true)
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.WEAPON_MODE_SETUP then
        CreateWeaponModeMenu(combineItem1)
        SetInventorySubHeader("choose_ammo", true)
        inventoryMode = INVENTORY_MODE.WEAPON_MODE
    elseif mode == INVENTORY_MODE.WEAPON_MODE then
        RunWeaponModeMenu()
    elseif mode == INVENTORY_MODE.WEAPON_MODE_CLOSE then
        SetInventorySubHeader("choose_ammo", false)
        inventoryMode = INVENTORY_MODE.ITEM_SELECTED
    elseif mode == INVENTORY_MODE.INVENTORY_OPENING then
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.RING_OPENING
        end
    elseif mode == INVENTORY_MODE.INVENTORY_EXIT then
        if AnimateInventory(mode) then
            ExitInventory()
        end
    end
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

-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.RingInventory)
-- ============================================================================

LevelFuncs.Engine.RingInventory.DoItemAction = DoItemAction
LevelFuncs.Engine.RingInventory.UpdateInventory = UpdateInventory
LevelFuncs.Engine.RingInventory.RunInventory = RunInventory

-- ============================================================================
-- CALLBACKS
-- ============================================================================

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.RingInventory.UpdateInventory)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.RingInventory.RunInventory)

return CustomInventory