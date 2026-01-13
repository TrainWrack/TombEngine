-- STATE MACHINE WITH LIFECYCLE PHASES
-- Consolidates setup/animation/active/closing into single states

-- ============================================================================
-- STATE LIFECYCLE - SIMPLIFIED
-- ============================================================================

--[[
    Each state has just 3 lifecycle hooks:
    
    onEnter() → onUpdate() → onExit()
       ↓           ↓            ↓
     Setup     Main Loop    Cleanup & Next State
     
    Example: EXAMINE state
    
    onEnter:  Save item data, start opening animation
    onUpdate: Handle animation, then user interaction, then closing animation
    onExit:   Cleanup, return next state
    
    Benefits:
    - Simple, predictable lifecycle
    - All state logic in one place
    - Phases are internal to onUpdate (using internal state)
    - Only 3 methods to understand
]]

local StatePhase = {
    OPENING = "opening",
    ACTIVE = "active",
    CLOSING = "closing"
}

-- ============================================================================
-- STATE MACHINE WITH STATE-LOCAL VARIABLES
-- ============================================================================

local InventoryStateMachine = {
    currentMode = nil,
    phase = StatePhase.OPENING,
    nextMode = nil,
    stateData = {}  -- NEW: State-local storage
}

-- ============================================================================
-- STATE DEFINITIONS WITH STATE-LOCAL VARIABLES
-- ============================================================================
local StateTransitions = {}
--[[

    -- ========================================================================
    -- EXAMINE STATE - With state-local variables
    -- ========================================================================
    [INVENTORY_MODE.EXAMINE] = {
        onEnter = function()
            -- Setup
            local selectedItem = GetSelectedItem(selectedRing)
            SaveItemData(selectedItem)
            DeleteChosenAmmo()
            TextChannels.SetText("HEADER", "examine", true)
            
            -- Initialize state-local variables
            InventoryStateMachine.stateData = {
                startRotation = CopyRotation(examineRotation),
                targetRotation = CopyRotation(selectedItem.rotation),
                startScale = examineScaler,
                zoomLevel = 1.0,
                rotationSpeed = 0.0,
                showingText = false,
                timeInState = 0
            }
            
            InventoryStateMachine.phase = StatePhase.OPENING
        end,
        
        onUpdate = function()
            local data = InventoryStateMachine.stateData
            data.timeInState = data.timeInState + 1
            
            local selectedItem = GetSelectedItem(selectedRing)
            
            if InventoryStateMachine.phase == StatePhase.OPENING then
                if AnimateInventory(INVENTORY_MODE.EXAMINE_OPEN) then
                    InventoryStateMachine.phase = StatePhase.ACTIVE
                end
                
            elseif InventoryStateMachine.phase == StatePhase.ACTIVE then
                -- Use state-local variables
                ExamineItem(selectedItem.objectID)
                
                -- Track rotation speed for momentum effect
                local oldRotation = data.startRotation
                local newRotation = examineRotation
                data.rotationSpeed = math.abs(newRotation.y - oldRotation.y)
                data.startRotation = CopyRotation(newRotation)
                
                -- Auto-show text after 2 seconds in state
                if data.timeInState > 60 and not data.showingText then
                    data.showingText = true
                    examineShowString = true
                end
                
            elseif InventoryStateMachine.phase == StatePhase.CLOSING then
                TextChannels.SetText("HEADER", "actions_inventory", true)
                if AnimateInventory(INVENTORY_MODE.EXAMINE_CLOSE) then
                    return combineItem1 and INVENTORY_MODE.ITEM_MENU or INVENTORY_MODE.INVENTORY
                end
            end
        end,
        
        onExit = function(nextState)
            -- Cleanup (state-local variables automatically cleared)
            examineShowString = false
            InventoryStateMachine.stateData = {}  -- Clear state data
            return nextState
        end
    },
    
    -- ========================================================================
    -- COMBINE STATE - With sophisticated state tracking
    -- ========================================================================
    [INVENTORY_MODE.COMBINE] = {
        onEnter = function()
            local selectedItem = GetSelectedItem(selectedRing)
            DeleteChosenAmmo()
            SaveItemData(selectedItem)
            SetupSecondaryRing(RING.COMBINE)
            TextChannels.SetText("HEADER", selectedItem.name, true)
            TextChannels.SetText("SUB_HEADER", "combine_with", true)
            
            -- State-local tracking
            InventoryStateMachine.stateData = {
                item1 = selectedItem.objectID,
                item2 = nil,
                attempts = 0,  -- Track failed combine attempts
                hintShown = false,
                rotationAngle = 0,
                pulsePhase = 0,  -- For pulsing compatible items
                compatibleItems = {}  -- Cache which items can combine with item1
            }
            
            -- Pre-calculate compatible items
            for _, combo in ipairs(PICKUP_DATA.combineTable) do
                if combo[1] == selectedItem.objectID then
                    table.insert(InventoryStateMachine.stateData.compatibleItems, combo[2])
                elseif combo[2] == selectedItem.objectID then
                    table.insert(InventoryStateMachine.stateData.compatibleItems, combo[1])
                end
            end
            
            InventoryStateMachine.phase = StatePhase.OPENING
        end,
        
        onUpdate = function()
            local data = InventoryStateMachine.stateData
            
            if InventoryStateMachine.phase == StatePhase.OPENING then
                if AnimateInventory(INVENTORY_MODE.COMBINE_RING_OPENING) then
                    InventoryStateMachine.phase = StatePhase.ACTIVE
                end
                
            elseif InventoryStateMachine.phase == StatePhase.ACTIVE then
                local selectedItem = GetSelectedItem(selectedRing)
                RotateItem(tostring(selectedItem.objectID))
                DrawItemLabel(selectedItem, true)
                
                -- Visual hint: pulse compatible items
                data.pulsePhase = (data.pulsePhase + 0.1) % (2 * math.pi)
                for _, compatibleID in ipairs(data.compatibleItems) do
                    local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(compatibleID))
                    if displayItem then
                        local pulse = 200 + 55 * math.sin(data.pulsePhase)
                        displayItem:SetColor(Color(255, 255, pulse, 255))
                    end
                end
                
                if performCombine then
                    data.item2 = GetSelectedItem(RING.COMBINE).objectID
                    
                    if CombineItems(data.item1, data.item2) then
                        TEN.Sound.PlaySound(SOUND_MAP.MENU_COMBINE)
                        InventoryStateMachine.phase = StatePhase.CLOSING
                    else
                        -- Track failed attempts
                        data.attempts = data.attempts + 1
                        TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                        
                        -- Show hint after 3 failed attempts
                        if data.attempts >= 3 and not data.hintShown then
                            data.hintShown = true
                            -- Could show a hint message here
                        end
                        
                        performCombine = false
                    end
                end
                
            elseif InventoryStateMachine.phase == StatePhase.CLOSING then
                TextChannels.SetText("SUB_HEADER", "combine_with", false)
                TextChannels.SetText("HEADER", "actions_inventory", true)
                
                local allComplete = true
                for index in pairs(inventory.ring) do
                    if not AnimateInventory_Ring(index, "close") then
                        allComplete = false
                    end
                end
                
                if allComplete then
                    inventoryOpenItem = combineResult or data.item1
                    LevelVars.Engine.CustomInventory.InventoryOpen = true
                    return INVENTORY_MODE.INVENTORY
                end
            end
        end,
        
        onExit = function(nextState)
            -- Cleanup
            combineItem1 = nil
            combineItem2 = nil
            combineResult = nil
            performCombine = false
            InventoryStateMachine.stateData = {}
            return nextState
        end
    },
    
    -- ========================================================================
    -- ITEM_MENU STATE - Track menu navigation
    -- ========================================================================
    [INVENTORY_MODE.ITEM_MENU] = {
        onEnter = function()
            local selectedItem = GetSelectedItem(selectedRing)
            SaveItemData(selectedItem)
            
            -- State-local menu tracking
            InventoryStateMachine.stateData = {
                itemID = selectedItem.objectID,
                menuIndex = 1,
                previousIndex = 1,
                selectionTime = 0,
                quickSelectEnabled = false  -- Enable after user learns menu
            }
            
            InventoryStateMachine.phase = StatePhase.OPENING
        end,
        
        onUpdate = function()
            local data = InventoryStateMachine.stateData
            data.selectionTime = data.selectionTime + 1
            
            if InventoryStateMachine.phase == StatePhase.OPENING then
                if AnimateInventory(INVENTORY_MODE.ITEM_SELECT) then
                    local selectedItem = GetSelectedItem(selectedRing)
                    previousRingAngle = currentRingAngle
                    combineItem1 = selectedItem.objectID
                    TextChannels.SetText("HEADER", selectedItem.name, true)
                    CreateItemMenu(selectedItem.objectID)
                    InventoryStateMachine.phase = StatePhase.ACTIVE
                end
                
            elseif InventoryStateMachine.phase == StatePhase.ACTIVE then
                ShowItemMenu()
                ShowChosenAmmo(combineItem1)
                
                -- Enable quick select after user spends time in menu
                if data.selectionTime > 300 then  -- 10 seconds
                    data.quickSelectEnabled = true
                end
                
                -- Could implement quick-select shortcuts here
                -- if data.quickSelectEnabled and key pressed then...
                
            elseif InventoryStateMachine.phase == StatePhase.CLOSING then
                DeleteChosenAmmo()
                TextChannels.SetText("HEADER", "actions_inventory", true)
                if AnimateInventory(INVENTORY_MODE.ITEM_DESELECT) then
                    return INVENTORY_MODE.INVENTORY
                end
            end
        end,
        
        onExit = function(nextState)
            combineItem1 = nil
            currentRingAngle = previousRingAngle
            InventoryStateMachine.stateData = {}
            return nextState
        end
    },
    
    -- ========================================================================
    -- AMMO_SELECT - Track ammo usage patterns
    -- ========================================================================
    [INVENTORY_MODE.AMMO_SELECT] = {
        onEnter = function()
            local selectedItem = GetSelectedItem(selectedRing)
            SaveItemData(selectedItem)
            DeleteChosenAmmo()
            SetupSecondaryRing(RING.AMMO, combineItem1)
            TextChannels.SetText("SUB_HEADER", "choose_ammo", true)
            
            -- Track ammo preferences
            InventoryStateMachine.stateData = {
                weaponID = combineItem1,
                lastSelectedAmmo = nil,
                switchCount = 0,  -- How many times user switched ammo
                preferredAmmo = nil  -- Learn user's preference
            }
            
            InventoryStateMachine.phase = StatePhase.OPENING
        end,
        
        onUpdate = function()
            local data = InventoryStateMachine.stateData
            
            if InventoryStateMachine.phase == StatePhase.OPENING then
                if AnimateInventory(INVENTORY_MODE.AMMO_SELECT_OPEN) then
                    InventoryStateMachine.phase = StatePhase.ACTIVE
                end
                
            elseif InventoryStateMachine.phase == StatePhase.ACTIVE then
                local selectedItem = GetSelectedItem(selectedRing)
                RotateItem(tostring(selectedItem.objectID))
                DrawItemLabel(selectedItem, false)
                
                -- Track ammo switching
                if selectedItem.objectID ~= data.lastSelectedAmmo then
                    data.switchCount = data.switchCount + 1
                    data.lastSelectedAmmo = selectedItem.objectID
                end
                
                if performCombine then
                    local ammo = PICKUP_DATA.AMMO_SET[selectedItem.objectID]
                    Lara:SetAmmoType(ammo.slot)
                    
                    -- Remember preference (could save this globally)
                    data.preferredAmmo = selectedItem.objectID
                    
                    InventoryStateMachine.phase = StatePhase.CLOSING
                end
                
            elseif InventoryStateMachine.phase == StatePhase.CLOSING then
                TextChannels.SetText("SUB_HEADER", "choose_ammo", false)
                if AnimateInventory(INVENTORY_MODE.AMMO_SELECT_CLOSE) then
                    selectedRing = previousRing
                    return INVENTORY_MODE.ITEM_MENU
                end
            end
        end,
        
        onExit = function(nextState)
            performCombine = false
            InventoryStateMachine.stateData = {}
            return nextState
        end
    }
} ]]--

