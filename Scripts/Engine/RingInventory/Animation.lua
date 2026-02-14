-- ============================================================================
-- ANIMATION FUNCTIONS
-- ============================================================================

--External Modules
local Constants = require("Engine.RingInventory.Constants")
local Examine = require("Engine.RingInventory.Examine")
local Interpolate = require("Engine.RingInventory.Interpolate")
local InventoryData = require("Engine.RingInventory.InventoryData")
local Ring = require("Engine.RingInventory.Ring")
local Settings = require("Engine.RingInventory.Settings")
local Utilities = require("Engine.RingInventory.Utilities")

--Variables
local itemRotation = Rotation(0, 0, 0)
local itemRotationOld = Rotation(0, 0, 0)
local itemStoreRotations = false
local menuAlpha = 0

--Animation functions
local Animation = {}

function Animation.SaveItemData(selectedItem)
    if itemStoreRotations then
        local displayItem = selectedItem:GetDisplayItem()
        itemRotationOld = displayItem:GetRotation()
        itemRotation = selectedItem:GetRotation()
        Examine.SetRotation(selectedItem:GetRotation())
        Examine.SetScale(selectedItem:GetScale())
        itemStoreRotations = false
    end
end

function Animation.EnableSaveItemData()
    itemStoreRotations = true
end

function Animation.Clear(prefix, motionTable)
    for _, motion in ipairs(motionTable) do
        local id = prefix..motion.key
        Interpolate.Clear(id)
    end
end

function Animation.PerformBatchMotion(prefix, motionTable, time, clearProgress, selectedRing, item, reverse)
    local interpolated = {}
    local allComplete = true
    local ringName = selectedRing and selectedRing:GetType() or nil
    
    for _, motion in ipairs(motionTable) do
        local id = prefix..motion.key
        local interp = {output = motion.start, progress = Constants.PROGRESS_COMPLETE}
        
        if motion.start ~= motion.finish then
            local startVal = reverse and motion.finish or motion.start
            local endVal = reverse and motion.start or motion.finish
            interp = Interpolate.Calculate(id, startVal, endVal, time, Interpolate.Easing.Smoothstep)
        end
        
        interpolated[motion.key] = interp
        
        if interp.progress < Constants.PROGRESS_COMPLETE then
            allComplete = false
        end
    end
    
    if selectedRing and (interpolated.ringCenter or interpolated.ringRadius or interpolated.ringAngle) then
        local center = interpolated.ringCenter and interpolated.ringCenter.output or Ring.CENTERS[ringName]
        local radius = interpolated.ringRadius and interpolated.ringRadius.output or Ring.RING_RADIUS
        local angle = interpolated.ringAngle and interpolated.ringAngle.output or 0
        selectedRing:Translate(center, radius, angle)
    end
    
    if selectedRing and interpolated.ringColor then
        selectedRing:Color(interpolated.ringColor.output, item)
    end
    
    if selectedRing and interpolated.ringFade then
        selectedRing:Fade(interpolated.ringFade.output, item)
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
        local displayItem = item:GetDisplayItem()
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
            Animation.Clear(prefix, motionTable)
        end
        return true
    end
end

function Animation.Inventory(mode, selectedRing, selectedItem)
    local InventoryStates = require("Engine.RingInventory.InventoryStates")
    local INVENTORY_MODE = InventoryStates.MODE
    
    local ringAnimation = {
        {key = "ringRadius", start = 0, finish = Ring.RING_RADIUS},
        {key = "ringAngle", start = -360, finish = selectedRing:GetCurrentAngle()},
        {key = "ringFade", start = Constants.ALPHA_MIN, finish = Constants.ALPHA_MAX},
        {key = "camera", start = Constants.CAMERA_START, finish = Constants.CAMERA_END},
        {key = "target", start = Constants.TARGET_START, finish = Constants.TARGET_END},
    }
    
    local useAnimation = {
        {key = "itemPosition", start = Constants.ITEM_START, finish = Constants.ITEM_END},
        {key = "itemScale", start = Examine.GetPreviousScale(), finish = Examine.GetScale()},
        {key = "itemRotation", start = itemRotationOld, finish = itemRotation},
    }
    
    local examineReset = {
        useAnimation[2],
        {key = "itemRotation", start = itemRotation, finish = Examine.GetRotation()},
    }
    
    local examineAnimation = {
        useAnimation[1],
        useAnimation[2],
        useAnimation[3],
        {key = "ringFade", start = Constants.ALPHA_MAX, finish = Constants.ALPHA_MIN},
    }
    
    local combineRingAnimation = {
        ringAnimation[1],
        ringAnimation[2],
        ringAnimation[3]
    }
    
    local combineClose = {
        {key = "ringFade", start = Constants.ALPHA_MAX, finish = Constants.ALPHA_MIN}
    }
    
    local menuFade = {
        {key = "menuFade", start = Constants.ALPHA_MIN, finish = Constants.ALPHA_MAX}
    }

    local ringRotate = {
        {key = "ringAngle", start = selectedRing:GetCurrentAngle(), finish = selectedRing:GetTargetAngle()},
        {key = "ringCenter", start = selectedRing:GetPosition(), finish = selectedRing:GetPosition()}
    }

    if mode == INVENTORY_MODE.RING_OPENING then
        if Animation.PerformBatchMotion("RingOpening", ringAnimation, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing) then
            InventoryData.FadeAll(true, true)
            LevelVars.Engine.RingInventory.InventoryOpenFreeze = true
            return true
        end
    elseif mode == INVENTORY_MODE.RING_CLOSING then
        InventoryData.FadeAll(false, true)
        if Animation.PerformBatchMotion("RingClosing", ringAnimation, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            return true
        end
    elseif mode == INVENTORY_MODE.RING_CHANGE then
        local allMotionComplete = true
        
        local rings = InventoryData.GetAllRings()
        for ringType, ring in pairs(rings) do

            local ringChange = 
            {
            {key = "ringAngle", start = -360, finish = 0},
            {key = "ringCenter", start = ring:GetPreviousPosition(), finish = ring:GetPosition()},
            }
            if not Animation.PerformBatchMotion("RingChange"..ringType, ringChange, Settings.ANIMATION.INVENTORY_ANIM_TIME, true, ring) then
                allMotionComplete = false
            end
        end

        if allMotionComplete then
            return true
        end
    elseif mode == INVENTORY_MODE.RING_ROTATE then
        if Animation.PerformBatchMotion("RingRotate", ringRotate, Settings.ANIMATION.ITEM_ANIM_TIME, true, selectedRing) then
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
        
        InventoryData.FadeAll(false, true)
        
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
    end
end

return Animation