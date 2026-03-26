--- Internal file used by the RingInventory module.
-- @module RingInventory.Text
-- @local

--External Modules
local Constants = require("Engine.RingInventory.Constants")
local Settings = require("Engine.RingInventory.Settings")
local Utilities = require("Engine.RingInventory.Utilities")

--Pointer to tables
local COLOR_MAP = Settings.ColorMap
local PICKUP_DATA = require("Engine.RingInventory.PickupData")

-- ============================================================================
-- TEXT CHANNEL SYSTEM
-- ============================================================================

local TextChannels = {}
local TextChannelStates = {}

-- Configuration
local TEXT_CONFIG = {
    FADE_SPEED = Settings.Animation.textAlphaSpeed,  -- Global fade speed
    MIN_ALPHA = Constants.ALPHA_MIN,
    MAX_ALPHA = Constants.ALPHA_MAX
}

-- ============================================================================
-- TEXT CHANNEL STRUCTURE
-- ============================================================================

--[[
    Each channel has:
    {
        name = "header",                          -- Unique identifier
        text = "actions_inventory",               -- Current display text
        position = Vec2(50, 4),                   -- Screen position (percentage)
        scale = 1.5,                              -- Text scale
        color = Color(255, 255, 255, 255),        -- Base color
        visible = true,                           -- Visibility flag
        flags = {                                 -- Display flags
            Strings.DisplayStringOption.CENTER,
            Strings.DisplayStringOption.SHADOW
        },
        translate = true,                         -- Use GetString() for localization
        fadeSpeed = nil                           -- Optional: override global fade speed
        -- Callbacks (optional)
        onTransitionComplete = config.onTransitionComplete,
        onShow = config.onShow,
        onHide = config.onHide
    }
]]

-- ============================================================================
-- INITIALIZE TEXT CHANNEL
-- ============================================================================

function TextChannels.Create(config)
    if not config.name then
        error("TextChannel requires a name")
    end

    -- Initialize channel state
    TextChannelStates[config.name] = {
        -- Configuration (immutable during lifetime)
        position = config.position or TEN.Vec2(50, 50),
        scale = config.scale or 1.0,
        color = config.color or TEN.Color(255, 255, 255, 255),
        flags = config.flags or {TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW},
        translate = config.translate ~= false,  -- Default true
        fadeSpeed = config.fadeSpeed or TEXT_CONFIG.FADE_SPEED,
        
        -- Current state (mutable)
        currentText = config.text or "",
        nextText = config.text or "",
        currentAlpha = config.visible and TEXT_CONFIG.MAX_ALPHA or TEXT_CONFIG.MIN_ALPHA,
        nextAlpha = TEXT_CONFIG.MIN_ALPHA,
        visible = config.visible or false,
        isTransitioning = false,
    }
    
    return config.name
end

-- ============================================================================
-- UPDATE TEXT CHANNEL
-- ============================================================================

function TextChannels.SetText(channelName, newText, shouldShow)
    local state = TextChannelStates[channelName]
    if not state then
        print("WARNING: Text channel '" .. channelName .. "' does not exist")
        return
    end
    
     -- Normalize text (treat nil as empty string)
    newText = newText or ""
    
    -- Check if visibility is changing
    local visibilityChanged = (shouldShow ~= nil and shouldShow ~= state.visible)
    
    -- Check if text is actually changing (compare against BOTH current AND next)
    local textChanged = (newText ~= "" and newText ~= state.currentText and newText ~= state.nextText)

    --check to prevent restarting mid-transition
    if state.isTransitioning and newText == state.nextText and not visibilityChanged then
        return
    end
    
    -- Only update if something actually changed
    if not visibilityChanged and not textChanged then
        -- Nothing changed, don't restart transition
        return
    end
    
    -- Handle visibility change
    if visibilityChanged then
        state.visible = shouldShow
        
        if shouldShow and state.onShow then
            state.onShow()
        elseif not shouldShow and state.onHide then
            state.onHide()
        end
    end
    
    -- Handle text change
    if textChanged then
        -- Text is actually different, start crossfade
        state.nextText = newText
        state.isTransitioning = true
        state.nextAlpha = TEXT_CONFIG.MIN_ALPHA
    end