-- ============================================================================
-- STATE MACHINE ENGINE - SIMPLIFIED
-- ============================================================================

function InventoryStateMachine.Initialize(initialMode)
    InventoryStateMachine.currentMode = initialMode or 0
    InventoryStateMachine.phase = StatePhase.OPENING
    InventoryStateMachine.nextMode = nil
    
    -- Call onEnter for initial state
    local state = StateTransitions[InventoryStateMachine.currentMode]
    if state and state.onEnter then
        state.onEnter()
    end
end

function InventoryStateMachine.Update()
    local state = StateTransitions[InventoryStateMachine.currentMode]
    
    if not state then
        print("ERROR: Unknown state: " .. tostring(InventoryStateMachine.currentMode))
        return
    end
    
    -- Call onUpdate (handles all phases internally)
    local nextMode = nil
    if state.onUpdate then
        nextMode = state.onUpdate()
    end
    
    -- If onUpdate returned a state, transition to it
    if nextMode then
        InventoryStateMachine.TransitionTo(nextMode)
    end
end

function InventoryStateMachine.TransitionTo(nextMode)
    if not nextMode then return end
    
    local currentState = StateTransitions[InventoryStateMachine.currentMode]
    local nextState = StateTransitions[nextMode]
    
    if not nextState then
        print("ERROR: Cannot transition to unknown mode: " .. tostring(nextMode))
        return
    end
    
    -- Call current state's onExit
    if currentState and currentState.onExit then
        nextMode = currentState.onExit(nextMode) or nextMode
    end
    
    -- Transition to next state
    local previousMode = InventoryStateMachine.currentMode
    InventoryStateMachine.currentMode = nextMode
    InventoryStateMachine.phase = StatePhase.OPENING
    
    -- Call next state's onEnter
    if nextState.onEnter then
        nextState.onEnter()
    end
    
    if debug then
        print(string.format("State transition: %s → %s", 
            tostring(previousMode), 
            tostring(nextMode)))
    end
