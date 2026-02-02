-- ============================================================================
-- ANIMATION FUNCTIONS
-- ============================================================================

--External Modules
local Interpolate = require("Engine.RingInventory.Interpolate")
local InventoryData= require("Engine.RingInventory.InventoryData")
local PICKUP_DATA = require("Engine.RingInventory.PickupData")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointers to tables
local CONSTANTS = require("Engine.RingInventory.Constants")
local INVENTORY_MODE = PICKUP_DATA.INVENTORY_MODE
local COLOR_MAP = Settings.COLOR_MAP

--Combine functions
local Animation = {}

function Animation.Clear(prefix, motionTable)
    for _, motion in ipairs(motionTable) do
        local id = prefix..motion.key
        Interpolate.Clear(id)
    end
end

function Animation.PerformBatchMotion(prefix, motionTable, time, clearProgress, ringName, item, reverse)
    local interpolated = {}
    local allComplete = true
    local omitSelectedItem = item and true or false
    
    for _, motion in ipairs(motionTable) do
        local id = prefix..motion.key
        local interp = {output = motion.start, progress = CONSTANTS.PROGRESS_COMPLETE}
        
        if motion.start ~= motion.finish then
            local startVal = reverse and motion.finish or motion.start
            local endVal = reverse and motion.start or motion.finish
            interp = Interpolate.Calculate(id, motion.type, startVal, endVal, time, true)
        end
        
        interpolated[motion.key] = interp
        
        if interp.progress < CONSTANTS.PROGRESS_COMPLETE then
            allComplete = false
        end
    end
    
    if interpolated.ringCenter or interpolated.ringRadius or interpolated.ringAngle then
        local center = interpolated.ringCenter and interpolated.ringCenter.output or inventory.ringPosition[ringName]
        local radius = interpolated.ringRadius and interpolated.ringRadius.output or CONSTANTS.RING_RADIUS
        local angle = interpolated.ringAngle and interpolated.ringAngle.output or 0
        Ring.Translate(ringName, center, radius, angle, ITEM_SPINBACK_ALPHA)
    end
    
    if interpolated.ringColor then
        Ring.Color(ringName, interpolated.ringColor.output, omitSelectedItem, ITEM_SPINBACK_ALPHA)
    end
    
    if interpolated.ringFade then
        Ring.FadeRing(ringName, interpolated.ringFade.output, omitSelectedItem)
    end
    
    if interpolated.menuFade then
        menuAlpha = interpolated.menuFade.output
    end
    
    if interpolated.camera then
        TEN.View.DisplayItem.SetCameraPosition(interpolated.camera.output, false)
    end
    
    if interpolated.target then
        TEN.View.DisplayItem.SetTargetPosition(interpolated.target.output, false)
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
            Animation.ClearBatchMotionProgress(prefix, motionTable)
        end
        return true
    end
end