end

function TextChannels.Show(channelName)
    local state = TextChannelStates[channelName]
    if state then
        state.visible = true
        
        if state.onShow then
            state.onShow()
        end
    end
end

function TextChannels.Hide(channelName)
    local state = TextChannelStates[channelName]
    if state then
        state.visible = false
        
        if state.onHide then
            state.onHide()
        end
        
    end
end

function TextChannels.SetPosition(channelName, position)
    local state = TextChannelStates[channelName]
    if state then
        state.position = position
    end
end

function TextChannels.SetScale(channelName, scale)
    local state = TextChannelStates[channelName]
    if state then
        state.scale = scale
    end
end

function TextChannels.SetColor(channelName, color)
    local state = TextChannelStates[channelName]
    if state then
        state.color = color
    end
end

function TextChannels.SetTranslate(channelName, translate)
    local state = TextChannelStates[channelName]
    if state then
        state.translate = translate
    end
end

-- ============================================================================
-- UPDATE ALL CHANNELS
-- ============================================================================

function TextChannels.Update()
    for channelName, state in pairs(TextChannelStates) do
        if state.isTransitioning then
            state.currentAlpha = math.max(state.currentAlpha - state.fadeSpeed, TEXT_CONFIG.MIN_ALPHA)
            state.nextAlpha = math.min(state.nextAlpha + state.fadeSpeed, TEXT_CONFIG.MAX_ALPHA)

            if state.currentAlpha <= TEXT_CONFIG.MIN_ALPHA and state.nextAlpha >= TEXT_CONFIG.MAX_ALPHA then
                -- Normal completion
                state.currentText = state.nextText
                state.currentAlpha = state.visible and TEXT_CONFIG.MAX_ALPHA or TEXT_CONFIG.MIN_ALPHA
                state.nextAlpha = TEXT_CONFIG.MIN_ALPHA
                state.isTransitioning = false
                
                if state.onTransitionComplete then
                    state.onTransitionComplete(state.currentText)
                end
            elseif state.currentAlpha <= TEXT_CONFIG.MIN_ALPHA and not state.visible then
                -- Stuck fading out while invisible - force complete
                state.currentText = state.nextText
                state.currentAlpha = TEXT_CONFIG.MIN_ALPHA
                state.nextAlpha = TEXT_CONFIG.MIN_ALPHA
                state.isTransitioning = false
            end
        else
            -- Not transitioning, just handle visibility fade
            if state.visible then
                state.currentAlpha = math.min(state.currentAlpha + state.fadeSpeed, TEXT_CONFIG.MAX_ALPHA)
            else
                state.currentAlpha = math.max(state.currentAlpha - state.fadeSpeed, TEXT_CONFIG.MIN_ALPHA)
            end
        end
    end
end

-- ============================================================================
-- RENDER CHANNEL
-- ============================================================================

function TextChannels.Draw(channelName)
    local state = TextChannelStates[channelName]
    if not state then return end
  
    -- Skip if completely invisible
    if state.currentAlpha <= 0 and state.nextAlpha <= 0 then
        return
    end
    
    local position = TEN.Util.PercentToScreen(state.position)
    
    -- Draw current text (fading out)
    if state.currentAlpha > 0 and state.currentText ~= "" then  -- ADD CHECK
        local textObj = TEN.Strings.DisplayString(
            state.currentText,
            position,
            state.scale,
            Utilities.ColorCombine(state.color, state.currentAlpha),
            state.translate,
            state.flags
        )
        TEN.Strings.ShowString(textObj, 1 / 30)
    end
    
    -- Draw next text (fading in) - only during transition
    if state.isTransitioning and state.nextAlpha > 0 and state.nextText ~= "" then  -- ADD CHECK
        local textObj = TEN.Strings.DisplayString(
            state.nextText,
            position,
            state.scale,
            Utilities.ColorCombine(state.color, state.nextAlpha),
            state.translate,
            state.flags
        )
        TEN.Strings.ShowString(textObj, 1 / 30)
    end
