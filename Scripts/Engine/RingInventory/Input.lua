-- InputHandler.lua
-- Manages input state, pulsing, and action callbacks for the inventory system

local InputHandler = {}

-- Configuration
local PULSE_DELAY = 120
local PULSE_INITIAL_DELAY = 30

-- Action pairs that lock each other
local OPPOSITE_ACTIONS = {
    [TEN.Input.ActionID.FORWARD] = TEN.Input.ActionID.BACK,
    [TEN.Input.ActionID.BACK] = TEN.Input.ActionID.FORWARD,
    [TEN.Input.ActionID.LEFT] = TEN.Input.ActionID.RIGHT,
    [TEN.Input.ActionID.RIGHT] = TEN.Input.ActionID.LEFT
}

-- State
InputHandler.timeInMenu = 0
InputHandler.actionCallbacks = {}

-- Update the menu timer (call once per frame)
function InputHandler.Update()
    InputHandler.timeInMenu = InputHandler.timeInMenu + 1
end

-- Reset the menu timer (when opening inventory)
function InputHandler.Reset()
    InputHandler.timeInMenu = 0
end

-- Clear all registered callbacks
function InputHandler.ClearCallbacks()
    InputHandler.actionCallbacks = {}
end

-- Check if an action is pulsed with delay and locking logic
function InputHandler.IsPulsed(actionID)
    -- Action already held prior to entering menu; lock input
    if TEN.Input.GetActionTimeActive(actionID) >= InputHandler.timeInMenu then
        return false
    end
    
    -- Check if opposite action is held (locks input)
    local oppositeAction = OPPOSITE_ACTIONS[actionID]
    if oppositeAction and TEN.Input.IsKeyHeld(oppositeAction) then
        return false
    end
    
    -- Return pulsed state with delays
    return TEN.Input.IsKeyPulsed(actionID, PULSE_DELAY, PULSE_INITIAL_DELAY)
end

-- Check if an action is held
function InputHandler.IsHeld(actionID)
    return TEN.Input.IsKeyHeld(actionID)
end

-- Check if an action is hit (single frame)
function InputHandler.IsHit(actionID)
    return TEN.Input.IsKeyHit(actionID)
end

-- Get current time in menu
function InputHandler.GetTimeInMenu()
    return InputHandler.timeInMenu
end

-- Register a callback for a pulsed action in a specific mode
function InputHandler.RegisterCallback(mode, actionID, callback)
    InputHandler.actionCallbacks[mode] = InputHandler.actionCallbacks[mode] or {}
    InputHandler.actionCallbacks[mode].pulsed = InputHandler.actionCallbacks[mode].pulsed or {}
    InputHandler.actionCallbacks[mode].pulsed[actionID] = callback
end

-- Register a callback for a held action in a specific mode
function InputHandler.RegisterHeldCallback(mode, actionID, callback)
    InputHandler.actionCallbacks[mode] = InputHandler.actionCallbacks[mode] or {}
    InputHandler.actionCallbacks[mode].held = InputHandler.actionCallbacks[mode].held or {}
    InputHandler.actionCallbacks[mode].held[actionID] = callback
end

-- Register a callback for a hit action in a specific mode
function InputHandler.RegisterHitCallback(mode, actionID, callback)
    InputHandler.actionCallbacks[mode] = InputHandler.actionCallbacks[mode] or {}
    InputHandler.actionCallbacks[mode].hit = InputHandler.actionCallbacks[mode].hit or {}
    InputHandler.actionCallbacks[mode].hit[actionID] = callback
end

-- Process pulsed actions for the current mode
function InputHandler.ProcessPulsedActions(mode, context)
    local callbacks = InputHandler.actionCallbacks[mode]
    if not callbacks or not callbacks.pulsed then
        return false
    end
    
    for actionID, callback in pairs(callbacks.pulsed) do
        if InputHandler.IsPulsed(actionID) then
            callback(context)
            return true
        end
    end
    
    return false
end

-- Process held actions for the current mode
function InputHandler.ProcessHeldActions(mode, context)
    local callbacks = InputHandler.actionCallbacks[mode]
    if not callbacks or not callbacks.held then
        return false
    end
    
    for actionID, callback in pairs(callbacks.held) do
        if InputHandler.IsHeld(actionID) then
            callback(context)
            -- Don't return true - allow multiple held actions
        end
    end
    
    return false
end

-- Process hit actions for the current mode
function InputHandler.ProcessHitActions(mode, context)
    local callbacks = InputHandler.actionCallbacks[mode]
    if not callbacks or not callbacks.hit then
        return false
    end
    
    for actionID, callback in pairs(callbacks.hit) do
        if InputHandler.IsHit(actionID) then
            callback(context)
            return true
        end
    end
    
    return false
end

-- Process all input types for the current mode
function InputHandler.ProcessMode(mode, context)
    -- Process in order: pulsed (returns early), then held, then hit
    if InputHandler.ProcessPulsedActions(mode, context) then
        return true
    end
    
    InputHandler.ProcessHeldActions(mode, context)
    InputHandler.ProcessHitActions(mode, context)
    
    return false
end

-- Helper: Register common navigation callbacks
function InputHandler.RegisterNavigation(mode, leftCallback, rightCallback, upCallback, downCallback)
    if leftCallback then
        InputHandler.RegisterCallback(mode, TEN.Input.ActionID.LEFT, leftCallback)
    end
    if rightCallback then
        InputHandler.RegisterCallback(mode, TEN.Input.ActionID.RIGHT, rightCallback)
    end
    if upCallback then
        InputHandler.RegisterCallback(mode, TEN.Input.ActionID.FORWARD, upCallback)
    end
    if downCallback then
        InputHandler.RegisterCallback(mode, TEN.Input.ActionID.BACK, downCallback)
    end
end

-- Helper: Register common action/select callbacks
function InputHandler.RegisterActions(mode, actionCallback, selectCallback)
    if actionCallback then
        InputHandler.RegisterCallback(mode, TEN.Input.ActionID.ACTION, actionCallback)
    end
    if selectCallback then
        InputHandler.RegisterCallback(mode, TEN.Input.ActionID.SELECT, selectCallback)
    end
end

-- Helper: Register common close callbacks
function InputHandler.RegisterClose(mode, closeCallback)
    InputHandler.RegisterCallback(mode, TEN.Input.ActionID.INVENTORY, closeCallback)
    InputHandler.RegisterCallback(mode, TEN.Input.ActionID.DESELECT, closeCallback)
end

return InputHandler