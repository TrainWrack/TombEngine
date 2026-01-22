-- MODERN ANIMATION SYSTEM
-- Declarative, chainable, state-integrated animations

-- ============================================================================
-- CORE INTERPOLATION (No Global State!)
-- ============================================================================

local Interpolate = {}

-- Easing functions
local Easing = {
    Linear = function(t) return t end,
    
    EaseInQuad = function(t) return t * t end,
    EaseOutQuad = function(t) return t * (2 - t) end,
    EaseInOutQuad = function(t)
        return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
    end,
    
    EaseInCubic = function(t) return t * t * t end,
    EaseOutCubic = function(t)
        local t1 = t - 1
        return t1 * t1 * t1 + 1
    end,
    EaseInOutCubic = function(t)
        return t < 0.5 and 4 * t * t * t or (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
    end,
    
    EaseInElastic = function(t)
        if t == 0 or t == 1 then return t end
        local p = 0.3
        local s = p / 4
        local t1 = t - 1
        return -(2 ^ (10 * t1) * math.sin((t1 - s) * (2 * math.pi) / p))
    end,
    
    EaseOutElastic = function(t)
        if t == 0 or t == 1 then return t end
        local p = 0.3
        local s = p / 4
        return 2 ^ (-10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
    end,
    
    Smoothstep = function(t)
        return t * t * (3 - 2 * t)
    end
}

-- Pure interpolation function (no state)
function Interpolate.Lerp(start, finish, t, easing)
    easing = easing or Easing.Linear
    local factor = easing(t)
    
    -- Number
    if type(start) == "number" then
        return start + (finish - start) * factor
    end
    
    -- Vec2
    if start.x and start.y and not start.z then
        return Vec2(
            start.x + (finish.x - start.x) * factor,
            start.y + (finish.y - start.y) * factor
        )
    end
    
    -- Vec3 or Rotation
    if start.x and start.y and start.z then
        local mt = getmetatable(start)
        
        -- Check if it's a Rotation (has __Signed method)
        if mt and mt.__Signed then
            return Rotation(
                start.x + (finish.x - start.x) * factor,
                start.y + (finish.y - start.y) * factor,
                start.z + (finish.z - start.z) * factor
            )
        else
            -- It's a Vec3
            return Vec3(
                start.x + (finish.x - start.x) * factor,
                start.y + (finish.y - start.y) * factor,
                start.z + (finish.z - start.z) * factor
            )
        end
    end
    
    -- Color
    if start.r and start.g and start.b then
        return Color(
            math.floor(start.r + (finish.r - start.r) * factor),
            math.floor(start.g + (finish.g - start.g) * factor),
            math.floor(start.b + (finish.b - start.b) * factor),
            math.floor(start.a + (finish.a - start.a) * factor)
        )
    end
    
    return finish  -- Fallback
end

-- ============================================================================
-- ANIMATION CLASS
-- ============================================================================

local Animation = {}
Animation.__index = Animation

function Animation.New(config)
    local anim = setmetatable({
        -- Core properties
        target = config.target,  -- What to animate (item, ring, etc.)
        property = config.property,  -- Which property (position, rotation, etc.)
        startValue = config.from,
        endValue = config.to,
        duration = config.duration or 0.5,  -- In seconds
        easing = config.easing or Easing.EaseOutCubic,
        
        -- Runtime state
        elapsed = 0,
        isComplete = false,
        isPlaying = false,
        isPaused = false,
        
        -- Callbacks
        onUpdate = config.onUpdate,
        onComplete = config.onComplete,
        onStart = config.onStart,
        
        -- Delay
        delay = config.delay or 0,
        delayElapsed = 0
    }, Animation)
    
    return anim
end

function Animation:Update(deltaTime)
    if not self.isPlaying or self.isPaused or self.isComplete then
        return false
    end
    
    -- Handle delay
    if self.delay > 0 and self.delayElapsed < self.delay then
        self.delayElapsed = self.delayElapsed + deltaTime
        return false
    end
    
    -- First frame after delay
    if self.elapsed == 0 and self.onStart then
        self.onStart(self.target)
    end
    
    -- Update elapsed time
    self.elapsed = math.min(self.elapsed + deltaTime, self.duration)
    local t = self.duration > 0 and (self.elapsed / self.duration) or 1
    
    -- Calculate current value
    local currentValue = Interpolate.Lerp(self.startValue, self.endValue, t, self.easing)
    
    -- Apply to target
    if self.target and self.property then
        self.target[self.property] = currentValue
    end
    
    -- Callback
    if self.onUpdate then
        self.onUpdate(currentValue, t, self.target)
    end
    
    -- Check completion
    if self.elapsed >= self.duration then
        self.isComplete = true
        self.isPlaying = false
        
        if self.onComplete then
            self.onComplete(self.target)
        end
        
        return true  -- Animation complete
    end
    
    return false  -- Still animating
end

function Animation:Play()
    self.isPlaying = true
    self.isPaused = false
    return self
end

function Animation:Pause()
    self.isPaused = true
    return self
end

function Animation:Resume()
    self.isPaused = false
    return self
end

function Animation:Reset()
    self.elapsed = 0
    self.delayElapsed = 0
    self.isComplete = false
    self.isPlaying = false
    return self
end

function Animation:Stop()
    self.isPlaying = false
    self.isComplete = true
    return self
end

-- ============================================================================
-- ANIMATION SEQUENCE (Chain multiple animations)
-- ============================================================================

local AnimationSequence = {}
AnimationSequence.__index = AnimationSequence

function AnimationSequence.New()
    local seq = setmetatable({
        animations = {},
        currentIndex = 1,
        isComplete = false,
        isPlaying = false,
        loop = false
    }, AnimationSequence)
    
    return seq
end

function AnimationSequence:Add(animation)
    table.insert(self.animations, animation)
    return self
end

function AnimationSequence:SetLoop(loop)
    self.loop = loop
    return self
end

function AnimationSequence:Update(deltaTime)
    if not self.isPlaying or self.isComplete then
        return false
    end
    
    if #self.animations == 0 then
        self.isComplete = true
        return true
    end
    
    local currentAnim = self.animations[self.currentIndex]
    if not currentAnim then
        self.isComplete = true
        return true
    end
    
    -- Play current animation if not started
    if not currentAnim.isPlaying then
        currentAnim:Play()
    end
    
    -- Update current animation
    local complete = currentAnim:Update(deltaTime)
    
    if complete then
        -- Move to next animation
        self.currentIndex = self.currentIndex + 1
        
        if self.currentIndex > #self.animations then
            if self.loop then
                -- Restart sequence
                self:Reset()
                self:Play()
            else
                self.isComplete = true
                return true
            end
        end
    end
    
    return false
end

function AnimationSequence:Play()
    self.isPlaying = true
    return self
end

function AnimationSequence:Reset()
    self.currentIndex = 1
    self.isComplete = false
    self.isPlaying = false
    
    for _, anim in ipairs(self.animations) do
        anim:Reset()
    end
    
    return self
end

-- ============================================================================
-- ANIMATION GROUP (Play multiple animations simultaneously)
-- ============================================================================

local AnimationGroup = {}
AnimationGroup.__index = AnimationGroup

function AnimationGroup.New()
    local group = setmetatable({
        animations = {},
        isComplete = false,
        isPlaying = false
    }, AnimationGroup)
    
    return group
end

function AnimationGroup:Add(animation)
    table.insert(self.animations, animation)
    return self
end

function AnimationGroup:Update(deltaTime)
    if not self.isPlaying or self.isComplete then
        return false
    end
    
    if #self.animations == 0 then
        self.isComplete = true
        return true
    end
    
    local allComplete = true
    
    for _, anim in ipairs(self.animations) do
        if not anim.isPlaying then
            anim:Play()
        end
        
        local complete = anim:Update(deltaTime)
        if not complete then
            allComplete = false
        end
    end
    
    if allComplete then
        self.isComplete = true
        return true
    end
    
    return false
end

function AnimationGroup:Play()
    self.isPlaying = true
    return self
end

function AnimationGroup:Reset()
    self.isComplete = false
    self.isPlaying = false
    
    for _, anim in ipairs(self.animations) do
        anim:Reset()
    end
    
    return self
end

-- ============================================================================
-- ANIMATION MANAGER (State-integrated)
-- ============================================================================

local AnimationManager = {
    animations = {},
    deltaTime = 1 / 30  -- Default to 30fps
}

function AnimationManager.Add(name, animation)
    AnimationManager.animations[name] = animation
    return animation
end

function AnimationManager.Play(name)
    local anim = AnimationManager.animations[name]
    if anim then
        anim:Play()
    end
    return anim
end

function AnimationManager.Stop(name)
    local anim = AnimationManager.animations[name]
    if anim then
        anim:Stop()
    end
end

function AnimationManager.Update()
    for name, anim in pairs(AnimationManager.animations) do
        if anim.isPlaying then
            local complete = anim:Update(AnimationManager.deltaTime)
            
            if complete then
                -- Remove completed animations
                AnimationManager.animations[name] = nil
            end
        end
    end
end

function AnimationManager.Clear(name)
    if name then
        AnimationManager.animations[name] = nil
    else
        AnimationManager.animations = {}
    end
end

function AnimationManager.IsPlaying(name)
    local anim = AnimationManager.animations[name]
    return anim and anim.isPlaying and not anim.isComplete
end

-- -- ============================================================================
-- -- PRESET ANIMATIONS (Common inventory animations)
-- -- ============================================================================

local Presets = {}

-- -- Ring opening animation
-- function Presets.RingOpen(ringName, ringCenter, ringRadius, targetAngle)
--     local group = AnimationGroup.New()
    
--     -- Radius animation
--     group:Add(Animation.New({
--         target = {value = 0},
--         property = "value",
--         from = 0,
--         to = ringRadius,
--         duration = 0.4,
--         easing = Easing.EaseOutCubic,
--         onUpdate = function(value)
--             TranslateRing(ringName, ringCenter, value, targetAngle, 0.3)
--         end
--     }))
    
--     -- Fade in animation
--     group:Add(Animation.New({
--         target = {value = 0},
--         property = "value",
--         from = 0,
--         to = 255,
--         duration = 0.4,
--         easing = Easing.EaseOutCubic,
--         onUpdate = function(value)
--             FadeRing(ringName, value, false)
--         end
--     }))
    
--     return group
-- end

-- -- Item selection animation
-- function Presets.ItemSelect(itemID, itemData)
--     local seq = AnimationSequence.New()
    
--     -- Move to center
--     seq:Add(Animation.New({
--         target = itemData,
--         property = "position",
--         from = Vec3(0, 200, 512),
--         to = Vec3(0, 0, 400),
--         duration = 0.3,
--         easing = Easing.EaseOutCubic,
--         onUpdate = function(pos)
--             local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(itemID))
--             if displayItem then
--                 displayItem:SetPosition(pos)
--             end
--         end
--     }))
    
--     -- Brighten
--     seq:Add(Animation.New({
--         target = {value = 128},
--         property = "value",
--         from = 128,
--         to = 255,
--         duration = 0.2,
--         easing = Easing.EaseOutQuad,
--         onUpdate = function(brightness)
--             SetItemBrightnessTarget(itemID, brightness > 200)
--         end
--     }))
    
--     return seq
-- end

-- -- Text crossfade (for TextChannels system)
-- function Presets.TextCrossfade(channelName, oldText, newText)
--     local group = AnimationGroup.New()
    
--     -- This is now handled by TextChannels system
--     -- But could be used for custom text effects
    
--     return group
-- end

-- -- Camera movement
-- function Presets.CameraMove(fromPos, toPos, fromTarget, toTarget, duration)
--     local group = AnimationGroup.New()
    
--     group:Add(Animation.New({
--         target = {value = fromPos},
--         property = "value",
--         from = fromPos,
--         to = toPos,
--         duration = duration or 0.5,
--         easing = Easing.EaseInOutCubic,
--         onUpdate = function(pos)
--             TEN.View.DisplayItem.SetCameraPosition(pos)
--         end
--     }))
    
--     group:Add(Animation.New({
--         target = {value = fromTarget},
--         property = "value",
--         from = fromTarget,
--         to = toTarget,
--         duration = duration or 0.5,
--         easing = Easing.EaseInOutCubic,
--         onUpdate = function(target)
--             TEN.View.DisplayItem.SetTargetPosition(target)
--         end
--     }))
    
--     return group
-- end

-- ============================================================================
-- INTEGRATION WITH STATE MACHINE
-- ============================================================================

-- Store animation in state data
function Presets.StateAnimation(stateMachine, animationName, animation)
    if not stateMachine.stateData.animations then
        stateMachine.stateData.animations = {}
    end
    
    stateMachine.stateData.animations[animationName] = animation
    animation:Play()
    
    return animation
end

-- Update all state animations
function Presets.UpdateStateAnimations(stateMachine, deltaTime)
    if not stateMachine.stateData.animations then
        return true  -- No animations, consider complete
    end
    
    local allComplete = true
    
    for name, anim in pairs(stateMachine.stateData.animations) do
        if anim.isPlaying then
            local complete = anim:Update(deltaTime)
            if not complete then
                allComplete = false
            end
        end
    end
    
    return allComplete
end

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

--[[
EXAMPLE 1: Simple animation

local fadeAnim = Animation.New({
    target = myObject,
    property = "alpha",
    from = 0,
    to = 255,
    duration = 0.5,
    easing = Easing.EaseOutCubic,
    onComplete = function()
        print("Fade complete!")
    end
})

fadeAnim:Play()
fadeAnim:Update(1/30)  -- Call each frame


EXAMPLE 2: Animation sequence

local seq = AnimationSequence.New()

seq:Add(Animation.New({
    target = item,
    property = "position",
    from = Vec3(0, 0, 0),
    to = Vec3(0, 100, 0),
    duration = 0.3
}))

seq:Add(Animation.New({
    target = item,
    property = "rotation",
    from = Rotation(0, 0, 0),
    to = Rotation(0, 360, 0),
    duration = 0.5
}))

seq:Play()


EXAMPLE 3: Animation group (parallel)

local group = AnimationGroup.New()

group:Add(Animation.New({
    target = item,
    property = "position",
    from = Vec3(0, 0, 0),
    to = Vec3(0, 100, 0),
    duration = 0.5
}))

group:Add(Animation.New({
    target = item,
    property = "scale",
    from = 1.0,
    to = 1.5,
    duration = 0.5
}))

group:Play()  // Both animations play at the same time


EXAMPLE 4: Integration with state machine

[INVENTORY_MODE.EXAMINE] = {
    onEnter = function()
        -- Create opening animation
        local openAnim = Presets.ItemSelect(itemID, itemData)
        Presets.StateAnimation(InventoryStateMachine, "opening", openAnim)
        
        InventoryStateMachine.phase = StatePhase.OPENING
    end,
    
    onUpdate = function()
        if InventoryStateMachine.phase == StatePhase.OPENING then
            -- Update animations
            if Presets.UpdateStateAnimations(InventoryStateMachine, 1/30) then
                InventoryStateMachine.phase = StatePhase.ACTIVE
            end
        elseif InventoryStateMachine.phase == StatePhase.ACTIVE then
            ExamineItem()
        end
    end
}


EXAMPLE 5: Using Animation Manager

-- Add animation
AnimationManager.Add("ringOpen", Presets.RingOpen("MAIN", center, radius, angle))
AnimationManager.Play("ringOpen")

// Each frame
AnimationManager.Update()

// Check if done
if not AnimationManager.IsPlaying("ringOpen") then
    -- Animation complete
end


EXAMPLE 6: Custom callback animation

local pulseAnim = Animation.New({
    target = {value = 0},
    property = "value",
    from = 0,
    to = 2 * math.pi,
    duration = 1.0,
    easing = Easing.Linear,
    onUpdate = function(value)
        local brightness = 200 + 55 * math.sin(value)
        SetItemColor(itemID, Color(brightness, brightness, brightness, 255))
    end
})

pulseAnim:SetLoop(true):Play()
]]

-- ============================================================================
-- COMPARISON: OLD VS NEW
-- ============================================================================

--[[
OLD SYSTEM (Batch Motion):

local ringAnimation = {
    {key = "ringRadius", type = Interpolate.Type.LINEAR, start = 0, finish = RING_RADIUS},
    {key = "ringAngle", type = Interpolate.Type.LINEAR, start = -360, finish = currentRingAngle},
    {key = "ringFade", type = Interpolate.Type.LINEAR, start = ALPHA_MIN, finish = ALPHA_MAX},
}

if PerformBatchMotion("RingOpening", ringAnimation, ANIMATION_TIME, true, ringName) then
    -- Complete
end

NEW SYSTEM:

local anim = AnimationGroup.New()
    :Add(Animation.New({from = 0, to = RING_RADIUS, duration = 0.4}))
    :Add(Animation.New({from = -360, to = currentRingAngle, duration = 0.4}))
    :Add(Animation.New({from = 0, to = 255, duration = 0.4}))

Presets.StateAnimation(StateMachine, "opening", anim)

if Presets.UpdateStateAnimations(StateMachine, 1/30) then
    -- Complete
end

-- BENEFITS:
--  No global state (LevelVars.Engine.InterpolateProgress removed)
--  Chainable API (animations.Add().Add().Play())
--  Built-in easing functions
--  Sequences (one after another)
--  Groups (parallel animations)
--  Cleaner callback system
--  State-integrated (stores in stateData)
--  Reusable presets
--  Better debugging (inspect animation objects)
--  More flexible (can pause, resume, reset)
-- ]]

return {
    Animation = Animation,
    AnimationSequence = AnimationSequence,
    AnimationGroup = AnimationGroup,
    AnimationManager = AnimationManager,
    Interpolate = Interpolate,
    Easing = Easing,
    Presets = Presets
}