end

-- ============================================================================
-- RENDER ALL VISIBLE CHANNELS
-- ============================================================================

function TextChannels.DrawAll()
    for channelName, state in pairs(TextChannelStates) do
        if state.visible or state.currentAlpha > 0 or state.isTransitioning then
            TextChannels.Draw(channelName)
        end
    end
end

-- ============================================================================
-- QUERY FUNCTIONS
-- ============================================================================

function TextChannels.IsTransitioning(channelName)
    local state = TextChannelStates[channelName]
    return state and state.isTransitioning or false
end

function TextChannels.GetText(channelName)
    local state = TextChannelStates[channelName]
    return state and state.currentText or nil
end

function TextChannels.IsVisible(channelName)
    local state = TextChannelStates[channelName]
    return state and state.visible or false
end

function TextChannels.GetAlpha(channelName)
    local state = TextChannelStates[channelName]
    return state and state.currentAlpha or 0
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

function TextChannels.Destroy(channelName)
    TextChannelStates[channelName] = nil
end

function TextChannels.DestroyAll()
    TextChannelStates = {}
end

-- ============================================================================
-- ADVANCED: CHANNEL GROUPS
-- ============================================================================

local TextChannelGroups = {}

function TextChannels.ShowGroup(groupName)
    local group = TextChannelGroups[groupName]
    if not group then return end
    
    for _, channelName in ipairs(group) do
        TextChannels.Show(channelName)
    end
end

function TextChannels.HideGroup(groupName)
    local group = TextChannelGroups[groupName]
    if not group then return end
    
    for _, channelName in ipairs(group) do
        TextChannels.Hide(channelName)
    end
end

function TextChannels.DrawGroup(groupName)
    local group = TextChannelGroups[groupName]
    if not group then return end
    
    for _, channelName in ipairs(group) do
        TextChannels.Draw(channelName)
    end
end

function TextChannels.AddToGroup(groupName, channelName)
    if not groupName or not channelName then
        return
    end

    -- Create group if it doesn't exist
    local group = TextChannelGroups[groupName]
    if not group then
        group = {}
        TextChannelGroups[groupName] = group
    end

    -- Prevent duplicates
    for _, existingChannel in ipairs(group) do
        if existingChannel == channelName then
            return
        end
    end

    table.insert(group, channelName)
end

function TextChannels.RemoveFromGroup(groupName, channelName)
    local group = TextChannelGroups[groupName]
    if not group then
        return
    end

    for i = #group, 1, -1 do
        if group[i] == channelName then
            table.remove(group, i)
            break
        end
    end

    -- Optional: clean up empty groups
    if #group == 0 then
        TextChannelGroups[groupName] = nil
    end
end