end

-- For states that need to trigger closing animation before transitioning
function InventoryStateMachine.BeginClosing()
    InventoryStateMachine.phase = StatePhase.CLOSING
end

-- ============================================================================
-- DEBUG HELPERS
-- ============================================================================

function InventoryStateMachine.GetDebugInfo()
    local stateDataStr = "none"
    if next(InventoryStateMachine.stateData) ~= nil then
        -- Format stateData for display
        local parts = {}
        for k, v in pairs(InventoryStateMachine.stateData) do
            if type(v) == "table" then
                table.insert(parts, k .. "=[table]")
            else
                table.insert(parts, k .. "=" .. tostring(v))
            end
        end
        stateDataStr = table.concat(parts, ", ")
    end
    
    return string.format("State: %s | Phase: %s | Data: {%s}", 
        tostring(InventoryStateMachine.currentMode),
        tostring(InventoryStateMachine.phase),
        stateDataStr)
end

function InventoryStateMachine.PrintDebug()
    print("=== State Machine Debug ===")
    print(InventoryStateMachine.GetDebugInfo())
    
    -- Print detailed state data
    if next(InventoryStateMachine.stateData) ~= nil then
        print("State Data Details:")
        for k, v in pairs(InventoryStateMachine.stateData) do
            if type(v) == "table" then
                print("  " .. k .. ": [table with " .. #v .. " items]")
            else
                print("  " .. k .. ": " .. tostring(v))
            end
        end
    end
    print("==========================")
end

-- ============================================================================
-- BENEFITS OF STATE-LOCAL VARIABLES
-- ============================================================================

--[[
STATE-LOCAL VARIABLES ARE PERFECT FOR:

1. Animation tracking
   - data.animationProgress = 0.0
   - data.startPosition = Vec3(...)
   - data.easingPhase = 0

2. User interaction tracking
   - data.attempts = 0  (failed combine attempts)
   - data.timeInState = 0  (how long user spent)
   - data.rotationSpeed = 0  (track momentum)

3. State-specific caching
   - data.compatibleItems = {...}  (pre-calculate once)
   - data.menuOptions = {...}
   - data.sortedList = {...}

4. Temporary UI state
   - data.hintShown = false
   - data.tutorialStep = 1
   - data.pulsePhase = 0  (for animations)

5. User preferences learning
   - data.preferredAmmo = itemID
   - data.lastSelection = index
   - data.quickSelectEnabled = false

BENEFITS:
No global pollution - variables only exist in this state
Automatic cleanup - cleared when state exits
Self-documenting - all state data in one place
Encapsulation - state manages its own data
No conflicts - different states can use same variable names

EXAMPLE:
Both EXAMINE and COMBINE can have data.timeInState without conflict!
Each state's data is isolated to that state.

PATTERN:
onEnter:  Initialize stateData = {...}
onUpdate: Use and modify stateData
onExit:   Clear stateData = {}
]]

-- ============================================================================
-- STATES CONSOLIDATED
-- ============================================================================

--[[
OLD STATES → NEW STATES:

INVENTORY_OPENING → INVENTORY (opening phase)
RING_OPENING → INVENTORY (opening phase)
INVENTORY → INVENTORY (active phase)
RING_ROTATE → RING_ROTATE (active phase only)
RING_CHANGE → RING_CHANGE (active phase only)
RING_CLOSING → CLOSE (active phase)
INVENTORY_EXIT → CLOSE (complete)

EXAMINE_OPEN → EXAMINE (opening phase)
EXAMINE → EXAMINE (active phase)
EXAMINE_RESET → EXAMINE (active phase, internal reset)
EXAMINE_CLOSE → EXAMINE (closing phase)

ITEM_SELECT → ITEM_MENU (opening phase)
ITEM_SELECTED → ITEM_MENU (active phase)
ITEM_DESELECT → ITEM_MENU (closing phase)

COMBINE_SETUP → COMBINE (setup phase)
COMBINE_RING_OPENING → COMBINE (opening phase)
COMBINE → COMBINE (active phase)
COMBINE_SUCCESS → COMBINE (active phase, success animation)
COMBINE_CLOSE → COMBINE (closing phase)
COMBINE_COMPLETE → COMBINE (complete)

AMMO_SELECT_SETUP → AMMO_SELECT (setup phase)
AMMO_SELECT_OPEN → AMMO_SELECT (opening phase)
AMMO_SELECT → AMMO_SELECT (active phase)
AMMO_SELECT_CLOSE → AMMO_SELECT (closing phase)

SAVE_SETUP → SAVE_MENU (setup phase)
SAVE_MENU → SAVE_MENU (active phase)
SAVE_CLOSE → SAVE_MENU (closing phase)

STATISTICS_OPEN → STATISTICS (opening phase)
STATISTICS → STATISTICS (active phase)
STATISTICS_CLOSE → STATISTICS (closing phase)

WEAPON_MODE_SETUP → WEAPON_MODE (setup phase)
WEAPON_MODE → WEAPON_MODE (active phase)
WEAPON_MODE_CLOSE → WEAPON_MODE (closing phase)

SEPARATE → SEPARATE (active phase)
SEPARATE_COMPLETE → SEPARATE (complete)

RESULT:
30+ states → ~12 states
Each state has clear lifecycle
Animation logic embedded in state
]]

-- ============================================================================
-- USAGE EXAMPLE WITH STATE-LOCAL VARIABLES
-- ============================================================================

--[[
FULL LIFECYCLE EXAMPLE WITH STATE-LOCAL DATA:

Frame 1: User enters COMBINE state
    → TransitionTo(COMBINE)
    → onEnter() runs:
        stateData = {
            item1 = revolver,
            attempts = 0,
            compatibleItems = [lasersight, silencer],
            pulsePhase = 0
        }
        phase = OPENING
    
Frame 2-15: Opening animation
    → onUpdate() runs each frame:
        if phase == OPENING then
            AnimateInventory()
        end
    → stateData persists across frames
    
Frame 16: Animation complete
    → onUpdate():
        phase = ACTIVE
        stateData.pulsePhase = 0.1  -- Start pulsing compatible items
    
Frame 17-100: User tries to combine
    → onUpdate():
        stateData.pulsePhase = 0.2, 0.3, 0.4...  (increments each frame)
        User selects wrong item
        stateData.attempts = 1  (track failed attempt)
        
    Frame 50:
        stateData.attempts = 2
        
    Frame 75:
        stateData.attempts = 3
        Show hint because attempts >= 3!
        
    Frame 100:
        User selects correct item (lasersight)
        CombineItems success!
        phase = CLOSING
    
Frame 101-115: Closing animation
    → onUpdate():
        AnimateInventory()
        stateData still available if needed
    
Frame 116: Exit
    → onExit() runs:
        stateData = {}  // All state-local data cleared!
        Cleanup global variables
    → Enter next state with fresh stateData

KEY POINT:
stateData is like a scratch pad for the state.
Initialize in onEnter, use in onUpdate, clear in onExit.
Each state gets its own isolated storage!
]]

--[[
REAL-WORLD EXAMPLE: EXAMINE STATE

Without state-local variables (BAD):
    -- Global pollution
    local examineTimeInState = 0
    local examineRotationSpeed = 0
    local examineShowingText = false
    local examineZoomLevel = 1.0
    -- These pollute global scope!
    -- Have to clean them up manually
    -- Name conflicts with other features

With state-local variables (GOOD):
    onEnter = function()
        InventoryStateMachine.stateData = {
            timeInState = 0,
            rotationSpeed = 0.0,
            showingText = false,
            zoomLevel = 1.0
        }
        -- Clean, isolated, self-documenting
    end
    
    onUpdate = function()
        local data = InventoryStateMachine.stateData
        data.timeInState = data.timeInState + 1
        
        -- Auto-show text after 2 seconds
        if data.timeInState > 60 then
            data.showingText = true
        end
    end
    
    onExit = function(nextState)
        InventoryStateMachine.stateData = {}
        -- Automatic cleanup!
    end

Benefits:
No global pollution
Clear what data belongs to this state
Automatic cleanup on state exit
Can use same names in different states (no conflicts)
Easy to debug - just print stateData
]]

return {
    StateMachine = InventoryStateMachine,
    StateTransitions = StateTransitions,
    StatePhase = StatePhase
}