function Animation.Inventory(mode)
    local selectedItem = GetSelectedItem(selectedRing)
    
    local ringAnimation = {
        {key = "ringRadius", type = Interpolate.Type.LINEAR, start = 0, finish = CONSTANTS.RING_RADIUS},
        {key = "ringAngle", type = Interpolate.Type.LINEAR, start = -360, finish = currentRingAngle},
        {key = "ringCenter", type = Interpolate.Type.VEC3, start = inventory.ringPosition[selectedRing], finish = inventory.ringPosition[selectedRing]},
        {key = "ringFade", type = Interpolate.Type.LINEAR, start = CONSTANTS.ALPHA_MIN, finish = CONSTANTS.ALPHA_MAX},
        {key = "camera", type = Interpolate.Type.VEC3, start = CONSTANTS.CAMERA_START, finish = CONSTANTS.CAMERA_END},
        {key = "target", type = Interpolate.Type.VEC3, start = CONSTANTS.TARGET_START, finish = CONSTANTS.TARGET_END},
    }
    
    local useAnimation = {
        {key = "itemPosition", type = Interpolate.Type.VEC3, start = CONSTANTS.ITEM_START, finish = CONSTANTS.ITEM_END},
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
        {key = "ringFade", type = Interpolate.Type.LINEAR, start = CONSTANTS.ALPHA_MAX, finish = CONSTANTS.ALPHA_MIN},
    }
    
    local combineRingAnimation = {
        ringAnimation[1],
        ringAnimation[2],
        ringAnimation[3],
        ringAnimation[4]
    }
    
    local combineClose = {
        {key = "ringFade", type = Interpolate.Type.LINEAR, start = CONSTANTS.ALPHA_MAX, finish = CONSTANTS.ALPHA_MIN}
    }
    
    local menuFade = {
        {key = "menuFade", type = Interpolate.Type.LINEAR, start = CONSTANTS.ALPHA_MIN, finish = CONSTANTS.ALPHA_MAX}
    }
    
    if mode == INVENTORY_MODE.INVENTORY_OPENING then
        if Animation.PerformBatchMotion("MenuFadeIn", menuFade, Settings.ANIMATION.ITEM_ANIM_TIME, false, nil, nil, false) then
            return true
        end
    elseif mode == INVENTORY_MODE.RING_OPENING then
        if Animation.PerformBatchMotion("RingOpening", ringAnimation, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing) then
            Ring.FadeAll(true, true)
            LevelVars.Engine.RingInventory.InventoryOpenFreeze = true
            return true
        end
    elseif mode == INVENTORY_MODE.RING_CLOSING then
        Ring.FadeAll(false, true)
        if Animation.PerformBatchMotion("RingClosing", ringAnimation, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            return true
        end
    elseif mode == INVENTORY_MODE.RING_CHANGE then
        local allMotionComplete = true
        
        local rings = InventoryData.GetAllRings()
        for index in pairs(rings) do
            local oldPosition = inventory.ringPosition[index]
            local newPosition = Vec3(oldPosition.x, oldPosition.y + direction * CONSTANTS.RING_POSITION_OFFSET, oldPosition.z)
            local motionSet = {
                {key = "ringAngle", type = Interpolate.Type.LINEAR, start = -360, finish = 0},
                {key = "ringCenter", type = Interpolate.Type.VEC3, start = oldPosition, finish = newPosition},
                {key = "ringColor", type = Interpolate.Type.COLOR, start = COLOR_MAP.ITEM_COLOR_DESELECTED, finish = COLOR_MAP.ITEM_COLOR_DESELECTED},
            }
            
            if Animation.PerformBatchMotion("RingChange"..index, motionSet, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, index) then
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
        
        if Animation.PerformBatchMotion("RingRotate", motionSet, Settings.ANIMATION.ITEM_ANIM_TIME, true, selectedRing) then
            currentRingAngle = targetRingAngle
            return true
        end
    elseif mode == INVENTORY_MODE.EXAMINE_OPEN or 
           mode == INVENTORY_MODE.STATISTICS_OPEN or 
           mode == INVENTORY_MODE.SAVE_SETUP or 
           mode == INVENTORY_MODE.COMBINE_SETUP or 
           mode == INVENTORY_MODE.ITEM_SELECT or 
           mode == INVENTORY_MODE.COMBINE_SUCCESS then
        if Animation.PerformBatchMotion("ExamineOpen", examineAnimation, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, selectedItem) then
            return true
        end
    elseif mode == INVENTORY_MODE.EXAMINE_CLOSE or 
           mode == INVENTORY_MODE.STATISTICS_CLOSE or 
           mode == INVENTORY_MODE.SAVE_CLOSE or 
           mode == INVENTORY_MODE.ITEM_DESELECT then
        if Animation.PerformBatchMotion("ExamineClose", examineAnimation, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, selectedItem, true) then
            return true
        end
    elseif mode == INVENTORY_MODE.EXAMINE_RESET then
        if Animation.PerformBatchMotion("ExamineReset", examineReset, Settings.ANIMATION.ITEM_ANIM_TIME, true, selectedRing, selectedItem, true) then
            return true
        end
    elseif mode == INVENTORY_MODE.COMBINE_RING_OPENING or mode == INVENTORY_MODE.AMMO_SELECT_OPEN then
        if Animation.PerformBatchMotion("CombineRingOpening", combineRingAnimation, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing) then
            return true
        end
    elseif mode == INVENTORY_MODE.COMBINE_CLOSE then
        local allMotionComplete = true
        local rings = InventoryData.GetAllRings()
        for index in pairs(rings) do
            if not Animation.PerformBatchMotion("combineCloseSuccess"..index, combineClose, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, index) then
                allMotionComplete = false
            end
        end
        if allMotionComplete then
            return true
        end
    elseif mode == INVENTORY_MODE.COMBINE_COMPLETE then
        local allMotionComplete = true
        local rings = InventoryData.GetAllRings()
        for index in pairs(rings) do
            if not Animation.PerformBatchMotion("combineCloseSuccess"..index, combineClose, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, index, nil, true) then
                allMotionComplete = false
            end
        end
        if allMotionComplete then
            return true
        end
    elseif mode == INVENTORY_MODE.ITEM_USE then
        if combineItem1 then
            if not Animation.PerformBatchMotion("ItemDeselect", useAnimation, Settings.ANIMATION.INVENTORY_ANIM_TIME, false, selectedRing, selectedItem, true) then
                return false
            end
        end
        
        Ring.FadeAll(false, true)
        
        if Animation.PerformBatchMotion("RingClosing", ringAnimation, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            if combineItem1 then
                Animation.ClearBatchMotionProgress("ItemDeselect", useAnimation)
            end
            return true
        end
        return false
    elseif mode == INVENTORY_MODE.AMMO_SELECT_CLOSE then
        if Animation.PerformBatchMotion("AmmoRingClosing", combineRingAnimation, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            return true
        end
    elseif mode == INVENTORY_MODE.SEPARATE then
        local allMotionComplete = true
        local rings = InventoryData.GetAllRings()
        for index in pairs(rings) do
            if not Animation.PerformBatchMotion("combineCloseSuccess"..index, combineClose, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, index) then
                allMotionComplete = false
            end
        end
        if allMotionComplete then
            return true
        end
    elseif mode == INVENTORY_MODE.SEPARATE_COMPLETE then
        local allMotionComplete = true
        local rings = InventoryData.GetAllRings()
        for index in pairs(rings) do
            if not Animation.PerformBatchMotion("combineCloseSuccess"..index, combineClose, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, index, nil, true) then
                allMotionComplete = false
            end
        end
        if allMotionComplete then
            return true
        end
    elseif mode == INVENTORY_MODE.INVENTORY_EXIT then
        if Animation.PerformBatchMotion("InventoryExit", menuFade, Settings.ANIMATION.ITEM_ANIM_TIME, false, nil, nil, true) then
            return true
        end
    end
end

return Animation