-- ============================================================================
-- TEXT SETUP
-- ============================================================================
TextChannels.CONFIGS = {
    HEADER = 
    {
        name = "HEADER",                 -- Unique identifier
        text = "",               -- Current display text
        position = TEN.Vec2(50, 4),                   -- Screen position (percentage)
        scale = 1.5,                              -- Text scale
        color = COLOR_MAP.headerText,        -- Base color
        visible = false,                           -- Visibility flag
        flags = 
        {                                 -- Display flags
            TEN.Strings.DisplayStringOption.CENTER,
            TEN.Strings.DisplayStringOption.SHADOW
        },
        translate = true,                         -- Use GetString() for localization
    },
    SUB_HEADER = 
    {
        name = "SUB_HEADER",                 
        text = "",               
        position = TEN.Vec2(50, 40.3),                   
        scale = 0.9,                             
        color = COLOR_MAP.headerText,        
        visible = false,                           
        flags = 
        {                                
            TEN.Strings.DisplayStringOption.CENTER,
            TEN.Strings.DisplayStringOption.SHADOW
        },
        translate = true,
    },
    ITEM_LABEL_PRIMARY = 
    {
        name = "ITEM_LABEL_PRIMARY",                 
        text = "",               
        position = TEN.Vec2(50, 80),                   
        scale = 1.5,                             
        color = COLOR_MAP.plainText,        
        visible = false,                           
        flags = 
        {                                
            TEN.Strings.DisplayStringOption.CENTER,
            TEN.Strings.DisplayStringOption.SHADOW
        },
        translate = false,
    },
    ITEM_LABEL_SECONDARY = 
    {
        name = "ITEM_LABEL_SECONDARY",                 
        text = "",               
        position = TEN.Vec2(50, 90),              
        scale = 1,                          
        color = COLOR_MAP.plainText,    
        visible = false,                     
        flags = 
        {
            TEN.Strings.DisplayStringOption.CENTER,
            TEN.Strings.DisplayStringOption.SHADOW
        },
        translate = false,
    },
        CONTROLS_SELECT = 
    {
        name = "CONTROLS_SELECT",                 
        text = "",               
        position = TEN.Vec2(3, 87),              
        scale = 0.7,                          
        color = COLOR_MAP.plainText,    
        visible = false,                     
        flags = 
        {
            TEN.Strings.DisplayStringOption.SHADOW
        },
        translate = false,
    },
        CONTROLS_BACK = 
    {
        name = "CONTROLS_BACK",                 
        text =  "",               
        position = TEN.Vec2(97, 87),              
        scale = 0.7,                          
        color = COLOR_MAP.plainText,    
        visible = false,                  
        flags = 
        {
            TEN.Strings.DisplayStringOption.RIGHT,
            TEN.Strings.DisplayStringOption.SHADOW
        },
        translate = false,
    }
}

function TextChannels.Setup()
    TextChannels.Create(TextChannels.CONFIGS.HEADER)
    TextChannels.Create(TextChannels.CONFIGS.SUB_HEADER)
    TextChannels.Create(TextChannels.CONFIGS.ITEM_LABEL_PRIMARY)
    TextChannels.Create(TextChannels.CONFIGS.ITEM_LABEL_SECONDARY)
    TextChannels.Create(TextChannels.CONFIGS.CONTROLS_SELECT)
    TextChannels.Create(TextChannels.CONFIGS.CONTROLS_BACK)
    TextChannels.AddToGroup("INVENTORY_UI", "HEADER")
    TextChannels.AddToGroup("INVENTORY_UI", "SUB_HEADER")
    TextChannels.AddToGroup("INVENTORY_UI", "ITEM_LABEL_PRIMARY")
    TextChannels.AddToGroup("INVENTORY_UI", "ITEM_LABEL_SECONDARY")
    TextChannels.AddToGroup("INVENTORY_UI", "CONTROLS_SELECT")
    TextChannels.AddToGroup("INVENTORY_UI", "CONTROLS_BACK")
end


function TextChannels.CreateItemLabel(item)
    
    if item then
        local label = TEN.Flow.GetString(item.name)
        local count = item.count
        local result = ""
    
        if count == -1 then
            result = TEN.Flow.GetString("unlimited"):gsub(" ", ""):gsub("%%s", "").." "
        elseif count > 1 or item.type == PICKUP_DATA.TYPE.AMMO or item.type == PICKUP_DATA.TYPE.MEDIPACK then
            result = tostring(count).." x "
        end
    
        local string = result..label

        return string
    end

    return ""

end

function TextChannels.SetItemLabel(item)

    local text = TextChannels.CreateItemLabel(item)
    TextChannels.SetText("ITEM_LABEL_PRIMARY", text, true)

end

function TextChannels.SetItemSubLabel(item)

    local text = TextChannels.CreateItemLabel(item)
    TextChannels.SetText("ITEM_LABEL_SECONDARY", text, true)

end

return TextChannels